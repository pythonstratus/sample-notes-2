DECLARE
    v_snapshot_table VARCHAR2(128) := 'entact_daily_post_snapshot_04172025';
    v_target_table VARCHAR2(128) := 'entact';
    v_count_snapshot NUMBER;
    v_count_target NUMBER;
    v_column_list VARCHAR2(4000);
    v_diff_count NUMBER := 0;
    v_match_pct NUMBER;
BEGIN
    -- Verify tables exist and get row counts
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_snapshot_table INTO v_count_snapshot;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_target_table INTO v_count_target;
    
    -- Get common columns
    FOR rec IN (
        SELECT c1.column_name 
        FROM user_tab_columns c1
        WHERE UPPER(c1.table_name) = UPPER(v_snapshot_table)
        AND EXISTS (
            SELECT 1 FROM user_tab_columns c2
            WHERE UPPER(c2.table_name) = UPPER(v_target_table)
            AND UPPER(c2.column_name) = UPPER(c1.column_name)
        )
        ORDER BY c1.column_name
    ) LOOP
        IF LENGTH(v_column_list) > 0 THEN
            v_column_list := v_column_list || ', ';
        END IF;
        v_column_list := v_column_list || rec.column_name;
    END LOOP;
    
    -- If no common columns found
    IF v_column_list IS NULL OR LENGTH(v_column_list) = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No common columns found between tables.');
        RETURN;
    END IF;
    
    -- Count differences directly using a cursor
    DECLARE
        TYPE diff_cursor IS REF CURSOR;
        diff_cur diff_cursor;
        v_sql VARCHAR2(4000);
        v_dummy VARCHAR2(1);
    BEGIN
        -- First part - records in snapshot not in target
        v_sql := 'SELECT ''X'' FROM ' || v_snapshot_table || ' s WHERE NOT EXISTS (SELECT 1 FROM ' || 
                 v_target_table || ' t WHERE ';
                 
        -- Add join conditions dynamically
        FOR rec IN (
            SELECT column_name 
            FROM user_tab_columns 
            WHERE UPPER(table_name) = UPPER(v_snapshot_table)
            AND EXISTS (
                SELECT 1 FROM user_tab_columns 
                WHERE UPPER(table_name) = UPPER(v_target_table)
                AND UPPER(column_name) = UPPER(column_name)
            )
        ) LOOP
            v_sql := v_sql || 's.' || rec.column_name || ' = t.' || rec.column_name || ' AND ';
        END LOOP;
        
        -- Remove the last ' AND '
        v_sql := SUBSTR(v_sql, 1, LENGTH(v_sql) - 5) || ')';
        
        -- Execute and count
        OPEN diff_cur FOR v_sql;
        LOOP
            FETCH diff_cur INTO v_dummy;
            EXIT WHEN diff_cur%NOTFOUND;
            v_diff_count := v_diff_count + 1;
        END LOOP;
        CLOSE diff_cur;
        
        -- Second part - records in target not in snapshot
        v_sql := 'SELECT ''X'' FROM ' || v_target_table || ' t WHERE NOT EXISTS (SELECT 1 FROM ' || 
                 v_snapshot_table || ' s WHERE ';
                 
        -- Add join conditions dynamically
        FOR rec IN (
            SELECT column_name 
            FROM user_tab_columns 
            WHERE UPPER(table_name) = UPPER(v_target_table)
            AND EXISTS (
                SELECT 1 FROM user_tab_columns 
                WHERE UPPER(table_name) = UPPER(v_snapshot_table)
                AND UPPER(column_name) = UPPER(column_name)
            )
        ) LOOP
            v_sql := v_sql || 't.' || rec.column_name || ' = s.' || rec.column_name || ' AND ';
        END LOOP;
        
        -- Remove the last ' AND '
        v_sql := SUBSTR(v_sql, 1, LENGTH(v_sql) - 5) || ')';
        
        -- Execute and count
        OPEN diff_cur FOR v_sql;
        LOOP
            FETCH diff_cur INTO v_dummy;
            EXIT WHEN diff_cur%NOTFOUND;
            v_diff_count := v_diff_count + 1;
        END LOOP;
        CLOSE diff_cur;
    END;
    
    -- Calculate match percentage
    IF GREATEST(v_count_snapshot, v_count_target) = 0 THEN
        v_match_pct := 100;
    ELSE
        v_match_pct := ROUND(100 - (v_diff_count / GREATEST(v_count_snapshot, v_count_target) * 100), 2);
    END IF;
    
    -- Display results in TOAD output
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('TABLE COMPARISON RESULTS');
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('Snapshot Table: ' || v_snapshot_table);
    DBMS_OUTPUT.PUT_LINE('Target Table: ' || v_target_table);
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('Snapshot Row Count: ' || v_count_snapshot);
    DBMS_OUTPUT.PUT_LINE('Target Row Count: ' || v_count_target);
    DBMS_OUTPUT.PUT_LINE('Difference Count: ' || v_diff_count);
    DBMS_OUTPUT.PUT_LINE('Match Percentage: ' || v_match_pct || '%');
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('Common Columns Compared: ' || v_column_list);
    DBMS_OUTPUT.PUT_LINE('================================================');
    
    -- If you want to display the first few difference records
    DBMS_OUTPUT.PUT_LINE('Sample differences (first 10 records):');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
    
    -- Show differences
    DECLARE
        v_sql VARCHAR2(4000);
        TYPE diff_rec IS RECORD (
            source VARCHAR2(100),
            row_data CLOB
        );
        TYPE diff_tab IS TABLE OF diff_rec;
        v_diffs diff_tab;
        
        CURSOR c_diff IS
            WITH a AS (
                SELECT 'Only in ' || v_snapshot_table AS source,
                       TO_CHAR(ROWNUM) || ': ' || 
                       SUBSTR(
                         (SELECT LISTAGG(column_name || '=' || TO_CHAR(s.column_value), ', ') 
                          FROM TABLE(SELECT CAST(COLLECT(column_name) AS sys.odcivarchar2list) 
                                     FROM user_tab_columns 
                                     WHERE table_name = UPPER(v_snapshot_table)) cols,
                          TABLE(SELECT * FROM XMLTABLE('/ROWSET/ROW' PASSING XMLTYPE(
                            SELECT DBMS_XMLGEN.GETXML('SELECT * FROM ' || v_snapshot_table || ' WHERE ROWNUM <= 10')
                            FROM DUAL)) s
                       ), 1, 200) AS row_data
                FROM DUAL
                WHERE ROWNUM <= 10
                UNION ALL
                SELECT 'Only in ' || v_target_table AS source,
                       TO_CHAR(ROWNUM) || ': ' || 
                       SUBSTR(
                         (SELECT LISTAGG(column_name || '=' || TO_CHAR(s.column_value), ', ') 
                          FROM TABLE(SELECT CAST(COLLECT(column_name) AS sys.odcivarchar2list) 
                                     FROM user_tab_columns 
                                     WHERE table_name = UPPER(v_target_table)) cols,
                          TABLE(SELECT * FROM XMLTABLE('/ROWSET/ROW' PASSING XMLTYPE(
                            SELECT DBMS_XMLGEN.GETXML('SELECT * FROM ' || v_target_table || ' WHERE ROWNUM <= 10')
                            FROM DUAL)) s
                       ), 1, 200) AS row_data
                FROM DUAL
                WHERE ROWNUM <= 10
            ) 
            SELECT source, row_data FROM a;
    BEGIN
        -- This approach is simplified to avoid complex dynamic SQL
        DBMS_OUTPUT.PUT_LINE('To see detailed differences, run this query:');
        DBMS_OUTPUT.PUT_LINE('SELECT * FROM ' || v_snapshot_table);
        DBMS_OUTPUT.PUT_LINE('MINUS');
        DBMS_OUTPUT.PUT_LINE('SELECT * FROM ' || v_target_table);
        DBMS_OUTPUT.PUT_LINE('UNION ALL');
        DBMS_OUTPUT.PUT_LINE('SELECT * FROM ' || v_target_table);
        DBMS_OUTPUT.PUT_LINE('MINUS');
        DBMS_OUTPUT.PUT_LINE('SELECT * FROM ' || v_snapshot_table);
    END;
END;
/
