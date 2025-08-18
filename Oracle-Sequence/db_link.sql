-- =====================================================
-- DATABASE LINK SEQUENCE SYNCHRONIZATION SOLUTION
-- =====================================================
-- Version: 1.0
-- Date: August 18, 2025
-- Purpose: Use single TINSIDCNT sequence from Legacy via database link
-- Benefits: No replication, no lag, no sync complexity
-- =====================================================

-- =====================================================
-- PART 1: LEGACY SYSTEM (ALS) - MINIMAL CHANGES
-- =====================================================

-- 1.1 Verify current TINSIDCNT sequence exists and get current value
SELECT sequence_name, last_number, cache_size, increment_by, max_value
FROM dba_sequences 
WHERE sequence_name = 'TINSIDCNT';

-- 1.2 Optional: Increase cache size for better performance across network
-- (Only if current cache is small - you have 20 which is reasonable)
-- ALTER SEQUENCE TINSIDCNT CACHE 50;

-- 1.3 Create dedicated database user for ENTITYDEV connections (recommended)
CREATE USER entitydev_link_user IDENTIFIED BY your_secure_password;

-- 1.4 Grant minimum required privileges
GRANT CREATE SESSION TO entitydev_link_user;
GRANT SELECT ON TINSIDCNT TO entitydev_link_user;

-- 1.5 Optional: Create synonym for easier access
CREATE PUBLIC SYNONYM TINSIDCNT_REMOTE FOR schema_owner.TINSIDCNT;
GRANT SELECT ON TINSIDCNT_REMOTE TO entitydev_link_user;

-- 1.6 Test sequence access
SELECT TINSIDCNT.NEXTVAL FROM DUAL;
SELECT TINSIDCNT.CURRVAL FROM DUAL;

-- =====================================================
-- PART 2: MODERNIZED SYSTEM (ENTITYDEV) - MAIN IMPLEMENTATION
-- =====================================================

-- 2.1 Create database link to Legacy system
CREATE DATABASE LINK als_sequence_link
CONNECT TO entitydev_link_user IDENTIFIED BY your_secure_password
USING '(DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST=als_hostname)(PORT=1521))
  (CONNECT_DATA=(SERVICE_NAME=als_service_name))
)';

-- Alternative: If you have TNS alias configured
-- CREATE DATABASE LINK als_sequence_link
-- CONNECT TO entitydev_link_user IDENTIFIED BY your_secure_password
-- USING 'ALS_TNS_ALIAS';

-- 2.2 Test database link connectivity
SELECT * FROM dual@als_sequence_link;

-- 2.3 Test sequence access through database link
SELECT TINSIDCNT.NEXTVAL@als_sequence_link FROM DUAL;
SELECT TINSIDCNT.CURRVAL@als_sequence_link FROM DUAL;

-- 2.4 Drop local TINSIDCNT sequence (IMPORTANT: Backup current value first!)
-- First, record current local value for reference
CREATE TABLE sequence_migration_backup AS
SELECT 
    'TINSIDCNT' as sequence_name,
    (SELECT last_number FROM user_sequences WHERE sequence_name = 'TINSIDCNT') as local_last_number,
    (SELECT TINSIDCNT.NEXTVAL@als_sequence_link FROM DUAL) as remote_current_value,
    SYSDATE as backup_date
FROM dual;

-- Verify backup
SELECT * FROM sequence_migration_backup;

-- Drop local sequence (point of no return - ensure backup is good!)
DROP SEQUENCE TINSIDCNT;

-- 2.5 Create synonym to make remote sequence transparent to applications
CREATE SYNONYM TINSIDCNT FOR TINSIDCNT@als_sequence_link;

-- 2.6 Test that applications can use sequence transparently
SELECT TINSIDCNT.NEXTVAL FROM DUAL;  -- Should work exactly like before
SELECT TINSIDCNT.CURRVAL FROM DUAL;

-- =====================================================
-- PART 3: APPLICATION CODE CHANGES (IF NEEDED)
-- =====================================================

-- 3.1 If applications cannot use synonyms, create wrapper function
CREATE OR REPLACE FUNCTION GET_NEXT_TINSIDCNT RETURN NUMBER AS
BEGIN
    RETURN TINSIDCNT.NEXTVAL@als_sequence_link;
END;
/

-- 3.2 Grant execute permission
GRANT EXECUTE ON GET_NEXT_TINSIDCNT TO your_app_user;

-- 3.3 Test wrapper function
SELECT GET_NEXT_TINSIDCNT FROM DUAL;

