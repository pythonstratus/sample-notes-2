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

-- Example usage of the stored procedure (for a DBA to execute)
DECLARE
    v_username VARCHAR2(30);
    v_password VARCHAR2(30);
BEGIN
    -- Call the procedure to create a new user
    create_new_user(
        p_username => 'NEW_USER',
        p_generated_username => v_username,
        p_generated_password => v_password
    );
    
    -- Output the results
    DBMS_OUTPUT.PUT_LINE('Username: ' || v_username);
    DBMS_OUTPUT.PUT_LINE('Password: ' || v_password);
END;
/
