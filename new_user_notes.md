# Enhanced Oracle User Creation with Role Management

## Overview
This script provides a comprehensive solution for Oracle DBAs to create multiple users with MD5 hashed passwords and standardized permissions through roles. It's designed to work with tools like TOAD and Spring Boot applications.

## Script

```sql
-- First, create the role for standardized permissions
CREATE OR REPLACE PROCEDURE setup_als_roles IS
BEGIN
  -- Create role (will ignore if it already exists)
  BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE als_user_role';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -955 THEN NULL; -- Role already exists
      ELSE RAISE;
      END IF;
  END;
  
  -- Grant necessary permissions to the role
  EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, DELETE ON [schema_name].[object_name] TO als_user_role';
END;
/

-- Main procedure for batch user creation with MD5 passwords
CREATE OR REPLACE PROCEDURE create_multiple_users (
  p_usernames IN SYS.ODCIVARCHAR2LIST,
  p_return_passwords OUT SYS.ODCIVARCHAR2LIST
) AUTHID CURRENT_USER IS
  v_random_str VARCHAR2(100);
  v_password VARCHAR2(100);
  v_hash_raw RAW(16);
  v_hash_hex VARCHAR2(32);
BEGIN
  -- First ensure the role exists
  setup_als_roles;
  
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
    BEGIN
      EXECUTE IMMEDIATE 'CREATE USER ' || DBMS_ASSERT.ENQUOTE_NAME(p_usernames(i)) || 
                       ' IDENTIFIED BY ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_password) ||
                       ' DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS';
                       
      -- Grant connect for basic login capability
      EXECUTE IMMEDIATE 'GRANT CONNECT TO ' || DBMS_ASSERT.ENQUOTE_NAME(p_usernames(i));
      
      -- Grant the role with table privileges
      EXECUTE IMMEDIATE 'GRANT als_user_role TO ' || DBMS_ASSERT.ENQUOTE_NAME(p_usernames(i));
      
      -- Add password to return collection
      p_return_passwords.EXTEND;
      p_return_passwords(p_return_passwords.COUNT) := p_usernames(i) || ':' || v_password;
    EXCEPTION
      WHEN OTHERS THEN
        -- Log error but continue with other users
        DBMS_OUTPUT.PUT_LINE('Error creating user ' || p_usernames(i) || ': ' || SQLERRM);
    END;
  END LOOP;
  
  COMMIT;
END;
/
```

## Example Usage

```sql
-- Example: Create three users at once
DECLARE
  v_usernames SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('USER1', 'USER2', 'USER3');
  v_passwords SYS.ODCIVARCHAR2LIST;
BEGIN
  -- Enable output to see results
  SET SERVEROUTPUT ON SIZE 1000000;
  
  -- Create multiple users
  create_multiple_users(v_usernames, v_passwords);
  
  -- Display results
  DBMS_OUTPUT.PUT_LINE('Created users with the following credentials:');
  DBMS_OUTPUT.PUT_LINE('----------------------------------------');
  FOR i IN 1..v_passwords.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(v_passwords(i));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('----------------------------------------');
  DBMS_OUTPUT.PUT_LINE('IMPORTANT: Store these credentials securely!');
END;
/
```

## Implementation Notes

1. Replace `[schema_name].[object_name]` with your actual schema and table names.

2. The script requires:
   - DBA privileges
   - EXECUTE permission on DBMS_CRYPTO
   - CREATE USER system privilege
   - CREATE ROLE system privilege

3. Security considerations:
   - Store generated passwords securely
   - Consider implementing password expiration policies
   - For production systems, consider additional security measures

4. The users created will be able to:
   - Connect to the database (CONNECT role)
   - Perform SELECT, INSERT, DELETE operations on the specified table
   - Store their own objects in the USERS tablespace

5. This approach is compatible with:
   - TOAD and other SQL clients
   - Spring Boot applications using JDBC
   - Any standard Oracle connection method
