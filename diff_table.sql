CREATE OR REPLACE PROCEDURE compare_tables(
    p_source_table IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_compare_field IN VARCHAR2 DEFAULT NULL,
    p_key_field IN VARCHAR2 DEFAULT NULL
) AS
    TYPE t_column_list IS TABLE OF VARCHAR2(128);
    v_compare_columns t_column_list := t_column_list();
    v_source_exists NUMBER;
    v_target_exists NUMBER;
    v_key_field VARCHAR2(128);
    v_compare_field VARCHAR2(128) := p_compare_field;
    v_sql VARCHAR2(32767);
    v_where_clause VARCHAR2(32767);
    v_count NUMBER;
    
    -- Variables to store comparison results
    v_rows_only_in_source NUMBER := 0;
    v_rows_only_in_target NUMBER := 0;
    v_rows_different NUMBER := 0;
    v_rows_matching NUMBER := 0;
    v_columns_compared NUMBER := 0;
    
    -- Cursor to get common columns between tables
    CURSOR c_common_columns IS
        SELECT column_name
        FROM all_tab_columns
        WHERE table_name = UPPER(p_source_table)
        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
        AND column_name IN (
            SELECT column_name
            FROM all_tab_columns
            WHERE table_name = UPPER(p_target_table)
            AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
        )
        ORDER BY column_id;
