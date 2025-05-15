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

These findings indicate records with the same count but different content - suggesting either different records or varied field values between our Modern Exadata tables and the Post tables.

## Enhanced Validation Technique

To precisely identify the nature of these discrepancies, we've implemented a detailed column-by-column comparison approach as shown below:

```sql
-- Column-by-column comparison with detailed difference reporting
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
```

## Sample Results

Here's a sample of what our analysis is revealing for CNTE4:

| SID | ROID | OICNT_Status | Source_OICNT | Target_OICNT | FTDCNT_Status | Source_FTDCNT | Target_FTDCNT |
|-----|------|--------------|--------------|--------------|---------------|---------------|---------------|
| 262496835 | 21012130 | Different | 1 | 0 | Same | 0 | 0 |
| 262496837 | 21012191 | Different | 1 | 0 | Same | 0 | 0 |
| 262496838 | 21012191 | Different | 1 | 0 | Same | 0 | 0 |

## Initial Insights

Our enhanced analysis reveals:

1. The primary discrepancies in CNTE4 appear to be in the OICNT column, where values are 1 in our source table but 0 in the target snapshot.

2. These differences are consistent and systematic rather than random, suggesting a potential business rule or transformation issue rather than data corruption.

3. The pattern may indicate:
   - A timing issue where counts were updated after the snapshot was taken
   - A business rule change in how these counts are calculated
   - A data transformation rule difference between environments

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
