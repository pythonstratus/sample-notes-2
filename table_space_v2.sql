-- 1. Check Your Own Objects and Tablespaces
SELECT 
    tablespace_name,
    COUNT(*) as object_count,
    ROUND(SUM(bytes)/1024/1024, 2) as total_size_mb
FROM user_segments
GROUP BY tablespace_name
ORDER BY total_size_mb DESC;

-- 2. Your Objects by Tablespace (Most Detailed for Regular Users)
SELECT 
    tablespace_name,
    segment_name,
    segment_type,
    ROUND(bytes/1024/1024, 2) as size_mb,
    blocks,
    extents
FROM user_segments
ORDER BY tablespace_name, bytes DESC;

-- 3. Using V$ Views (Usually Accessible to Most Users)
-- Tablespace Free Space Information
SELECT 
    tablespace_name,
    ROUND(SUM(bytes)/1024/1024, 2) as free_space_mb
FROM v$tempfile
WHERE tablespace_name IS NOT NULL
GROUP BY tablespace_name
UNION ALL
SELECT 
    ts.name as tablespace_name,
    ROUND(SUM(df.bytes)/1024/1024, 2) as total_space_mb
FROM v$tablespace ts, v$datafile df
WHERE ts.ts# = df.ts#
GROUP BY ts.name;

-- 4. Current Session Tablespace Usage
SELECT 
    username,
    default_tablespace,
    temporary_tablespace
FROM user_users;

-- 5. Check Tablespace Quotas (What you're allowed to use)
SELECT 
    tablespace_name,
    CASE 
        WHEN max_bytes = -1 THEN 'UNLIMITED'
        ELSE ROUND(max_bytes/1024/1024, 2) || ' MB'
    END as quota,
    ROUND(bytes/1024/1024, 2) as used_mb,
    CASE 
        WHEN max_bytes = -1 THEN 0
        ELSE ROUND((bytes/max_bytes)*100, 2)
    END as quota_used_percent
FROM user_ts_quotas
ORDER BY tablespace_name;

-- 6. Alternative Approach Using ALL_ Views (if you have access)
-- Check what tablespaces exist
SELECT DISTINCT tablespace_name
FROM all_segments
ORDER BY tablespace_name;

-- 7. Your Tables and Their Tablespace Usage
SELECT 
    table_name,
    tablespace_name,
    num_rows,
    blocks,
    avg_row_len,
    ROUND((num_rows * avg_row_len)/1024/1024, 2) as estimated_size_mb
FROM user_tables
WHERE tablespace_name IS NOT NULL
ORDER BY estimated_size_mb DESC NULLS LAST;

-- 8. Your Indexes and Their Tablespace Usage
SELECT 
    index_name,
    table_name,
    tablespace_name,
    leaf_blocks,
    distinct_keys,
    clustering_factor
FROM user_indexes
WHERE tablespace_name IS NOT NULL
ORDER BY leaf_blocks DESC;

-- 9. Basic System Information (Usually Available)
SELECT 
    name,
    value
FROM v$parameter
WHERE name IN ('db_block_size', 'db_name', 'instance_name');

-- 10. Check for Temporary Tablespace Usage (Current Session)
SELECT 
    tablespace,
    segtype,
    blocks,
    ROUND(blocks * (SELECT value FROM v$parameter WHERE name = 'db_block_size') / 1024 / 1024, 2) as size_mb
FROM v$tempseg_usage
WHERE session_addr = (SELECT saddr FROM v$session WHERE sid = (SELECT sid FROM v$mystat WHERE rownum = 1));

-- 11. General Database Information
SELECT 
    name as database_name,
    platform_name,
    open_mode,
    database_role
FROM v$database;

-- 12. Check Available Tablespaces via ALL_TABLESPACES (if accessible)
SELECT 
    tablespace_name,
    status,
    contents,
    logging,
    extent_management
FROM all_tablespaces
ORDER BY tablespace_name;

-- 13. Find Your Largest Objects Across All Tablespaces
SELECT 
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes/1024/1024, 2) as size_mb,
    extents,
    blocks
FROM user_segments
WHERE bytes > 1048576  -- Objects larger than 1MB
ORDER BY bytes DESC;

-- 14. Check Table and Index Growth Potential
SELECT 
    'TABLE' as object_type,
    table_name as object_name,
    tablespace_name,
    num_rows,
    blocks,
    ROUND(blocks * 8192 / 1024 / 1024, 2) as current_size_mb  -- Assuming 8K block size
FROM user_tables
WHERE num_rows > 0
UNION ALL
SELECT 
    'INDEX' as object_type,
    index_name as object_name,
    tablespace_name,
    leaf_blocks as num_rows,
    leaf_blocks as blocks,
    ROUND(leaf_blocks * 8192 / 1024 / 1024, 2) as current_size_mb
FROM user_indexes
WHERE leaf_blocks > 0
ORDER BY current_size_mb DESC;

-- 15. If You Have Access to Resource Limits
SELECT 
    resource_name,
    current_utilization,
    max_utilization,
    initial_allocation,
    limit_value
FROM v$resource_limit
WHERE resource_name LIKE '%TABLESPACE%' OR resource_name LIKE '%SPACE%';

-- 16. Simple Space Check for Your Schema
SELECT 
    'Total Objects' as metric,
    COUNT(*) as value,
    '' as unit
FROM user_objects
UNION ALL
SELECT 
    'Total Size (MB)' as metric,
    ROUND(SUM(bytes)/1024/1024, 2) as value,
    'MB' as unit
FROM user_segments
UNION ALL
SELECT 
    'Number of Tablespaces Used' as metric,
    COUNT(DISTINCT tablespace_name) as value,
    '' as unit
FROM user_segments
WHERE tablespace_name IS NOT NULL;

-- 17. Emergency Space Check (Minimal Privileges Required)
-- This should work even with very limited privileges
SELECT 
    tablespace_name,
    segment_type,
    COUNT(*) as object_count,
    ROUND(SUM(bytes)/1024/1024, 2) as total_mb
FROM user_segments
GROUP BY tablespace_name, segment_type
ORDER BY tablespace_name, total_mb DESC;