BEGIN
    -- Validate required input parameters
    IF p_source_table IS NULL OR p_target_table IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Source table and target table must be specified');
    END IF;
    
    -- Check if the tables exist
    SELECT COUNT(*) INTO v_source_exists 
    FROM all_tables 
    WHERE table_name = UPPER(p_source_table) AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    
    SELECT COUNT(*) INTO v_target_exists 
    FROM all_tables 
    WHERE table_name = UPPER(p_target_table) AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    
    IF v_source_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Source table ' || p_source_table || ' does not exist');
    END IF;
    
    IF v_target_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Target table ' || p_target_table || ' does not exist');
    END IF;
    
    -- Determine key field if not provided
    IF p_key_field IS NULL THEN
        -- Try to find a primary key
        BEGIN
            SELECT column_name INTO v_key_field
            FROM all_cons_columns
            WHERE constraint_name = (
                SELECT constraint_name 
                FROM all_constraints 
                WHERE table_name = UPPER(p_source_table) 
                AND constraint_type = 'P'
                AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
            )
            AND ROWNUM = 1
            AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- If no primary key, try to find a unique constraint
                BEGIN
                    SELECT column_name INTO v_key_field
                    FROM all_cons_columns
                    WHERE constraint_name = (
                        SELECT constraint_name 
                        FROM all_constraints 
                        WHERE table_name = UPPER(p_source_table) 
                        AND constraint_type = 'U'
                        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
                    )
                    AND ROWNUM = 1
                    AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- If no unique constraint, use the first column
                        SELECT column_name INTO v_key_field
                        FROM all_tab_columns
                        WHERE table_name = UPPER(p_source_table)
                        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
                        AND ROWNUM = 1
                        ORDER BY column_id;
                END;
        END;
    ELSE
        v_key_field := p_key_field;
    END IF;
    
    -- Verify key field exists in both tables
    SELECT COUNT(*) INTO v_source_exists
    FROM all_tab_columns
    WHERE table_name = UPPER(p_source_table)
    AND column_name = UPPER(v_key_field)
    AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    
    SELECT COUNT(*) INTO v_target_exists
    FROM all_tab_columns
    WHERE table_name = UPPER(p_target_table)
    AND column_name = UPPER(v_key_field)
    AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    
    IF v_source_exists = 0 OR v_target_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Key field ' || v_key_field || ' does not exist in both tables');
    END IF;
    
    -- Determine which columns to compare
    IF p_compare_field IS NULL THEN
        -- Compare all common columns except the key field
        FOR col_rec IN c_common_columns LOOP
            IF col_rec.column_name <> v_key_field THEN
                v_compare_columns.EXTEND;
                v_compare_columns(v_compare_columns.COUNT) := col_rec.column_name;
            END IF;
        END LOOP;
        
        IF v_compare_columns.COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'No common columns found between tables except key field');
        END IF;
    ELSE
        -- Check if the specified comparison field exists in both tables
        SELECT COUNT(*) INTO v_source_exists
        FROM all_tab_columns
        WHERE table_name = UPPER(p_source_table)
        AND column_name = UPPER(p_compare_field)
        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        
        SELECT COUNT(*) INTO v_target_exists
        FROM all_tab_columns
        WHERE table_name = UPPER(p_target_table)
        AND column_name = UPPER(p_compare_field)
        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        
        IF v_source_exists = 0 OR v_target_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Compare field ' || p_compare_field || ' does not exist in both tables');
        END IF;
        
        v_compare_columns.EXTEND;
        v_compare_columns(1) := p_compare_field;
    END IF;
    
    -- Create a temporary table to store comparison results
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE temp_compare_results';
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Table doesn't exist, that's fine
    END;
    
    -- Create temp table with dynamic columns based on what we're comparing
    v_sql := 'CREATE GLOBAL TEMPORARY TABLE temp_compare_results (
        key_value VARCHAR2(4000),
        status VARCHAR2(20),';
        
    -- Add column pairs for each comparison column
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || '
        ' || v_compare_columns(i) || '_source CLOB,
        ' || v_compare_columns(i) || '_target CLOB,';
    END LOOP;
    
    -- Remove the trailing comma and add the closing parenthesis
    v_sql := SUBSTR(v_sql, 1, LENGTH(v_sql) - 1);
    v_sql := v_sql || ') ON COMMIT PRESERVE ROWS';
    
    EXECUTE IMMEDIATE v_sql;
        
    -- Find records only in source
    v_sql := '
        INSERT INTO temp_compare_results (key_value, status';
    
    -- Add source columns
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', ' || v_compare_columns(i) || '_source';
    END LOOP;
    
    v_sql := v_sql || ')
        SELECT s.' || v_key_field || ', ''ONLY_IN_SOURCE''';
    
    -- Add source values
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', s.' || v_compare_columns(i);
    END LOOP;
    
    v_sql := v_sql || '
        FROM ' || p_source_table || ' s
        WHERE NOT EXISTS (
            SELECT 1 
            FROM ' || p_target_table || ' t
            WHERE t.' || v_key_field || ' = s.' || v_key_field || '
        )';
    
    EXECUTE IMMEDIATE v_sql;
    v_rows_only_in_source := SQL%ROWCOUNT;
    
    -- Find records only in target
    v_sql := '
        INSERT INTO temp_compare_results (key_value, status';
    
    -- Add target columns
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', ' || v_compare_columns(i) || '_target';
    END LOOP;
    
    v_sql := v_sql || ')
        SELECT t.' || v_key_field || ', ''ONLY_IN_TARGET''';
    
    -- Add target values
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', t.' || v_compare_columns(i);
    END LOOP;
    
    v_sql := v_sql || '
        FROM ' || p_target_table || ' t
        WHERE NOT EXISTS (
            SELECT 1 
            FROM ' || p_source_table || ' s
            WHERE s.' || v_key_field || ' = t.' || v_key_field || '
        )';
    
    EXECUTE IMMEDIATE v_sql;
    v_rows_only_in_target := SQL%ROWCOUNT;
    
    -- Build the WHERE clause for the different values comparison
    v_where_clause := '';
    FOR i IN 1..v_compare_columns.COUNT LOOP
        IF i > 1 THEN
            v_where_clause := v_where_clause || ' OR ';
        END IF;
        
        v_where_clause := v_where_clause || '
            DECODE(s.' || v_compare_columns(i) || ', t.' || v_compare_columns(i) || ', 0, 1) = 1
            OR (s.' || v_compare_columns(i) || ' IS NULL AND t.' || v_compare_columns(i) || ' IS NOT NULL)
            OR (s.' || v_compare_columns(i) || ' IS NOT NULL AND t.' || v_compare_columns(i) || ' IS NULL)';
    END LOOP;
    
    -- Find records with different values
    v_sql := '
        INSERT INTO temp_compare_results (key_value, status';
    
    -- Add all columns for source and target
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', ' || v_compare_columns(i) || '_source, ' || v_compare_columns(i) || '_target';
    END LOOP;
    
    v_sql := v_sql || ')
        SELECT s.' || v_key_field || ', ''DIFFERENT''';
    
    -- Add source and target values
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', s.' || v_compare_columns(i) || ', t.' || v_compare_columns(i);
    END LOOP;
    
    v_sql := v_sql || '
        FROM ' || p_source_table || ' s
        JOIN ' || p_target_table || ' t ON t.' || v_key_field || ' = s.' || v_key_field || '
        WHERE ' || v_where_clause;
    
    EXECUTE IMMEDIATE v_sql;
    v_rows_different := SQL%ROWCOUNT;
    
    -- Count matching records
    v_sql := '
        SELECT COUNT(*)
        FROM ' || p_source_table || ' s
        JOIN ' || p_target_table || ' t ON t.' || v_key_field || ' = s.' || v_key_field || '
        WHERE NOT (' || v_where_clause || ')';
    
    EXECUTE IMMEDIATE v_sql INTO v_rows_matching;
    
    -- Output summary
    DBMS_OUTPUT.PUT_LINE('==================== COMPARISON SUMMARY ====================');
    DBMS_OUTPUT.PUT_LINE('Source table: ' || p_source_table);
    DBMS_OUTPUT.PUT_LINE('Target table: ' || p_target_table);
    DBMS_OUTPUT.PUT_LINE('Key field: ' || v_key_field);
    
    -- List the columns being compared
    DBMS_OUTPUT.PUT_LINE('Compared columns:');
    FOR i IN 1..v_compare_columns.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('  - ' || v_compare_columns(i));
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Records only in source: ' || v_rows_only_in_source);
    DBMS_OUTPUT.PUT_LINE('Records only in target: ' || v_rows_only_in_target);
    DBMS_OUTPUT.PUT_LINE('Records with differences: ' || v_rows_different);
    DBMS_OUTPUT.PUT_LINE('Records matching exactly: ' || v_rows_matching);
    DBMS_OUTPUT.PUT_LINE('Total differences: ' || (v_rows_only_in_source + v_rows_only_in_target + v_rows_different));
    DBMS_OUTPUT.PUT_LINE('==========================================================');
    
    -- Output detailed results
    IF v_rows_only_in_source > 0 OR v_rows_only_in_target > 0 OR v_rows_different > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Detailed differences available in the TEMP_COMPARE_RESULTS table');
        DBMS_OUTPUT.PUT_LINE('Query with: SELECT * FROM temp_compare_results ORDER BY status, key_value');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END compare_tables;
/
