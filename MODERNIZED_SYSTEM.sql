-- =====================================================
-- MODERNIZED SYSTEM (ENTITYDEV) - SYNC PROCEDURES
-- =====================================================

-- 1. Create database link to ALS replica (if not exists)
-- CREATE DATABASE LINK als_replica_link
-- CONNECT TO replica_user IDENTIFIED BY replica_password
-- USING 'ALS_REPLICA_TNS_ALIAS';

-- 2. Create local sequence control monitoring table
CREATE TABLE LOCAL_SEQUENCE_STATUS (
    SEQUENCE_NAME       VARCHAR2(128) PRIMARY KEY,
    LOCAL_CURRENT_VALUE NUMBER(18),
    REPLICA_CURRENT_VALUE NUMBER(18),
    LAST_SYNC_TIME      TIMESTAMP,
    SYNC_STATUS         VARCHAR2(20),
    ERROR_MESSAGE       VARCHAR2(4000)
);

-- 3. Create sequence synchronization procedure
CREATE OR REPLACE PROCEDURE SYNC_SEQUENCE_FROM_REPLICA (
    p_sequence_name IN VARCHAR2 DEFAULT 'TINSIDCNT'
) AS
    v_replica_value    NUMBER;
    v_local_value      NUMBER;
    v_difference       NUMBER;
    v_sql              VARCHAR2(500);
    v_error_msg        VARCHAR2(4000);
BEGIN
    -- Get current value from replicated control table
    BEGIN
        SELECT CURRENT_VALUE 
        INTO v_replica_value
        FROM replica_schema.SEQUENCE_CONTROL@als_replica_link
        WHERE SEQUENCE_NAME = p_sequence_name;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_error_msg := 'Sequence ' || p_sequence_name || ' not found in replica control table';
            RAISE_APPLICATION_ERROR(-20003, v_error_msg);
    END;
    
    -- Get current local sequence value
    SELECT last_number 
    INTO v_local_value
    FROM user_sequences 
    WHERE sequence_name = p_sequence_name;
    
    v_difference := v_replica_value - v_local_value;
    
    -- Only sync if there's a significant difference (beyond cache tolerance)
    IF ABS(v_difference) > 25 THEN  -- Allow for cache differences
        
        -- For Oracle 18c and later with RESTART capability
        BEGIN
            v_sql := 'ALTER SEQUENCE ' || p_sequence_name || 
                    ' RESTART START WITH ' || (v_replica_value + 1);
            EXECUTE IMMEDIATE v_sql;
            
            v_error_msg := 'SUCCESS: Synced ' || p_sequence_name || 
                          ' from ' || v_local_value || ' to ' || v_replica_value;
                          
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback: Drop and recreate sequence
                BEGIN
                    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || p_sequence_name;
                    
                    v_sql := 'CREATE SEQUENCE ' || p_sequence_name || 
                            ' START WITH ' || (v_replica_value + 1) ||
                            ' INCREMENT BY 1 MAXVALUE 9999999999 CACHE 20 NOCYCLE NOORDER';
                    EXECUTE IMMEDIATE v_sql;
                    
                    v_error_msg := 'SUCCESS: Recreated ' || p_sequence_name || 
                                  ' starting at ' || (v_replica_value + 1);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_error_msg := 'ERROR: ' || SQLERRM;
                        RAISE;
                END;
        END;
    ELSE
        v_error_msg := 'SKIPPED: Difference (' || v_difference || ') within tolerance';
    END IF;
    
    -- Update status table
    MERGE INTO LOCAL_SEQUENCE_STATUS lss
    USING (SELECT p_sequence_name as seq_name FROM dual) src
    ON (lss.SEQUENCE_NAME = src.seq_name)
    WHEN MATCHED THEN
        UPDATE SET 
            LOCAL_CURRENT_VALUE = v_local_value,
            REPLICA_CURRENT_VALUE = v_replica_value,
            LAST_SYNC_TIME = SYSTIMESTAMP,
            SYNC_STATUS = CASE 
                WHEN v_error_msg LIKE 'SUCCESS%' THEN 'SYNCED'
                WHEN v_error_msg LIKE 'SKIPPED%' THEN 'IN_SYNC' 
                ELSE 'ERROR' 
            END,
            ERROR_MESSAGE = v_error_msg
    WHEN NOT MATCHED THEN
        INSERT (SEQUENCE_NAME, LOCAL_CURRENT_VALUE, REPLICA_CURRENT_VALUE, 
                LAST_SYNC_TIME, SYNC_STATUS, ERROR_MESSAGE)
        VALUES (p_sequence_name, v_local_value, v_replica_value,
                SYSTIMESTAMP, 
                CASE 
                    WHEN v_error_msg LIKE 'SUCCESS%' THEN 'SYNCED'
                    WHEN v_error_msg LIKE 'SKIPPED%' THEN 'IN_SYNC' 
                    ELSE 'ERROR' 
                END,
                v_error_msg);
                
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE(v_error_msg);
    
