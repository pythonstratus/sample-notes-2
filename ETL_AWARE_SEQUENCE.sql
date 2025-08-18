-- =====================================================
-- COMPLETE ETL-AWARE SEQUENCE SYNCHRONIZATION SOLUTION
-- =====================================================
-- Version: 1.0
-- Date: August 18, 2025
-- Purpose: Synchronize TINSIDCNT sequence between Legacy (ALS) and Modernized (ENTITYDEV) systems
-- =====================================================

-- =====================================================
-- PART 1: LEGACY SYSTEM (ALS) SETUP
-- =====================================================

-- 1.1 Create sequence control table
CREATE TABLE SEQUENCE_CONTROL (
    SEQUENCE_NAME     VARCHAR2(128) PRIMARY KEY,
    CURRENT_VALUE     NUMBER(18) NOT NULL,
    LAST_UPDATED      TIMESTAMP DEFAULT SYSTIMESTAMP,
    UPDATED_BY        VARCHAR2(50) DEFAULT USER,
    CACHE_SIZE        NUMBER(10) DEFAULT 20,
    STATUS            VARCHAR2(10) DEFAULT 'ACTIVE'
);

-- 1.2 Create supporting tables
CREATE TABLE SEQUENCE_CONTROL_LOG (
    LOG_ID          NUMBER GENERATED ALWAYS AS IDENTITY,
    SEQUENCE_NAME   VARCHAR2(128),
    ERROR_MESSAGE   VARCHAR2(4000),
    ERROR_TIME      TIMESTAMP,
    RESOLVED_FLAG   CHAR(1) DEFAULT 'N'
);

-- 1.3 Create indexes
CREATE INDEX IDX_SEQ_CTRL_UPDATED ON SEQUENCE_CONTROL(LAST_UPDATED);

-- 1.4 Initialize with current TINSIDCNT value
-- IMPORTANT: Replace 254223193 with actual current value from DBA_SEQUENCES
INSERT INTO SEQUENCE_CONTROL (
    SEQUENCE_NAME, 
    CURRENT_VALUE, 
    CACHE_SIZE,
    UPDATED_BY
) VALUES (
    'TINSIDCNT', 
    254223193,  -- *** REPLACE WITH ACTUAL CURRENT VALUE ***
    20,
    'INITIAL_SETUP'
);

COMMIT;

-- 1.5 Create sequence management functions
CREATE OR REPLACE FUNCTION GET_NEXT_SEQUENCE_VALUE (
    p_sequence_name IN VARCHAR2
) RETURN NUMBER AS
    v_next_value NUMBER;
BEGIN
    UPDATE SEQUENCE_CONTROL 
    SET CURRENT_VALUE = CURRENT_VALUE + 1,
        LAST_UPDATED = SYSTIMESTAMP,
        UPDATED_BY = USER
    WHERE SEQUENCE_NAME = p_sequence_name
    RETURNING CURRENT_VALUE INTO v_next_value;
    
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Sequence ' || p_sequence_name || ' not found');
    END IF;
    
    COMMIT;
    RETURN v_next_value;
END;
/

-- 1.6 Create update procedure
CREATE OR REPLACE PROCEDURE UPDATE_SEQUENCE_CONTROL (
    p_sequence_name IN VARCHAR2,
    p_increment_by  IN NUMBER DEFAULT 1
) AS
    v_new_value NUMBER;
BEGIN
    UPDATE SEQUENCE_CONTROL 
    SET CURRENT_VALUE = CURRENT_VALUE + p_increment_by,
        LAST_UPDATED = SYSTIMESTAMP,
        UPDATED_BY = USER
    WHERE SEQUENCE_NAME = p_sequence_name
    RETURNING CURRENT_VALUE INTO v_new_value;
    
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Sequence ' || p_sequence_name || ' not found');
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Sequence ' || p_sequence_name || ' updated to: ' || v_new_value);
END;
/

