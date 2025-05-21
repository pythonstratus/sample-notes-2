CREATE OR REPLACE FUNCTION compare_columns_only(
    p_source_table IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_include_columns IN VARCHAR2,
    p_key_field IN VARCHAR2 DEFAULT NULL
) RETURN SYS_REFCURSOR
AS
    TYPE t_column_list IS TABLE OF VARCHAR2(128);
    v_compare_columns t_column_list := t_column_list();
    v_include_columns t_column_list := t_column_list();
    v_source_exists NUMBER;
    v_target_exists NUMBER;
    v_key_field VARCHAR2(128);
    v_sql VARCHAR2(32767);
    v_dynamic_cursor SYS_REFCURSOR;
    v_count NUMBER;
    v_include_column VARCHAR2(128);
    v_start_pos NUMBER;
    v_end_pos NUMBER;
    v_temp_str VARCHAR2(4000);
    
BEGIN
    -- Validate required input parameters
    IF p_source_table IS NULL OR p_target_table IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Source table and target table must be specified');
    END IF;
    
    IF p_include_columns IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Include columns parameter must be specified');
    END IF;
    
    -- Process the include columns list into a collection
    v_temp_str := p_include_columns || ',';
    v_start_pos := 1;
    
    LOOP
        v_end_pos := INSTR(v_temp_str, ',', v_start_pos);
        EXIT WHEN v_end_pos = 0;
        
        v_include_column := TRIM(UPPER(SUBSTR(v_temp_str, v_start_pos, v_end_pos - v_start_pos)));
        
        IF v_include_column IS NOT NULL THEN
            v_include_columns.EXTEND;
            v_include_columns(v_include_columns.COUNT) := v_include_column;
        END IF;
        
        v_start_pos := v_end_pos + 1;
    END LOOP;
    
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
        v_key_field := UPPER(p_key_field);
    END IF;
    
    -- Verify key field exists in both tables
    SELECT COUNT(*) INTO v_source_exists
    FROM all_tab_columns
    WHERE table_name = UPPER(p_source_table)
    AND column_name = v_key_field
    AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    
    SELECT COUNT(*) INTO v_target_exists
    FROM all_tab_columns
    WHERE table_name = UPPER(p_target_table)
    AND column_name = v_key_field
    AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    
    IF v_source_exists = 0 OR v_target_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Key field ' || v_key_field || ' does not exist in both tables');
    END IF;
    
    -- Verify included columns exist in both tables
    FOR i IN 1..v_include_columns.COUNT LOOP
        SELECT COUNT(*) INTO v_source_exists
        FROM all_tab_columns
        WHERE table_name = UPPER(p_source_table)
        AND column_name = v_include_columns(i)
        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        
        SELECT COUNT(*) INTO v_target_exists
        FROM all_tab_columns
        WHERE table_name = UPPER(p_target_table)
        AND column_name = v_include_columns(i)
        AND owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
        
        IF v_source_exists = 0 OR v_target_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Column ' || v_include_columns(i) || ' does not exist in both tables');
        ELSE
            -- Add to comparison columns
            v_compare_columns.EXTEND;
            v_compare_columns(v_compare_columns.COUNT) := v_include_columns(i);
        END IF;
    END LOOP;
    
    IF v_compare_columns.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'No valid columns to compare');
    END IF;
    
    -- Log comparison parameters to console
    DBMS_OUTPUT.PUT_LINE('Comparing tables: ' || p_source_table || ' and ' || p_target_table);
    DBMS_OUTPUT.PUT_LINE('Key field: ' || v_key_field);
    DBMS_OUTPUT.PUT_LINE('Comparing the following columns: ');
    FOR i IN 1..v_compare_columns.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('  - ' || v_compare_columns(i));
    END LOOP;
    
    -- Build a SQL query that does a full outer join and returns differences
    v_sql := '
    WITH source_data AS (
        SELECT s.' || v_key_field || ' AS key_value';
    
    -- Add source columns
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', 
            s.' || v_compare_columns(i) || ' AS ' || v_compare_columns(i) || '_source';
    END LOOP;
    
    v_sql := v_sql || '
        FROM ' || p_source_table || ' s
    ),
    target_data AS (
        SELECT t.' || v_key_field || ' AS key_value';
    
    -- Add target columns
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', 
            t.' || v_compare_columns(i) || ' AS ' || v_compare_columns(i) || '_target';
    END LOOP;
    
    v_sql := v_sql || '
        FROM ' || p_target_table || ' t
    ),
    comparison AS (
        SELECT 
            CASE
                WHEN t.key_value IS NULL THEN ''[+] ONLY_IN_SOURCE''
                WHEN s.key_value IS NULL THEN ''[-] ONLY_IN_TARGET''
                ELSE ''[≠] DIFFERENT''
            END AS status,
            COALESCE(s.key_value, t.key_value) AS key_value';
    
    -- Add source and target columns to select with diff markers
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ',
        s.' || v_compare_columns(i) || '_source,
        t.' || v_compare_columns(i) || '_target,
        CASE
            WHEN s.' || v_compare_columns(i) || '_source IS NULL AND t.' || v_compare_columns(i) || '_target IS NOT NULL THEN ''[NULL→VALUE]''
            WHEN s.' || v_compare_columns(i) || '_source IS NOT NULL AND t.' || v_compare_columns(i) || '_target IS NULL THEN ''[VALUE→NULL]''
            WHEN s.' || v_compare_columns(i) || '_source != t.' || v_compare_columns(i) || '_target 
                 OR (s.' || v_compare_columns(i) || '_source IS NULL AND t.' || v_compare_columns(i) || '_target IS NOT NULL)
                 OR (s.' || v_compare_columns(i) || '_source IS NOT NULL AND t.' || v_compare_columns(i) || '_target IS NULL)
            THEN ''[≠] DIFFERENT''
            ELSE ''[=] SAME''
        END AS ' || v_compare_columns(i) || '_diff';
    END LOOP;
    
    v_sql := v_sql || '
        FROM source_data s
        FULL OUTER JOIN target_data t ON s.key_value = t.key_value
    )
    SELECT 
        status,
        key_value';
        
    -- Add columns to the final select with diff indicator columns
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ',
        ' || v_compare_columns(i) || '_source,
        ' || v_compare_columns(i) || '_target,
        ' || v_compare_columns(i) || '_diff';
    END LOOP;
    
    v_sql := v_sql || '
    FROM comparison c
    WHERE ';
    
    -- Add condition to show only rows with differences in the specified columns
    v_sql := v_sql || '(status = ''[+] ONLY_IN_SOURCE'' OR status = ''[-] ONLY_IN_TARGET''';
    
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ' OR ' || v_compare_columns(i) || '_diff != ''[=] SAME''';
    END LOOP;
    
    v_sql := v_sql || ')
    ORDER BY status, key_value';
    
    -- For debugging
    -- DBMS_OUTPUT.PUT_LINE('Executing SQL: ' || v_sql);
    
    -- Open cursor with the dynamic SQL
    OPEN v_dynamic_cursor FOR v_sql;
    
    -- Return the cursor
    RETURN v_dynamic_cursor;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END compare_columns_only;
/
