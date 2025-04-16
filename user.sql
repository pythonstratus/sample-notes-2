-- 1. Setup Roles Procedure
CREATE OR REPLACE PROCEDURE setup_roles (
  p_role_type IN VARCHAR2  -- 'USER', 'DEVELOPER', 'ADMIN'
) IS
  v_role_name VARCHAR2(30);
BEGIN
  v_role_name := CASE 
    WHEN p_role_type = 'USER' THEN 'als_user_role'
    WHEN p_role_type = 'DEVELOPER' THEN 'als_developer_role'
    WHEN p_role_type = 'ADMIN' THEN 'als_admin_role'
    ELSE 'als_user_role'
  END;
  
  -- Create role if it doesn't exist
  BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE ' || v_role_name;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -955 THEN NULL; -- Role already exists
      ELSE RAISE;
      END IF;
  END;
  
  -- Grant appropriate permissions based on role type
  CASE p_role_type
    WHEN 'USER' THEN
      DBMS_OUTPUT.PUT_LINE('Creating USER role with SELECT permissions');
      -- No additional grants here - use grant_tables_to_role procedure
    WHEN 'DEVELOPER' THEN
      DBMS_OUTPUT.PUT_LINE('Creating DEVELOPER role with SELECT, INSERT, DELETE permissions');
      -- No additional grants here - use grant_tables_to_role procedure
    WHEN 'ADMIN' THEN
      DBMS_OUTPUT.PUT_LINE('Creating ADMIN role with full permissions');
      EXECUTE IMMEDIATE 'GRANT CREATE TABLE, CREATE VIEW, CREATE TYPE TO ' || v_role_name;
  END CASE;
END;
/

