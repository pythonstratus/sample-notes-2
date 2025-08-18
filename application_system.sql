-- =====================================================
-- APPLICATION INTEGRATION AND TESTING
-- =====================================================

-- 1. Modified application code approach for Legacy system
-- Instead of: SELECT TINSIDCNT.NEXTVAL FROM DUAL
-- Use: SELECT GET_NEXT_SEQUENCE_VALUE('TINSIDCNT') FROM DUAL

-- 2. ETL-aware pre-job synchronization for 3 AM process
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
        checkpoint_time,
        sequence_name,
        legacy_value,
        replica_value,
        modernized_value,
        checkpoint_type
    )
    SELECT 
        SYSTIMESTAMP,
        'TINSIDCNT',
        NVL((SELECT CURRENT_VALUE FROM schema_name.SEQUENCE_CONTROL@legacy_direct_link 
             WHERE SEQUENCE_NAME = 'TINSIDCNT'), -1),
        (SELECT CURRENT_VALUE FROM replica_schema.SEQUENCE_CONTROL@als_replica_link 
         WHERE SEQUENCE_NAME = 'TINSIDCNT'),
        (SELECT last_number FROM user_sequences WHERE sequence_name = 'TINSIDCNT'),
        'PRE_ETL'
    FROM dual;
    
    COMMIT;
    
    -- Step 3: Final verification
    VERIFY_SEQUENCE_SYNC;
    
    v_end_time := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end_time - v_start_time));
    
    DBMS_OUTPUT.PUT_LINE('Pre-ETL sync completed in ' || ROUND(v_duration, 2) || ' seconds');
    DBMS_OUTPUT.PUT_LINE('ETL jobs can now proceed with synchronized sequences');
    DBMS_OUTPUT.PUT_LINE('=== END PRE-ETL SYNC ===');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR in pre-ETL sync: ' || SQLERRM);
        -- Log error but don't block ETL
        INSERT INTO SEQUENCE_SYNC_CHECKPOINT (
            checkpoint_time, sequence_name, checkpoint_type, error_message
        ) VALUES (
            SYSTIMESTAMP, 'TINSIDCNT', 'PRE_ETL_ERROR', SQLERRM
        );
        COMMIT;
        RAISE;
END;
/

-- 2a. Create checkpoint table for ETL coordination
CREATE TABLE SEQUENCE_SYNC_CHECKPOINT (
    checkpoint_id    NUMBER GENERATED ALWAYS AS IDENTITY,
    checkpoint_time  TIMESTAMP,
    sequence_name    VARCHAR2(128),
    legacy_value     NUMBER,
    replica_value    NUMBER,
    modernized_value NUMBER,
    checkpoint_type  VARCHAR2(50), -- PRE_ETL, POST_ETL, EMERGENCY, etc.
    error_message    VARCHAR2(4000),
    created_by       VARCHAR2(50) DEFAULT USER
);

-- 2b. Post-ETL validation procedure
CREATE OR REPLACE PROCEDURE POST_ETL_SEQUENCE_VALIDATION AS
    v_pre_etl_legacy     NUMBER;
    v_pre_etl_modernized NUMBER;
    v_post_etl_legacy    NUMBER;
    v_post_etl_modernized NUMBER;
    v_legacy_increment   NUMBER;
    v_modernized_increment NUMBER;
    v_mismatch_count     NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== POST-ETL SEQUENCE VALIDATION ===');
    
    -- Get pre-ETL values from last checkpoint
    SELECT legacy_value, modernized_value 
    INTO v_pre_etl_legacy, v_pre_etl_modernized
    FROM (
        SELECT legacy_value, modernized_value,
               ROW_NUMBER() OVER (ORDER BY checkpoint_time DESC) as rn
        FROM SEQUENCE_SYNC_CHECKPOINT 
        WHERE checkpoint_type = 'PRE_ETL' 
        AND sequence_name = 'TINSIDCNT'
        AND checkpoint_time >= TRUNC(SYSDATE)
    ) WHERE rn = 1;
    
    -- Get current post-ETL values
    BEGIN
        SELECT CURRENT_VALUE INTO v_post_etl_legacy
        FROM schema_name.SEQUENCE_CONTROL@legacy_direct_link
        WHERE SEQUENCE_NAME = 'TINSIDCNT';
    EXCEPTION
        WHEN OTHERS THEN
            v_post_etl_legacy := -1; -- Indicate unavailable
    END;
    
    SELECT last_number INTO v_post_etl_modernized
    FROM user_sequences
    WHERE sequence_name = 'TINSIDCNT';
    
    -- Calculate increments
    v_legacy_increment := v_post_etl_legacy - v_pre_etl_legacy;
    v_modernized_increment := v_post_etl_modernized - v_pre_etl_modernized;
    
    DBMS_OUTPUT.PUT_LINE('Legacy sequence increment: ' || v_legacy_increment);
    DBMS_OUTPUT.PUT_LINE('Modernized sequence increment: ' || v_modernized_increment);
    
    -- Check for data mismatches
    SELECT COUNT(*) INTO v_mismatch_count FROM V_DATA_COMPARISON;
    
    -- Create post-ETL checkpoint
    INSERT INTO SEQUENCE_SYNC_CHECKPOINT (
        checkpoint_time,
        sequence_name,
        legacy_value,
        modernized_value,
        checkpoint_type
    ) VALUES (
        SYSTIMESTAMP,
        'TINSIDCNT',
        v_post_etl_legacy,
        v_post_etl_modernized,
        'POST_ETL'
    );
    
    -- Validation results
    IF ABS(v_legacy_increment - v_modernized_increment) <= 25 THEN
        DBMS_OUTPUT.PUT_LINE('SEQUENCE VALIDATION: PASS');
    ELSE
        DBMS_OUTPUT.PUT_LINE('SEQUENCE VALIDATION: FAIL - Significant divergence detected');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Data comparison mismatches: ' || v_mismatch_count);
    
    IF v_mismatch_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('DATA VALIDATION: PASS - No mismatches found');
    ELSE
        DBMS_OUTPUT.PUT_LINE('DATA VALIDATION: REVIEW NEEDED - ' || v_mismatch_count || ' mismatches found');
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('=== END POST-ETL VALIDATION ===');
END;
/

