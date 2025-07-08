-- 1. Basic Tablespace Information
SELECT 
    tablespace_name,
    status,
    contents,
    logging,
    extent_management,
    allocation_type,
    segment_space_management,
    bigfile
FROM dba_tablespaces
ORDER BY tablespace_name;

-- 2. Tablespace Size and Usage Summary
SELECT 
    ts.tablespace_name,
    ROUND(ts.total_size_mb, 2) AS total_size_mb,
    ROUND(ts.total_size_mb / 1024, 2) AS total_size_gb,
    ROUND(fs.free_size_mb, 2) AS free_size_mb,
    ROUND(fs.free_size_mb / 1024, 2) AS free_size_gb,
    ROUND((ts.total_size_mb - fs.free_size_mb), 2) AS used_size_mb,
    ROUND(((ts.total_size_mb - fs.free_size_mb) / ts.total_size_mb) * 100, 2) AS used_percent,
    ROUND((fs.free_size_mb / ts.total_size_mb) * 100, 2) AS free_percent
FROM 
    (SELECT 
        tablespace_name,
        SUM(bytes) / 1024 / 1024 AS total_size_mb
     FROM dba_data_files
     GROUP BY tablespace_name
    ) ts
JOIN 
    (SELECT 
        tablespace_name,
        SUM(bytes) / 1024 / 1024 AS free_size_mb
     FROM dba_free_space
     GROUP BY tablespace_name
    ) fs ON ts.tablespace_name = fs.tablespace_name
ORDER BY used_percent DESC;

-- 3. Detailed Tablespace Usage with Alert Status
SELECT 
    tablespace_name,
    total_size_mb,
    used_size_mb,
    free_size_mb,
    used_percent,
    free_percent,
    CASE 
        WHEN used_percent >= 90 THEN 'CRITICAL'
        WHEN used_percent >= 80 THEN 'WARNING'
        WHEN used_percent >= 70 THEN 'CAUTION'
        ELSE 'OK'
    END AS status_alert
FROM (
    SELECT 
        ts.tablespace_name,
        ROUND(ts.total_size_mb, 2) AS total_size_mb,
        ROUND((ts.total_size_mb - NVL(fs.free_size_mb, 0)), 2) AS used_size_mb,
        ROUND(NVL(fs.free_size_mb, 0), 2) AS free_size_mb,
        ROUND(((ts.total_size_mb - NVL(fs.free_size_mb, 0)) / ts.total_size_mb) * 100, 2) AS used_percent,
        ROUND((NVL(fs.free_size_mb, 0) / ts.total_size_mb) * 100, 2) AS free_percent
    FROM 
        (SELECT 
            tablespace_name,
            SUM(bytes) / 1024 / 1024 AS total_size_mb
         FROM dba_data_files
         GROUP BY tablespace_name
        ) ts
    LEFT JOIN 
        (SELECT 
            tablespace_name,
            SUM(bytes) / 1024 / 1024 AS free_size_mb
         FROM dba_free_space
         GROUP BY tablespace_name
        ) fs ON ts.tablespace_name = fs.tablespace_name
)
ORDER BY used_percent DESC;

-- 4. Tablespace Data Files Information
SELECT 
    df.tablespace_name,
    df.file_name,
    df.file_id,
    ROUND(df.bytes / 1024 / 1024, 2) AS size_mb,
    ROUND(df.maxbytes / 1024 / 1024, 2) AS max_size_mb,
    df.autoextensible,
    df.status,
    df.online_status
FROM dba_data_files df
ORDER BY df.tablespace_name, df.file_id;

-- 5. Temporary Tablespace Information
SELECT 
    tf.tablespace_name,
    tf.file_name,
    ROUND(tf.bytes / 1024 / 1024, 2) AS size_mb,
    ROUND(tf.maxbytes / 1024 / 1024, 2) AS max_size_mb,
    tf.autoextensible,
    tf.status
FROM dba_temp_files tf
ORDER BY tf.tablespace_name;

-- 6. Tablespace Free Space Details
SELECT 
    tablespace_name,
    file_id,
    block_id,
    ROUND(bytes / 1024 / 1024, 2) AS free_space_mb,
    blocks
FROM dba_free_space
WHERE tablespace_name IN (
    SELECT tablespace_name 
    FROM dba_tablespaces 
    WHERE contents = 'PERMANENT'
)
ORDER BY tablespace_name, bytes DESC;

