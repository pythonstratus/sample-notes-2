-- =====================================================
-- ENTITYDEV EXADATA SYSTEM - DATABASE LINK IMPLEMENTATION
-- =====================================================
-- Purpose: Implement database link to Legacy ALS for sequence access
-- System: ENTITYDEV (Exadata)
-- Target: Use Legacy TINSIDCNT sequence via database link
-- Estimated Time: 20 minutes
-- Prerequisites: ALS Legacy setup must be completed first
-- =====================================================

-- =====================================================
-- STEP 1: PRE-IMPLEMENTATION VERIFICATION
-- =====================================================

-- 1.1 Connect as schema owner on ENTITYDEV
-- sqlplus schema_owner/password@ENTITYDEV_TNS_ALIAS

-- 1.2 Verify current local sequence status
SELECT 
    sequence_name, 
    last_number, 
    cache_size, 
    increment_by,
    max_value,
    cycle_flag
FROM user_sequences 
WHERE sequence_name = 'TINSIDCNT';

-- Record the last_number value - this is critical for rollback

-- 1.3 Test current local sequence functionality
SELECT TINSIDCNT.NEXTVAL FROM DUAL;
SELECT TINSIDCNT.CURRVAL FROM DUAL;

-- Record these values for comparison

-- 1.4 Check if any applications are currently using the sequence
-- (Optional) Run during low-activity period to minimize impact

-- =====================================================
-- STEP 2: NETWORK CONNECTIVITY VERIFICATION
-- =====================================================

-- 2.1 Test TNS connectivity to Legacy system
-- Run from command line: tnsping ALS_TNS_ALIAS
-- Should return successful connection

-- 2.2 Verify connection details (update these variables)
-- ALS_HOSTNAME: [Get from ALS DBA team]
-- ALS_SERVICE_NAME: [Get from ALS DBA team]  
-- ALS_PORT: 1521 (standard)
-- USERNAME: entitydev_link_user
-- PASSWORD: EntityDev2025!Link

-- =====================================================
-- STEP 3: CREATE BACKUP OF CURRENT STATE
-- =====================================================

-- 3.1 Create comprehensive backup table
CREATE TABLE tinsidcnt_sequence_backup AS
SELECT 
    'TINSIDCNT' as sequence_name,
    (SELECT last_number FROM user_sequences WHERE sequence_name = 'TINSIDCNT') as local_last_number,
    (SELECT cache_size FROM user_sequences WHERE sequence_name = 'TINSIDCNT') as local_cache_size,
    (SELECT increment_by FROM user_sequences WHERE sequence_name = 'TINSIDCNT') as local_increment,
    SYSDATE as backup_date,
    USER as backed_up_by,
    'PRE_DB_LINK_IMPLEMENTATION' as backup_reason
FROM dual;

-- 3.2 Verify backup was created successfully
SELECT * FROM tinsidcnt_sequence_backup;

-- 3.3 Create additional safety backup with current state
CREATE TABLE current_sequence_usage_backup AS
SELECT 
    table_name,
    column_name,
    'Uses TINSIDCNT sequence' as notes
FROM user_tab_columns 
WHERE column_name LIKE '%TIN_SID%' OR column_name LIKE '%TINSIDCNT%';

-- This helps identify which tables use the sequence

-- =====================================================
-- STEP 4: CREATE DATABASE LINK TO LEGACY
-- =====================================================

-- 4.1 Create database link with full connection string
-- Replace ALS_HOSTNAME and ALS_SERVICE_NAME with actual values
CREATE DATABASE LINK als_sequence_link
CONNECT TO entitydev_link_user IDENTIFIED BY "EntityDev2025!Link"
USING '(DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST=ALS_HOSTNAME)(PORT=1521))
  (CONNECT_DATA=(SERVICE_NAME=ALS_SERVICE_NAME))
)';

-- Alternative: If TNS alias is configured on ENTITYDEV
-- CREATE DATABASE LINK als_sequence_link
-- CONNECT TO entitydev_link_user IDENTIFIED BY "EntityDev2025!Link"
-- USING 'ALS_TNS_ALIAS';

-- 4.2 Test database link connectivity
SELECT 'Database link connection successful' as status FROM dual@als_sequence_link;

-- Should return: Database link connection successful