-- 3. Verification query for data comparison
CREATE OR REPLACE VIEW V_DATA_COMPARISON AS
WITH legacy_data AS (
    SELECT tin_sid, other_columns
    FROM ent_table@als_replica_link
    WHERE created_date >= TRUNC(SYSDATE)  -- Today's data
),
modernized_data AS (
    SELECT tin_sid, other_columns  
    FROM ent_table
    WHERE created_date >= TRUNC(SYSDATE)  -- Today's data
)
SELECT 
    'LEGACY_ONLY' as source,
    l.tin_sid,
    l.other_columns
FROM legacy_data l
WHERE NOT EXISTS (
    SELECT 1 FROM modernized_data m 
    WHERE m.tin_sid = l.tin_sid
)
UNION ALL
SELECT 
    'MODERNIZED_ONLY' as source,
    m.tin_sid,
    m.other_columns
FROM modernized_data m
WHERE NOT EXISTS (
    SELECT 1 FROM legacy_data l 
    WHERE l.tin_sid = m.tin_sid
)
UNION ALL
SELECT 
    'DATA_MISMATCH' as source,
    m.tin_sid,
    m.other_columns
FROM modernized_data m
JOIN legacy_data l ON m.tin_sid = l.tin_sid
WHERE m.other_columns != l.other_columns;  -- Adjust comparison as needed

-- 4. Complete testing script
CREATE OR REPLACE PROCEDURE RUN_SEQUENCE_SYNC_TEST AS
    v_legacy_start    NUMBER;
    v_modernized_start NUMBER;
    v_legacy_end      NUMBER;
    v_modernized_end  NUMBER;
    v_test_iterations NUMBER := 10;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SEQUENCE SYNCHRONIZATION TEST ===');
    
    -- 1. Get starting values
    SELECT CURRENT_VALUE INTO v_legacy_start
    FROM replica_schema.SEQUENCE_CONTROL@als_replica_link
    WHERE SEQUENCE_NAME = 'TINSIDCNT';
    
    SELECT last_number INTO v_modernized_start
    FROM user_sequences
    WHERE sequence_name = 'TINSIDCNT';
    
    DBMS_OUTPUT.PUT_LINE('Starting Values - Legacy: ' || v_legacy_start || 
                        ', Modernized: ' || v_modernized_start);
    
    -- 2. Force synchronization
    SYNC_SEQUENCE_FROM_REPLICA('TINSIDCNT');
    
    -- 3. Test sequence generation on modernized system
    DBMS_OUTPUT.PUT_LINE('Generating ' || v_test_iterations || ' sequence values...');
    
    FOR i IN 1..v_test_iterations LOOP
        INSERT INTO test_sequence_table (id, tin_sid, test_data)
        VALUES (i, TINSIDCNT.NEXTVAL, 'Test data ' || i);
    END LOOP;
    
    COMMIT;
    
    -- 4. Check final values
    SELECT CURRENT_VALUE INTO v_legacy_end
    FROM replica_schema.SEQUENCE_CONTROL@als_replica_link
    WHERE SEQUENCE_NAME = 'TINSIDCNT';
    
    SELECT last_number INTO v_modernized_end
    FROM user_sequences
    WHERE sequence_name = 'TINSIDCNT';
    
    DBMS_OUTPUT.PUT_LINE('Final Values - Legacy: ' || v_legacy_end || 
                        ', Modernized: ' || v_modernized_end);
    
    -- 5. Analyze results
    DBMS_OUTPUT.PUT_LINE('Legacy Increment: ' || (v_legacy_end - v_legacy_start));
    DBMS_OUTPUT.PUT_LINE('Modernized Increment: ' || (v_modernized_end - v_modernized_start));
    
    IF ABS((v_legacy_end - v_legacy_start) - (v_modernized_end - v_modernized_start)) <= 25 THEN
        DBMS_OUTPUT.PUT_LINE('TEST RESULT: PASS - Sequences within acceptable range');
    ELSE
        DBMS_OUTPUT.PUT_LINE('TEST RESULT: FAIL - Sequences diverged significantly');
    END IF;
    
    -- 6. Show sync status
    FOR rec IN (SELECT * FROM V_SEQUENCE_SYNC_STATUS WHERE SEQUENCE_NAME = 'TINSIDCNT') LOOP
        DBMS_OUTPUT.PUT_LINE('Sync Status: ' || rec.SYNC_STATUS || 
                           ', Health: ' || rec.SYNC_HEALTH ||
                           ', Last Sync: ' || rec.LAST_SYNC_TIME);
    END LOOP;
    