-- =====================================================
-- PART 4: MONITORING AND VALIDATION
-- =====================================================

-- 4.1 Create monitoring view for sequence status
CREATE OR REPLACE VIEW V_SEQUENCE_LINK_STATUS AS
WITH link_test AS (
    SELECT 
        CASE 
            WHEN dummy IS NOT NULL THEN 'CONNECTED'
            ELSE 'FAILED'
        END as link_status
    FROM dual@als_sequence_link
),
sequence_info AS (
    SELECT 
        TINSIDCNT.CURRVAL@als_sequence_link as current_value
    FROM dual@als_sequence_link
)
SELECT 
    'TINSIDCNT' as sequence_name,
    lt.link_status,
    si.current_value,
    SYSDATE as check_time,
    'als_sequence_link' as database_link_name
FROM link_test lt
CROSS JOIN sequence_info si;

-- 4.2 Create health check procedure
CREATE OR REPLACE PROCEDURE CHECK_SEQUENCE_LINK_HEALTH AS
    v_link_status VARCHAR2(20);
    v_current_value NUMBER;
    v_test_value NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SEQUENCE DATABASE LINK HEALTH CHECK ===');
    
    -- Test basic connectivity
    BEGIN
        SELECT link_status, current_value 
        INTO v_link_status, v_current_value
        FROM V_SEQUENCE_LINK_STATUS;
        
        DBMS_OUTPUT.PUT_LINE('Database Link Status: ' || v_link_status);
        DBMS_OUTPUT.PUT_LINE('Current Sequence Value: ' || v_current_value);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Database link connectivity failed');
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            RETURN;
    END;
    
    -- Test sequence functionality
    BEGIN
        SELECT TINSIDCNT.NEXTVAL INTO v_test_value FROM DUAL;
        DBMS_OUTPUT.PUT_LINE('Sequence Test - Next Value: ' || v_test_value);
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Sequence is accessible and functional');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Sequence access failed');
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('=== END HEALTH CHECK ===');
END;
/

-- 4.3 Create data comparison validation
CREATE OR REPLACE VIEW V_TIN_SID_COMPARISON AS
WITH legacy_data AS (
    SELECT tin_sid, other_columns, created_date
    FROM ent_table@als_replica_link  -- Assuming you still have replica for other data
    WHERE created_date >= TRUNC(SYSDATE)
),
modernized_data AS (
    SELECT tin_sid, other_columns, created_date
    FROM ent_table
    WHERE created_date >= TRUNC(SYSDATE)
)
SELECT 
    COALESCE(l.tin_sid, m.tin_sid) as tin_sid,
    CASE 
        WHEN l.tin_sid IS NULL THEN 'MODERNIZED_ONLY'
        WHEN m.tin_sid IS NULL THEN 'LEGACY_ONLY'
        WHEN l.other_columns != m.other_columns THEN 'DATA_MISMATCH'
        ELSE 'MATCH'
    END as comparison_status,
    l.other_columns as legacy_data,
    m.other_columns as modernized_data
FROM legacy_data l
FULL OUTER JOIN modernized_data m ON l.tin_sid = m.tin_sid;

-- 4.4 Create validation procedure for ETL results
CREATE OR REPLACE PROCEDURE VALIDATE_ETL_RESULTS AS
    v_mismatch_count NUMBER;
    v_legacy_only NUMBER;
    v_modernized_only NUMBER;
    v_data_mismatch NUMBER;
    v_perfect_match NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ETL VALIDATION RESULTS ===');
    DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    
    -- Count different types of mismatches
    SELECT 
        SUM(CASE WHEN comparison_status = 'LEGACY_ONLY' THEN 1 ELSE 0 END),
        SUM(CASE WHEN comparison_status = 'MODERNIZED_ONLY' THEN 1 ELSE 0 END),
        SUM(CASE WHEN comparison_status = 'DATA_MISMATCH' THEN 1 ELSE 0 END),
        SUM(CASE WHEN comparison_status = 'MATCH' THEN 1 ELSE 0 END)
    INTO v_legacy_only, v_modernized_only, v_data_mismatch, v_perfect_match
    FROM V_TIN_SID_COMPARISON;
    
    v_mismatch_count := v_legacy_only + v_modernized_only + v_data_mismatch;
    
    DBMS_OUTPUT.PUT_LINE('Perfect Matches: ' || v_perfect_match);
    DBMS_OUTPUT.PUT_LINE('Legacy Only: ' || v_legacy_only);
    DBMS_OUTPUT.PUT_LINE('Modernized Only: ' || v_modernized_only);
    DBMS_OUTPUT.PUT_LINE('Data Mismatches: ' || v_data_mismatch);
    DBMS_OUTPUT.PUT_LINE('Total Mismatches: ' || v_mismatch_count);
    
    IF v_mismatch_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULT: 100% MATCH - Perfect synchronization achieved!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULT: Review needed - ' || v_mismatch_count || ' discrepancies found');
        
        -- Show sample mismatches if any
        IF v_mismatch_count > 0 AND v_mismatch_count <= 10 THEN
            DBMS_OUTPUT.PUT_LINE('Sample Mismatches:');
            FOR rec IN (
                SELECT tin_sid, comparison_status 
                FROM V_TIN_SID_COMPARISON 
                WHERE comparison_status != 'MATCH' 
                AND ROWNUM <= 5
            ) LOOP
                DBMS_OUTPUT.PUT_LINE('  TIN_SID: ' || rec.tin_sid || ' - ' || rec.comparison_status);
            END LOOP;
        END IF;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== END VALIDATION ===');
