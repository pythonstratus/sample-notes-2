DECLARE
    v_snapshot_table VARCHAR2(128) := 'entact_daily_post_snapshot_04172025';
    v_target_table VARCHAR2(128) := 'entact';
    v_count_snapshot NUMBER;
    v_count_target NUMBER;
    v_diff_count NUMBER := 0;
    v_match_pct NUMBER;
    v_sql VARCHAR2(4000);
    v_common_cols NUMBER;
BEGIN
    -- Verify tables exist and get row counts
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_snapshot_table INTO v_count_snapshot;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_target_table INTO v_count_target;
    
    -- Check if tables have common columns
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (
        SELECT column_name FROM user_tab_columns WHERE UPPER(table_name) = ''' || UPPER(v_snapshot_table) || '''
        INTERSECT
        SELECT column_name FROM user_tab_columns WHERE UPPER(table_name) = ''' || UPPER(v_target_table) || '''
    )' INTO v_common_cols;
    
    IF v_common_cols = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No common columns found between ' || v_snapshot_table || ' and ' || v_target_table);
        RETURN;
    END IF;
    
    -- Count differences (simplistic approach to avoid complex SQL)
    v_diff_count := ABS(v_count_snapshot - v_count_target);
    
    -- Calculate match percentage (simple estimate based on row counts)
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
    DBMS_OUTPUT.PUT_LINE('Target Row Count: ' || v_target_table);
    DBMS_OUTPUT.PUT_LINE('Estimated Difference Count: ' || v_diff_count);
    DBMS_OUTPUT.PUT_LINE('Estimated Match Percentage: ' || v_match_pct || '%');
    DBMS_OUTPUT.PUT_LINE('Common Column Count: ' || v_common_cols);
    DBMS_OUTPUT.PUT_LINE('================================================');
    
    -- Display common columns (limited to first 10 for brevity)
    DBMS_OUTPUT.PUT_LINE('First 10 common columns:');
    FOR rec IN (
        SELECT column_name FROM (
            SELECT column_name FROM user_tab_columns WHERE UPPER(table_name) = UPPER(v_snapshot_table)
            INTERSECT
            SELECT column_name FROM user_tab_columns WHERE UPPER(table_name) = UPPER(v_target_table)
        ) WHERE ROWNUM <= 10
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('- ' || rec.column_name);
    END LOOP;
    
    -- Provide a suggestion for viewing detailed differences
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('To see detailed differences, run these queries:');
    DBMS_OUTPUT.PUT_LINE(''); 
    DBMS_OUTPUT.PUT_LINE('-- Records in ' || v_snapshot_table || ' not in ' || v_target_table || ':');
    DBMS_OUTPUT.PUT_LINE('SELECT * FROM ' || v_snapshot_table || ' MINUS SELECT * FROM ' || v_target_table || ';');
    DBMS_OUTPUT.PUT_LINE(''); 
    DBMS_OUTPUT.PUT_LINE('-- Records in ' || v_target_table || ' not in ' || v_snapshot_table || ':');
    DBMS_OUTPUT.PUT_LINE('SELECT * FROM ' || v_target_table || ' MINUS SELECT * FROM ' || v_snapshot_table || ';');
END;
/
