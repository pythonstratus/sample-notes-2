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
    v_join_condition VARCHAR2(32767);
    v_diff_conditions VARCHAR2(32767);
    v_count NUMBER := 0;
    
BEGIN
    DBMS_LOB.CREATETEMPORARY(v_result, TRUE);
    
    -- Build column list (excluding the key column from comparison)
    SELECT LISTAGG('t1.' || column_name || ' AS t1_' || column_name || 
                   ', t2.' || column_name || ' AS t2_' || column_name, ', ')
           WITHIN GROUP (ORDER BY column_position)
    INTO v_columns
    FROM all_tab_columns
    WHERE table_name = UPPER(p_table1)
    AND owner = UPPER(p_schema);
    
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
    DBMS_LOB.APPEND(v_result, '=== RECORDS WITH DIFFERENCES ===' || CHR(10));
    
    v_sql := 'SELECT COUNT(*) FROM ' || p_schema || '.' || p_table1 || ' t1 ' ||
             'INNER JOIN ' || p_schema || '.' || p_table2 || ' t2 ' ||
             'ON t1.' || p_key_column || ' = t2.' || p_key_column ||
             ' WHERE ' || v_diff_conditions;
    
    EXECUTE IMMEDIATE v_sql INTO v_count;
    DBMS_LOB.APPEND(v_result, 'Count: ' || v_count || CHR(10) || CHR(10));
    
    -- Records only in table1
    DBMS_LOB.APPEND(v_result, '=== RECORDS ONLY IN ' || p_table1 || ' ===' || CHR(10));
    
    v_sql := 'SELECT COUNT(*) FROM ' || p_schema || '.' || p_table1 || ' t1 ' ||
             'WHERE NOT EXISTS (SELECT 1 FROM ' || p_schema || '.' || p_table2 || ' t2 ' ||
             'WHERE t1.' || p_key_column || ' = t2.' || p_key_column || ')';
    
    EXECUTE IMMEDIATE v_sql INTO v_count;
    DBMS_LOB.APPEND(v_result, 'Count: ' || v_count || CHR(10) || CHR(10));
    
    -- Records only in table2
    DBMS_LOB.APPEND(v_result, '=== RECORDS ONLY IN ' || p_table2 || ' ===' || CHR(10));
    
    v_sql := 'SELECT COUNT(*) FROM ' || p_schema || '.' || p_table2 || ' t2 ' ||
             'WHERE NOT EXISTS (SELECT 1 FROM ' || p_schema || '.' || p_table1 || ' t1 ' ||
             'WHERE t1.' || p_key_column || ' = t2.' || p_key_column || ')';
    
    EXECUTE IMMEDIATE v_sql INTO v_count;
    DBMS_LOB.APPEND(v_result, 'Count: ' || v_count || CHR(10));
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_LOB.APPEND(v_result, 'Error: ' || SQLERRM);
        RETURN v_result;
END compare_tables;
/



-- Compare two tables using EMPLOYEE_ID as the key
SELECT compare_tables('EMPLOYEES_OLD', 'EMPLOYEES_NEW', 'EMPLOYEE_ID') 
FROM DUAL;

-- Compare tables in a specific schema
SELECT compare_tables('ORDERS', 'ORDERS_BACKUP', 'ORDER_ID', 'SALES_SCHEMA') 
FROM DUAL;
