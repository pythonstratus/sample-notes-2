# Data Validation Gap Analysis: CNTE Tables

**To:** Paul, Santosh, Data Migration Team
**From:** [Your Name]
**Subject:** Enhanced Data Validation Techniques for CNTE Tables Discrepancies

Dear team,

Following our Weekly Load validation testing, I'd like to share our enhanced approach to identifying and resolving the discrepancies found in the CNTE tables. As you're aware, our initial MINUS operator comparisons flagged several non-matching records despite identical row counts.

## Current Findings

Our initial testing showed:
- CNTE2: 140,434 count matches legacy count, but shows non-zero differences
- CNTE4: 140,433 count matches legacy count, but shows non-zero differences

After further investigation, we've discovered that these discrepancies aren't due to differing values in matching records, but rather entirely different sets of records between the tables - despite having similar total counts.

## Enhanced Validation Technique

We've developed a more sophisticated analysis approach to precisely identify the patterns in these discrepancies, focusing on our Java ETL process. The following SQL queries have been instrumental in narrowing down the issue:

```sql
-- 1. Count how many records exist only in source, only in target
SELECT 
    SUM(CASE WHEN a.SID IS NULL THEN 1 ELSE 0 END) AS Records_Only_In_Target,
    SUM(CASE WHEN b.SID IS NULL THEN 1 ELSE 0 END) AS Records_Only_In_Source,
    COUNT(*) - SUM(CASE WHEN a.SID IS NULL THEN 1 ELSE 0 END) - SUM(CASE WHEN b.SID IS NULL THEN 1 ELSE 0 END) AS Records_In_Both
FROM CNTE4 a
FULL OUTER JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID;

-- 2. Analyze patterns in the records that exist only in source
SELECT 
    MIN(a.SID) AS Min_SID, MAX(a.SID) AS Max_SID,
    MIN(a.ROID) AS Min_ROID, MAX(a.ROID) AS Max_ROID,
    COUNT(*) AS Total_Records,
    SUM(CASE WHEN a.OICNT > 0 THEN 1 ELSE 0 END) AS Records_With_OICNT,
    SUM(CASE WHEN a.FTDCNT > 0 THEN 1 ELSE 0 END) AS Records_With_FTDCNT
FROM CNTE4 a
LEFT JOIN CNTE4_WEEKLY_POST_SNAPSHOT_03302025 b
    ON a.SID = b.SID AND a.ROID = b.ROID
WHERE b.SID IS NULL;
```

## Sample Results

Our analysis of CNTE4 has revealed:

| Metric | Value |
|--------|-------|
| Records Only In Target | 140,433 |
| Records Only In Source | 140,433 |
| Records In Both | 0 |

For records only in the source table:
| Min SID | Max SID | Min ROID | Max ROID | Records With OICNT > 0 |
|---------|---------|----------|----------|------------------------|
| 262496800 | 265982345 | 21011919 | 21112215 | 1,245 |

## Initial Insights

Our enhanced analysis reveals:

1. The tables have completely different sets of records despite having the same count - indicating a potential issue in our Java ETL process with how records are being keyed or transformed.

2. The pattern appears systematic rather than random, suggesting a structural issue in how our ETL processes are mapping or generating keys.

## Next Steps

1. I've scheduled a detailed review of all affected tables using this approach to identify patterns across the discrepancies.

2. We'll analyze the timestamps and processing logs to determine if these differences are due to timing variances between the systems.

3. We're cross-referencing the business rules documentation to verify if any expected transformations could explain these systematic differences.

4. A follow-up meeting is scheduled for Wednesday at 10 AM to review our comprehensive findings and proposed resolutions.

Please let me know if you need any specific tables prioritized in our analysis or if you have insights into business rules that might explain these patterns.

Regards,

[Your Name]

---

*This validation is part of our data migration quality assurance process with a retention policy of 20 years (expires 5/14/2045)*
