-- Oracle Function to generate comprehensive index report for a schema
-- Returns a pipelined table function that can be queried directly

-- First, create the object types for the return data
CREATE OR REPLACE TYPE index_report_row AS OBJECT (
    schema_name VARCHAR2(128),
    table_name VARCHAR2(128),
    index_name VARCHAR2(128),
    index_type VARCHAR2(50),
    uniqueness VARCHAR2(10),
    is_primary_key VARCHAR2(3),
    is_unique_constraint VARCHAR2(3),
    status VARCHAR2(20),
    tablespace_name VARCHAR2(128),
    key_columns VARCHAR2(4000),
    included_columns VARCHAR2(4000),
    compression VARCHAR2(20),
    degree VARCHAR2(10),
    num_rows NUMBER,
    leaf_blocks NUMBER,
    distinct_keys NUMBER,
    blevel NUMBER
);
/

CREATE OR REPLACE TYPE index_report_table AS TABLE OF index_report_row;
/

-- Main function that returns index information
CREATE OR REPLACE FUNCTION fn_get_index_report (
    p_schema_name IN VARCHAR2 DEFAULT NULL,
    p_table_name IN VARCHAR2 DEFAULT NULL,
    p_index_type IN VARCHAR2 DEFAULT NULL,
    p_include_system_tables IN VARCHAR2 DEFAULT 'N'
) RETURN index_report_table PIPELINED
IS
    v_schema_name VARCHAR2(128);
    v_row index_report_row;
    
