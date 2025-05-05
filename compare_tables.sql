CREATE OR REPLACE PROCEDURE compare_tables(
    p_snapshot_table IN VARCHAR2,
    p_target_table IN VARCHAR2
)
AS
    -- Variables
    v_sql VARCHAR2(32767);
    v_count_snapshot NUMBER;
    v_count_target NUMBER;
    v_diff_count NUMBER;
    v_match_pct NUMBER;
    v_error_msg VARCHAR2(4000);
    v_column_list VARCHAR2(32767);
    v_comparison_clause VARCHAR2(32767);
BEGIN
    -- Create COMPARISON_RESULTS table if it doesn't exist
    BEGIN
        EXECUTE IMMEDIATE 'SELECT 1 FROM COMPARISON_RESULTS WHERE ROWNUM = 1';
    EXCEPTION
        WHEN OTHERS THEN
            EXECUTE IMMEDIATE '
                CREATE TABLE COMPARISON_RESULTS (
                    SNAPSHOT_TABLE VARCHAR2(128),
                    TARGET_TABLE VARCHAR2(128),
                    SNAPSHOT_COUNT NUMBER,
                    TARGET_COUNT NUMBER,
                    DIFFERENCE_COUNT NUMBER,
                    COMPARISON_DATE DATE,
                    ADDITIONAL_INFO VARCHAR2(4000)
                )
            ';
    END;

    -- Get common columns between tables
    v_sql := '
        SELECT LISTAGG(column_name, '','') WITHIN GROUP (ORDER BY column_name)
        FROM (
            SELECT column_name
            FROM user_tab_columns
            WHERE table_name = ''' || p_snapshot_table || '''
            INTERSECT
            SELECT column_name
            FROM user_tab_columns
            WHERE table_name = ''' || p_target_table || '''
        )';
    
    BEGIN
        EXECUTE IMMEDIATE v_sql INTO v_column_list;
        
        -- Check if any common columns found
        IF v_column_list IS NULL OR v_column_list = '' THEN
            RAISE_APPLICATION_ERROR(-20002, 'No common columns found between ' || p_snapshot_table || ' and ' || p_target_table);
        END IF;
        
        -- Count records in each table
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_snapshot_table INTO v_count_snapshot;
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_target_table INTO v_count_target;
        
        -- Count differences
        v_sql := '
            SELECT COUNT(*) FROM (
                SELECT ' || v_column_list || ' FROM ' || p_snapshot_table || '
                MINUS
                SELECT ' || v_column_list || ' FROM ' || p_target_table || '
            UNION ALL
                SELECT ' || v_column_list || ' FROM ' || p_target_table || '
                MINUS
                SELECT ' || v_column_list || ' FROM ' || p_snapshot_table || '
            )';
        
        EXECUTE IMMEDIATE v_sql INTO v_diff_count;
        
        -- Calculate match percentage
        IF GREATEST(v_count_snapshot, v_count_target) = 0 THEN
            v_match_pct := 100;
        ELSE
            v_match_pct := ROUND(100 - (v_diff_count / GREATEST(v_count_snapshot, v_count_target) * 100), 2);
        END IF;
        
        -- Insert results into comparison table
        INSERT INTO COMPARISON_RESULTS (
            SNAPSHOT_TABLE,
            TARGET_TABLE,
            SNAPSHOT_COUNT,
            TARGET_COUNT,
            DIFFERENCE_COUNT,
            COMPARISON_DATE,
            ADDITIONAL_INFO
        ) VALUES (
            p_snapshot_table,
            p_target_table,
            v_count_snapshot,
            v_count_target,
            v_diff_count,
            SYSDATE,
            'Match percentage: ' || TO_CHAR(v_match_pct) || '%'
        );
        
        -- Create comparison clause for the difference table
        v_comparison_clause := '';
        DECLARE
            v_column_array DBMS_SQL.VARCHAR2_TABLE;
            v_start_pos INTEGER := 1;
            v_end_pos INTEGER;
            v_col_name VARCHAR2(128);
            i INTEGER := 1;
        BEGIN
            v_column_array := DBMS_SQL.VARCHAR2_TABLE();
            
            -- Parse column list
            WHILE v_start_pos <= LENGTH(v_column_list) LOOP
                v_end_pos := INSTR(v_column_list, ',', v_start_pos);
                IF v_end_pos = 0 THEN
                    v_col_name := TRIM(SUBSTR(v_column_list, v_start_pos));
                    v_start_pos := LENGTH(v_column_list) + 1;
                ELSE
                    v_col_name := TRIM(SUBSTR(v_column_list, v_start_pos, v_end_pos - v_start_pos));
                    v_start_pos := v_end_pos + 1;
                END IF;
                
                v_column_array.EXTEND;
                v_column_array(i) := v_col_name;
                i := i + 1;
            END LOOP;
            
            -- Build comparison clause
            FOR j IN 1..v_column_array.COUNT LOOP
                IF j > 1 THEN
                    v_comparison_clause := v_comparison_clause || ' AND ';
                END IF;
                v_comparison_clause := v_comparison_clause || 's.' || v_column_array(j) || ' = t.' || v_column_array(j);
            END LOOP;
        END;
        
        -- Create detailed difference table
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE DIFF_' || p_snapshot_table || '_' || p_target_table || ' PURGE';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        IF v_comparison_clause IS NOT NULL AND v_comparison_clause != '' THEN
            v_sql := '
                CREATE TABLE DIFF_' || p_snapshot_table || '_' || p_target_table || ' AS
                SELECT ''Only in ' || p_snapshot_table || ''' AS SOURCE, t.* 
                FROM ' || p_snapshot_table || ' t
                WHERE NOT EXISTS (
                    SELECT 1 FROM ' || p_target_table || ' s
                    WHERE ' || v_comparison_clause || '
                )
                UNION ALL
                SELECT ''Only in ' || p_target_table || ''' AS SOURCE, t.*
                FROM ' || p_target_table || ' t
                WHERE NOT EXISTS (
                    SELECT 1 FROM ' || p_snapshot_table || ' s
                    WHERE ' || v_comparison_clause || '
                )';
            
            EXECUTE IMMEDIATE v_sql;
            DBMS_OUTPUT.PUT_LINE('Comparison complete. Results stored in COMPARISON_RESULTS table.');
            DBMS_OUTPUT.PUT_LINE('Detailed differences stored in DIFF_' || p_snapshot_table || '_' || p_target_table);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Could not create difference table - no comparison clause generated.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            
            BEGIN
                INSERT INTO COMPARISON_RESULTS (
                    SNAPSHOT_TABLE,
                    TARGET_TABLE,
                    SNAPSHOT_COUNT,
                    TARGET_COUNT,
                    DIFFERENCE_COUNT,
                    COMPARISON_DATE,
                    ADDITIONAL_INFO
                ) VALUES (
                    p_snapshot_table,
                    p_target_table,
                    -1,
                    -1,
                    -1,
                    SYSDATE,
                    'Error: ' || SUBSTR(v_error_msg, 1, 3990)
                );
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Could not log error to COMPARISON_RESULTS: ' || SQLERRM);
            END;
            
            DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_msg);
            RAISE;
    END;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Procedure error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END compare_tables;
/