EXCEPTION
    WHEN OTHERS THEN
        v_error_msg := 'FATAL ERROR: ' || SQLERRM;
        
        -- Log the error
        MERGE INTO LOCAL_SEQUENCE_STATUS lss
        USING (SELECT p_sequence_name as seq_name FROM dual) src
        ON (lss.SEQUENCE_NAME = src.seq_name)
        WHEN MATCHED THEN
            UPDATE SET 
                LAST_SYNC_TIME = SYSTIMESTAMP,
                SYNC_STATUS = 'ERROR',
                ERROR_MESSAGE = v_error_msg
        WHEN NOT MATCHED THEN
            INSERT (SEQUENCE_NAME, LAST_SYNC_TIME, SYNC_STATUS, ERROR_MESSAGE)
            VALUES (p_sequence_name, SYSTIMESTAMP, 'ERROR', v_error_msg);
        
        COMMIT;
        RAISE;
END;
/

-- 4. Create monitoring view for easy status checking
CREATE OR REPLACE VIEW V_SEQUENCE_SYNC_STATUS AS
SELECT 
    lss.SEQUENCE_NAME,
    lss.LOCAL_CURRENT_VALUE,
    lss.REPLICA_CURRENT_VALUE,
    (lss.REPLICA_CURRENT_VALUE - lss.LOCAL_CURRENT_VALUE) AS DIFFERENCE,
    lss.SYNC_STATUS,
    lss.LAST_SYNC_TIME,
    CASE 
        WHEN ABS(lss.REPLICA_CURRENT_VALUE - lss.LOCAL_CURRENT_VALUE) <= 25 THEN 'WITHIN_TOLERANCE'
        WHEN lss.REPLICA_CURRENT_VALUE > lss.LOCAL_CURRENT_VALUE THEN 'LOCAL_BEHIND'
        ELSE 'LOCAL_AHEAD'
    END AS SYNC_HEALTH,
    lss.ERROR_MESSAGE
FROM LOCAL_SEQUENCE_STATUS lss;

-- 5. Create ETL-aware sync job with replication lag handling
CREATE OR REPLACE PROCEDURE SYNC_WITH_LAG_HANDLING (
    p_sequence_name IN VARCHAR2 DEFAULT 'TINSIDCNT',
    p_max_wait_seconds IN NUMBER DEFAULT 300  -- 5 minutes max wait
) AS
    v_replica_value     NUMBER;
    v_legacy_value      NUMBER;
    v_wait_count        NUMBER := 0;
    v_max_iterations    NUMBER := p_max_wait_seconds / 10; -- Check every 10 seconds
    v_replication_lag   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting ETL-aware sequence sync with lag handling...');
    
    -- Step 1: Wait for replication to catch up
    LOOP
        -- Get current value from legacy source (via database link)
        BEGIN
            EXECUTE IMMEDIATE 'SELECT CURRENT_VALUE FROM schema_name.SEQUENCE_CONTROL@legacy_direct_link WHERE SEQUENCE_NAME = :1'
            INTO v_legacy_value USING p_sequence_name;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Cannot access legacy direct - using replica value');
                v_legacy_value := NULL;
                EXIT; -- Proceed with replica value
        END;
        
        -- Get replicated value
        SELECT CURRENT_VALUE INTO v_replica_value
        FROM replica_schema.SEQUENCE_CONTROL@als_replica_link
        WHERE SEQUENCE_NAME = p_sequence_name;
        
        -- Calculate replication lag
        v_replication_lag := NVL(v_legacy_value - v_replica_value, 0);
        
        DBMS_OUTPUT.PUT_LINE('Iteration ' || v_wait_count || ': Legacy=' || 
                            NVL(TO_CHAR(v_legacy_value), 'N/A') || 
                            ', Replica=' || v_replica_value || 
                            ', Lag=' || v_replication_lag);
        
        -- Exit if replication is caught up or max wait reached
        IF v_replication_lag <= 1 OR v_wait_count >= v_max_iterations THEN
            EXIT;
        END IF;
        
        -- Wait 10 seconds before checking again
        DBMS_LOCK.SLEEP(10);
        v_wait_count := v_wait_count + 1;
    END LOOP;
    
    -- Step 2: Proceed with normal sync using replica value
    IF v_replication_lag > 1 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Proceeding with replication lag of ' || v_replication_lag);
    END IF;
    
    -- Use the standard sync procedure
    SYNC_SEQUENCE_FROM_REPLICA(p_sequence_name);
    
    DBMS_OUTPUT.PUT_LINE('ETL-aware sync completed.');
