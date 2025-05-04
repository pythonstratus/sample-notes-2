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
    
    -- Create temporary comparison results table if it doesn't exist
    BEGIN
        EXECUTE IMMEDIATE 'SELECT 1 FROM COMPARISON_RESULTS WHERE 1=2';
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
BEGIN
    -- Validate that both tables exist
    BEGIN
        EXECUTE IMMEDIATE 'SELECT 1 FROM ' || p_snapshot_table || ' WHERE ROWNUM = 1';
        EXECUTE IMMEDIATE 'SELECT 1 FROM ' || p_target_table || ' WHERE ROWNUM = 1';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'One or both tables do not exist: ' || p_snapshot_table || ', ' || p_target_table);
    END;
    
    -- Get column list (using only columns that exist in both tables)
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
        
    -- Execute dynamic SQL to get column list
    DECLARE
        v_column_list VARCHAR2(32767);
    BEGIN
        EXECUTE IMMEDIATE v_sql INTO v_column_list;
        
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
        EXCEPTION
            WHEN OTHERS THEN NULL; -- Table might not exist
        END;
        
        -- Create column comparison statements for WHERE clause
        DECLARE
            v_column_array DBMS_SQL.VARCHAR2_TABLE;
            v_column_name VARCHAR2(128);
            v_comparison_clause VARCHAR2(32767) := '';
            v_counter INTEGER := 1;
        BEGIN
            -- Split column list into array
            FOR i IN 1..LENGTH(v_column_list) - LENGTH(REPLACE(v_column_list, ',', '')) + 1 LOOP
                v_column_name := REGEXP_SUBSTR(v_column_list, '[^,]+', 1, i);
                v_column_array(v_counter) := TRIM(v_column_name);
                v_counter := v_counter + 1;
            END LOOP;
            
            -- Build comparison clause
            FOR i IN 1..v_column_array.COUNT LOOP
                IF i > 1 THEN
                    v_comparison_clause := v_comparison_clause || ' AND ';
                END IF;
                v_comparison_clause := v_comparison_clause || 's.' || v_column_array(i) || ' = t.' || v_column_array(i);
            END LOOP;
            
            -- Create detailed comparison table
            EXECUTE IMMEDIATE '
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
        END;
        
        DBMS_OUTPUT.PUT_LINE('Comparison complete. Results stored in COMPARISON_RESULTS table.');
        DBMS_OUTPUT.PUT_LINE('Detailed differences stored in DIFF_' || p_snapshot_table || '_' || p_target_table);
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error
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
                'Error comparing tables: ' || SQLERRM
            );
            RAISE;
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