-- 4.3 Test sequence access through database link
-- Replace SEQUENCE_OWNER with actual schema from ALS setup
SELECT SEQUENCE_OWNER.TINSIDCNT.NEXTVAL@als_sequence_link as remote_next FROM DUAL;
SELECT SEQUENCE_OWNER.TINSIDCNT.CURRVAL@als_sequence_link as remote_current FROM DUAL;

-- If public synonym was created on ALS, test that too:
SELECT TINSIDCNT_REMOTE.NEXTVAL@als_sequence_link as remote_synonym_next FROM DUAL;
SELECT TINSIDCNT_REMOTE.CURRVAL@als_sequence_link as remote_synonym_current FROM DUAL;

-- Record these values - they should be sequential

-- =====================================================
-- STEP 5: COMPARE LOCAL VS REMOTE SEQUENCES
-- =====================================================

-- 5.1 Side-by-side comparison
SELECT 
    'LOCAL_ENTITYDEV' as source,
    (SELECT last_number FROM user_sequences WHERE sequence_name = 'TINSIDCNT') as sequence_value,
    'Before synchronization' as notes
FROM dual
UNION ALL
SELECT 
    'REMOTE_LEGACY' as source,
    SEQUENCE_OWNER.TINSIDCNT.CURRVAL@als_sequence_link as sequence_value,  -- Replace SEQUENCE_OWNER
    'Legacy current value' as notes
FROM dual;

-- Note the difference - this shows why sync is needed

-- =====================================================
-- STEP 6: IMPLEMENT SEQUENCE REDIRECTION
-- =====================================================

-- 6.1 *** CRITICAL POINT OF NO RETURN ***
-- After this step, the local sequence will be permanently removed
-- Ensure backup from Step 3 is verified and accessible

-- Confirm backup one more time
SELECT 'Backup verification' as check_type, COUNT(*) as record_count 
FROM tinsidcnt_sequence_backup;
-- Should return 1 record

-- 6.2 Drop the local TINSIDCNT sequence
DROP SEQUENCE TINSIDCNT;

-- 6.3 Create synonym to redirect to remote sequence
-- Use the approach that worked in Step 4.3 testing
CREATE SYNONYM TINSIDCNT FOR SEQUENCE_OWNER.TINSIDCNT@als_sequence_link;

-- Alternative if using public synonym:
-- CREATE SYNONYM TINSIDCNT FOR TINSIDCNT_REMOTE@als_sequence_link;

-- =====================================================
-- STEP 7: VALIDATE NEW CONFIGURATION
-- =====================================================

-- 7.1 Test that local calls now use remote sequence
SELECT TINSIDCNT.NEXTVAL as next_value FROM DUAL;
SELECT TINSIDCNT.CURRVAL as current_value FROM DUAL;

-- These values should now come from Legacy system

-- 7.2 Comprehensive functionality test
DECLARE
    v_test1 NUMBER;
    v_test2 NUMBER;
    v_test3 NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SEQUENCE FUNCTIONALITY TEST ===');
    
    -- Test sequence calls
    SELECT TINSIDCNT.NEXTVAL INTO v_test1 FROM DUAL;
    SELECT TINSIDCNT.NEXTVAL INTO v_test2 FROM DUAL;
    SELECT TINSIDCNT.CURRVAL INTO v_test3 FROM DUAL;
    
    DBMS_OUTPUT.PUT_LINE('First NEXTVAL: ' || v_test1);
    DBMS_OUTPUT.PUT_LINE('Second NEXTVAL: ' || v_test2);
    DBMS_OUTPUT.PUT_LINE('CURRVAL: ' || v_test3);
    
    -- Validate expected behavior
    IF v_test2 = v_test1 + 1 AND v_test3 = v_test2 THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Sequence functioning correctly');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: Unexpected sequence behavior');
        DBMS_OUTPUT.PUT_LINE('Expected: ' || v_test1 || ' + 1 = ' || v_test2);
        DBMS_OUTPUT.PUT_LINE('Expected: CURRVAL = ' || v_test2 || ', Got: ' || v_test3);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== END FUNCTIONALITY TEST ===');
END;
/