END;
/

-- 5a. Create multiple sync job schedules based on ETL timing
-- Job 1: Pre-ETL sync (runs before 3 AM ETL)
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'PRE_ETL_SEQUENCE_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN SYNC_WITH_LAG_HANDLING(''TINSIDCNT'', 600); END;', -- 10 min wait
        start_date      => TRUNC(SYSDATE) + 1 + 2.75/24, -- 2:45 AM daily
        repeat_interval => 'FREQ=DAILY',
        enabled         => FALSE, -- Enable manually after testing
        comments        => 'Pre-ETL sequence sync - runs at 2:45 AM before ETL jobs'
    );
END;
/

-- Job 2: Regular monitoring sync (less frequent during ETL window)
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'REGULAR_SEQUENCE_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN 
                              IF TO_NUMBER(TO_CHAR(SYSDATE, ''HH24'')) NOT BETWEEN 2 AND 4 THEN
                                SYNC_SEQUENCE_FROM_REPLICA(''TINSIDCNT''); 
                              END IF;
                            END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY; INTERVAL=15', -- Every 15 minutes outside ETL window
        enabled         => TRUE,
        comments        => 'Regular sync - avoids ETL window (2-4 AM)'
    );
END;
/

-- Job 3: Post-ETL validation sync
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'POST_ETL_SEQUENCE_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN SYNC_WITH_LAG_HANDLING(''TINSIDCNT'', 300); GENERATE_DAILY_SEQUENCE_REPORT; END;',
        start_date      => TRUNC(SYSDATE) + 1 + 4.25/24, -- 4:15 AM daily
        repeat_interval => 'FREQ=DAILY',
        enabled         => FALSE, -- Enable manually after testing
        comments        => 'Post-ETL sync and validation - runs at 4:15 AM after ETL completion'
    );
END;
/

-- 6. Create manual verification procedure
CREATE OR REPLACE PROCEDURE VERIFY_SEQUENCE_SYNC AS
    v_count NUMBER;
BEGIN
    -- Check sync status
    SELECT COUNT(*) INTO v_count
    FROM V_SEQUENCE_SYNC_STATUS
    WHERE SYNC_HEALTH != 'WITHIN_TOLERANCE'
    AND SEQUENCE_NAME = 'TINSIDCNT';
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: TINSIDCNT sequence out of sync!');
        
        FOR rec IN (SELECT * FROM V_SEQUENCE_SYNC_STATUS 
                   WHERE SEQUENCE_NAME = 'TINSIDCNT') LOOP
            DBMS_OUTPUT.PUT_LINE('Local: ' || rec.LOCAL_CURRENT_VALUE || 
                               ', Replica: ' || rec.REPLICA_CURRENT_VALUE ||
                               ', Difference: ' || rec.DIFFERENCE ||
                               ', Status: ' || rec.SYNC_HEALTH);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('SUCCESS: TINSIDCNT sequence is synchronized');
    END IF;
END;
/
