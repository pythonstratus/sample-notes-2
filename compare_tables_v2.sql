CREATE OR REPLACE FUNCTION compare_tables_update_fn(
    p_source_table IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_compare_field IN VARCHAR2 DEFAULT NULL,
    p_key_field IN VARCHAR2 DEFAULT NULL,
    p_source_schema IN VARCHAR2 DEFAULT NULL,
    p_target_schema IN VARCHAR2 DEFAULT NULL
) RETURN SYS_REFCURSOR
AS
    TYPE t_column_list IS TABLE OF VARCHAR2(128);
    v_compare_columns t_column_list := t_column_list();
    v_source_exists NUMBER;
    v_target_exists NUMBER;
    v_key_field VARCHAR2(128);
    v_sql VARCHAR2(32767);
    v_dynamic_cursor SYS_REFCURSOR;
    v_count NUMBER;
    v_source_schema VARCHAR2(128);
    v_target_schema VARCHAR2(128);
    v_source_table_full VARCHAR2(261); -- schema.table (128.128 + 1 for dot)
    v_target_table_full VARCHAR2(261);
    v_source_table_name VARCHAR2(128);
    v_target_table_name VARCHAR2(128);
    
BEGIN
    -- Validate required input parameters
    IF p_source_table IS NULL OR p_target_table IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Source table and target table must be specified');
    END IF;
    
    -- Parse schema and table names for source
    IF INSTR(p_source_table, '.') > 0 THEN
        v_source_schema := UPPER(SUBSTR(p_source_table, 1, INSTR(p_source_table, '.') - 1));
        v_source_table_name := UPPER(SUBSTR(p_source_table, INSTR(p_source_table, '.') + 1));
    ELSE
        v_source_schema := COALESCE(UPPER(p_source_schema), SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));
        v_source_table_name := UPPER(p_source_table);
    END IF;
    
    -- Parse schema and table names for target
    IF INSTR(p_target_table, '.') > 0 THEN
        v_target_schema := UPPER(SUBSTR(p_target_table, 1, INSTR(p_target_table, '.') - 1));
        v_target_table_name := UPPER(SUBSTR(p_target_table, INSTR(p_target_table, '.') + 1));
    ELSE
        v_target_schema := COALESCE(UPPER(p_target_schema), SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'));
        v_target_table_name := UPPER(p_target_table);
    END IF;
    
    -- Build full table names for SQL
    v_source_table_full := v_source_schema || '.' || v_source_table_name;
    v_target_table_full := v_target_schema || '.' || v_target_table_name;
    
    -- Check if the tables exist and are accessible
    BEGIN
        SELECT COUNT(*) INTO v_source_exists 
        FROM all_tables 
        WHERE table_name = v_source_table_name 
        AND owner = v_source_schema;
        
        IF v_source_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Source table ' || v_source_table_full || ' does not exist or is not accessible');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002, 'Source table ' || v_source_table_full || ' does not exist or is not accessible: ' || SQLERRM);
    END;
    
    BEGIN
        SELECT COUNT(*) INTO v_target_exists 
        FROM all_tables 
        WHERE table_name = v_target_table_name 
        AND owner = v_target_schema;
        
        IF v_target_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Target table ' || v_target_table_full || ' does not exist or is not accessible');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Target table ' || v_target_table_full || ' does not exist or is not accessible: ' || SQLERRM);
    END;
    
    -- Determine key field if not provided
    IF p_key_field IS NULL THEN
        -- Try to find a primary key
        BEGIN
            SELECT column_name INTO v_key_field
            FROM all_cons_columns
            WHERE constraint_name = (
                SELECT constraint_name 
                FROM all_constraints 
                WHERE table_name = v_source_table_name 
                AND constraint_type = 'P'
                AND owner = v_source_schema
            )
            AND ROWNUM = 1
            AND owner = v_source_schema;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- If no primary key, try to find a unique constraint
                BEGIN
                    SELECT column_name INTO v_key_field
                    FROM all_cons_columns
                    WHERE constraint_name = (
                        SELECT constraint_name 
                        FROM all_constraints 
                        WHERE table_name = v_source_table_name 
                        AND constraint_type = 'U'
                        AND owner = v_source_schema
                    )
                    AND ROWNUM = 1
                    AND owner = v_source_schema;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- If no unique constraint, use the first column
                        SELECT column_name INTO v_key_field
                        FROM all_tab_columns
                        WHERE table_name = v_source_table_name
                        AND owner = v_source_schema
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
    WHERE table_name = v_source_table_name
    AND column_name = v_key_field
    AND owner = v_source_schema;
    
    SELECT COUNT(*) INTO v_target_exists
    FROM all_tab_columns
    WHERE table_name = v_target_table_name
    AND column_name = v_key_field
    AND owner = v_target_schema;
    
    IF v_source_exists = 0 OR v_target_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Key field ' || v_key_field || ' does not exist in both tables');
    END IF;
    
    -- Determine which columns to compare
    IF p_compare_field IS NULL THEN
        -- Compare all common columns except the key field
        FOR col_rec IN (
            SELECT column_name
            FROM all_tab_columns
            WHERE table_name = v_source_table_name
            AND owner = v_source_schema
            AND column_name IN (
                SELECT column_name
                FROM all_tab_columns
                WHERE table_name = v_target_table_name
                AND owner = v_target_schema
            )
            AND column_name <> v_key_field
            ORDER BY column_id
        ) LOOP
            v_compare_columns.EXTEND;
            v_compare_columns(v_compare_columns.COUNT) := col_rec.column_name;
        END LOOP;
        
        IF v_compare_columns.COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'No common columns found between tables except key field');
        END IF;
    ELSE
        -- Check if the specified comparison field exists in both tables
        SELECT COUNT(*) INTO v_source_exists
        FROM all_tab_columns
        WHERE table_name = v_source_table_name
        AND column_name = UPPER(p_compare_field)
        AND owner = v_source_schema;
        
        SELECT COUNT(*) INTO v_target_exists
        FROM all_tab_columns
        WHERE table_name = v_target_table_name
        AND column_name = UPPER(p_compare_field)
        AND owner = v_target_schema;
        
        IF v_source_exists = 0 OR v_target_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Compare field ' || p_compare_field || ' does not exist in both tables');
        END IF;
        
        v_compare_columns.EXTEND;
        v_compare_columns(1) := UPPER(p_compare_field);
    END IF;
    
    -- Log comparison parameters to console
    DBMS_OUTPUT.PUT_LINE('Comparing tables: ' || v_source_table_full || ' and ' || v_target_table_full);
    DBMS_OUTPUT.PUT_LINE('Key field: ' || v_key_field);
    DBMS_OUTPUT.PUT_LINE('Comparing ' || v_compare_columns.COUNT || ' column(s)');
    
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
        FROM ' || v_source_table_full || ' s
    ),
    target_data AS (
        SELECT t.' || v_key_field || ' AS key_value';
    
    -- Add target columns
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ', 
            t.' || v_compare_columns(i) || ' AS ' || v_compare_columns(i) || '_target';
    END LOOP;
    
    v_sql := v_sql || '
        FROM ' || v_target_table_full || ' t
    )
    SELECT 
        CASE
            WHEN t.key_value IS NULL THEN ''ONLY_IN_SOURCE''
            WHEN s.key_value IS NULL THEN ''ONLY_IN_TARGET''
            ELSE ''DIFFERENT''
        END AS status,
        COALESCE(s.key_value, t.key_value) AS key_value';
    
    -- Add source and target columns to select
    FOR i IN 1..v_compare_columns.COUNT LOOP
        v_sql := v_sql || ',
        s.' || v_compare_columns(i) || '_source,
        t.' || v_compare_columns(i) || '_target';
    END LOOP;
    
    -- Build the difference detection logic
    v_sql := v_sql || '
    FROM source_data s
    FULL OUTER JOIN target_data t ON s.key_value = t.key_value
    WHERE t.key_value IS NULL  -- Records only in source
       OR s.key_value IS NULL  -- Records only in target
       OR (';
    
    -- Add comparison for each column
    FOR i IN 1..v_compare_columns.COUNT LOOP
        IF i > 1 THEN
            v_sql := v_sql || ' OR ';
        END IF;
        
        v_sql := v_sql || '
           DECODE(s.' || v_compare_columns(i) || '_source, t.' || v_compare_columns(i) || '_target, 0, 1) = 1
           OR (s.' || v_compare_columns(i) || '_source IS NULL AND t.' || v_compare_columns(i) || '_target IS NOT NULL)
           OR (s.' || v_compare_columns(i) || '_source IS NOT NULL AND t.' || v_compare_columns(i) || '_target IS NULL)';
    END LOOP;
    
    v_sql := v_sql || ')
    ORDER BY status, key_value';
    
    -- For debugging - uncomment to see generated SQL
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
END compare_tables_update_fn;
/
