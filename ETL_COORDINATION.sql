-- =====================================================
-- ETL COORDINATION AND REPLICATION LAG HANDLING
-- =====================================================

-- 1. ETL Timing Coordination View
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

-- 2. Replication lag monitoring procedure
CREATE OR REPLACE PROCEDURE MONITOR_REPLICATION_LAG AS
    v_legacy_value    NUMBER;
    v_replica_value   NUMBER;
    v_lag_seconds     NUMBER;
    v_lag_threshold   NUMBER := 60; -- Alert if lag > 1 minute
    v_last_replica_update TIMESTAMP;
BEGIN
    -- Get values from both sources
    BEGIN
        SELECT CURRENT_VALUE INTO v_legacy_value
        FROM schema_name.SEQUENCE_CONTROL@legacy_direct_link
        WHERE SEQUENCE_NAME = 'TINSIDCNT';
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: Cannot access legacy system directly');
            v_legacy_value := NULL;
    END;
    
    SELECT CURRENT_VALUE, LAST_UPDATED INTO v_replica_value, v_last_replica_update
    FROM replica_schema.SEQUENCE_CONTROL@als_replica_link
    WHERE SEQUENCE_NAME = 'TINSIDCNT';
    
    -- Calculate time-based lag
    v_lag_seconds := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_last_replica_update));
    
    -- Report status
    DBMS_OUTPUT.PUT_LINE('=== REPLICATION LAG MONITORING ===');
    DBMS_OUTPUT.PUT_LINE('Legacy Value: ' || NVL(TO_CHAR(v_legacy_value), 'UNAVAILABLE'));
    DBMS_OUTPUT.PUT_LINE('Replica Value: ' || v_replica_value);
    DBMS_OUTPUT.PUT_LINE('Value Difference: ' || NVL(TO_CHAR(v_legacy_value - v_replica_value), 'N/A'));
    DBMS_OUTPUT.PUT_LINE('Last Replica Update: ' || TO_CHAR(v_last_replica_update, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('Time Lag: ' || ROUND(v_lag_seconds, 2) || ' seconds');
    
    -- Alert logic
    IF v_lag_seconds > v_lag_threshold THEN
        DBMS_OUTPUT.PUT_LINE('ALERT: Replication lag exceeds threshold (' || v_lag_threshold || 's)');
        
        -- Log alert
        INSERT INTO REPLICATION_LAG_ALERTS (
            alert_time, sequence_name, lag_seconds, legacy_value, replica_value
        ) VALUES (
            SYSTIMESTAMP, 'TINSIDCNT', v_lag_seconds, v_legacy_value, v_replica_value
        );
        COMMIT;
    END IF;
END;
/

-- 3. Create replication lag alerts table
CREATE TABLE REPLICATION_LAG_ALERTS (
    alert_id      NUMBER GENERATED ALWAYS AS IDENTITY,
    alert_time    TIMESTAMP,
    sequence_name VARCHAR2(128),
    lag_seconds   NUMBER,
    legacy_value  NUMBER,
    replica_value NUMBER,
    resolved_time TIMESTAMP,
    resolved_by   VARCHAR2(50)
);

-- 4. Smart ETL coordination procedure
CREATE OR REPLACE PROCEDURE COORDINATE_ETL_SEQUENCE_SYNC AS
    v_etl_phase VARCHAR2(50);
    v_in_window CHAR(1);
    v_proceed   BOOLEAN := TRUE;
BEGIN
    -- Check current ETL phase
    SELECT etl_phase, in_etl_window 
    INTO v_etl_phase, v_in_window
    FROM V_ETL_COORDINATION_STATUS;
    
    DBMS_OUTPUT.PUT_LINE('Current ETL Phase: ' || v_etl_phase);
    
    CASE v_etl_phase
        WHEN 'PRE_ETL_SYNC_WINDOW' THEN
            -- 2:45-3:00 AM: Prepare for ETL
            DBMS_OUTPUT.PUT_LINE('Executing pre-ETL sequence synchronization...');
            PRE_ETL_SEQUENCE_SYNC;
            
        WHEN 'ETL_ACTIVE_WINDOW' THEN
            -- 3:00-4:00 AM: ETL running, minimal interference
            DBMS_OUTPUT.PUT_LINE('ETL active - monitoring only');
            MONITOR_REPLICATION_LAG;
            
        WHEN 'POST_ETL_VALIDATION_WINDOW' THEN
            -- 4:00-4:30 AM: Validate results
            DBMS_OUTPUT.PUT_LINE('Executing post-ETL validation...');
            POST_ETL_SEQUENCE_VALIDATION;
            
        ELSE
            -- Normal operations: regular sync
            DBMS_OUTPUT.PUT_LINE('Normal operations - executing regular sync');
            SYNC_SEQUENCE_FROM_REPLICA('TINSIDCNT');
    END CASE;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR in ETL coordination: ' || SQLERRM);
        -- Don't let sync errors block ETL processes
        NULL;
END;
/

-- 5. Emergency procedures for when things go wrong
CREATE OR REPLACE PROCEDURE EMERGENCY_ETL_RECOVERY AS
    v_max_legacy_tin   NUMBER;
    v_max_modern_tin   NUMBER;
    v_safe_start_value NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== EMERGENCY ETL RECOVERY ===');
    DBMS_OUTPUT.PUT_LINE('WARNING: This procedure should only be used when ETL processes have failed');
    
    -- Find maximum TIN_SID values from actual data
    SELECT NVL(MAX(tin_sid), 0) INTO v_max_legacy_tin
    FROM ent_table@als_replica_link
    WHERE created_date >= TRUNC(SYSDATE) - 1; -- Last day's data
    
    SELECT NVL(MAX(tin_sid), 0) INTO v_max_modern_tin  
    FROM ent_table
    WHERE created_date >= TRUNC(SYSDATE) - 1; -- Last day's data
    
    v_safe_start_value := GREATEST(v_max_legacy_tin, v_max_modern_tin) + 1000; -- Add buffer
    
    DBMS_OUTPUT.PUT_LINE('Max Legacy TIN_SID: ' || v_max_legacy_tin);
    DBMS_OUTPUT.PUT_LINE('Max Modern TIN_SID: ' || v_max_modern_tin);
    DBMS_OUTPUT.PUT_LINE('Safe restart value: ' || v_safe_start_value);
    
    -- Reset local sequence
    EXECUTE IMMEDIATE 'DROP SEQUENCE TINSIDCNT';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE TINSIDCNT START WITH ' || v_safe_start_value ||
                     ' INCREMENT BY 1 MAXVALUE 9999999999 CACHE 20 NOCYCLE NOORDER';
    
    -- Update control tables if possible
    BEGIN
        -- Update legacy control table
        UPDATE schema_name.SEQUENCE_CONTROL@legacy_direct_link
        SET CURRENT_VALUE = v_safe_start_value,
            LAST_UPDATED = SYSTIMESTAMP,
            UPDATED_BY = 'EMERGENCY_RECOVERY'
        WHERE SEQUENCE_NAME = 'TINSIDCNT';
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Legacy control table updated');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not update legacy control table: ' || SQLERRM);
    END;
    
    -- Log the recovery
    INSERT INTO SEQUENCE_SYNC_CHECKPOINT (
        checkpoint_time, sequence_name, modernized_value, checkpoint_type, error_message
    ) VALUES (
        SYSTIMESTAMP, 'TINSIDCNT', v_safe_start_value, 'EMERGENCY_RECOVERY',
        'Recovery from max values - Legacy: ' || v_max_legacy_tin || ', Modern: ' || v_max_modern_tin
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Emergency recovery completed. Sequence reset to: ' || v_safe_start_value);
    DBMS_OUTPUT.PUT_LINE('IMPORTANT: Coordinate with legacy team to ensure consistency');
    DBMS_OUTPUT.PUT_LINE('=== END EMERGENCY RECOVERY ===');
END;
/

-- 6. Comprehensive status dashboard procedure
CREATE OR REPLACE PROCEDURE ETL_SEQUENCE_DASHBOARD AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ETL SEQUENCE SYNCHRONIZATION DASHBOARD ===');
    DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Current ETL phase
    FOR rec IN (SELECT * FROM V_ETL_COORDINATION_STATUS) LOOP
        DBMS_OUTPUT.PUT_LINE('CURRENT STATUS:');
        DBMS_OUTPUT.PUT_LINE('  ETL Phase: ' || rec.etl_phase);
        DBMS_OUTPUT.PUT_LINE('  In ETL Window: ' || rec.in_etl_window);
        DBMS_OUTPUT.PUT_LINE('  Recommended Action: ' || rec.recommended_action);
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
    
    -- Sequence synchronization status
    DBMS_OUTPUT.PUT_LINE('SEQUENCE SYNC STATUS:');
    FOR rec IN (SELECT * FROM V_SEQUENCE_SYNC_STATUS WHERE SEQUENCE_NAME = 'TINSIDCNT') LOOP
        DBMS_OUTPUT.PUT_LINE('  Local Value: ' || rec.LOCAL_CURRENT_VALUE);
        DBMS_OUTPUT.PUT_LINE('  Replica Value: ' || rec.REPLICA_CURRENT_VALUE);
        DBMS_OUTPUT.PUT_LINE('  Difference: ' || rec.DIFFERENCE);
        DBMS_OUTPUT.PUT_LINE('  Health Status: ' || rec.SYNC_HEALTH);
        DBMS_OUTPUT.PUT_LINE('  Last Sync: ' || TO_CHAR(rec.LAST_SYNC_TIME, 'YYYY-MM-DD HH24:MI:SS'));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Recent checkpoints
    DBMS_OUTPUT.PUT_LINE('RECENT CHECKPOINTS (Last 24 hours):');
    FOR rec IN (
        SELECT checkpoint_type, checkpoint_time, legacy_value, modernized_value
        FROM SEQUENCE_SYNC_CHECKPOINT 
        WHERE checkpoint_time >= SYSDATE - 1
        AND sequence_name = 'TINSIDCNT'
        ORDER BY checkpoint_time DESC
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || TO_CHAR(rec.checkpoint_time, 'MM-DD HH24:MI') || 
                           ' [' || rec.checkpoint_type || '] ' ||
                           'Legacy=' || NVL(TO_CHAR(rec.legacy_value), 'N/A') ||
                           ', Modern=' || NVL(TO_CHAR(rec.modernized_value), 'N/A'));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Active alerts
    DECLARE
        v_alert_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_alert_count
        FROM REPLICATION_LAG_ALERTS
        WHERE resolved_time IS NULL;
        
        DBMS_OUTPUT.PUT_LINE('ACTIVE ALERTS: ' || v_alert_count);
        
        IF v_alert_count > 0 THEN
            FOR rec IN (
                SELECT alert_time, lag_seconds
                FROM REPLICATION_LAG_ALERTS
                WHERE resolved_time IS NULL
                ORDER BY alert_time DESC
                FETCH FIRST 3 ROWS ONLY
            ) LOOP
                DBMS_OUTPUT.PUT_LINE('  ' || TO_CHAR(rec.alert_time, 'MM-DD HH24:MI') ||
                                   ' - Lag: ' || ROUND(rec.lag_seconds, 1) || 's');
            END LOOP;
        END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== END DASHBOARD ===');
END;
/