END;
/

-- =====================================================
-- PART 5: ERROR HANDLING AND RECOVERY
-- =====================================================

-- 5.1 Create fallback procedure for database link failures
CREATE OR REPLACE PROCEDURE HANDLE_SEQUENCE_LINK_FAILURE AS
    v_max_tin_sid NUMBER;
    v_safe_start NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== EMERGENCY: DATABASE LINK FAILURE RECOVERY ===');
    
    -- Find maximum TIN_SID in local data
    SELECT NVL(MAX(tin_sid), 0) INTO v_max_tin_sid
    FROM ent_table;
    
    v_safe_start := v_max_tin_sid + 1000; -- Add safety buffer
    
    DBMS_OUTPUT.PUT_LINE('Maximum local TIN_SID found: ' || v_max_tin_sid);
    DBMS_OUTPUT.PUT_LINE('Creating emergency local sequence starting at: ' || v_safe_start);
    
    -- Create emergency local sequence
    EXECUTE IMMEDIATE 'CREATE SEQUENCE TINSIDCNT_EMERGENCY 
                       START WITH ' || v_safe_start || '
                       INCREMENT BY 1 
                       MAXVALUE 9999999999 
                       CACHE 20 
                       NOCYCLE 
                       NOORDER';
    
    -- Create emergency synonym
    EXECUTE IMMEDIATE 'DROP SYNONYM TINSIDCNT';
    EXECUTE IMMEDIATE 'CREATE SYNONYM TINSIDCNT FOR TINSIDCNT_EMERGENCY';
    
    DBMS_OUTPUT.PUT_LINE('Emergency sequence created and activated');
    DBMS_OUTPUT.PUT_LINE('IMPORTANT: Coordinate with Legacy team and restore link ASAP');
    DBMS_OUTPUT.PUT_LINE('=== END EMERGENCY RECOVERY ===');
END;
/

-- 5.2 Create procedure to restore from emergency mode
CREATE OR REPLACE PROCEDURE RESTORE_FROM_EMERGENCY_MODE AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== RESTORING FROM EMERGENCY MODE ===');
    
    -- Test database link
    BEGIN
        DECLARE
            v_test VARCHAR2(1);
        BEGIN
            SELECT dummy INTO v_test FROM dual@als_sequence_link;
            DBMS_OUTPUT.PUT_LINE('Database link connectivity restored');
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Database link still not accessible');
            DBMS_OUTPUT.PUT_LINE('Cannot restore from emergency mode');
            RETURN;
    END;
    
    -- Drop emergency sequence and restore original synonym
    BEGIN
        EXECUTE IMMEDIATE 'DROP SYNONYM TINSIDCNT';
        EXECUTE IMMEDIATE 'DROP SEQUENCE TINSIDCNT_EMERGENCY';
        EXECUTE IMMEDIATE 'CREATE SYNONYM TINSIDCNT FOR TINSIDCNT@als_sequence_link';
        
        DBMS_OUTPUT.PUT_LINE('Emergency sequence removed');
        DBMS_OUTPUT.PUT_LINE('Original database link sequence restored');
        
        -- Test functionality
        DECLARE
            v_test_value NUMBER;
        BEGIN
            SELECT TINSIDCNT.NEXTVAL INTO v_test_value FROM DUAL;
            DBMS_OUTPUT.PUT_LINE('Test sequence call successful: ' || v_test_value);
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR during restoration: ' || SQLERRM);
            RAISE;
    END;
    
    DBMS_OUTPUT.PUT_LINE('=== RESTORATION COMPLETE ===');