-- 7.3 Performance test
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration NUMBER;
    v_test_value NUMBER;
    v_total_duration NUMBER := 0;
    v_iterations NUMBER := 5;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== PERFORMANCE TEST ===');
    DBMS_OUTPUT.PUT_LINE('Testing ' || v_iterations || ' sequence calls...');
    
    FOR i IN 1..v_iterations LOOP
        v_start_time := SYSTIMESTAMP;
        SELECT TINSIDCNT.NEXTVAL INTO v_test_value FROM DUAL;
        v_end_time := SYSTIMESTAMP;
        
        v_duration := EXTRACT(SECOND FROM (v_end_time - v_start_time));
        v_total_duration := v_total_duration + v_duration;
        
        DBMS_OUTPUT.PUT_LINE('Call ' || i || ': ' || ROUND(v_duration * 1000, 2) || 'ms, Value: ' || v_test_value);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Average response time: ' || ROUND((v_total_duration / v_iterations) * 1000, 2) || ' milliseconds');
    
    IF (v_total_duration / v_iterations) < 0.1 THEN
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE: EXCELLENT');
    ELSIF (v_total_duration / v_iterations) < 0.5 THEN
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE: GOOD');
    ELSE
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE: REVIEW NEEDED - Response time slow');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== END PERFORMANCE TEST ===');
END;
/

-- =====================================================
-- STEP 8: CREATE MONITORING AND HEALTH CHECK TOOLS
-- =====================================================

-- 8.1 Create comprehensive health check procedure
CREATE OR REPLACE PROCEDURE check_sequence_link_health AS
    v_link_status VARCHAR2(50);
    v_remote_accessible CHAR(1) := 'N';
    v_sequence_accessible CHAR(1) := 'N';
    v_current_value NUMBER;
    v_test_value NUMBER;
    v_response_time NUMBER;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== DATABASE LINK HEALTH CHECK ===');
    DBMS_OUTPUT.PUT_LINE('Check Time: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: Basic database link connectivity
    BEGIN
        SELECT 'CONNECTED' INTO v_link_status FROM dual@als_sequence_link;
        v_remote_accessible := 'Y';
        DBMS_OUTPUT.PUT_LINE('✓ Database Link: CONNECTED');
    EXCEPTION
        WHEN OTHERS THEN
            v_link_status := 'FAILED: ' || SUBSTR(SQLERRM, 1, 50);
            DBMS_OUTPUT.PUT_LINE('✗ Database Link: ' || v_link_status);
    END;
    
    -- Test 2: Sequence accessibility (only if link works)
    IF v_remote_accessible = 'Y' THEN
        BEGIN
            v_start_time := SYSTIMESTAMP;
            SELECT TINSIDCNT.CURRVAL INTO v_current_value FROM DUAL;
            SELECT TINSIDCNT.NEXTVAL INTO v_test_value FROM DUAL;
            v_end_time := SYSTIMESTAMP;
            
            v_response_time := EXTRACT(SECOND FROM (v_end_time - v_start_time));
            v_sequence_accessible := 'Y';
            
            DBMS_OUTPUT.PUT_LINE('✓ Sequence Access: FUNCTIONAL');
            DBMS_OUTPUT.PUT_LINE('  Current Value: ' || v_current_value);
            DBMS_OUTPUT.PUT_LINE('  Test NEXTVAL: ' || v_test_value);
            DBMS_OUTPUT.PUT_LINE('  Response Time: ' || ROUND(v_response_time * 1000, 2) || ' ms');
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('✗ Sequence Access: FAILED - ' || SUBSTR(SQLERRM, 1, 100));
        END;
    END IF;
    
    -- Test 3: Synonym functionality
    IF v_sequence_accessible = 'Y' THEN
        BEGIN
            DECLARE
                v_synonym_test NUMBER;
            BEGIN
                SELECT TINSIDCNT.NEXTVAL INTO v_synonym_test FROM DUAL;
                DBMS_OUTPUT.PUT_LINE('✓ Synonym Access: WORKING (Value: ' || v_synonym_test || ')');
            END;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('✗ Synonym Access: FAILED - ' || SUBSTR(SQLERRM, 1, 100));
        END;
    END IF;
    
    -- Overall status
    DBMS_OUTPUT.PUT_LINE('');
    IF v_remote_accessible = 'Y' AND v_sequence_accessible = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('OVERALL STATUS: ✓ HEALTHY - All systems functional');
    ELSE
        DBMS_OUTPUT.PUT_LINE('OVERALL STATUS: ✗ ISSUES DETECTED - Review errors above');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== END HEALTH CHECK ===');
END;
/

-- 8.2 Test the health check procedure
EXEC check_sequence_link_health;

-- 8.3 Create monitoring view for ongoing status
CREATE OR REPLACE VIEW v_sequence_link_status AS
SELECT 
    'als_sequence_link' as database_link_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM dual@als_sequence_link) 
        THEN 'CONNECTED' 
        ELSE 'FAILED' 
    END as connection_status,
    TINSIDCNT.CURRVAL as current_sequence_value,
    SYSDATE as last_check_time