-- 7. Top Objects by Size in Each Tablespace
SELECT 
    tablespace_name,
    owner,
    segment_name,
    segment_type,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    extents
FROM (
    SELECT 
        tablespace_name,
        owner,
        segment_name,
        segment_type,
        bytes,
        extents,
        ROW_NUMBER() OVER (PARTITION BY tablespace_name ORDER BY bytes DESC) as rn
    FROM dba_segments
)
WHERE rn <= 5  -- Top 5 objects per tablespace
ORDER BY tablespace_name, bytes DESC;

-- 8. Tablespace Growth Monitoring (if you have AWR/Statspack history)
SELECT 
    snap_date,
    tablespace_name,
    total_size_mb,
    used_size_mb,
    free_size_mb,
    used_percent
FROM (
    SELECT 
        TO_DATE(TO_CHAR(s.begin_interval_time, 'YYYY-MM-DD'), 'YYYY-MM-DD') as snap_date,
        ts.tablespace_name,
        ROUND(SUM(ts.tablespace_size * dt.block_size) / 1024 / 1024, 2) as total_size_mb,
        ROUND(SUM(ts.tablespace_usedsize * dt.block_size) / 1024 / 1024, 2) as used_size_mb,
        ROUND(SUM((ts.tablespace_size - ts.tablespace_usedsize) * dt.block_size) / 1024 / 1024, 2) as free_size_mb,
        ROUND((SUM(ts.tablespace_usedsize * dt.block_size) / SUM(ts.tablespace_size * dt.block_size)) * 100, 2) as used_percent
    FROM dba_hist_tbspc_space_usage ts,
         dba_hist_snapshot s,
         dba_tablespaces dt
    WHERE ts.snap_id = s.snap_id
    AND ts.tablespace_name = dt.tablespace_name
    AND s.begin_interval_time >= SYSDATE - 30  -- Last 30 days
    GROUP BY TO_DATE(TO_CHAR(s.begin_interval_time, 'YYYY-MM-DD'), 'YYYY-MM-DD'), ts.tablespace_name
)
ORDER BY snap_date DESC, tablespace_name;

-- 9. Autoextend Information for Data Files
SELECT 
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024, 2) AS current_size_mb,
    ROUND(maxbytes / 1024 / 1024, 2) AS max_size_mb,
    ROUND((maxbytes - bytes) / 1024 / 1024, 2) AS can_grow_mb,
    autoextensible,
    ROUND(increment_by * (SELECT value FROM v$parameter WHERE name = 'db_block_size') / 1024 / 1024, 2) AS increment_mb
FROM dba_data_files
WHERE autoextensible = 'YES'
ORDER BY tablespace_name;

-- 10. Quick Tablespace Health Check
SELECT 
    tablespace_name,
    CASE 
        WHEN used_percent >= 95 THEN '🔴 CRITICAL - Immediate action required'
        WHEN used_percent >= 90 THEN '🟠 WARNING - Monitor closely'
        WHEN used_percent >= 80 THEN '🟡 CAUTION - Plan for expansion'
        WHEN used_percent >= 70 THEN '🟢 OK - Normal usage'
        ELSE '✅ EXCELLENT - Low usage'
    END AS health_status,
    CONCAT(used_percent, '%') AS usage_percentage,
    CONCAT(ROUND(free_size_mb/1024, 1), ' GB') AS free_space,
    CASE 
        WHEN autoextend_count > 0 THEN 'Can auto-extend'
        ELSE 'Fixed size'
    END AS extensibility
FROM (
    SELECT 
        ts.tablespace_name,
        ROUND(((ts.total_size_mb - NVL(fs.free_size_mb, 0)) / ts.total_size_mb) * 100, 1) AS used_percent,
        NVL(fs.free_size_mb, 0) AS free_size_mb,
        ae.autoextend_count
    FROM 
        (SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS total_size_mb
         FROM dba_data_files GROUP BY tablespace_name) ts
    LEFT JOIN 
        (SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS free_size_mb
         FROM dba_free_space GROUP BY tablespace_name) fs 
        ON ts.tablespace_name = fs.tablespace_name
    LEFT JOIN
        (SELECT tablespace_name, COUNT(*) AS autoextend_count
         FROM dba_data_files WHERE autoextensible = 'YES' 
         GROUP BY tablespace_name) ae
        ON ts.tablespace_name = ae.tablespace_name
)
ORDER BY used_percent DESC;
