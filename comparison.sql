-- 1. JOIN-based comparison to show side-by-side differences
-- This shows matching records with different values
SELECT 
    a.*, b.*
FROM CNTE4 a
JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE 
    a.OICNT <> b.OICNT OR 
    a.FTDCNT <> b.FTDCNT OR
    a.OICCNT <> b.OICCNT OR
    a.NIDRSCNT <> b.NIDRSCNT;

-- 2. Identify records only in source table with NULL placeholders for missing columns
-- This shows what exists in table A but not B with column details
SELECT 
    a.SID, a.ROID, a.OICNT, a.FTDCNT, a.OICCNT, a.NIDRSCNT,
    'Only in Source' AS Record_Status
FROM CNTE4 a
LEFT JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE b.SID IS NULL
UNION ALL
SELECT 
    b.SID, b.ROID, b.OICNT, b.FTDCNT, b.OICCNT, b.NIDRSCNT,
    'Only in Target' AS Record_Status
FROM CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
LEFT JOIN CNTE4 a
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE a.SID IS NULL;

-- 3. Hash-based comparison to identify all differences
-- Useful for tables with many columns
SELECT 
    CASE 
        WHEN a.hash_value IS NULL THEN 'Only in Target'
        WHEN b.hash_value IS NULL THEN 'Only in Source'
        ELSE 'Different Values'
    END AS Difference_Type,
    COALESCE(a.SID, b.SID) AS SID,
    COALESCE(a.ROID, b.ROID) AS ROID,
    a.OICNT AS Source_OICNT, 
    b.OICNT AS Target_OICNT,
    a.FTDCNT AS Source_FTDCNT, 
    b.FTDCNT AS Target_FTDCNT
FROM 
    (SELECT SID, ROID, OICNT, FTDCNT, OICCNT, NIDRSCNT,
        HASHBYTES('SHA2_256', CONCAT(SID, ROID, OICNT, FTDCNT, OICCNT, NIDRSCNT)) AS hash_value
     FROM CNTE4) a
FULL OUTER JOIN 
    (SELECT SID, ROID, OICNT, FTDCNT, OICCNT, NIDRSCNT,
        HASHBYTES('SHA2_256', CONCAT(SID, ROID, OICNT, FTDCNT, OICCNT, NIDRSCNT)) AS hash_value
     FROM CNTE4_WEEKLY_POST_SNAPSHOT_03302025) b
ON a.SID = b.SID AND a.ROID = b.ROID
WHERE a.hash_value <> b.hash_value OR a.hash_value IS NULL OR b.hash_value IS NULL;

-- 4. Column-by-column comparison with detailed difference reporting
-- Shows which specific columns differ for each record
SELECT
    a.SID, a.ROID,
    CASE WHEN a.OICNT <> b.OICNT THEN 'Different' ELSE 'Same' END AS OICNT_Status,
    a.OICNT AS Source_OICNT, b.OICNT AS Target_OICNT,
    CASE WHEN a.FTDCNT <> b.FTDCNT THEN 'Different' ELSE 'Same' END AS FTDCNT_Status,
    a.FTDCNT AS Source_FTDCNT, b.FTDCNT AS Target_FTDCNT,
    CASE WHEN a.OICCNT <> b.OICCNT THEN 'Different' ELSE 'Same' END AS OICCNT_Status,
    a.OICCNT AS Source_OICCNT, b.OICCNT AS Target_OICCNT,
    CASE WHEN a.NIDRSCNT <> b.NIDRSCNT THEN 'Different' ELSE 'Same' END AS NIDRSCNT_Status,
    a.NIDRSCNT AS Source_NIDRSCNT, b.NIDRSCNT AS Target_NIDRSCNT
FROM CNTE4 a
JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE 
    a.OICNT <> b.OICNT OR 
    a.FTDCNT <> b.FTDCNT OR
    a.OICCNT <> b.OICCNT OR
    a.NIDRSCNT <> b.NIDRSCNT;

-- 5. Statistical comparison to understand patterns in differences
-- Helps identify systematic issues
SELECT
    'OICNT' AS Column_Name,
    AVG(ABS(a.OICNT - b.OICNT)) AS Avg_Difference,
    MAX(ABS(a.OICNT - b.OICNT)) AS Max_Difference,
    COUNT(*) AS Records_With_Differences
FROM CNTE4 a
JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE a.OICNT <> b.OICNT
UNION ALL
SELECT
    'FTDCNT' AS Column_Name,
    AVG(ABS(a.FTDCNT - b.FTDCNT)) AS Avg_Difference,
    MAX(ABS(a.FTDCNT - b.FTDCNT)) AS Max_Difference,
    COUNT(*) AS Records_With_Differences
FROM CNTE4 a
JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE a.FTDCNT <> b.FTDCNT;

-- 6. Sample of differences using window functions
-- Gets a representative sample of different records
WITH DiffRecords AS (
    SELECT 
        a.SID, a.ROID, 
        a.OICNT AS Source_OICNT, b.OICNT AS Target_OICNT,
        a.FTDCNT AS Source_FTDCNT, b.FTDCNT AS Target_FTDCNT,
        ROW_NUMBER() OVER (PARTITION BY 
            CASE WHEN a.OICNT <> b.OICNT THEN 1 ELSE 0 END,
            CASE WHEN a.FTDCNT <> b.FTDCNT THEN 1 ELSE 0 END,
            CASE WHEN a.OICCNT <> b.OICCNT THEN 1 ELSE 0 END,
            CASE WHEN a.NIDRSCNT <> b.NIDRSCNT THEN 1 ELSE 0 END
        ORDER BY a.SID) AS rn
    FROM CNTE4 a
    JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
        ON a.SID = b.SID AND a.ROID = b.ROID
    WHERE 
        a.OICNT <> b.OICNT OR 
        a.FTDCNT <> b.FTDCNT OR
        a.OICCNT <> b.OICCNT OR
        a.NIDRSCNT <> b.NIDRSCNT
)
SELECT * FROM DiffRecords WHERE rn <= 10;
