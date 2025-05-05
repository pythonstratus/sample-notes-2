CREATE OR REPLACE PROCEDURE compare_tables(
    p_snapshot_table IN VARCHAR2,
    p_target_table IN VARCHAR2
)
AS
    -- Variables to hold dynamic SQL
    v_sql VARCHAR2(32767);
    v_count_snapshot NUMBER;
    v_count_target NUMBER;
    v_diff_count NUMBER;
    v_error_msg VARCHAR2(4000);
    
    -- Create temporary comparison results table if it doesn't exist
    BEGIN
        BEGIN
            EXECUTE IMMEDIATE 'SELECT 1 FROM COMPARISON_RESULTS WHERE 1=2';
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
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
                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('Error creating COMPARISON_RESULTS table: ' || SQLERRM);
                END;
        END;

        -- Validate that both tables exist
        BEGIN
            EXECUTE IMMEDIATE 'SELECT 1 FROM ' || p_snapshot_table || ' WHERE ROWNUM = 1';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20001, 'Source table does not exist: ' || p_snapshot_table);
        END;
        
        BEGIN
            EXECUTE IMMEDIATE 'SELECT 1 FROM ' || p_target_table || ' WHERE ROWNUM = 1';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20001, 'Target table does not exist: ' || p_target_table);
        END;
        
        -- Get column list (using only columns that exist in both tables)
        BEGIN
            v_sql := '
                WITH snapshot_cols AS (
                    SELECT column_name
                    FROM user_tab_columns
                    WHERE table_name = ''' || p_snapshot_table || '''
                ),
                target_cols AS (
                    SELECT column_name
                    FROM user_tab_columns
                    WHERE table_name = ''' || p_target_table || '''
                ),
                common_cols AS (
                    SELECT column_name
                    FROM snapshot_cols
                    INTERSECT
                    SELECT column_name
                    FROM target_cols
                )
                SELECT LISTAGG(column_name, '','') WITHIN GROUP (ORDER BY column_name) AS column_list
                FROM common_cols';
                
            DBMS_OUTPUT.PUT_LINE('Column list SQL prepared');
            
            -- Execute dynamic SQL to get column list
            DECLARE
                v_column_list VARCHAR2(32767);
            BEGIN
                EXECUTE IMMEDIATE v_sql INTO v_column_list;
                DBMS_OUTPUT.PUT_LINE('Column list retrieved: ' || SUBSTR(v_column_list, 1, 100) || '...');
                
                -- Check if column list is empty
                IF v_column_list IS NULL OR LENGTH(v_column_list) = 0 THEN
                    RAISE_APPLICATION_ERROR(-20002, 'No common columns found between tables');
                END IF;
                
                -- Count records in each table
                BEGIN
                    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_snapshot_table INTO v_count_snapshot;
                    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_target_table INTO v_count_target;
                    
                    DBMS_OUTPUT.PUT_LINE('Record counts: ' || p_snapshot_table || '=' || v_count_snapshot || 
                                         ', ' || p_target_table || '=' || v_count_target);
                                         
                    -- Initialize collection (fix for common error)
                    DECLARE
                        TYPE str_array IS TABLE OF VARCHAR2(128);
                        v_cols str_array := str_array();
                        v_comparison_clause VARCHAR2(32767) := '';
                        v_col_name VARCHAR2(128);
                        v_pos NUMBER;
                        v_remains VARCHAR2(32767);
                    BEGIN
                        -- Parse column list manually
                        v_remains := v_column_list;
                        WHILE v_remains IS NOT NULL LOOP
                            v_pos := INSTR(v_remains, ',');
                            IF v_pos > 0 THEN
                                v_col_name := TRIM(SUBSTR(v_remains, 1, v_pos - 1));
                                v_remains := SUBSTR(v_remains, v_pos + 1);
                            ELSE
                                v_col_name := TRIM(v_remains);
                                v_remains := NULL;
                            END IF;
                            
                            v_cols.EXTEND;
                            v_cols(v_cols.COUNT) := v_col_name;
                        END LOOP;
                        
                        -- Build comparison clause
                        FOR i IN 1..v_cols.COUNT LOOP
                            IF i > 1 THEN
                                v_comparison_clause := v_comparison_clause || ' AND ';
                            END IF;
                            v_comparison_clause := v_comparison_clause || 's.' || v_cols(i) || ' = t.' || v_cols(i);
                        END LOOP;
                        
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
                        
                        BEGIN
                            EXECUTE IMMEDIATE v_sql INTO v_diff_count;
                            DBMS_OUTPUT.PUT_LINE('Difference count: ' || v_diff_count);
                            
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
                                    ELSE ROUND(100 - (v_diff_count / GREATEST(v_count_snapshot, v_count_target) * 100), 2)
                                END || '%'
                            );
                            
                            -- Create detailed comparison table for this pair
                            -- First drop the table if it exists
                            BEGIN
                                EXECUTE IMMEDIATE 'DROP TABLE DIFF_' || p_snapshot_table || '_' || p_target_table || ' PURGE';
                                DBMS_OUTPUT.PUT_LINE('Dropped existing difference table');
                            EXCEPTION
                                WHEN OTHERS THEN
                                    DBMS_OUTPUT.PUT_LINE('Difference table did not exist or could not be dropped: ' || SQLERRM);
                            END;
                            
                            -- Create detailed comparison table
                            v_sql := '
                                CREATE TABLE DIFF_' || p_snapshot_table || '_' || p_target_table || ' AS
                                (
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
                                    )
                                )';
                                
                            EXECUTE IMMEDIATE v_sql;
                            DBMS_OUTPUT.PUT_LINE('Created difference table: DIFF_' || p_snapshot_table || '_' || p_target_table);
                            
                            DBMS_OUTPUT.PUT_LINE('Comparison complete. Results stored in COMPARISON_RESULTS table.');
                            DBMS_OUTPUT.PUT_LINE('Detailed differences stored in DIFF_' || p_snapshot_table || '_' || p_target_table);
                        EXCEPTION
                            WHEN OTHERS THEN
                                v_error_msg := SQLERRM;
                                DBMS_OUTPUT.PUT_LINE('Error in difference calculation or table creation: ' || v_error_msg);
                                RAISE;
                        END;
                    END;
                EXCEPTION
                    WHEN OTHERS THEN
                        v_error_msg := SQLERRM;
                        DBMS_OUTPUT.PUT_LINE('Error counting records: ' || v_error_msg);
                        RAISE;
                END;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_msg := SQLERRM;
                    DBMS_OUTPUT.PUT_LINE('Error processing column list: ' || v_error_msg);
                    RAISE;
            END;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_msg := SQLERRM;
                DBMS_OUTPUT.PUT_LINE('Error building column list SQL: ' || v_error_msg);
                RAISE;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error
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
                    'Error comparing tables: ' || SUBSTR(SQLERRM, 1, 3990)
                );
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Could not log error to COMPARISON_RESULTS: ' || SQLERRM);
            END;
            DBMS_OUTPUT.PUT_LINE('Procedure error: ' || SQLERRM);
    END;
    
    COMMIT;
END compare_tables;
/


BEGIN
    compare_tables('YOUR_SNAPSHOT_TABLE', 'YOUR_TARGET_TABLE');
END;
/


SELECT * FROM COMPARISON_RESULTS 
WHERE SNAPSHOT_TABLE = 'YOUR_SNAPSHOT_TABLE' 
AND TARGET_TABLE = 'YOUR_TARGET_TABLE';


SELECT * FROM DIFF_YOUR_SNAPSHOT_TABLE_YOUR_TARGET_TABLE;