FROM dual;

-- 8.4 Test the monitoring view
SELECT * FROM v_sequence_link_status;

-- =====================================================
-- STEP 9: APPLICATION COMPATIBILITY VERIFICATION
-- =====================================================

-- 9.1 Test sequence in typical application context
-- Create a test table to simulate application usage
CREATE TABLE test_sequence_usage (
    id NUMBER,
    tin_sid NUMBER,
    test_data VARCHAR2(100),
    created_date DATE DEFAULT SYSDATE
);

-- 9.2 Test INSERT operations with sequence
INSERT INTO test_sequence_usage (id, tin_sid, test_data)
VALUES (1, TINSIDCNT.NEXTVAL, 'Test record 1');

INSERT INTO test_sequence_usage (id, tin_sid, test_data)
VALUES (2, TINSIDCNT.NEXTVAL, 'Test record 2');

INSERT INTO test_sequence_usage (id, tin_sid, test_data)
VALUES (3, TINSIDCNT.NEXTVAL, 'Test record 3');

COMMIT;

-- 9.3 Verify test results
SELECT * FROM test_sequence_usage ORDER BY id;

-- TIN_SID values should be sequential from Legacy system

-- 9.4 Check that values are indeed coming from Legacy
SELECT 
    'TEST_TABLE' as source,
    MAX(tin_sid) as max_tin_sid
FROM test_sequence_usage
UNION ALL
SELECT 
    'LEGACY_SEQUENCE' as source,
    TINSIDCNT.CURRVAL as max_tin_sid
FROM dual;

-- Values should be closely aligned

-- =====================================================
-- STEP 10: EMERGENCY ROLLBACK PROCEDURES
-- =====================================================