-- 1.7 Grant privileges (adjust schema names as needed)
GRANT SELECT, INSERT, UPDATE ON SEQUENCE_CONTROL TO ggadmin;
GRANT SELECT, INSERT, UPDATE ON SEQUENCE_CONTROL TO your_app_user;
GRANT EXECUTE ON GET_NEXT_SEQUENCE_VALUE TO your_app_user;
GRANT EXECUTE ON UPDATE_SEQUENCE_CONTROL TO your_app_user;

-- =====================================================
-- PART 2: GOLDENGATE CONFIGURATION
-- =====================================================

-- 2.1 Enable supplemental logging (run as SYSDBA)
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- 2.2 Extract parameter file (create as EXT_SEQ_CTRL.prm)
/*
EXTRACT EXT_SEQ_CTRL
USERID ggadmin, PASSWORD your_gg_password
RMTHOST entitydev_hostname, MGRPORT 7809
RMTTRAIL ./dirdat/sc

TRANLOGOPTIONS DBLOGREADER
DBOPTIONS ALLOWUNUSEDCOLUMN

-- Capture sequence control table changes only
TABLE your_schema.SEQUENCE_CONTROL;
*/

-- 2.3 Replicat parameter file (create as REP_SEQ_CTRL.prm)
/*
REPLICAT REP_SEQ_CTRL
USERID ggadmin, PASSWORD your_gg_password
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_seq_ctrl.dsc, PURGE

HANDLECOLLISIONS
DBOPTIONS SUPPRESSTRIGGERS

-- Map sequence control table to replica schema
MAP your_schema.SEQUENCE_CONTROL, TARGET replica_schema.SEQUENCE_CONTROL;
*/

-- =====================================================
-- PART 3: MODERNIZED SYSTEM (ENTITYDEV) SETUP
-- =====================================================

-- 3.1 Create database links (adjust connection details)
/*
CREATE DATABASE LINK als_replica_link
CONNECT TO replica_user IDENTIFIED BY replica_password
USING 'ALS_REPLICA_TNS_ALIAS';

CREATE DATABASE LINK legacy_direct_link
CONNECT TO legacy_user IDENTIFIED BY legacy_password  
USING 'ALS_DIRECT_TNS_ALIAS';
*/

-- 3.2 Create monitoring and control tables
CREATE TABLE LOCAL_SEQUENCE_STATUS (
    SEQUENCE_NAME       VARCHAR2(128) PRIMARY KEY,
    LOCAL_CURRENT_VALUE NUMBER(18),
    REPLICA_CURRENT_VALUE NUMBER(18),
    LAST_SYNC_TIME      TIMESTAMP,
    SYNC_STATUS         VARCHAR2(20),
    ERROR_MESSAGE       VARCHAR2(4000)
);

CREATE TABLE SEQUENCE_SYNC_CHECKPOINT (
    CHECKPOINT_ID    NUMBER GENERATED ALWAYS AS IDENTITY,
    CHECKPOINT_TIME  TIMESTAMP,
    SEQUENCE_NAME    VARCHAR2(128),
    LEGACY_VALUE     NUMBER,
    REPLICA_VALUE    NUMBER,
    MODERNIZED_VALUE NUMBER,
    CHECKPOINT_TYPE  VARCHAR2(50),
    ERROR_MESSAGE    VARCHAR2(4000),
    CREATED_BY       VARCHAR2(50) DEFAULT USER
);

CREATE TABLE REPLICATION_LAG_ALERTS (
    ALERT_ID      NUMBER GENERATED ALWAYS AS IDENTITY,
    ALERT_TIME    TIMESTAMP,
    SEQUENCE_NAME VARCHAR2(128),
    LAG_SECONDS   NUMBER,
    LEGACY_VALUE  NUMBER,
    REPLICA_VALUE NUMBER,
    RESOLVED_TIME TIMESTAMP,
    RESOLVED_BY   VARCHAR2(50)
);

-- 3.3 Create core synchronization procedure
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
    IF ABS(v_difference) > 25 THEN
        BEGIN
            -- For Oracle 18c and later with RESTART capability
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