-- 2. Grant Tables to Role Procedure
CREATE OR REPLACE PROCEDURE grant_tables_to_role (
  p_role_name IN VARCHAR2,
  p_table_list IN SYS.ODCIVARCHAR2LIST,
  p_privs IN VARCHAR2  -- 'SELECT' or 'SELECT,INSERT,DELETE', etc.
) IS
BEGIN
  FOR i IN 1..p_table_list.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'GRANT ' || p_privs || ' ON ' || p_table_list(i) || ' TO ' || p_role_name;
      DBMS_OUTPUT.PUT_LINE('Granted ' || p_privs || ' on ' || p_table_list(i) || ' to ' || p_role_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error granting privileges on ' || p_table_list(i) || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

-- 3. Create Multiple Users with Role Assignment
CREATE OR REPLACE PROCEDURE create_multiple_users (
  p_usernames IN SYS.ODCIVARCHAR2LIST,
  p_role_type IN VARCHAR2,  -- 'USER', 'DEVELOPER', 'ADMIN'
  p_return_passwords OUT SYS.ODCIVARCHAR2LIST,
  p_test_only IN BOOLEAN DEFAULT FALSE
) AUTHID CURRENT_USER IS
  v_random_str VARCHAR2(100);
  v_password VARCHAR2(100);
  v_hash_raw RAW(16);
  v_hash_hex VARCHAR2(32);
  v_role_name VARCHAR2(30);
BEGIN
  -- Determine role name based on role type
  v_role_name := CASE 
    WHEN p_role_type = 'USER' THEN 'als_user_role'
    WHEN p_role_type = 'DEVELOPER' THEN 'als_developer_role'
    WHEN p_role_type = 'ADMIN' THEN 'als_admin_role'
    ELSE 'als_user_role'
  END;
  
  -- Ensure the role exists
  IF NOT p_test_only THEN
    setup_roles(p_role_type);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Would ensure role exists: ' || v_role_name);
  END IF;
  
  -- Initialize the output collection
  p_return_passwords := SYS.ODCIVARCHAR2LIST();
  
  -- Process each username
  FOR i IN 1..p_usernames.COUNT LOOP
    -- Generate random string as password base
    v_random_str := DBMS_RANDOM.STRING('A', 16) || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF');
    
    -- Generate MD5 hash
    v_hash_raw := DBMS_CRYPTO.HASH(
                src => UTL_RAW.CAST_TO_RAW(v_random_str),
                typ => DBMS_CRYPTO.HASH_MD5);
    
    -- Convert to hex and take first 8 chars
    v_hash_hex := RAWTOHEX(v_hash_raw);
    v_password := SUBSTR(v_hash_hex, 1, 8);
    
    -- Create the user
    IF NOT p_test_only THEN
      BEGIN
        EXECUTE IMMEDIATE 'CREATE USER ' || DBMS_ASSERT.ENQUOTE_NAME(p_usernames(i)) || 
                         ' IDENTIFIED BY ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_password) ||
                         ' DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS';
                         
        -- Grant connect for basic login capability
        EXECUTE IMMEDIATE 'GRANT CONNECT TO ' || DBMS_ASSERT.ENQUOTE_NAME(p_usernames(i));
        
        -- Grant the appropriate role
        EXECUTE IMMEDIATE 'GRANT ' || v_role_name || ' TO ' || DBMS_ASSERT.ENQUOTE_NAME(p_usernames(i));
        
        -- Add password to return collection
        p_return_passwords.EXTEND;
        p_return_passwords(p_return_passwords.COUNT) := p_usernames(i) || ':' || v_password;
      EXCEPTION
        WHEN OTHERS THEN
          -- Log error but continue with other users
          DBMS_OUTPUT.PUT_LINE('Error creating user ' || p_usernames(i) || ': ' || SQLERRM);
      END;
    ELSE
      -- Test mode - just report what would happen
      DBMS_OUTPUT.PUT_LINE('Would create user: ' || p_usernames(i) || ' with password: ' || v_password);
      DBMS_OUTPUT.PUT_LINE('Would grant role: ' || v_role_name || ' to user: ' || p_usernames(i));
      
      -- Still add to return collection for testing
      p_return_passwords.EXTEND;
      p_return_passwords(p_return_passwords.COUNT) := p_usernames(i) || ':' || v_password || ' (TEST MODE)';
    END IF;
  END LOOP;
  
  IF NOT p_test_only THEN
    COMMIT;
  ELSE
    DBMS_OUTPUT.PUT_LINE('TEST MODE: No changes were made to the database.');
  END IF;
END;
/

-- 4. Generate Documentation for Change Requests
CREATE OR REPLACE PROCEDURE generate_change_doc (
  p_usernames IN SYS.ODCIVARCHAR2LIST,
  p_role_type IN VARCHAR2,
  p_tables IN SYS.ODCIVARCHAR2LIST DEFAULT NULL
) IS
  v_role_name VARCHAR2(30);
  v_privs VARCHAR2(100);
BEGIN
  v_role_name := CASE 
    WHEN p_role_type = 'USER' THEN 'als_user_role'
    WHEN p_role_type = 'DEVELOPER' THEN 'als_developer_role'
    WHEN p_role_type = 'ADMIN' THEN 'als_admin_role'
    ELSE 'als_user_role'
  END;
  
  v_privs := CASE 
    WHEN p_role_type = 'USER' THEN 'SELECT'
    WHEN p_role_type = 'DEVELOPER' THEN 'SELECT, INSERT, DELETE'
    WHEN p_role_type = 'ADMIN' THEN 'SELECT, INSERT, UPDATE, DELETE, CREATE TABLE, CREATE VIEW, CREATE TYPE'
    ELSE 'SELECT'
  END;

  DBMS_OUTPUT.PUT_LINE('Change Request Documentation');
  DBMS_OUTPUT.PUT_LINE('=============================');
  DBMS_OUTPUT.PUT_LINE('Users to be created: ' || p_usernames.COUNT);
  FOR i IN 1..p_usernames.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('- ' || p_usernames(i));
  END LOOP;
  
  DBMS_OUTPUT.PUT_LINE('Role to be assigned: ' || v_role_name);
  DBMS_OUTPUT.PUT_LINE('Privileges associated with role: ' || v_privs);
  
  IF p_tables IS NOT NULL AND p_tables.COUNT > 0 THEN
    DBMS_OUTPUT.PUT_LINE('Tables to grant privileges on:');
    FOR i IN 1..p_tables.COUNT LOOP
      DBMS_OUTPUT.PUT_LINE('- ' || p_tables(i) || ' (' || v_privs || ')');
    END LOOP;
  END IF;
  
  DBMS_OUTPUT.PUT_LINE('=============================');
  DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('Change Request Prepared For: Christina');
END;
/

-- 5. Example Usage
-- This section demonstrates how to use the procedures
CREATE OR REPLACE PROCEDURE run_complete_example (
  p_test_only IN BOOLEAN DEFAULT TRUE
) IS
  v_usernames SYS.ODCIVARCHAR2LIST;
  v_tables SYS.ODCIVARCHAR2LIST;
  v_passwords SYS.ODCIVARCHAR2LIST;
  v_role_type VARCHAR2(30) := 'DEVELOPER';
  v_role_name VARCHAR2(30);
  v_privs VARCHAR2(100);
BEGIN
  -- Enable output
  DBMS_OUTPUT.ENABLE(1000000);
  
  -- Setup example data
  v_usernames := SYS.ODCIVARCHAR2LIST('USER1', 'USER2', 'USER3');
  v_tables := SYS.ODCIVARCHAR2LIST('[schema_name].[table1]', '[schema_name].[table2]', '[schema_name].[table3]');
  
  -- Determine role name and privileges based on role type
  v_role_name := CASE 
    WHEN v_role_type = 'USER' THEN 'als_user_role'
    WHEN v_role_type = 'DEVELOPER' THEN 'als_developer_role'
    WHEN v_role_type = 'ADMIN' THEN 'als_admin_role'
    ELSE 'als_user_role'
  END;
  
  v_privs := CASE 
    WHEN v_role_type = 'USER' THEN 'SELECT'
    WHEN v_role_type = 'DEVELOPER' THEN 'SELECT, INSERT, DELETE'
    WHEN v_role_type = 'ADMIN' THEN 'SELECT, INSERT, UPDATE, DELETE'
    ELSE 'SELECT'
  END;
  
  -- Step 1: Generate documentation for change request
  generate_change_doc(v_usernames, v_role_type, v_tables);
  
  -- Step 2: Create the role (if running in non-test mode)
  IF NOT p_test_only THEN
    setup_roles(v_role_type);
  ELSE
    DBMS_OUTPUT.PUT_LINE('TEST MODE: Would create role: ' || v_role_name);
  END IF;
  
  -- Step 3: Grant table privileges to the role
  IF NOT p_test_only THEN
    grant_tables_to_role(v_role_name, v_tables, v_privs);
  ELSE
    DBMS_OUTPUT.PUT_LINE('TEST MODE: Would grant ' || v_privs || ' on tables to role: ' || v_role_name);
    FOR i IN 1..v_tables.COUNT LOOP
      DBMS_OUTPUT.PUT_LINE('- ' || v_tables(i));
    END LOOP;
  END IF;
  
  -- Step 4: Create users and assign the role
  create_multiple_users(v_usernames, v_role_type, v_passwords, p_test_only);
  
  -- Step 5: Display results
  DBMS_OUTPUT.PUT_LINE('Results:');
  DBMS_OUTPUT.PUT_LINE('--------');
  FOR i IN 1..v_passwords.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(v_passwords(i));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('--------');
  
  IF p_test_only THEN
    DBMS_OUTPUT.PUT_LINE('To execute this for real, call run_complete_example(FALSE)');
  END IF;
END;
/

-- Execute the example in test mode
BEGIN
  run_complete_example(TRUE);  -- TRUE = test mode, FALSE = actual execution
END;
/