-- 10.1 Create emergency rollback procedure (DO NOT RUN unless emergency)
CREATE OR REPLACE PROCEDURE emergency_rollback_sequence AS
    v_backup_value NUMBER;
    v_backup_cache NUMBER;
    v_backup_increment NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== EMERGENCY ROLLBACK PROCEDURE ===');
    DBMS_OUTPUT.PUT_LINE('WARNING: This will restore local sequence and remove database link');
    
    -- Get backup values
    SELECT 
        local_last_number,
        local_cache_size,
        local_increment
    INTO v_backup_value, v_backup_cache, v_backup_increment
    FROM tinsidcnt_sequence_backup;
    
    DBMS_OUTPUT.PUT_LINE('Restoring from backup:');
    DBMS_OUTPUT.PUT_LINE('  Last Number: ' || v_backup_value);
    DBMS_OUTPUT.PUT_LINE('  Cache Size: ' || v_backup_cache);
    DBMS_OUTPUT.PUT_LINE('  Increment: ' || v_backup_increment);
    
    -- Remove synonym
    DROP SYNONYM TINSIDCNT;
    
    -- Recreate local sequence with backed up settings
    EXECUTE IMMEDIATE 'CREATE SEQUENCE TINSIDCNT 
                       START WITH ' || (v_backup_value + 1) || '
                       INCREMENT BY ' || v_backup_increment || '
                       CACHE ' || v_backup_cache || '
                       MAXVALUE 9999999999 
                       NOCYCLE 
                       NOORDER';
    
    -- Test local sequence
    DECLARE
        v_test NUMBER;
    BEGIN
        SELECT TINSIDCNT.NEXTVAL INTO v_test FROM DUAL;
        DBMS_OUTPUT.PUT_LINE('Local sequence test value: ' || v_test);
    END;
    
    -- Archive the database link (don't drop automatically for investigation)
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Local sequence restored successfully');
    DBMS_OUTPUT.PUT_LINE('Database link preserved for manual cleanup');
    DBMS_OUTPUT.PUT_LINE('Coordinate with DBA to drop link: als_sequence_link');
    DBMS_OUTPUT.PUT_LINE('=== END ROLLBACK ===');
END;
/

-- =====================================================
-- STEP 11: DOCUMENTATION AND HANDOVER
-- =====================================================

-- 11.1 Create implementation documentation table
CREATE TABLE db_link_implementation_log AS
SELECT 
    'als_sequence_link' as database_link_name,
    'entitydev_link_user' as remote_username,
    'ALS_HOSTNAME:1521/ALS_SERVICE_NAME' as remote_connection,  -- Update with actual values
    'SEQUENCE_OWNER.TINSIDCNT' as remote_sequence,  -- Replace SEQUENCE_OWNER with actual  
    SYSDATE as implementation_date,
    USER as implemented_by,
    (SELECT current_sequence_value FROM v_sequence_link_status) as current_sequence_value,
    'ACTIVE' as status
FROM dual;

-- 11.2 Verify documentation
SELECT * FROM db_link_implementation_log;

-- 11.3 Final comprehensive test
EXEC check_sequence_link_health;

-- =====================================================
-- STEP 12: CLEANUP TEST DATA
-- =====================================================

-- 12.1 Remove test table (optional - keep for reference if desired)
-- DROP TABLE test_sequence_usage;

-- =====================================================
-- FINAL VERIFICATION CHECKLIST
-- =====================================================

-- 12.1 Complete verification checklist
SELECT 
    'Database Link Created' as check_item,
    CASE WHEN EXISTS (SELECT 1 FROM user_db_links WHERE db_link = 'ALS_SEQUENCE_LINK') 
         THEN '✓ PASS' ELSE '✗ FAIL' END as status
FROM dual
UNION ALL
SELECT 
    'Database Link Connectivity',
    CASE WHEN EXISTS (SELECT 1 FROM dual@als_sequence_link) 
         THEN '✓ PASS' ELSE '✗ FAIL' END
FROM dual
UNION ALL
SELECT 
    'Sequence Access',
    CASE WHEN TINSIDCNT.NEXTVAL > 0 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM dual
UNION ALL
SELECT 
    'Synonym Created',
    CASE WHEN EXISTS (SELECT 1 FROM user_synonyms WHERE synonym_name = 'TINSIDCNT')
         THEN '✓ PASS' ELSE '✗ FAIL' END
FROM dual
UNION ALL
SELECT 
    'Backup Created',
    CASE WHEN EXISTS (SELECT 1 FROM tinsidcnt_sequence_backup)
         THEN '✓ PASS' ELSE '✗ FAIL' END
FROM dual
UNION ALL
SELECT 
    'Local Sequence Removed',
    CASE WHEN NOT EXISTS (SELECT 1 FROM user_sequences WHERE sequence_name = 'TINSIDCNT')
         THEN '✓ PASS' ELSE '✗ FAIL' END
FROM dual;

-- All items should show ✓ PASS

-- =====================================================
-- IMPLEMENTATION COMPLETE - ENTITYDEV SIDE
-- =====================================================

PROMPT 
PROMPT ===================================================
PROMPT ENTITYDEV DATABASE LINK IMPLEMENTATION COMPLETED
PROMPT ===================================================
PROMPT 
PROMPT Summary:
PROMPT - Database link created: als_sequence_link
PROMPT - Local TINSIDCNT sequence removed
PROMPT - Synonym created: TINSIDCNT → Legacy sequence
PROMPT - Backup available: tinsidcnt_sequence_backup
PROMPT - Health check available: check_sequence_link_health
PROMPT 
PROMPT Current Status:
PROMPT - All sequence calls now go to Legacy system
PROMPT - Both ENTITYDEV and Legacy use same sequence source
PROMPT - Data comparison should show perfect TIN_SID alignment
PROMPT 
PROMPT Monitoring:
PROMPT - Health Check: EXEC check_sequence_link_health
PROMPT - Status View: SELECT * FROM v_sequence_link_status
PROMPT - Implementation Log: SELECT * FROM db_link_implementation_log
PROMPT 
PROMPT Emergency Procedures:
PROMPT - Rollback available: emergency_rollback_sequence
PROMPT - Backup preserved: tinsidcnt_sequence_backup
PROMPT 
PROMPT Next Steps:
PROMPT 1. Test ETL jobs with new sequence configuration
PROMPT 2. Validate data comparison results (should be perfect match)
PROMPT 3. Monitor performance during normal operations
PROMPT 4. Coordinate with application team for validation
PROMPT 
PROMPT ===================================================