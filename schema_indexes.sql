-- Oracle Stored Procedure to generate comprehensive index report for a schema
-- This procedure provides detailed information about all indexes across all tables

CREATE OR REPLACE PROCEDURE sp_generate_index_report (
    p_schema_name IN VARCHAR2 DEFAULT NULL,  -- Optional: specify schema, defaults to current user
    p_table_name IN VARCHAR2 DEFAULT NULL,   -- Optional: specify specific table, NULL for all tables
    p_index_type IN VARCHAR2 DEFAULT NULL,   -- Optional: filter by index type (NORMAL, BITMAP, etc.)
    p_include_system_tables IN VARCHAR2 DEFAULT 'N', -- Include system tables (default: N)
    p_output_format IN VARCHAR2 DEFAULT 'DETAILED'   -- Options: 'DETAILED', 'SUMMARY', 'DROP_RECREATE'
) IS
    v_schema_name VARCHAR2(128);
    v_sql CLOB;
    
    -- Cursor for detailed report
    CURSOR c_detailed_indexes IS
        SELECT 
            i.owner AS schema_name,
            i.table_name,
            i.index_name,
            i.index_type,
            i.uniqueness,
            CASE WHEN c.constraint_type = 'P' THEN 'YES' ELSE 'NO' END AS is_primary_key,
            CASE WHEN c.constraint_type = 'U' THEN 'YES' ELSE 'NO' END AS is_unique_constraint,
            i.status,
            i.degree AS parallelism,
            i.compression,
            i.prefix_length,
            i.tablespace_name,
            -- Get index columns
            LISTAGG(ic.column_name || 
                   CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE ' ASC' END, 
                   ', ') WITHIN GROUP (ORDER BY ic.column_position) AS key_columns,
            -- Get index size
            s.bytes/1024 AS index_size_kb,
            i.num_rows,
            i.leaf_blocks,
            i.distinct_keys,
            i.blevel AS b_tree_level,
            i.clustering_factor
        FROM all_indexes i
        LEFT JOIN all_constraints c ON i.owner = c.owner 
                                   AND i.index_name = c.constraint_name
        LEFT JOIN all_ind_columns ic ON i.owner = ic.index_owner 
                                    AND i.index_name = ic.index_name
        LEFT JOIN dba_segments s ON i.owner = s.owner 
                                AND i.index_name = s.segment_name 
                                AND s.segment_type LIKE 'INDEX%'
        WHERE i.owner = v_schema_name
            AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
            AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
            AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
            AND i.index_type != 'LOB'  -- Exclude LOB indexes
        GROUP BY i.owner, i.table_name, i.index_name, i.index_type, i.uniqueness,
                 c.constraint_type, i.status, i.degree, i.compression, i.prefix_length,
                 i.tablespace_name, s.bytes, i.num_rows, i.leaf_blocks, 
                 i.distinct_keys, i.blevel, i.clustering_factor
        ORDER BY i.owner, i.table_name, i.index_name;

    -- Cursor for summary report
    CURSOR c_summary_indexes IS
        SELECT 
            i.owner AS schema_name,
            i.table_name,
            COUNT(*) AS total_indexes,
            SUM(CASE WHEN i.index_type = 'NORMAL' THEN 1 ELSE 0 END) AS normal_indexes,
            SUM(CASE WHEN i.index_type = 'BITMAP' THEN 1 ELSE 0 END) AS bitmap_indexes,
            SUM(CASE WHEN i.index_type = 'FUNCTION-BASED NORMAL' THEN 1 ELSE 0 END) AS function_based_indexes,
            SUM(CASE WHEN i.uniqueness = 'UNIQUE' THEN 1 ELSE 0 END) AS unique_indexes,
            SUM(CASE WHEN c.constraint_type = 'P' THEN 1 ELSE 0 END) AS primary_key_indexes,
            SUM(CASE WHEN i.status = 'UNUSABLE' THEN 1 ELSE 0 END) AS unusable_indexes,
            ROUND(SUM(NVL(s.bytes,0))/1024, 2) AS total_index_size_kb
        FROM all_indexes i
        LEFT JOIN all_constraints c ON i.owner = c.owner 
                                   AND i.index_name = c.constraint_name
        LEFT JOIN dba_segments s ON i.owner = s.owner 
                                AND i.index_name = s.segment_name 
                                AND s.segment_type LIKE 'INDEX%'
        WHERE i.owner = v_schema_name
            AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
            AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
            AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
            AND i.index_type != 'LOB'  -- Exclude LOB indexes
        GROUP BY i.owner, i.table_name
        ORDER BY i.owner, i.table_name;

    -- Cursor for drop/recreate scripts
    CURSOR c_drop_recreate IS
        SELECT 
            i.owner AS schema_name,
            i.table_name,
            i.index_name,
            i.index_type,
            i.uniqueness,
            CASE WHEN c.constraint_type IN ('P', 'U') THEN 'YES' ELSE 'NO' END AS is_constraint,
            i.tablespace_name,
            i.compression,
            i.degree,
            -- Get columns for CREATE statement
            LISTAGG(ic.column_name || 
                   CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE '' END, 
                   ', ') WITHIN GROUP (ORDER BY ic.column_position) AS index_columns
        FROM all_indexes i
        LEFT JOIN all_constraints c ON i.owner = c.owner 
                                   AND i.index_name = c.constraint_name
        LEFT JOIN all_ind_columns ic ON i.owner = ic.index_owner 
                                    AND i.index_name = ic.index_name
        WHERE i.owner = v_schema_name
            AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
            AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
            AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
            AND i.index_type != 'LOB'  -- Exclude LOB indexes
            AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes
        GROUP BY i.owner, i.table_name, i.index_name, i.index_type, i.uniqueness,
                 c.constraint_type, i.tablespace_name, i.compression, i.degree
        ORDER BY i.owner, i.table_name, i.index_name;

