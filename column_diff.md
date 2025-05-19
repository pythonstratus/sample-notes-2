CREATE OR REPLACE FUNCTION compare_table_structure(
    p_source_table IN VARCHAR2,
    p_target_table IN VARCHAR2
) RETURN SYS_REFCURSOR
AS
    v_source_exists NUMBER;
    v_target_exists NUMBER;
    v_result_cursor SYS_REFCURSOR;
    v_source_schema VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    v_target_schema VARCHAR2(128) := SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
    v_source_owner VARCHAR2(128);
    v_target_owner VARCHAR2(128);
    v_source_table_name VARCHAR2(128);
    v_target_table_name VARCHAR2(128);
BEGIN
    -- Parse schema and table names
    IF INSTR(p_source_table, '.') > 0 THEN
        v_source_schema := SUBSTR(p_source_table, 1, INSTR(p_source_table, '.') - 1);
        v_source_table_name := SUBSTR(p_source_table, INSTR(p_source_table, '.') + 1);
    ELSE
        v_source_table_name := p_source_table;
    END IF;
    
    IF INSTR(p_target_table, '.') > 0 THEN
        v_target_schema := SUBSTR(p_target_table, 1, INSTR(p_target_table, '.') - 1);
        v_target_table_name := SUBSTR(p_target_table, INSTR(p_target_table, '.') + 1);
    ELSE
        v_target_table_name := p_target_table;
    END IF;
    
    v_source_owner := UPPER(v_source_schema);
    v_target_owner := UPPER(v_target_schema);
    v_source_table_name := UPPER(v_source_table_name);
    v_target_table_name := UPPER(v_target_table_name);

    -- Check if the tables exist
    SELECT COUNT(*) INTO v_source_exists 
    FROM all_tables 
    WHERE table_name = v_source_table_name AND owner = v_source_owner;
    
    SELECT COUNT(*) INTO v_target_exists 
    FROM all_tables 
    WHERE table_name = v_target_table_name AND owner = v_target_owner;
    
    IF v_source_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Source table ' || p_source_table || ' does not exist');
    END IF;
    
    IF v_target_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Target table ' || p_target_table || ' does not exist');
    END IF;

    -- Output comparison info
    DBMS_OUTPUT.PUT_LINE('Comparing table structures:');
    DBMS_OUTPUT.PUT_LINE('Source: ' || v_source_owner || '.' || v_source_table_name);
    DBMS_OUTPUT.PUT_LINE('Target: ' || v_target_owner || '.' || v_target_table_name);
    
    -- Complex query that performs a full structural comparison between tables
    OPEN v_result_cursor FOR
    WITH source_columns AS (
        SELECT 
            column_name,
            data_type,
            data_length,
            data_precision,
            data_scale,
            nullable,
            column_id,
            default_length,
            data_default,
            char_length,
            char_used
        FROM all_tab_columns
        WHERE owner = v_source_owner
        AND table_name = v_source_table_name
    ),
    target_columns AS (
        SELECT 
            column_name,
            data_type,
            data_length,
            data_precision,
            data_scale,
            nullable,
            column_id,
            default_length,
            data_default,
            char_length,
            char_used
        FROM all_tab_columns
        WHERE owner = v_target_owner
        AND table_name = v_target_table_name
    ),
    source_only AS (
        SELECT 
            s.column_name,
            s.data_type,
            s.data_length,
            s.data_precision,
            s.data_scale,
            s.nullable,
            s.column_id,
            'ONLY_IN_SOURCE' AS status,
            NULL AS difference_details
        FROM source_columns s
        WHERE NOT EXISTS (
            SELECT 1
            FROM target_columns t
            WHERE t.column_name = s.column_name
        )
    ),
    target_only AS (
        SELECT 
            t.column_name,
            t.data_type,
            t.data_length,
            t.data_precision,
            t.data_scale,
            t.nullable,
            t.column_id,
            'ONLY_IN_TARGET' AS status,
            NULL AS difference_details
        FROM target_columns t
        WHERE NOT EXISTS (
            SELECT 1
            FROM source_columns s
            WHERE s.column_name = t.column_name
        )
    ),
    common_different AS (
        SELECT 
            s.column_name,
            s.data_type AS source_data_type,
            t.data_type AS target_data_type,
            s.data_length AS source_length,
            t.data_length AS target_length,
            s.data_precision AS source_precision,
            t.data_precision AS target_precision,
            s.data_scale AS source_scale,
            t.data_scale AS target_scale,
            s.nullable AS source_nullable,
            t.nullable AS target_nullable,
            s.column_id AS source_position,
            t.column_id AS target_position,
            'DIFFERENT' AS status,
            CASE
                WHEN s.data_type != t.data_type
                THEN 'Data type: ' || s.data_type || ' vs ' || t.data_type
                WHEN s.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') AND 
                     (NVL(s.char_length, 0) != NVL(t.char_length, 0) OR NVL(s.char_used, 'B') != NVL(t.char_used, 'B'))
                THEN 'Size: ' || 
                     CASE WHEN s.char_used = 'C' THEN s.char_length || ' CHAR' 
                          WHEN s.char_used = 'B' THEN s.char_length || ' BYTE'
                          ELSE TO_CHAR(s.data_length) END || 
                     ' vs ' || 
                     CASE WHEN t.char_used = 'C' THEN t.char_length || ' CHAR' 
                          WHEN t.char_used = 'B' THEN t.char_length || ' BYTE'
                          ELSE TO_CHAR(t.data_length) END
                WHEN s.data_type IN ('NUMBER') AND 
                     (NVL(s.data_precision, 0) != NVL(t.data_precision, 0) OR 
                      NVL(s.data_scale, 0) != NVL(t.data_scale, 0))
                THEN 'Precision/Scale: ' || 
                     NVL(TO_CHAR(s.data_precision), '*') || ',' || NVL(TO_CHAR(s.data_scale), '*') || 
                     ' vs ' || 
                     NVL(TO_CHAR(t.data_precision), '*') || ',' || NVL(TO_CHAR(t.data_scale), '*')
                WHEN s.data_type NOT IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR', 'NUMBER') AND 
                     NVL(s.data_length, 0) != NVL(t.data_length, 0)
                THEN 'Length: ' || NVL(TO_CHAR(s.data_length), '*') || ' vs ' || NVL(TO_CHAR(t.data_length), '*')
                WHEN s.nullable != t.nullable
                THEN 'Nullability: ' || s.nullable || ' vs ' || t.nullable
                WHEN s.column_id != t.column_id
                THEN 'Position: ' || TO_CHAR(s.column_id) || ' vs ' || TO_CHAR(t.column_id)
                WHEN NVL(s.default_length, 0) != NVL(t.default_length, 0) OR
                     NVL(TO_CHAR(s.data_default), '*') != NVL(TO_CHAR(t.data_default), '*')
                THEN 'Default value differs'
                ELSE 'Other difference'
            END AS difference_details
        FROM source_columns s
        JOIN target_columns t ON s.column_name = t.column_name
        WHERE s.data_type != t.data_type
           OR NVL(s.data_length, 0) != NVL(t.data_length, 0)
           OR NVL(s.data_precision, 0) != NVL(t.data_precision, 0)
           OR NVL(s.data_scale, 0) != NVL(t.data_scale, 0)
           OR s.nullable != t.nullable
           OR NVL(s.char_length, 0) != NVL(t.char_length, 0)
           OR NVL(s.char_used, 'B') != NVL(t.char_used, 'B')
           OR NVL(s.default_length, 0) != NVL(t.default_length, 0)
           OR NVL(TO_CHAR(s.data_default), '*') != NVL(TO_CHAR(t.data_default), '*')
    ),
    common_same AS (
        SELECT 
            s.column_name,
            s.data_type,
            s.data_length,
            s.data_precision,
            s.data_scale,
            s.nullable,
            s.column_id,
            'IDENTICAL' AS status,
            NULL AS difference_details
        FROM source_columns s
        JOIN target_columns t ON s.column_name = t.column_name
        WHERE s.data_type = t.data_type
          AND NVL(s.data_length, 0) = NVL(t.data_length, 0)
          AND NVL(s.data_precision, 0) = NVL(t.data_precision, 0)
          AND NVL(s.data_scale, 0) = NVL(t.data_scale, 0)
          AND s.nullable = t.nullable
          AND NVL(s.char_length, 0) = NVL(t.char_length, 0)
          AND NVL(s.char_used, 'B') = NVL(t.char_used, 'B')
          AND NVL(s.default_length, 0) = NVL(t.default_length, 0)
          AND NVL(TO_CHAR(s.data_default), '*') = NVL(TO_CHAR(t.data_default), '*')
    ),
    all_columns AS (
        -- Columns only in source
        SELECT 
            column_name,
            status,
            'Column only exists in source table' AS description,
            column_id AS sort_order,
            data_type || 
            CASE 
                WHEN data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') 
                THEN '(' || data_length || ')' 
                WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL 
                THEN '(' || data_precision || 
                     CASE WHEN data_scale IS NOT NULL AND data_scale > 0 
                          THEN ',' || data_scale 
                          ELSE '' 
                     END || ')'
                ELSE ''
            END AS source_details,
            '' AS target_details,
            difference_details
        FROM source_only
        
        UNION ALL
        
        -- Columns only in target
        SELECT 
            column_name,
            status,
            'Column only exists in target table' AS description,
            column_id AS sort_order,
            '' AS source_details,
            data_type || 
            CASE 
                WHEN data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') 
                THEN '(' || data_length || ')' 
                WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL 
                THEN '(' || data_precision || 
                     CASE WHEN data_scale IS NOT NULL AND data_scale > 0 
                          THEN ',' || data_scale 
                          ELSE '' 
                     END || ')'
                ELSE ''
            END AS target_details,
            difference_details
        FROM target_only
        
        UNION ALL
        
        -- Columns in both but different
        SELECT 
            column_name,
            status,
            'Column definition differs' AS description,
            source_position AS sort_order,
            source_data_type || 
            CASE 
                WHEN source_data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') 
                THEN '(' || source_length || ')' 
                WHEN source_data_type = 'NUMBER' AND source_precision IS NOT NULL 
                THEN '(' || source_precision || 
                     CASE WHEN source_scale IS NOT NULL AND source_scale > 0 
                          THEN ',' || source_scale 
                          ELSE '' 
                     END || ')'
                ELSE ''
            END || 
            CASE WHEN source_nullable = 'N' THEN ' NOT NULL' ELSE '' END
            AS source_details,
            target_data_type || 
            CASE 
                WHEN target_data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') 
                THEN '(' || target_length || ')' 
                WHEN target_data_type = 'NUMBER' AND target_precision IS NOT NULL 
                THEN '(' || target_precision || 
                     CASE WHEN target_scale IS NOT NULL AND target_scale > 0 
                          THEN ',' || target_scale 
                          ELSE '' 
                     END || ')'
                ELSE ''
            END || 
            CASE WHEN target_nullable = 'N' THEN ' NOT NULL' ELSE '' END
            AS target_details,
            difference_details
        FROM common_different
        
        UNION ALL
        
        -- Columns in both and identical (optional, comment out if not needed)
        SELECT 
            column_name,
            status,
            'Column identical in both tables' AS description,
            column_id AS sort_order,
            data_type || 
            CASE 
                WHEN data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') 
                THEN '(' || data_length || ')' 
                WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL 
                THEN '(' || data_precision || 
                     CASE WHEN data_scale IS NOT NULL AND data_scale > 0 
                          THEN ',' || data_scale 
                          ELSE '' 
                     END || ')'
                ELSE ''
            END || 
            CASE WHEN nullable = 'N' THEN ' NOT NULL' ELSE '' END
            AS source_details,
            data_type || 
            CASE 
                WHEN data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') 
                THEN '(' || data_length || ')' 
                WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL 
                THEN '(' || data_precision || 
                     CASE WHEN data_scale IS NOT NULL AND data_scale > 0 
                          THEN ',' || data_scale 
                          ELSE '' 
                     END || ')'
                ELSE ''
            END || 
            CASE WHEN nullable = 'N' THEN ' NOT NULL' ELSE '' END
            AS target_details,
            difference_details
        FROM common_same
    )
    SELECT 
        column_name,
        status,
        description,
        source_details,
        target_details,
        difference_details
    FROM all_columns
    ORDER BY 
        CASE 
            WHEN status = 'ONLY_IN_SOURCE' THEN 1
            WHEN status = 'ONLY_IN_TARGET' THEN 2
            WHEN status = 'DIFFERENT' THEN 3
            WHEN status = 'IDENTICAL' THEN 4
            ELSE 5
        END,
        sort_order;
        
    -- Output a summary to DBMS_OUTPUT
    DECLARE
        v_source_only NUMBER;
        v_target_only NUMBER;
        v_different NUMBER;
        v_same NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_source_only FROM all_tab_columns WHERE owner = v_source_owner AND table_name = v_source_table_name
        AND column_name NOT IN (SELECT column_name FROM all_tab_columns WHERE owner = v_target_owner AND table_name = v_target_table_name);
        
        SELECT COUNT(*) INTO v_target_only FROM all_tab_columns WHERE owner = v_target_owner AND table_name = v_target_table_name
        AND column_name NOT IN (SELECT column_name FROM all_tab_columns WHERE owner = v_source_owner AND table_name = v_source_table_name);
        
        SELECT COUNT(*) INTO v_different FROM (
            SELECT s.column_name
            FROM all_tab_columns s
            JOIN all_tab_columns t ON s.column_name = t.column_name
            WHERE s.owner = v_source_owner
            AND s.table_name = v_source_table_name
            AND t.owner = v_target_owner
            AND t.table_name = v_target_table_name
            AND (s.data_type != t.data_type
               OR NVL(s.data_length, 0) != NVL(t.data_length, 0)
               OR NVL(s.data_precision, 0) != NVL(t.data_precision, 0)
               OR NVL(s.data_scale, 0) != NVL(t.data_scale, 0)
               OR s.nullable != t.nullable
               OR NVL(s.char_length, 0) != NVL(t.char_length, 0)
               OR NVL(s.char_used, 'B') != NVL(t.char_used, 'B')
               OR NVL(s.default_length, 0) != NVL(t.default_length, 0)
               OR NVL(TO_CHAR(s.data_default), '*') != NVL(TO_CHAR(t.data_default), '*'))
        );
        
        SELECT COUNT(*) INTO v_same FROM (
            SELECT s.column_name
            FROM all_tab_columns s
            JOIN all_tab_columns t ON s.column_name = t.column_name
            WHERE s.owner = v_source_owner
            AND s.table_name = v_source_table_name
            AND t.owner = v_target_owner
            AND t.table_name = v_target_table_name
            AND s.data_type = t.data_type
            AND NVL(s.data_length, 0) = NVL(t.data_length, 0)
            AND NVL(s.data_precision, 0) = NVL(t.data_precision, 0)
            AND NVL(s.data_scale, 0) = NVL(t.data_scale, 0)
            AND s.nullable = t.nullable
            AND NVL(s.char_length, 0) = NVL(t.char_length, 0)
            AND NVL(s.char_used, 'B') = NVL(t.char_used, 'B')
            AND NVL(s.default_length, 0) = NVL(t.default_length, 0)
            AND NVL(TO_CHAR(s.data_default), '*') = NVL(TO_CHAR(t.data_default), '*')
        );
        
        DBMS_OUTPUT.PUT_LINE('==================== STRUCTURE COMPARISON SUMMARY ====================');
        DBMS_OUTPUT.PUT_LINE('Columns only in source: ' || v_source_only);
        DBMS_OUTPUT.PUT_LINE('Columns only in target: ' || v_target_only);
        DBMS_OUTPUT.PUT_LINE('Columns with different definitions: ' || v_different);
        DBMS_OUTPUT.PUT_LINE('Columns with identical definitions: ' || v_same);
        DBMS_OUTPUT.PUT_LINE('Total structural differences: ' || (v_source_only + v_target_only + v_different));
        DBMS_OUTPUT.PUT_LINE('=================================================================');
    END;
    
    RETURN v_result_cursor;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END compare_table_structure;
/


DECLARE
    v_cursor SYS_REFCURSOR;
BEGIN
    v_cursor := compare_table_structure('ENT', 'ENT_WEEKLY_post_SNAPSHOT_03302025');
    DBMS_SQL.RETURN_RESULT(v_cursor);
END;
