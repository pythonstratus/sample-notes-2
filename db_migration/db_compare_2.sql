CREATE OR REPLACE FUNCTION compare_tables(
    p_table1 IN VARCHAR2,
    p_table2 IN VARCHAR2,
    p_key_column IN VARCHAR2,
    p_schema IN VARCHAR2 DEFAULT USER
) RETURN CLOB
IS
    v_result CLOB;
    v_sql VARCHAR2(32767);
    v_columns VARCHAR2(32767);
    v_diff_conditions VARCHAR2(32767);
    v_count NUMBER := 0;
    
BEGIN
    -- Initialize the CLOB
    v_result := '';
    
    -- Build difference condition for WHERE clause
    SELECT LISTAGG('NVL(TO_CHAR(t1.' || column_name || '), ''NULL'') != ' ||
                   'NVL(TO_CHAR(t2.' || column_name || '), ''NULL'')', ' OR ')
           WITHIN GROUP (ORDER BY column_position)
    INTO v_diff_conditions
    FROM all_tab_columns
    WHERE table_name = UPPER(p_table1)
    AND owner = UPPER(p_schema)
    AND column_name != UPPER(p_key_column);
    
    -- Compare records that exist in both tables but have differences
    v_result := v_result || '=== RECORDS WITH DIFFERENCES ===' || CHR(10);
    
    v_sql := 'SELECT COUNT(*) FROM ' || p_schema || '.' || p_table1 || ' t1 ' ||
             'INNER JOIN ' || p_schema || '.' || p_table2 || ' t2 ' ||
             'ON t1.' || p_key_column || ' = t2.' || p_key_column ||
             ' WHERE ' || v_diff_conditions;
    
    EXECUTE IMMEDIATE v_sql INTO v_count;
    v_result := v_result || 'Count: ' || v_count || CHR(10) || CHR(10);
    
    -- Records only in table1
    v_result := v_result || '=== RECORDS ONLY IN ' || p_table1 || ' ===' || CHR(10);
    
    v_sql := 'SELECT COUNT(*) FROM ' || p_schema || '.' || p_table1 || ' t1 ' ||
             'WHERE NOT EXISTS (SELECT 1 FROM ' || p_schema || '.' || p_table2 || ' t2 ' ||
             'WHERE t1.' || p_key_column || ' = t2.' || p_key_column || ')';
    
    EXECUTE IMMEDIATE v_sql INTO v_count;
    v_result := v_result || 'Count: ' || v_count || CHR(10) || CHR(10);
    
    -- Records only in table2
    v_result := v_result || '=== RECORDS ONLY IN ' || p_table2 || ' ===' || CHR(10);
    
    v_sql := 'SELECT COUNT(*) FROM ' || p_schema || '.' || p_table2 || ' t2 ' ||
             'WHERE NOT EXISTS (SELECT 1 FROM ' || p_schema || '.' || p_table1 || ' t1 ' ||
             'WHERE t1.' || p_key_column || ' = t2.' || p_key_column || ')';
    
    EXECUTE IMMEDIATE v_sql INTO v_count;
    v_result := v_result || 'Count: ' || v_count || CHR(10);
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error: ' || SQLERRM;
END compare_tables;
/
