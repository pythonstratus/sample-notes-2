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
    v_column_list VARCHAR2(32767);
    v_error_msg VARCHAR2(4000);
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

    -- Verify tables exist
    BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_snapshot_table INTO v_count_snapshot;
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_target_table INTO v_count_target;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'One or both tables do not exist: ' || SQLERRM);
    END;
    
    -- Manually build the column list - avoiding complex SQL that uses temp space
    BEGIN
        -- Get column list directly, trading complexity for less temp space usage
        v_column_list := '';
        
        FOR rec IN (
            SELECT c1.column_name 
            FROM user_tab_columns c1
            WHERE UPPER(c1.table_name) = UPPER(p_snapshot_table)
            AND EXISTS (
                SELECT 1 FROM user_tab_columns c2
                WHERE UPPER(c2.table_name) = UPPER(p_target_table)
                AND UPPER(c2.column_name) = UPPER(c1.column_name)
            )
            ORDER BY c1.column_name
        ) LOOP
            IF v_column_list IS NOT NULL AND v_column_list != '' THEN
                v_column_list := v_column_list || ',';
            END IF;
            v_column_list := v_column_list || rec.column_name;
        END LOOP;
        
        -- If no columns found, raise error
        IF v_column_list IS NULL OR v_column_list = '' THEN
            RAISE_APPLICATION_ERROR(-20002, 'No common columns found between tables');
        END IF;
        
        -- Count differences using more efficient SQL
        v_sql := '
            SELECT NVL(SUM(1), 0) FROM (
                SELECT ROWNUM AS rn FROM ' || p_snapshot_table || ' s
                WHERE NOT EXISTS (
                    SELECT 1 FROM ' || p_target_table || ' t
                    WHERE ';
                    
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
                    v_sql := v_sql || 's.' || v_col || ' = t.' || v_col;
                    EXIT;
                ELSE
                    v_col := SUBSTR(v_column_list, v_pos, v_next_pos - v_pos);
                    v_sql := v_sql || 's.' || v_col || ' = t.' || v_col || ' AND ';
                    v_pos := v_next_pos + 1;
                END IF;
            END LOOP;
            
            v_sql := v_sql || '
                )
                UNION ALL
                SELECT ROWNUM AS rn FROM ' || p_target_table || ' t
                WHERE NOT EXISTS (
                    SELECT 1 FROM ' || p_snapshot_table || ' s
                    WHERE ';
                    
            -- Reset position
            v_pos := 1;
            
            -- Add column comparisons for second half
            LOOP
                v_next_pos := INSTR(v_column_list, ',', v_pos);
                
                IF v_next_pos = 0 THEN
                    v_col := SUBSTR(v_column_list, v_pos);
                    v_sql := v_sql || 't.' || v_col || ' = s.' || v_col;
                    EXIT;
                ELSE
                    v_col := SUBSTR(v_column_list, v_pos, v_next_pos - v_pos);
                    v_sql := v_sql || 't.' || v_col || ' = s.' || v_col || ' AND ';
                    v_pos := v_next_pos + 1;
                END IF;
            END LOOP;
            
            v_sql := v_sql || '
                )
            )';
            
            -- Execute the SQL to count differences
            EXECUTE IMMEDIATE v_sql INTO v_diff_count;
        END;
        
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
            'Match percentage: ' || 
            CASE 
                WHEN GREATEST(v_count_snapshot, v_count_target) = 0 THEN '100'
                ELSE TO_CHAR(ROUND(100 - (v_diff_count / GREATEST(v_count_snapshot, v_count_target) * 100), 2))
            END || '%'
        );
        
        -- Create difference table only if explicitly requested later (skipping this to save space)
        DBMS_OUTPUT.PUT_LINE('Comparison complete. Results stored in COMPARISON_RESULTS table.');
        DBMS_OUTPUT.PUT_LINE('Columns compared: ' || v_column_list);
        DBMS_OUTPUT.PUT_LINE('Total differences found: ' || v_diff_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_msg);
            
            -- Try to log the error
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
                    v_count_snapshot,
                    v_count_target,
                    -1,
                    SYSDATE,
                    'Error: ' || SUBSTR(v_error_msg, 1, 3990)
                );
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Could not log error to COMPARISON_RESULTS: ' || SQLERRM);
            END;
            
            RAISE;
    END;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Procedure error: ' || SQLERRM);
        RAISE;
END compare_tables;
/