-- 3.4 Create ETL-aware sync with lag handling
CREATE OR REPLACE PROCEDURE SYNC_WITH_LAG_HANDLING (
    p_sequence_name IN VARCHAR2 DEFAULT 'TINSIDCNT',
    p_max_wait_seconds IN NUMBER DEFAULT 300
) AS
    v_replica_value     NUMBER;
    v_legacy_value      NUMBER;
    v_wait_count        NUMBER := 0;
    v_max_iterations    NUMBER := p_max_wait_seconds / 10;
    v_replication_lag   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting ETL-aware sequence sync with lag handling...');
    
    -- Wait for replication to catch up
    LOOP
        -- Get current value from legacy source (if accessible)
        BEGIN
            EXECUTE IMMEDIATE 'SELECT CURRENT_VALUE FROM schema_name.SEQUENCE_CONTROL@legacy_direct_link WHERE SEQUENCE_NAME = :1'
            INTO v_legacy_value USING p_sequence_name;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Cannot access legacy direct - using replica value');
                v_legacy_value := NULL;
                EXIT;
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
    
    -- Proceed with normal sync using replica value
    IF v_replication_lag > 1 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Proceeding with replication lag of ' || v_replication_lag);
    END IF;
    
    SYNC_SEQUENCE_FROM_REPLICA(p_sequence_name);
    DBMS_OUTPUT.PUT_LINE('ETL-aware sync completed.');
END;
/

-- 3.5 Create ETL coordination procedures
CREATE OR REPLACE PROCEDURE PRE_ETL_SEQUENCE_SYNC AS
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_end_time   TIMESTAMP;
    v_duration   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== PRE-ETL SEQUENCE SYNCHRONIZATION ===');
    DBMS_OUTPUT.PUT_LINE('Start Time: ' || TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS.FF3'));
    
    -- Step 1: Wait for any ongoing replication to complete
    DBMS_OUTPUT.PUT_LINE('Step 1: Checking replication lag...');
    SYNC_WITH_LAG_HANDLING('TINSIDCNT', 600); -- Wait up to 10 minutes
    
    -- Step 2: Create a checkpoint for comparison
    INSERT INTO SEQUENCE_SYNC_CHECKPOINT (
        checkpoint_time, sequence_name, legacy_value, replica_value, modernized_value, checkpoint_type
    )
    SELECT 
        SYSTIMESTAMP, 'TINSIDCNT',
        NVL((SELECT CURRENT_VALUE FROM schema_name.SEQUENCE_CONTROL@legacy_direct_link WHERE SEQUENCE_NAME = 'TINSIDCNT'), -1),
        (SELECT CURRENT_VALUE FROM replica_schema.SEQUENCE_CONTROL@als_replica_link WHERE SEQUENCE_NAME = 'TINSIDCNT'),
        (SELECT last_number FROM user_sequences WHERE sequence_name = 'TINSIDCNT'),
        'PRE_ETL'
    FROM dual;
    COMMIT;
    
    v_end_time := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end_time - v_start_time));
    
    DBMS_OUTPUT.PUT_LINE('Pre-ETL sync completed in ' || ROUND(v_duration, 2) || ' seconds');
    DBMS_OUTPUT.PUT_LINE('=== END PRE-ETL SYNC ===');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR in pre-ETL sync: ' || SQLERRM);
        INSERT INTO SEQUENCE_SYNC_CHECKPOINT (
            checkpoint_time, sequence_name, checkpoint_type, error_message
        ) VALUES (
            SYSTIMESTAMP, 'TINSIDCNT', 'PRE_ETL_ERROR', SQLERRM
        );
        COMMIT;
        RAISE;
END;
/

-- 3.6 Create monitoring views
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