END;
/

-- =====================================================
-- PART 6: TESTING AND VALIDATION
-- =====================================================

-- 6.1 Complete functionality test
DECLARE
    v_test1 NUMBER;
    v_test2 NUMBER;
    v_test3 NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== COMPREHENSIVE FUNCTIONALITY TEST ===');
    
    -- Test sequence calls
    SELECT TINSIDCNT.NEXTVAL INTO v_test1 FROM DUAL;
    SELECT TINSIDCNT.NEXTVAL INTO v_test2 FROM DUAL;
    SELECT TINSIDCNT.CURRVAL INTO v_test3 FROM DUAL;
    
    DBMS_OUTPUT.PUT_LINE('Test 1 (NEXTVAL): ' || v_test1);
    DBMS_OUTPUT.PUT_LINE('Test 2 (NEXTVAL): ' || v_test2);
    DBMS_OUTPUT.PUT_LINE('Test 3 (CURRVAL): ' || v_test3);
    
    IF v_test2 = v_test1 + 1 AND v_test3 = v_test2 THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Sequence functioning correctly');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: Sequence behavior unexpected');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== END FUNCTIONALITY TEST ===');
END;
/

-- 6.2 Run health check
EXEC CHECK_SEQUENCE_LINK_HEALTH;

-- 6.3 Check current status
SELECT * FROM V_SEQUENCE_LINK_STATUS;

-- =====================================================
-- PART 7: DEPLOYMENT CHECKLIST QUERIES
-- =====================================================

-- 7.1 Pre-deployment verification
SELECT 'Current local sequence value' as check_type, last_number as value
FROM user_sequences WHERE sequence_name = 'TINSIDCNT'
UNION ALL
SELECT 'Current remote sequence value', TINSIDCNT.CURRVAL@als_sequence_link
FROM dual;

-- 7.2 Post-deployment verification
SELECT 'Database link test' as check_type, 'SUCCESS' as status
FROM dual@als_sequence_link
UNION ALL
SELECT 'Sequence accessibility', 'SUCCESS'
FROM dual WHERE EXISTS (SELECT TINSIDCNT.CURRVAL FROM dual)
UNION ALL
SELECT 'Synonym functionality', 'SUCCESS'  
FROM dual WHERE EXISTS (SELECT TINSIDCNT.NEXTVAL FROM dual);

-- =====================================================
-- PART 8: PERFORMANCE MONITORING
-- =====================================================

-- 8.1 Create performance monitoring view
CREATE OR REPLACE VIEW V_SEQUENCE_PERFORMANCE AS
SELECT 
    'Database Link Response' as metric_name,
    EXTRACT(SECOND FROM (SYSTIMESTAMP - lag(SYSTIMESTAMP) OVER (ORDER BY SYSTIMESTAMP))) as response_time_seconds,
    TINSIDCNT.NEXTVAL as sequence_value,
    SYSTIMESTAMP as measurement_time
FROM dual;

-- 8.2 Simple performance test
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration NUMBER;
    v_test_value NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== PERFORMANCE TEST ===');
    
    v_start_time := SYSTIMESTAMP;
    SELECT TINSIDCNT.NEXTVAL INTO v_test_value FROM DUAL;
    v_end_time := SYSTIMESTAMP;
    
    v_duration := EXTRACT(SECOND FROM (v_end_time - v_start_time));
    
    DBMS_OUTPUT.PUT_LINE('Sequence call duration: ' || ROUND(v_duration * 1000, 2) || ' milliseconds');
    DBMS_OUTPUT.PUT_LINE('Sequence value returned: ' || v_test_value);
    
    IF v_duration < 1 THEN
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE: GOOD - Response time acceptable');
    ELSE
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE: REVIEW - Response time may be slow');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=== END PERFORMANCE TEST ===');
END;
/

-- =====================================================
-- FINAL VERIFICATION COMMANDS
-- =====================================================

-- Verify everything is working
EXEC CHECK_SEQUENCE_LINK_HEALTH;
EXEC VALIDATE_ETL_RESULTS;

-- Test sequence functionality
SELECT TINSIDCNT.NEXTVAL as next_value FROM DUAL;
SELECT TINSIDCNT.CURRVAL as current_value FROM DUAL;