BEGIN
    -- Set default schema if not provided
    IF p_schema_name IS NULL THEN
        SELECT user INTO v_schema_name FROM dual;
    ELSE
        v_schema_name := UPPER(p_schema_name);
    END IF;
    
    -- Detailed report
    IF UPPER(p_output_format) = 'DETAILED' THEN
        DBMS_OUTPUT.PUT_LINE('=== DETAILED INDEX REPORT FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('Schema', 15) || RPAD('Table', 30) || RPAD('Index', 30) || 
                           RPAD('Type', 20) || RPAD('Unique', 8) || RPAD('PK', 4) || RPAD('Status', 10) || 
                           RPAD('Size(KB)', 10) || 'Columns');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 15, '-') || RPAD('-', 30, '-') || RPAD('-', 30, '-') || 
                           RPAD('-', 20, '-') || RPAD('-', 8, '-') || RPAD('-', 4, '-') || RPAD('-', 10, '-') || 
                           RPAD('-', 10, '-') || RPAD('-', 50, '-'));
        
        FOR rec IN c_detailed_indexes LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(NVL(rec.schema_name, ' '), 15) ||
                RPAD(NVL(rec.table_name, ' '), 30) ||
                RPAD(NVL(rec.index_name, ' '), 30) ||
                RPAD(NVL(rec.index_type, ' '), 20) ||
                RPAD(NVL(rec.uniqueness, ' '), 8) ||
                RPAD(NVL(rec.is_primary_key, ' '), 4) ||
                RPAD(NVL(rec.status, ' '), 10) ||
                RPAD(NVL(TO_CHAR(rec.index_size_kb), ' '), 10) ||
                NVL(rec.key_columns, ' ')
            );
        END LOOP;
        
    -- Summary report
    ELSIF UPPER(p_output_format) = 'SUMMARY' THEN
        DBMS_OUTPUT.PUT_LINE('=== SUMMARY INDEX REPORT FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('Table', 30) || RPAD('Total', 8) || RPAD('Normal', 8) || 
                           RPAD('Bitmap', 8) || RPAD('Func', 8) || RPAD('Unique', 8) || 
                           RPAD('PK', 4) || RPAD('Unusable', 10) || 'Size(KB)');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 30, '-') || RPAD('-', 8, '-') || RPAD('-', 8, '-') || 
                           RPAD('-', 8, '-') || RPAD('-', 8, '-') || RPAD('-', 8, '-') || 
                           RPAD('-', 4, '-') || RPAD('-', 10, '-') || RPAD('-', 10, '-'));
        
        FOR rec IN c_summary_indexes LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(NVL(rec.table_name, ' '), 30) ||
                RPAD(NVL(TO_CHAR(rec.total_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(rec.normal_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(rec.bitmap_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(rec.function_based_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(rec.unique_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(rec.primary_key_indexes), ' '), 4) ||
                RPAD(NVL(TO_CHAR(rec.unusable_indexes), ' '), 10) ||
                NVL(TO_CHAR(rec.total_index_size_kb), ' ')
            );
        END LOOP;
        
    -- Drop and recreate scripts
    ELSIF UPPER(p_output_format) = 'DROP_RECREATE' THEN
        DBMS_OUTPUT.PUT_LINE('=== DROP STATEMENTS FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR rec IN c_drop_recreate LOOP
            DBMS_OUTPUT.PUT_LINE('DROP INDEX ' || rec.schema_name || '.' || rec.index_name || ';');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('=== CREATE STATEMENTS FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR rec IN c_drop_recreate LOOP
            v_sql := 'CREATE ';
            
            -- Add UNIQUE if applicable
            IF rec.uniqueness = 'UNIQUE' THEN
                v_sql := v_sql || 'UNIQUE ';
            END IF;
            
            -- Add BITMAP if applicable
            IF rec.index_type = 'BITMAP' THEN
                v_sql := v_sql || 'BITMAP ';
            END IF;
            
            v_sql := v_sql || 'INDEX ' || rec.schema_name || '.' || rec.index_name || 
                     ' ON ' || rec.schema_name || '.' || rec.table_name || 
                     ' (' || rec.index_columns || ')';
            
            -- Add tablespace if specified
            IF rec.tablespace_name IS NOT NULL THEN
                v_sql := v_sql || ' TABLESPACE ' || rec.tablespace_name;
            END IF;
            
            -- Add compression if enabled
            IF rec.compression = 'ENABLED' THEN
                v_sql := v_sql || ' COMPRESS';
            END IF;
            
            -- Add parallel degree if > 1
            IF rec.degree > 1 THEN
                v_sql := v_sql || ' PARALLEL ' || rec.degree;
            END IF;
            
            v_sql := v_sql || ';';
            
            DBMS_OUTPUT.PUT_LINE(v_sql);
        END LOOP;
        
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== REPORT COMPLETED ===');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END sp_generate_index_report;
/

-- Example usage:
/*
-- Get detailed report for all indexes in current schema
EXEC sp_generate_index_report(p_output_format => 'DETAILED');

-- Get summary report for specific schema
EXEC sp_generate_index_report(p_schema_name => 'HR', p_output_format => 'SUMMARY');

-- Get DROP and CREATE scripts for all normal indexes in specific schema
EXEC sp_generate_index_report(p_schema_name => 'HR', p_index_type => 'NORMAL', p_output_format => 'DROP_RECREATE');

-- Get report for specific table
EXEC sp_generate_index_report(p_schema_name => 'HR', p_table_name => 'EMPLOYEES', p_output_format => 'DETAILED');

-- Alternative execution method:
BEGIN
    sp_generate_index_report(
        p_schema_name => 'HR',
        p_output_format => 'DROP_RECREATE'
    );
END;
/
*/