END;
/

-- 5. Create test table for validation
CREATE TABLE test_sequence_table (
    id          NUMBER,
    tin_sid     NUMBER,
    test_data   VARCHAR2(100),
    created_at  TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- 6. Emergency sequence reset procedure
CREATE OR REPLACE PROCEDURE EMERGENCY_SEQUENCE_RESET AS
    v_max_tin_sid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('EMERGENCY: Resetting TINSIDCNT sequence...');
    
    -- Find maximum TIN_SID currently in use
    SELECT NVL(MAX(tin_sid), 0) INTO v_max_tin_sid
    FROM ent_table;
    
    DBMS_OUTPUT.PUT_LINE('Maximum TIN_SID found in data: ' || v_max_tin_sid);
    
    -- Reset sequence to start after maximum value
    EXECUTE IMMEDIATE 'DROP SEQUENCE TINSIDCNT';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE TINSIDCNT START WITH ' || (v_max_tin_sid + 1) ||
                     ' INCREMENT BY 1 MAXVALUE 9999999999 CACHE 20 NOCYCLE NOORDER';
    
    -- Update control table if accessible
    BEGIN
        UPDATE replica_schema.SEQUENCE_CONTROL@als_replica_link
        SET CURRENT_VALUE = v_max_tin_sid + 1,
            LAST_UPDATED = SYSTIMESTAMP,
            UPDATED_BY = 'EMERGENCY_RESET'
        WHERE SEQUENCE_NAME = 'TINSIDCNT';
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: Could not update replica control table');
    END;
    
    DBMS_OUTPUT.PUT_LINE('Emergency reset completed. New sequence starts at: ' || (v_max_tin_sid + 1));
END;
/

-- 7. Daily monitoring report
CREATE OR REPLACE PROCEDURE GENERATE_DAILY_SEQUENCE_REPORT AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== DAILY SEQUENCE SYNCHRONIZATION REPORT ===');
    DBMS_OUTPUT.PUT_LINE('Report Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    
    -- Sequence status
    FOR rec IN (SELECT * FROM V_SEQUENCE_SYNC_STATUS) LOOP
        DBMS_OUTPUT.PUT_LINE('Sequence: ' || rec.SEQUENCE_NAME);
        DBMS_OUTPUT.PUT_LINE('  Local Value: ' || rec.LOCAL_CURRENT_VALUE);
        DBMS_OUTPUT.PUT_LINE('  Replica Value: ' || rec.REPLICA_CURRENT_VALUE);
        DBMS_OUTPUT.PUT_LINE('  Difference: ' || rec.DIFFERENCE);
        DBMS_OUTPUT.PUT_LINE('  Health: ' || rec.SYNC_HEALTH);
        DBMS_OUTPUT.PUT_LINE('  Last Sync: ' || rec.LAST_SYNC_TIME);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || rec.SYNC_STATUS);
        IF rec.ERROR_MESSAGE IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('  Message: ' || rec.ERROR_MESSAGE);
        END IF;
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
    
    -- Data comparison summary
    DECLARE
        v_mismatch_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_mismatch_count FROM V_DATA_COMPARISON;
        DBMS_OUTPUT.PUT_LINE('Data Comparison: ' || v_mismatch_count || ' mismatches found');
        
        IF v_mismatch_count > 0 AND v_mismatch_count <= 10 THEN
            DBMS_OUTPUT.PUT_LINE('Mismatch Details:');
            FOR rec IN (SELECT * FROM V_DATA_COMPARISON WHERE ROWNUM <= 10) LOOP
                DBMS_OUTPUT.PUT_LINE('  ' || rec.source || ': TIN_SID=' || rec.tin_sid);
            END LOOP;
        END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('=== END REPORT ===');
END;
/
