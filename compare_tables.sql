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
        
        -- Create detailed difference table
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE DIFF_' || p_snapshot_table || '_' || p_target_table || ' PURGE';
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        -- Create a simplified difference table using EXISTS subquery with column list
        v_sql := '
            CREATE TABLE DIFF_' || p_snapshot_table || '_' || p_target_table || ' AS
            SELECT ''Only in ' || p_snapshot_table || ''' AS SOURCE, a.* 
            FROM ' || p_snapshot_table || ' a
            WHERE NOT EXISTS (
                SELECT 1 FROM ' || p_target_table || ' b
                WHERE 1=1';
                
        -- Add column comparisons
        DECLARE
            v_pos NUMBER := 1;
            v_next_pos NUMBER;
            v_col VARCHAR2(128);
        BEGIN
            LOOP
                v_next_pos := INSTR(v_column_list, ',', v_pos);
                
                IF v_next_pos = 0 THEN
                    v_col := SUBSTR(v_column_list, v_pos);
                    v_sql := v_sql || ' AND a.' || v_col || ' = b.' || v_col;
                    EXIT;
                ELSE
                    v_col := SUBSTR(v_column_list, v_pos, v_next_pos - v_pos);
                    v_sql := v_sql || ' AND a.' || v_col || ' = b.' || v_col;
                    v_pos := v_next_pos + 1;
                END IF;
            END LOOP;
            
            -- Complete the first half of the query
            v_sql := v_sql || '
            )
            UNION ALL
            SELECT ''Only in ' || p_target_table || ''' AS SOURCE, a.* 
            FROM ' || p_target_table || ' a
            WHERE NOT EXISTS (
                SELECT 1 FROM ' || p_snapshot_table || ' b
                WHERE 1=1';
                
            -- Reset position
            v_pos := 1;
            
            -- Add column comparisons for second half
            LOOP
                v_next_pos := INSTR(v_column_list, ',', v_pos);
                
                IF v_next_pos = 0 THEN
                    v_col := SUBSTR(v_column_list, v_pos);
                    v_sql := v_sql || ' AND a.' || v_col || ' = b.' || v_col;
                    EXIT;
                ELSE
                    v_col := SUBSTR(v_column_list, v_pos, v_next_pos - v_pos);
                    v_sql := v_sql || ' AND a.' || v_col || ' = b.' || v_col;
                    v_pos := v_next_pos + 1;
                END IF;
            END LOOP;
            
            -- Complete the query
            v_sql := v_sql || '
            )';
            
            -- Execute the SQL
            EXECUTE IMMEDIATE v_sql;
            
            DBMS_OUTPUT.PUT_LINE('Comparison complete. Results stored in COMPARISON_RESULTS table.');
            DBMS_OUTPUT.PUT_LINE('Detailed differences stored in DIFF_' || p_snapshot_table || '_' || p_target_table);
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            
            -- Log error to comparison results
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