CREATE OR REPLACE VIEW V_ETL_COORDINATION_STATUS AS
WITH current_time AS (
    SELECT 
        SYSDATE as current_dt,
        TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) as current_hour,
        TO_NUMBER(TO_CHAR(SYSDATE, 'MI')) as current_minute
    FROM dual
),
etl_window AS (
    SELECT 
        CASE 
            WHEN current_hour = 2 AND current_minute >= 45 THEN 'PRE_ETL_SYNC_WINDOW'
            WHEN current_hour = 3 THEN 'ETL_ACTIVE_WINDOW' 
            WHEN current_hour = 4 AND current_minute <= 30 THEN 'POST_ETL_VALIDATION_WINDOW'
            ELSE 'NORMAL_OPERATIONS'
        END as etl_phase,
        CASE 
            WHEN current_hour BETWEEN 2 AND 4 THEN 'Y'
            ELSE 'N'
        END as in_etl_window
    FROM current_time
)
SELECT 
    ct.current_dt,
    ew.etl_phase,
    ew.in_etl_window,
    CASE ew.etl_phase
        WHEN 'PRE_ETL_SYNC_WINDOW' THEN 'Sequence sync should be running'
        WHEN 'ETL_ACTIVE_WINDOW' THEN 'ETL jobs active - avoid sequence changes'
        WHEN 'POST_ETL_VALIDATION_WINDOW' THEN 'Validation and reporting phase'
        ELSE 'Regular sync operations allowed'
    END as recommended_action
FROM current_time ct
CROSS JOIN etl_window ew;

-- 3.7 Create scheduled jobs
BEGIN
    -- Pre-ETL sync job (2:45 AM daily)
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'PRE_ETL_SEQUENCE_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN PRE_ETL_SEQUENCE_SYNC; END;',
        start_date      => TRUNC(SYSDATE) + 1 + 2.75/24,
        repeat_interval => 'FREQ=DAILY',
        enabled         => FALSE, -- Enable manually after testing
        comments        => 'Pre-ETL sequence sync - runs at 2:45 AM'
    );
    
    -- Regular monitoring sync (every 15 minutes, avoiding ETL window)
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'REGULAR_SEQUENCE_SYNC',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN 
                              IF TO_NUMBER(TO_CHAR(SYSDATE, ''HH24'')) NOT BETWEEN 2 AND 4 THEN
                                SYNC_SEQUENCE_FROM_REPLICA(''TINSIDCNT''); 
                              END IF;
                            END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY; INTERVAL=15',
        enabled         => FALSE, -- Enable manually after testing
        comments        => 'Regular sync - avoids ETL window'
    );
END;
/

-- 3.8 Create verification and testing procedures
CREATE OR REPLACE PROCEDURE VERIFY_SEQUENCE_SYNC AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM V_SEQUENCE_SYNC_STATUS
    WHERE SYNC_HEALTH != 'WITHIN_TOLERANCE'
    AND SEQUENCE_NAME = 'TINSIDCNT';
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: TINSIDCNT sequence out of sync!');
        FOR rec IN (SELECT * FROM V_SEQUENCE_SYNC_STATUS WHERE SEQUENCE_NAME = 'TINSIDCNT') LOOP
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

-- 3.9 Create emergency procedures
CREATE OR REPLACE PROCEDURE EMERGENCY_SEQUENCE_RESET AS
    v_max_tin_sid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('EMERGENCY: Resetting TINSIDCNT sequence...');
    
    -- Find maximum TIN_SID currently in use
    SELECT NVL(MAX(tin_sid), 0) INTO v_max_tin_sid FROM ent_table;
    DBMS_OUTPUT.PUT_LINE('Maximum TIN_SID found in data: ' || v_max_tin_sid);
    
    -- Reset sequence to start after maximum value
    EXECUTE IMMEDIATE 'DROP SEQUENCE TINSIDCNT';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE TINSIDCNT START WITH ' || (v_max_tin_sid + 1) ||
                     ' INCREMENT BY 1 MAXVALUE 9999999999 CACHE 20 NOCYCLE NOORDER';
    
    DBMS_OUTPUT.PUT_LINE('Emergency reset completed. New sequence starts at: ' || (v_max_tin_sid + 1));
END;
/

-- =====================================================
-- PART 4: TESTING AND VALIDATION
-- =====================================================

-- 4.1 Test basic sync functionality
EXEC SYNC_SEQUENCE_FROM_REPLICA('TINSIDCNT');

-- 4.2 Check sync status
SELECT * FROM V_SEQUENCE_SYNC_STATUS;

-- 4.3 Verify ETL coordination status
SELECT * FROM V_ETL_COORDINATION_STATUS;

-- 4.4 Manual verification
EXEC VERIFY_SEQUENCE_SYNC;
