# Instructions for Executing Oracle User Creation Stored Procedure

## Prerequisites
- Oracle Database client tools installed (SQL*Plus or SQLcl)
- DBA privileges (SYSDBA or user with CREATE USER and GRANT privileges)
- Access to the database server

## Step-by-Step Execution Instructions

### 1. Connect to the Database with DBA Privileges

Using SQL*Plus:
```sql
sqlplus username/password@database AS SYSDBA
```

Or using SQLcl:
```sql
sql username/password@database AS SYSDBA
```

Replace `username`, `password`, and `database` with your actual credentials and database service name.

### 2. Check Required Privileges

Verify you have the necessary privileges:
```sql
SELECT * FROM SESSION_PRIVS WHERE PRIVILEGE IN 
('CREATE USER', 'CREATE PROCEDURE', 'CREATE SESSION', 'ALTER USER');
```

### 3. Create the Stored Procedure

Copy and paste the entire stored procedure script into your SQL client and execute it. The script should include:

```sql
CREATE OR REPLACE PROCEDURE create_new_user (
    p_username IN VARCHAR2,
    p_generated_username OUT VARCHAR2,
    p_generated_password OUT VARCHAR2
)
AUTHID CURRENT_USER
IS
    v_random_str VARCHAR2(100);
    v_password VARCHAR2(100);
    v_hash_raw RAW(16);
    v_hash_hex VARCHAR2(32);
BEGIN
    -- Generate a random string as the base for password
    v_random_str := DBMS_RANDOM.STRING('A', 16);
    
    -- Generate MD5 hash of the random string
    v_hash_raw := DBMS_CRYPTO.HASH(
                    src => UTL_RAW.CAST_TO_RAW(v_random_str),
                    typ => DBMS_CRYPTO.HASH_MD5);
    
    -- Convert hash to hex
    v_hash_hex := RAWTOHEX(v_hash_raw);
    
    -- Take first 8 characters of the hash as password
    v_password := SUBSTR(v_hash_hex, 1, 8);
    
    -- Create the Oracle user
    EXECUTE IMMEDIATE 'CREATE USER ' || DBMS_ASSERT.ENQUOTE_NAME(p_username) || 
                      ' IDENTIFIED BY ' || DBMS_ASSERT.ENQUOTE_LITERAL(v_password);
                      
    -- Grant privileges on ENTITYDEV.ALS table
    EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, DELETE ON ENTITYDEV.ALS TO ' || 
                      DBMS_ASSERT.ENQUOTE_NAME(p_username);
    
    -- Set output parameters
    p_generated_username := p_username;
    p_generated_password := v_password;
    
    -- Commit the transaction
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END create_new_user;
/
```

### 4. Enable DBMS_OUTPUT to See Results

```sql
SET SERVEROUTPUT ON SIZE 1000000;
```

### 5. Execute the Procedure

Use the following PL/SQL block to call the procedure. Make sure to replace 'NEW_USERNAME' with the actual username you want to create:

```sql
DECLARE
    v_username VARCHAR2(30);
    v_password VARCHAR2(30);
BEGIN
    -- Call the procedure to create a new user
    create_new_user(
        p_username => 'NEW_USERNAME',
        p_generated_username => v_username,
        p_generated_password => v_password
    );
    
    -- Output the results
    DBMS_OUTPUT.PUT_LINE('Username: ' || v_username);
    DBMS_OUTPUT.PUT_LINE('Password: ' || v_password);
END;
/
```

### 6. Verify the User Was Created

After executing, verify the user creation with:

```sql
SELECT username, account_status FROM dba_users WHERE username = 'NEW_USERNAME';
```

### 7. Verify the Granted Privileges

Verify that the required privileges were granted:

```sql
SELECT grantee, privilege, table_name 
FROM dba_tab_privs 
WHERE grantee = 'NEW_USERNAME' 
AND table_name = 'ALS' 
AND owner = 'ENTITYDEV';
```

### 8. Optional: Document the New User

Record the newly created username and password in your secure credential management system, as this is the only time you'll see the generated password in plaintext.

## Troubleshooting Common Issues

1. **ORA-01031: insufficient privileges**
   - Ensure you're connected as SYSDBA or a user with administrative privileges.

2. **ORA-00942: table or view does not exist**
   - Verify the ENTITYDEV.ALS table exists and is accessible.

3. **ORA-04063: procedure has errors**
   - Check for compilation errors with:
     ```sql
     SHOW ERRORS PROCEDURE create_new_user;
     ```

4. **ORA-06550: line X, column Y: PLS-00201: identifier 'DBMS_CRYPTO' must be declared**
   - Grant execute permissions on DBMS_CRYPTO:
     ```sql
     GRANT EXECUTE ON SYS.DBMS_CRYPTO TO your_dba_user;
     ```

5. **Password Not Visible**
   - Ensure SERVEROUTPUT is set ON before executing the procedure.

## Security Notes

- Store the generated passwords securely
- Consider implementing a more secure password policy if needed
- This procedure creates users with simple privileges; adjust as necessary for your security requirements
- Remember that user creation and privilege management are sensitive administrative functions
