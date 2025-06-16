-- Simple Oracle Index Report - No custom types needed
-- Creates views that can be queried directly

-- View 1: Detailed Index Report
CREATE OR REPLACE VIEW v_index_report AS
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
    i.clustering_factor,
    -- Get index columns using correlated subquery
    (SELECT LISTAGG(ic.column_name || 
           CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE '' END, ', ') 
           WITHIN GROUP (ORDER BY ic.column_position)
     FROM all_ind_columns ic 
     WHERE ic.index_owner = i.owner 
       AND ic.index_name = i.index_name) AS key_columns
FROM all_indexes i
LEFT JOIN all_constraints c ON i.owner = c.owner 
                           AND i.index_name = c.constraint_name
WHERE i.index_type != 'LOB'  -- Exclude LOB indexes
ORDER BY i.owner, i.table_name, i.index_name;

-- View 2: Index Summary by Table
CREATE OR REPLACE VIEW v_index_summary AS
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
    SUM(NVL(i.leaf_blocks, 0)) AS total_leaf_blocks,
    SUM(NVL(i.num_rows, 0)) AS total_rows
FROM all_indexes i
LEFT JOIN all_constraints c ON i.owner = c.owner 
                           AND i.index_name = c.constraint_name
WHERE i.index_type != 'LOB'
GROUP BY i.owner, i.table_name
ORDER BY i.owner, i.table_name;

-- View 3: DROP Index Statements
CREATE OR REPLACE VIEW v_drop_index_statements AS
SELECT 
    i.owner AS schema_name,
    i.table_name,
    i.index_name,
    i.index_type,
    'DROP INDEX ' || i.owner || '.' || i.index_name || ';' AS drop_statement
FROM all_indexes i
LEFT JOIN all_constraints c ON i.owner = c.owner 
                           AND i.index_name = c.constraint_name
WHERE i.index_type != 'LOB'
  AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes (PK, UK)
ORDER BY i.owner, i.table_name, i.index_name;

-- View 4: CREATE Index Statements  
CREATE OR REPLACE VIEW v_create_index_statements AS
SELECT 
    i.owner AS schema_name,
    i.table_name,
    i.index_name,
    i.index_type,
    i.uniqueness,
    -- Build CREATE statement
    'CREATE ' ||
    CASE WHEN i.uniqueness = 'UNIQUE' THEN 'UNIQUE ' ELSE '' END ||
    CASE WHEN i.index_type = 'BITMAP' THEN 'BITMAP ' ELSE '' END ||
    'INDEX ' || i.owner || '.' || i.index_name || 
    ' ON ' || i.owner || '.' || i.table_name || ' (' ||
    (SELECT LISTAGG(ic.column_name || 
           CASE WHEN ic.descend = 'DESC' THEN ' DESC' ELSE '' END, ', ') 
           WITHIN GROUP (ORDER BY ic.column_position)
     FROM all_ind_columns ic 
     WHERE ic.index_owner = i.owner 
       AND ic.index_name = i.index_name) || ')' ||
    CASE WHEN i.tablespace_name IS NOT NULL THEN ' TABLESPACE ' || i.tablespace_name ELSE '' END ||
    CASE WHEN i.compression = 'ENABLED' THEN ' COMPRESS' ELSE '' END ||
    CASE WHEN i.degree != 'DEFAULT' AND TO_NUMBER(i.degree) > 1 THEN ' PARALLEL ' || i.degree ELSE '' END ||
    ';' AS create_statement
FROM all_indexes i
LEFT JOIN all_constraints c ON i.owner = c.owner 
                           AND i.index_name = c.constraint_name
WHERE i.index_type != 'LOB'
  AND c.constraint_type IS NULL  -- Exclude constraint-backed indexes
ORDER BY i.owner, i.table_name, i.index_name;

-- Simple query functions using basic SQL (no custom types)
-- You can save these as scripts and run them with parameters

/*
=== USAGE EXAMPLES ===

-- 1. Get detailed index report for specific schema
SELECT * FROM v_index_report WHERE schema_name = 'ENTITYDEV';

-- 2. Get detailed index report for specific table
SELECT * FROM v_index_report 
WHERE schema_name = 'ENTITYDEV' 
  AND table_name = 'YOUR_TABLE_NAME';

-- 3. Get summary by table for specific schema
SELECT * FROM v_index_summary WHERE schema_name = 'ENTITYDEV';

-- 4. Get DROP statements for specific schema (COPY THESE BEFORE ETL)
SELECT drop_statement FROM v_drop_index_statements 
WHERE schema_name = 'ENTITYDEV'
ORDER BY table_name, index_name;

-- 5. Get CREATE statements for specific schema (COPY THESE AFTER ETL)
SELECT create_statement FROM v_create_index_statements 
WHERE schema_name = 'ENTITYDEV'
ORDER BY table_name, index_name;

-- 6. Count indexes by type for specific schema
SELECT 
    index_type,
    COUNT(*) as index_count
FROM v_index_report 
WHERE schema_name = 'ENTITYDEV'
GROUP BY index_type
ORDER BY index_count DESC;

-- 7. Find unusable indexes
SELECT schema_name, table_name, index_name, status
FROM v_index_report 
WHERE schema_name = 'ENTITYDEV'
  AND status = 'UNUSABLE';

-- 8. Get indexes for tables with most indexes
SELECT * FROM v_index_summary 
WHERE schema_name = 'ENTITYDEV'
  AND total_indexes > 5
ORDER BY total_indexes DESC;

-- 9. Find function-based indexes
SELECT * FROM v_index_report 
WHERE schema_name = 'ENTITYDEV'
  AND index_type LIKE 'FUNCTION%';

-- 10. Export DROP statements to a file (copy and save as .sql)
SELECT 'SPOOL drop_indexes.log' FROM dual
UNION ALL
SELECT drop_statement FROM v_drop_index_statements 
WHERE schema_name = 'ENTITYDEV'
UNION ALL
SELECT 'SPOOL OFF' FROM dual;

-- 11. Export CREATE statements to a file (copy and save as .sql)
SELECT 'SPOOL create_indexes.log' FROM dual
UNION ALL
SELECT create_statement FROM v_create_index_statements 
WHERE schema_name = 'ENTITYDEV'
UNION ALL
SELECT 'SPOOL OFF' FROM dual;

*/
