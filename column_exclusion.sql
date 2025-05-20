CREATE OR REPLACE FUNCTION compare_tables_exclude_columns(
    p_source_table IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_exclude_columns IN VARCHAR2 DEFAULT NULL,
    p_compare_field IN VARCHAR2 DEFAULT NULL,
    p_key_field IN VARCHAR2 DEFAULT NULL
) RETURN SYS_REFCURSOR
AS
    TYPE t_column_list IS TABLE OF VARCHAR2(128);
    v_compare_columns t_column_list := t_column_list();
    v_exclude_columns t_column_list := t_column_list();
    v_source_exists NUMBER;
    v_target_exists NUMBER;
    v_key_field VARCHAR2(128);
    v_sql VARCHAR2(32767);
    v_dynamic_cursor SYS_REFCURSOR;
    v_count NUMBER;
    v_exclude_column VARCHAR2(128);
    v_start_pos NUMBER;
    v_end_pos NUMBER;
    v_temp_str VARCHAR2(4000);
    
BEGIN
    -- Validate required input parameters
    IF p_source_table IS NULL OR p_target_table IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Source table and target table must be specified');
    END IF;
    
    -- Process the exclude columns list into a collection
    IF p_exclude_columns IS NOT NULL THEN
        v_temp_str := p_exclude_columns || ',';
        v_start_pos := 1;
        
        LOOP
            v_end_pos := INSTR(v_temp_str, ',', v_start_pos);
            EXIT WHEN v_end_pos = 0;
            
            v_exclude_column := TRIM(UPPER(SUBSTR(v_temp_str, v_start_pos, v_end_pos - v_start_pos)));
            
            IF v_exclude_column IS NOT NULL THEN
                v_exclude_columns.EXTEND;
                v_exclude_columns(v_exclude_columns.COUNT) := v_exclude_column;
            END IF;
            
            v_start_pos := v_end_pos + 1;
        END LOOP;
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
    
    -- Determine which columns to compare
    IF p_compare_field IS NULL THEN
        -- Compare all common columns except the key field and excluded columns
        FOR col_rec IN (
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
            AND column_name <> v_key_field
            ORDER BY column_id
        ) LOOP
            -- Skip excluded columns
            IF v_exclude_columns.COUNT > 0 THEN
                v_count := 0;
                FOR i IN 1..v_exclude_columns.COUNT LOOP
                    IF col_rec.column_name = v_exclude_columns(i) THEN
                        v_count := 1;
                        EXIT;
                    END IF;
                END LOOP;
                
                IF v_count = 0 THEN
                    v_compare_columns.EXTEND;
                    v_compare_columns(v_compare_columns.COUNT) := col_rec.column_name;
                END IF;
            ELSE
                v_compare_columns.EXTEND;
                v_compare_columns(v_compare_columns.COUNT) := col_rec.column_name;
            END IF;
        END LOOP;
        
        IF v_compare_columns.COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'No common columns found between tables to compare (after excluding specified columns)');
        END IF;
    ELSE
        -- Check if the specified comparison field exists in both tables and isn't excluded
        IF v_exclude_columns.COUNT > 0 THEN
            FOR i IN 1..v_exclude_columns.COUNT LOOP
                IF UPPER(p_compare_field) = v_exclude_columns(i) THEN
                    RAISE_APPLICATION_ERROR(-20009, 'Compare field ' || p_compare_field || ' is in the excluded columns list');
                END IF;
            END LOOP;
        END IF;
        
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
        v_compare_columns(1) := UPPER(p_compare_field);
    END IF;
    
    -- Log comparison parameters to console
    DBMS_OUTPUT.PUT_LINE('Comparing tables: ' || p_source_table || ' and ' || p_target_table);
    DBMS_OUTPUT.PUT_LINE('Key field: ' || v_key_field);
    DBMS_OUTPUT.PUT_LINE('Comparing ' || v_compare_columns.COUNT || ' column(s)');
    
    IF v_exclude_columns.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Excluded columns: ');
        FOR i IN 1..v_exclude_columns.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_exclude_columns(i));
        END LOOP;
    END IF;
    
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
    
    -- Open cursor with the dynamic SQL
    OPEN v_dynamic_cursor FOR v_sql;
    
    -- Return the cursor
    RETURN v_dynamic_cursor;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END compare_tables_exclude_columns;
/
