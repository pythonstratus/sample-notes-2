-- Oracle Stored Procedure to generate comprehensive index report for a schema
-- Fixed version addressing compilation errors

CREATE OR REPLACE PROCEDURE sp_generate_index_report (
    p_schema_name IN VARCHAR2 DEFAULT NULL,  -- Optional: specify schema, defaults to current user
    p_table_name IN VARCHAR2 DEFAULT NULL,   -- Optional: specify specific table, NULL for all tables
    p_index_type IN VARCHAR2 DEFAULT NULL,   -- Optional: filter by index type (NORMAL, BITMAP, etc.)
    p_include_system_tables IN VARCHAR2 DEFAULT 'N', -- Include system tables (default: N)
    p_output_format IN VARCHAR2 DEFAULT 'DETAILED'   -- Options: 'DETAILED', 'SUMMARY', 'DROP_RECREATE'
) IS
    v_schema_name VARCHAR2(128);
    v_sql CLOB;
    
BEGIN
    -- Set default schema if not provided
    IF p_schema_name IS NULL THEN
        SELECT USER INTO v_schema_name FROM dual;
    ELSE
        v_schema_name := UPPER(p_schema_name);
    END IF;
    
    -- Enable DBMS_OUTPUT
    DBMS_OUTPUT.ENABLE(1000000);
    
    -- Detailed report
    IF UPPER(p_output_format) = 'DETAILED' THEN
        DBMS_OUTPUT.PUT_LINE('=== DETAILED INDEX REPORT FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('Schema', 15) || RPAD('Table', 30) || RPAD('Index', 30) || 
                           RPAD('Type', 20) || RPAD('Unique', 8) || RPAD('PK', 4) || RPAD('Status', 10) || 'Columns');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 15, '-') || RPAD('-', 30, '-') || RPAD('-', 30, '-') || 
                           RPAD('-', 20, '-') || RPAD('-', 8, '-') || RPAD('-', 4, '-') || RPAD('-', 10, '-') || 
                           RPAD('-', 50, '-'));
        
        -- Use explicit cursor with FOR loop
        FOR idx_rec IN (
            SELECT 
                i.owner AS schema_name,
                i.table_name,
                i.index_name,
                i.index_type,
                i.uniqueness,
                CASE WHEN c.constraint_type = 'P' THEN 'YES' ELSE 'NO' END AS is_primary_key,
                i.status,
                -- Get index columns using subquery
                (SELECT LISTAGG(ic.column_name || 
                       CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE ' ASC' END, ', ') 
                       WITHIN GROUP (ORDER BY ic.column_position)
                 FROM all_ind_columns ic 
                 WHERE ic.index_owner = i.owner 
                   AND ic.index_name = i.index_name) AS key_columns
            FROM all_indexes i
            LEFT JOIN all_constraints c ON i.owner = c.owner 
                                       AND i.index_name = c.constraint_name
            WHERE i.owner = v_schema_name
                AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
                AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
                AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
                AND i.index_type != 'LOB'  -- Exclude LOB indexes
            ORDER BY i.owner, i.table_name, i.index_name
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(NVL(idx_rec.schema_name, ' '), 15) ||
                RPAD(NVL(idx_rec.table_name, ' '), 30) ||
                RPAD(NVL(idx_rec.index_name, ' '), 30) ||
                RPAD(NVL(idx_rec.index_type, ' '), 20) ||
                RPAD(NVL(idx_rec.uniqueness, ' '), 8) ||
                RPAD(NVL(idx_rec.is_primary_key, ' '), 4) ||
                RPAD(NVL(idx_rec.status, ' '), 10) ||
                NVL(idx_rec.key_columns, ' ')
            );
        END LOOP;
        
    -- Summary report
    ELSIF UPPER(p_output_format) = 'SUMMARY' THEN
        DBMS_OUTPUT.PUT_LINE('=== SUMMARY INDEX REPORT FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('Table', 30) || RPAD('Total', 8) || RPAD('Normal', 8) || 
                           RPAD('Bitmap', 8) || RPAD('Func', 8) || RPAD('Unique', 8) || 
                           RPAD('PK', 4) || RPAD('Unusable', 10));
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 30, '-') || RPAD('-', 8, '-') || RPAD('-', 8, '-') || 
                           RPAD('-', 8, '-') || RPAD('-', 8, '-') || RPAD('-', 8, '-') || 
                           RPAD('-', 4, '-') || RPAD('-', 10, '-'));
        
        FOR sum_rec IN (
            SELECT 
                i.table_name,
                COUNT(*) AS total_indexes,
                SUM(CASE WHEN i.index_type = 'NORMAL' THEN 1 ELSE 0 END) AS normal_indexes,
                SUM(CASE WHEN i.index_type = 'BITMAP' THEN 1 ELSE 0 END) AS bitmap_indexes,
                SUM(CASE WHEN i.index_type = 'FUNCTION-BASED NORMAL' THEN 1 ELSE 0 END) AS function_based_indexes,
                SUM(CASE WHEN i.uniqueness = 'UNIQUE' THEN 1 ELSE 0 END) AS unique_indexes,
                SUM(CASE WHEN c.constraint_type = 'P' THEN 1 ELSE 0 END) AS primary_key_indexes,
                SUM(CASE WHEN i.status = 'UNUSABLE' THEN 1 ELSE 0 END) AS unusable_indexes
            FROM all_indexes i
            LEFT JOIN all_constraints c ON i.owner = c.owner 
                                       AND i.index_name = c.constraint_name
            WHERE i.owner = v_schema_name
                AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
                AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
                AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
                AND i.index_type != 'LOB'  -- Exclude LOB indexes
            GROUP BY i.table_name
            ORDER BY i.table_name
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(NVL(sum_rec.table_name, ' '), 30) ||
                RPAD(NVL(TO_CHAR(sum_rec.total_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(sum_rec.normal_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(sum_rec.bitmap_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(sum_rec.function_based_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(sum_rec.unique_indexes), ' '), 8) ||
                RPAD(NVL(TO_CHAR(sum_rec.primary_key_indexes), ' '), 4) ||
                NVL(TO_CHAR(sum_rec.unusable_indexes), ' ')
            );
        END LOOP;
        
    -- Drop and recreate scripts
    ELSIF UPPER(p_output_format) = 'DROP_RECREATE' THEN
        DBMS_OUTPUT.PUT_LINE('=== DROP STATEMENTS FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('-- Execute these BEFORE your ETL process');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR drop_rec IN (
            SELECT 
                i.owner AS schema_name,
                i.index_name
            FROM all_indexes i
            LEFT JOIN all_constraints c ON i.owner = c.owner 
                                       AND i.index_name = c.constraint_name
            WHERE i.owner = v_schema_name
                AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
                AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
                AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
                AND i.index_type != 'LOB'  -- Exclude LOB indexes
                AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes
            ORDER BY i.table_name, i.index_name
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('DROP INDEX ' || drop_rec.schema_name || '.' || drop_rec.index_name || ';');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('=== CREATE STATEMENTS FOR SCHEMA: ' || v_schema_name || ' ===');
        DBMS_OUTPUT.PUT_LINE('-- Execute these AFTER your ETL process');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR create_rec IN (
            SELECT 
                i.owner AS schema_name,
                i.table_name,
                i.index_name,
                i.index_type,
                i.uniqueness,
                i.tablespace_name,
                i.compression,
                CASE WHEN i.degree = 'DEFAULT' THEN '1' ELSE i.degree END AS degree,
                -- Get columns for CREATE statement
                (SELECT LISTAGG(ic.column_name || 
                       CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE '' END, ', ') 
                       WITHIN GROUP (ORDER BY ic.column_position)
                 FROM all_ind_columns ic 
                 WHERE ic.index_owner = i.owner 
                   AND ic.index_name = i.index_name) AS index_columns
            FROM all_indexes i
            LEFT JOIN all_constraints c ON i.owner = c.owner 
                                       AND i.index_name = c.constraint_name
            WHERE i.owner = v_schema_name
                AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
                AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
                AND (p_include_system_tables = 'Y' OR i.table_name NOT LIKE 'SYS_%')
                AND i.index_type != 'LOB'  -- Exclude LOB indexes
                AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes
            ORDER BY i.table_name, i.index_name
        ) LOOP
            v_sql := 'CREATE ';
            
            -- Add UNIQUE if applicable
            IF create_rec.uniqueness = 'UNIQUE' THEN
                v_sql := v_sql || 'UNIQUE ';
            END IF;
            
            -- Add BITMAP if applicable
            IF create_rec.index_type = 'BITMAP' THEN
                v_sql := v_sql || 'BITMAP ';
            END IF;
            
            v_sql := v_sql || 'INDEX ' || create_rec.schema_name || '.' || create_rec.index_name || 
                     ' ON ' || create_rec.schema_name || '.' || create_rec.table_name || 
                     ' (' || create_rec.index_columns || ')';
            
            -- Add tablespace if specified
            IF create_rec.tablespace_name IS NOT NULL THEN
                v_sql := v_sql || ' TABLESPACE ' || create_rec.tablespace_name;
            END IF;
            
            -- Add compression if enabled
            IF create_rec.compression = 'ENABLED' THEN
                v_sql := v_sql || ' COMPRESS';
            END IF;
            
            -- Add parallel degree if > 1
            IF TO_NUMBER(create_rec.degree) > 1 THEN
                v_sql := v_sql || ' PARALLEL ' || create_rec.degree;
            END IF;
            
            v_sql := v_sql || ';';
            
            DBMS_OUTPUT.PUT_LINE(v_sql);
        END LOOP;
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('Invalid output format. Use: DETAILED, SUMMARY, or DROP_RECREATE');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== REPORT COMPLETED ===');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END sp_generate_index_report;
/

-- Grant execute permission (run as schema owner or DBA)
-- GRANT EXECUTE ON sp_generate_index_report TO PUBLIC;

-- Example usage (make sure to enable SERVEROUTPUT first):
/*
SET SERVEROUTPUT ON SIZE 1000000;

-- Get detailed report for current schema
EXEC sp_generate_index_report(p_output_format => 'DETAILED');

-- Get summary report for specific schema
EXEC sp_generate_index_report(p_schema_name => 'HR', p_output_format => 'SUMMARY');

-- Get DROP and CREATE scripts for specific schema
EXEC sp_generate_index_report(p_schema_name => 'YOUR_SCHEMA', p_output_format => 'DROP_RECREATE');

-- Get report for specific table
EXEC sp_generate_index_report(p_table_name => 'YOUR_TABLE', p_output_format => 'DETAILED');
*/
