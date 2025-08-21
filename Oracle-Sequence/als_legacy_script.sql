-- =====================================================
-- ALS LEGACY SYSTEM (SOLARIS) - DATABASE LINK SETUP
-- =====================================================
-- Purpose: Prepare Legacy system for ENTITYDEV database link connection
-- System: ALS (Solaris)
-- Target: Allow ENTITYDEV to access TINSIDCNT sequence
-- Estimated Time: 10 minutes
-- =====================================================

-- =====================================================
-- STEP 1: PRE-IMPLEMENTATION VERIFICATION
-- =====================================================

-- 1.1 Connect as SYSDBA or user with appropriate privileges
-- sqlplus / as sysdba

-- 1.2 Verify current TINSIDCNT sequence status
SELECT 
    sequence_owner,
    sequence_name, 
    last_number, 
    cache_size, 
    increment_by,
    max_value,
    cycle_flag
FROM dba_sequences 
WHERE sequence_name = 'TINSIDCNT';

-- Record the results - particularly sequence_owner and last_number
-- Expected: last_number around 254,223,193

-- 1.3 Identify the sequence owner (replace in subsequent steps)
-- Note the SEQUENCE_OWNER from above query
-- This will be used throughout the script - replace all instances of SEQUENCE_OWNER

-- 1.4 Test sequence functionality  
-- Replace SEQUENCE_OWNER with actual value from Step 1.2
SELECT SEQUENCE_OWNER.TINSIDCNT.NEXTVAL FROM DUAL;  
SELECT SEQUENCE_OWNER.TINSIDCNT.CURRVAL FROM DUAL;

-- Record these values for comparison with ENTITYDEV

-- =====================================================
-- STEP 2: CREATE DATABASE USER FOR ENTITYDEV
-- =====================================================

-- 2.1 Create dedicated user for ENTITYDEV connections
-- Use a strong password and record it securely
CREATE USER entitydev_link_user IDENTIFIED BY "EntityDev2025!Link";

-- 2.2 Grant basic connection privilege
GRANT CREATE SESSION TO entitydev_link_user;

-- 2.3 Grant sequence access to the specific schema
-- Replace SEQUENCE_OWNER with actual schema from Step 1.2
GRANT SELECT ON SEQUENCE_OWNER.TINSIDCNT TO entitydev_link_user;

-- 2.4 Optional: Create public synonym for easier access
-- This makes the sequence accessible without schema prefix
CREATE PUBLIC SYNONYM TINSIDCNT_REMOTE FOR SEQUENCE_OWNER.TINSIDCNT;
GRANT SELECT ON TINSIDCNT_REMOTE TO entitydev_link_user;

-- =====================================================
-- STEP 3: VERIFY USER SETUP
-- =====================================================

-- 3.1 Connect as the new user to test privileges
-- sqlplus entitydev_link_user/"EntityDev2025!Link"@ALS_TNS_ALIAS

-- 3.2 Verify user identity
SELECT USER FROM DUAL;
-- Should return: ENTITYDEV_LINK_USER

-- 3.3 Test sequence access with schema prefix
SELECT SEQUENCE_OWNER.TINSIDCNT.NEXTVAL FROM DUAL;  
SELECT SEQUENCE_OWNER.TINSIDCNT.CURRVAL FROM DUAL;

-- Record these values

-- 3.4 Test sequence access with public synonym (if created)
SELECT TINSIDCNT_REMOTE.NEXTVAL FROM DUAL;
SELECT TINSIDCNT_REMOTE.CURRVAL FROM DUAL;

-- Both methods should work and return sequential values

-- 3.5 Exit from entitydev_link_user session
-- EXIT

-- =====================================================
-- STEP 4: SECURITY AND MONITORING SETUP
-- =====================================================

-- 4.1 Connect back as SYSDBA
-- sqlplus / as sysdba

-- 4.2 Create audit trail for sequence access (optional)
-- This helps monitor usage from ENTITYDEV
AUDIT SELECT ON SEQUENCE_OWNER.TINSIDCNT BY entitydev_link_user;

-- 4.3 Check current database links (for documentation)
SELECT 
    db_link,
    username,
    host,
    created
FROM dba_db_links
WHERE owner = 'PUBLIC' OR owner = 'ENTITYDEV_LINK_USER';

-- 4.4 Verify listener configuration (informational)
-- Run from command line: lsnrctl status
-- Ensure listener is accepting connections on port 1521

-- =====================================================
-- STEP 5: NETWORK AND CONNECTIVITY VERIFICATION
-- =====================================================

-- 5.1 Document connection details for ENTITYDEV team
SELECT 
    'Connection Details for ENTITYDEV' as info_type,
    'Host: ' || sys_context('USERENV', 'SERVER_HOST') as detail
FROM dual
UNION ALL
SELECT 
    'Database Service',
    'Service: ' || sys_context('USERENV', 'DB_NAME')
FROM dual
UNION ALL
SELECT 
    'User Created',
    'User: entitydev_link_user'
FROM dual
UNION ALL
SELECT 
    'Password',
    'Password: EntityDev2025!Link'
FROM dual
UNION ALL
SELECT 
    'Sequence Owner',
    'Schema: SEQUENCE_OWNER'  -- Replace with actual value
FROM dual;

-- 5.2 Test TNS connectivity (informational)
-- Run from command line: tnsping ALS_TNS_ALIAS

-- =====================================================
-- STEP 6: FINAL VERIFICATION AND DOCUMENTATION
-- =====================================================

