-- 1. Count how many records exist only in source, only in target
SELECT 
    SUM(CASE WHEN a.SID IS NULL THEN 1 ELSE 0 END) AS Records_Only_In_Target,
    SUM(CASE WHEN b.SID IS NULL THEN 1 ELSE 0 END) AS Records_Only_In_Source,
    COUNT(*) - SUM(CASE WHEN a.SID IS NULL THEN 1 ELSE 0 END) - SUM(CASE WHEN b.SID IS NULL THEN 1 ELSE 0 END) AS Records_In_Both
FROM CNTE4 a
FULL OUTER JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID;

-- 2. Analyze patterns in the records that exist only in one table
-- For records only in source:
SELECT 
    MIN(a.SID) AS Min_SID, MAX(a.SID) AS Max_SID,
    MIN(a.ROID) AS Min_ROID, MAX(a.ROID) AS Max_ROID,
    COUNT(*) AS Total_Records,
    SUM(CASE WHEN a.OICNT > 0 THEN 1 ELSE 0 END) AS Records_With_OICNT,
    SUM(CASE WHEN a.FTDCNT > 0 THEN 1 ELSE 0 END) AS Records_With_FTDCNT,
    SUM(CASE WHEN a.OICCNT > 0 THEN 1 ELSE 0 END) AS Records_With_OICCNT,
    SUM(CASE WHEN a.NIDRSCNT > 0 THEN 1 ELSE 0 END) AS Records_With_NIDRSCNT
FROM CNTE4 a
LEFT JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE b.SID IS NULL;

-- 3. Same analysis for records only in target
SELECT 
    MIN(b.SID) AS Min_SID, MAX(b.SID) AS Max_SID,
    MIN(b.ROID) AS Min_ROID, MAX(b.ROID) AS Max_ROID,
    COUNT(*) AS Total_Records,
    SUM(CASE WHEN b.OICNT > 0 THEN 1 ELSE 0 END) AS Records_With_OICNT,
    SUM(CASE WHEN b.FTDCNT > 0 THEN 1 ELSE 0 END) AS Records_With_FTDCNT,
    SUM(CASE WHEN b.OICCNT > 0 THEN 1 ELSE 0 END) AS Records_With_OICCNT,
    SUM(CASE WHEN b.NIDRSCNT > 0 THEN 1 ELSE 0 END) AS Records_With_NIDRSCNT
FROM CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
LEFT JOIN CNTE4 a
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE a.SID IS NULL;

-- 4. Look for patterns in the SID and ROID values that might explain the differences
SELECT 
    'Only in Source' AS Location,
    CAST(ROID/1000 AS INT)*1000 AS ROID_Range,
    COUNT(*) AS Record_Count
FROM CNTE4 a
LEFT JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE b.SID IS NULL
GROUP BY CAST(ROID/1000 AS INT)*1000
UNION ALL
SELECT 
    'Only in Target' AS Location,
    CAST(ROID/1000 AS INT)*1000 AS ROID_Range,
    COUNT(*) AS Record_Count
FROM CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
LEFT JOIN CNTE4 a
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE a.SID IS NULL
GROUP BY CAST(ROID/1000 AS INT)*1000
ORDER BY ROID_Range, Location;

-- 5. Check for possible key mismatches by examining closest matches
-- This helps identify if there might be slight differences in keys
WITH SourceOnly AS (
    SELECT a.SID, a.ROID
    FROM CNTE4 a
    LEFT JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
        ON a.SID = b.SID AND a.ROID = b.ROID
    WHERE b.SID IS NULL
),
TargetOnly AS (
    SELECT b.SID, b.ROID
    FROM CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    LEFT JOIN CNTE4 a
        ON a.SID = b.SID AND a.ROID = b.ROID
    WHERE a.SID IS NULL
)
SELECT TOP 100
    s.SID AS Source_SID, s.ROID AS Source_ROID,
    t.SID AS Target_SID, t.ROID AS Target_ROID,
    ABS(s.SID - t.SID) AS SID_Difference,
    ABS(s.ROID - t.ROID) AS ROID_Difference
FROM SourceOnly s
CROSS JOIN TargetOnly t
WHERE ABS(s.SID - t.SID) < 10 OR ABS(s.ROID - t.ROID) < 10
ORDER BY ABS(s.SID - t.SID) + ABS(s.ROID - t.ROID);

-- 6. Count by differences in key components
-- This checks if there's a pattern to the differences in keys
SELECT
    s.SID - t.SID AS SID_Difference,
    s.ROID - t.ROID AS ROID_Difference,
    COUNT(*) AS Occurrence_Count
FROM SourceOnly s
CROSS JOIN TargetOnly t
WHERE ABS(s.SID - t.SID) < 100 AND ABS(s.ROID - t.ROID) < 100
GROUP BY s.SID - t.SID, s.ROID - t.ROID
HAVING COUNT(*) > 5
ORDER BY COUNT(*) DESC;