BEGIN
    -- Set default schema if not provided
    IF p_schema_name IS NULL THEN
        SELECT USER INTO v_schema_name FROM dual;
    ELSE
        v_schema_name := UPPER(p_schema_name);
    END IF;
    
    -- Query and pipe rows
    FOR rec IN (
        SELECT 
            i.owner AS schema_name,
            i.table_name,
            i.index_name,
            i.index_type,
            i.uniqueness,
            CASE WHEN c.constraint_type = 'P' THEN 'YES' ELSE 'NO' END AS is_primary_key,
            CASE WHEN c.constraint_type = 'U' THEN 'YES' ELSE 'NO' END AS is_unique_constraint,
            i.status,
            i.tablespace_name,
            i.compression,
            CASE WHEN i.degree = 'DEFAULT' THEN '1' ELSE i.degree END AS degree,
            i.num_rows,
            i.leaf_blocks,
            i.distinct_keys,
            i.blevel,
            -- Get index columns
            (SELECT LISTAGG(ic.column_name || 
                   CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE '' END, ', ') 
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
        ORDER BY i.table_name, i.index_name
    ) LOOP
        v_row := index_report_row(
            rec.schema_name,
            rec.table_name,
            rec.index_name,
            rec.index_type,
            rec.uniqueness,
            rec.is_primary_key,
            rec.is_unique_constraint,
            rec.status,
            rec.tablespace_name,
            rec.key_columns,
            NULL, -- included_columns (Oracle doesn't have this concept like SQL Server)
            rec.compression,
            rec.degree,
            rec.num_rows,
            rec.leaf_blocks,
            rec.distinct_keys,
            rec.blevel
        );
        
        PIPE ROW(v_row);
    END LOOP;
    
    RETURN;
END fn_get_index_report;
/

-- Summary function for aggregated data
CREATE OR REPLACE TYPE index_summary_row AS OBJECT (
    schema_name VARCHAR2(128),
    table_name VARCHAR2(128),
    total_indexes NUMBER,
    normal_indexes NUMBER,
    bitmap_indexes NUMBER,
    function_based_indexes NUMBER,
    unique_indexes NUMBER,
    primary_key_indexes NUMBER,
    unusable_indexes NUMBER,
    total_leaf_blocks NUMBER
);
/

CREATE OR REPLACE TYPE index_summary_table AS TABLE OF index_summary_row;
/

CREATE OR REPLACE FUNCTION fn_get_index_summary (
    p_schema_name IN VARCHAR2 DEFAULT NULL,
    p_table_name IN VARCHAR2 DEFAULT NULL
) RETURN index_summary_table PIPELINED
IS
    v_schema_name VARCHAR2(128);
    v_row index_summary_row;
    
BEGIN
    -- Set default schema if not provided
    IF p_schema_name IS NULL THEN
        SELECT USER INTO v_schema_name FROM dual;
    ELSE
        v_schema_name := UPPER(p_schema_name);
    END IF;
    
    FOR rec IN (
        SELECT 
            i.owner AS schema_name,
            i.table_name,
            COUNT(*) AS total_indexes,
            SUM(CASE WHEN i.index_type = 'NORMAL' THEN 1 ELSE 0 END) AS normal_indexes,
            SUM(CASE WHEN i.index_type = 'BITMAP' THEN 1 ELSE 0 END) AS bitmap_indexes,
            SUM(CASE WHEN i.index_type LIKE 'FUNCTION-BASED%' THEN 1 ELSE 0 END) AS function_based_indexes,
            SUM(CASE WHEN i.uniqueness = 'UNIQUE' THEN 1 ELSE 0 END) AS unique_indexes,
            SUM(CASE WHEN c.constraint_type = 'P' THEN 1 ELSE 0 END) AS primary_key_indexes,
            SUM(CASE WHEN i.status = 'UNUSABLE' THEN 1 ELSE 0 END) AS unusable_indexes,
            SUM(NVL(i.leaf_blocks, 0)) AS total_leaf_blocks
        FROM all_indexes i
        LEFT JOIN all_constraints c ON i.owner = c.owner 
                                   AND i.index_name = c.constraint_name
        WHERE i.owner = v_schema_name
            AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
            AND i.index_type != 'LOB'
        GROUP BY i.owner, i.table_name
        ORDER BY i.table_name
    ) LOOP
        v_row := index_summary_row(
            rec.schema_name,
            rec.table_name,
            rec.total_indexes,
            rec.normal_indexes,
            rec.bitmap_indexes,
            rec.function_based_indexes,
            rec.unique_indexes,
            rec.primary_key_indexes,
            rec.unusable_indexes,
            rec.total_leaf_blocks
        );
        
        PIPE ROW(v_row);
    END LOOP;
    
    RETURN;
END fn_get_index_summary;
/

-- Function to generate DROP statements
CREATE OR REPLACE FUNCTION fn_get_drop_statements (
    p_schema_name IN VARCHAR2 DEFAULT NULL,
    p_table_name IN VARCHAR2 DEFAULT NULL,
    p_index_type IN VARCHAR2 DEFAULT NULL
) RETURN SYS.ODCIVARCHAR2LIST PIPELINED
IS
    v_schema_name VARCHAR2(128);
    
BEGIN
    -- Set default schema if not provided
    IF p_schema_name IS NULL THEN
        SELECT USER INTO v_schema_name FROM dual;
    ELSE
        v_schema_name := UPPER(p_schema_name);
    END IF;
    
    FOR rec IN (
        SELECT 
            'DROP INDEX ' || i.owner || '.' || i.index_name || ';' AS drop_statement
        FROM all_indexes i
        LEFT JOIN all_constraints c ON i.owner = c.owner 
                                   AND i.index_name = c.constraint_name
        WHERE i.owner = v_schema_name
            AND (p_table_name IS NULL OR i.table_name = UPPER(p_table_name))
            AND (p_index_type IS NULL OR i.index_type = UPPER(p_index_type))
            AND i.index_type != 'LOB'
            AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes
        ORDER BY i.table_name, i.index_name
    ) LOOP
        PIPE ROW(rec.drop_statement);
    END LOOP;
    
    RETURN;
END fn_get_drop_statements;
/

-- Function to generate CREATE statements
CREATE OR REPLACE FUNCTION fn_get_create_statements (
    p_schema_name IN VARCHAR2 DEFAULT NULL,
    p_table_name IN VARCHAR2 DEFAULT NULL,
    p_index_type IN VARCHAR2 DEFAULT NULL
) RETURN SYS.ODCIVARCHAR2LIST PIPELINED
IS
    v_schema_name VARCHAR2(128);
    v_sql VARCHAR2(4000);
    
BEGIN
    -- Set default schema if not provided
    IF p_schema_name IS NULL THEN
        SELECT USER INTO v_schema_name FROM dual;
    ELSE
        v_schema_name := UPPER(p_schema_name);
    END IF;
    
    FOR rec IN (
        SELECT 
            i.owner,
            i.table_name,
            i.index_name,
            i.index_type,
            i.uniqueness,
            i.tablespace_name,
            i.compression,
            CASE WHEN i.degree = 'DEFAULT' THEN '1' ELSE i.degree END AS degree,
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
            AND i.index_type != 'LOB'
            AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes
        ORDER BY i.table_name, i.index_name
    ) LOOP
        v_sql := 'CREATE ';
        
        -- Add UNIQUE if applicable
        IF rec.uniqueness = 'UNIQUE' THEN
            v_sql := v_sql || 'UNIQUE ';
        END IF;
        
        -- Add BITMAP if applicable
        IF rec.index_type = 'BITMAP' THEN
            v_sql := v_sql || 'BITMAP ';
        END IF;
        
        v_sql := v_sql || 'INDEX ' || rec.owner || '.' || rec.index_name || 
                 ' ON ' || rec.owner || '.' || rec.table_name || 
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
        IF TO_NUMBER(rec.degree) > 1 THEN
            v_sql := v_sql || ' PARALLEL ' || rec.degree;
        END IF;
        
        v_sql := v_sql || ';';
        
        PIPE ROW(v_sql);
    END LOOP;
    
    RETURN;
END fn_get_create_statements;
/

-- Example usage queries:
/*
-- 1. Get detailed index report for current schema
SELECT * FROM TABLE(fn_get_index_report());

-- 2. Get detailed index report for specific schema
SELECT * FROM TABLE(fn_get_index_report('ENTITYDEV'));

-- 3. Get summary report
SELECT * FROM TABLE(fn_get_index_summary('ENTITYDEV'));

-- 4. Get DROP statements for all indexes (copy and run before ETL)
SELECT * FROM TABLE(fn_get_drop_statements('ENTITYDEV'));

-- 5. Get CREATE statements for all indexes (copy and run after ETL)
SELECT * FROM TABLE(fn_get_create_statements('ENTITYDEV'));

-- 6. Get indexes for specific table
SELECT * FROM TABLE(fn_get_index_report('ENTITYDEV', 'YOUR_TABLE_NAME'));

-- 7. Get only normal indexes
SELECT * FROM TABLE(fn_get_index_report('ENTITYDEV', NULL, 'NORMAL'));

-- 8. Count indexes by type
SELECT 
    index_type,
    COUNT(*) as count
FROM TABLE(fn_get_index_report('ENTITYDEV'))
GROUP BY index_type
ORDER BY count DESC;
*/