-- 6.1 Create implementation log
CREATE TABLE entitydev_link_setup_log AS
SELECT 
    'entitydev_link_user' as username_created,
    'SEQUENCE_OWNER.TINSIDCNT' as sequence_granted,  -- Replace SEQUENCE_OWNER with actual
    (SELECT last_number FROM dba_sequences WHERE sequence_name = 'TINSIDCNT') as current_sequence_value,
    SYSDATE as setup_date,
    USER as setup_by
FROM dual;

-- 6.2 Verify the log
SELECT * FROM entitydev_link_setup_log;

-- 6.3 Final privilege verification
SELECT 
    grantee,
    privilege,
    grantable,
    table_name
FROM dba_tab_privs 
WHERE grantee = 'ENTITYDEV_LINK_USER'
AND table_name = 'TINSIDCNT';

-- Should show SELECT privilege granted

-- 6.4 Final sequence test
SELECT 
    'Final Test' as test_type,
    SEQUENCE_OWNER.TINSIDCNT.NEXTVAL as next_value,  -- Replace SEQUENCE_OWNER with actual
    SYSDATE as test_time
FROM dual;

-- Record this value to compare with ENTITYDEV tests

-- =====================================================
-- STEP 7: SECURITY RECOMMENDATIONS
-- =====================================================

-- 7.1 Document security considerations
/*
SECURITY NOTES:

1. USER PRIVILEGES: entitydev_link_user has minimal privileges
   - CREATE SESSION (connection only)
   - SELECT on TINSIDCNT sequence only
   - No other database access

2. PASSWORD POLICY: Use strong password and rotate periodically
   - Current: EntityDev2025!Link
   - Change regularly per security policy

3. NETWORK SECURITY: 
   - Connection from ENTITYDEV only
   - Consider firewall rules if needed
   - Monitor connection attempts

4. AUDITING: 
   - Sequence access is audited
   - Review audit logs regularly

5. TEMPORARY NATURE:
   - This setup is for validation phase only
   - Remove user when validation complete
*/

-- =====================================================
-- STEP 8: HANDOVER INFORMATION FOR ENTITYDEV TEAM
-- =====================================================

-- 8.1 Connection information to provide to ENTITYDEV DBA
/*
ENTITYDEV TEAM - CONNECTION DETAILS:

Database Link Configuration:
- Username: entitydev_link_user
- Password: EntityDev2025!Link
- Host: [ALS_HOSTNAME] (get from sys_context query above)
- Port: 1521
- Service: [ALS_SERVICE_NAME] (get from sys_context query above)

Sequence Access:
- Full name: SEQUENCE_OWNER.TINSIDCNT (replace SEQUENCE_OWNER with actual)
- Alternative: TINSIDCNT_REMOTE (public synonym)
- Current value: [value from final test above]

Connection String Format:
CREATE DATABASE LINK als_sequence_link
CONNECT TO entitydev_link_user IDENTIFIED BY "EntityDev2025!Link"
USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=ALS_HOSTNAME)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ALS_SERVICE)))';

Test Commands:
SELECT * FROM dual@als_sequence_link;
SELECT TINSIDCNT.NEXTVAL@als_sequence_link FROM DUAL;
*/

-- =====================================================
-- STEP 9: CLEANUP PROCEDURE (FOR FUTURE USE)
-- =====================================================

-- 9.1 Create cleanup procedure for when validation is complete
CREATE OR REPLACE PROCEDURE cleanup_entitydev_link AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== CLEANING UP ENTITYDEV DATABASE LINK SETUP ===');
    
    -- Remove audit policy
    NOAUDIT SELECT ON SEQUENCE_OWNER.TINSIDCNT BY entitydev_link_user;  -- Replace SEQUENCE_OWNER with actual
    
    -- Drop public synonym
    DROP PUBLIC SYNONYM TINSIDCNT_REMOTE;
    
    -- Drop user (will cascade privileges)
    DROP USER entitydev_link_user;
    
    -- Archive setup log
    CREATE TABLE entitydev_link_setup_log_archive AS
    SELECT *, SYSDATE as archived_date, 'CLEANUP_COMPLETE' as status
    FROM entitydev_link_setup_log;
    
    DROP TABLE entitydev_link_setup_log;
    
    DBMS_OUTPUT.PUT_LINE('Cleanup completed successfully');
    DBMS_OUTPUT.PUT_LINE('User entitydev_link_user removed');
    DBMS_OUTPUT.PUT_LINE('All privileges revoked');
    DBMS_OUTPUT.PUT_LINE('=== END CLEANUP ===');
END;
/

-- DO NOT RUN cleanup_entitydev_link procedure yet!
-- Save for future when validation phase is complete

-- =====================================================
-- IMPLEMENTATION COMPLETE - ALS LEGACY SIDE
-- =====================================================

PROMPT 
PROMPT ===================================================
PROMPT ALS LEGACY SETUP COMPLETED SUCCESSFULLY
PROMPT ===================================================
PROMPT 
PROMPT Summary:
PROMPT - User created: entitydev_link_user
PROMPT - Password: EntityDev2025!Link  
PROMPT - Sequence access granted: SEQUENCE_OWNER.TINSIDCNT
PROMPT - Public synonym created: TINSIDCNT_REMOTE
PROMPT 
PROMPT Next Steps:
PROMPT 1. Provide connection details to ENTITYDEV DBA team
PROMPT 2. Coordinate ENTITYDEV implementation
PROMPT 3. Validate connectivity from ENTITYDEV
PROMPT 
PROMPT Security Notes:
PROMPT - Minimal privileges granted (SELECT on sequence only)
PROMPT - Audit trail enabled
PROMPT - Cleanup procedure available for future use
PROMPT 
PROMPT Connection Test from ENTITYDEV should show:
PROMPT - Successful connection to dual@als_sequence_link
PROMPT - Sequence values from TINSIDCNT@als_sequence_link
PROMPT 
PROMPT ===================================================