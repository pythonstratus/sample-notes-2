-- =====================================================
-- TRANTRAIL DATA EXTRACTION QUERIES
-- Purpose: Extract 300-400 records from different Areas/Orgs
-- =====================================================

-- OPTION 1: STRATIFIED SAMPLING BY ROID (Primary Approach) - FIXED
-- This ensures representation across different Regional Offices
WITH org_counts AS (
    SELECT ROID, COUNT(*) as total_records
    FROM ENTITYDEV.TRANTRAIL 
    WHERE EXTRDT IS NOT NULL 
      AND STATUS IS NOT NULL
      AND ROID IS NOT NULL
    GROUP BY ROID
    HAVING COUNT(*) > 5  -- Only include orgs with meaningful data
),
sample_per_org AS (
    SELECT ROID, 
           CASE 
               WHEN total_records >= 50 THEN 20  -- Large orgs: 20 records each
               WHEN total_records >= 20 THEN 15  -- Medium orgs: 15 records each  
               ELSE 10                           -- Small orgs: 10 records each
           END as sample_size
    FROM org_counts
),
ranked_records AS (
    SELECT t.*, 
           ROW_NUMBER() OVER (
               PARTITION BY t.ROID 
               ORDER BY t.EXTRDT DESC, t.INITDT DESC, DBMS_RANDOM.VALUE
           ) as rn
    FROM ENTITYDEV.TRANTRAIL t
    INNER JOIN sample_per_org s ON t.ROID = s.ROID
    WHERE t.EXTRDT IS NOT NULL 
      AND t.STATUS IS NOT NULL
      AND t.ROID IS NOT NULL
)
SELECT *
FROM ranked_records r
INNER JOIN sample_per_org s ON r.ROID = s.ROID
WHERE r.rn <= s.sample_size
ORDER BY r.ROID, r.EXTRDT DESC;

-- =====================================================

-- OPTION 2: GEOGRAPHIC DIVERSITY BY ZIPCDE REGIONS
-- Groups zipcodes into regions and samples from each
WITH zipcode_regions AS (
    SELECT ZIPCDE,
           CASE 
               WHEN ZIPCDE BETWEEN 1000 AND 19999 THEN 'Northeast'
               WHEN ZIPCDE BETWEEN 20000 AND 39999 THEN 'Southeast' 
               WHEN ZIPCDE BETWEEN 40000 AND 59999 THEN 'Midwest'
               WHEN ZIPCDE BETWEEN 60000 AND 79999 THEN 'Central'
               WHEN ZIPCDE BETWEEN 80000 AND 99999 THEN 'West'
               ELSE 'Other'
           END as region,
           COUNT(*) as region_count
    FROM ENTITYDEV.TRANTRAIL 
    WHERE ZIPCDE > 0 AND EXTRDT IS NOT NULL
    GROUP BY ZIPCDE,
           CASE 
               WHEN ZIPCDE BETWEEN 1000 AND 19999 THEN 'Northeast'
               WHEN ZIPCDE BETWEEN 20000 AND 39999 THEN 'Southeast' 
               WHEN ZIPCDE BETWEEN 40000 AND 59999 THEN 'Midwest'
               WHEN ZIPCDE BETWEEN 60000 AND 79999 THEN 'Central'
               WHEN ZIPCDE BETWEEN 80000 AND 99999 THEN 'West'
               ELSE 'Other'
           END
),
regional_sample AS (
    SELECT t.*,
           zr.region,
           ROW_NUMBER() OVER (
               PARTITION BY zr.region 
               ORDER BY t.EXTRDT DESC, DBMS_RANDOM.VALUE
           ) as regional_rank
    FROM ENTITYDEV.TRANTRAIL t
    INNER JOIN zipcode_regions zr ON t.ZIPCDE = zr.ZIPCDE
    WHERE t.EXTRDT IS NOT NULL 
      AND t.STATUS IS NOT NULL
      AND zr.region != 'Other'
)
SELECT *
FROM regional_sample
WHERE regional_rank <= 80  -- 80 records per region = ~400 total
ORDER BY region, EXTRDT DESC;

-- =====================================================

-- OPTION 3: MULTI-DIMENSIONAL DIVERSITY SAMPLING (FIXED)
-- Combines ROID, ZIPCDE regions, and STATUS for maximum diversity
WITH valid_zipcodes AS (
    -- First, clean and validate ZIP codes
    SELECT *
    FROM ENTITYDEV.TRANTRAIL 
    WHERE ZIPCDE BETWEEN 1000 AND 99999  -- Valid US ZIP range only
      AND EXTRDT IS NOT NULL 
      AND STATUS IS NOT NULL
),
diversity_matrix AS (
    SELECT ROID,
           CASE 
               WHEN ZIPCDE BETWEEN 1000 AND 19999 THEN 'NE'
               WHEN ZIPCDE BETWEEN 20000 AND 39999 THEN 'SE' 
               WHEN ZIPCDE BETWEEN 40000 AND 59999 THEN 'MW'
               WHEN ZIPCDE BETWEEN 60000 AND 79999 THEN 'CN'
               WHEN ZIPCDE BETWEEN 80000 AND 99999 THEN 'WE'
               ELSE 'OT'
           END as geo_region,
           STATUS,
           COUNT(*) as combination_count
    FROM valid_zipcodes
    GROUP BY ROID,
           CASE 
               WHEN ZIPCDE BETWEEN 1000 AND 19999 THEN 'NE'
               WHEN ZIPCDE BETWEEN 20000 AND 39999 THEN 'SE' 
               WHEN ZIPCDE BETWEEN 40000 AND 59999 THEN 'MW'
               WHEN ZIPCDE BETWEEN 60000 AND 79999 THEN 'CN'
               WHEN ZIPCDE BETWEEN 80000 AND 99999 THEN 'WE'
               ELSE 'OT'
           END,
           STATUS
    HAVING COUNT(*) >= 3  -- Only meaningful combinations
),
diverse_sample AS (
    SELECT t.*,
           dm.geo_region,
           ROW_NUMBER() OVER (
               PARTITION BY t.ROID, dm.geo_region, t.STATUS 
               ORDER BY t.EXTRDT DESC, t.LSTTOUCH DESC, DBMS_RANDOM.VALUE
           ) as diversity_rank
    FROM valid_zipcodes t
    INNER JOIN diversity_matrix dm ON t.ROID = dm.ROID 
                                   AND t.STATUS = dm.STATUS
                                   AND CASE 
                                           WHEN t.ZIPCDE BETWEEN 1000 AND 19999 THEN 'NE'
                                           WHEN t.ZIPCDE BETWEEN 20000 AND 39999 THEN 'SE' 
                                           WHEN t.ZIPCDE BETWEEN 40000 AND 59999 THEN 'MW'
                                           WHEN t.ZIPCDE BETWEEN 60000 AND 79999 THEN 'CN'
                                           WHEN t.ZIPCDE BETWEEN 80000 AND 99999 THEN 'WE'
                                           ELSE 'OT'
                                       END = dm.geo_region
)
SELECT *
FROM diverse_sample
WHERE diversity_rank <= 5  -- Up to 5 records per unique combination
ORDER BY ROID, geo_region, STATUS, EXTRDT DESC
FETCH FIRST 400 ROWS ONLY;

-- =====================================================

-- OPTION 4: TIME-BASED STRATIFIED SAMPLING
-- Ensures temporal diversity across different periods (Fixed Oracle compatibility)
WITH time_strata AS (
    SELECT 
        EXTRACT(YEAR FROM EXTRDT) as extract_year,
        CEIL(EXTRACT(MONTH FROM EXTRDT)/3) as extract_quarter,  -- Calculate quarter manually
        ROID,
        COUNT(*) as period_count
    FROM ENTITYDEV.TRANTRAIL 
    WHERE EXTRDT IS NOT NULL 
      AND EXTRDT >= ADD_MONTHS(SYSDATE, -24)  -- Last 2 years
    GROUP BY EXTRACT(YEAR FROM EXTRDT), CEIL(EXTRACT(MONTH FROM EXTRDT)/3), ROID
    HAVING COUNT(*) >= 2
),
temporal_sample AS (
    SELECT t.*,
           ts.extract_year,
           ts.extract_quarter,
           ROW_NUMBER() OVER (
               PARTITION BY ts.extract_year, ts.extract_quarter, t.ROID 
               ORDER BY t.EXTRDT DESC, t.HRS DESC, DBMS_RANDOM.VALUE
           ) as temporal_rank
    FROM ENTITYDEV.TRANTRAIL t
    INNER JOIN time_strata ts ON t.ROID = ts.ROID 
                              AND EXTRACT(YEAR FROM t.EXTRDT) = ts.extract_year
                              AND CEIL(EXTRACT(MONTH FROM t.EXTRDT)/3) = ts.extract_quarter
    WHERE t.EXTRDT IS NOT NULL 
      AND t.STATUS IS NOT NULL
)
SELECT *
FROM temporal_sample
WHERE temporal_rank <= 8  -- 8 records per quarter per org
ORDER BY extract_year DESC, extract_quarter DESC, ROID, EXTRDT DESC
FETCH FIRST 350 ROWS ONLY;

-- =====================================================

-- OPTION 5: BUSINESS VALIDATION FOCUSED QUERY
-- Prioritizes records with complete data for validation
SELECT *
FROM (
    SELECT t.*,
           ROW_NUMBER() OVER (
               PARTITION BY t.ROID 
               ORDER BY 
                   CASE WHEN t.CLOSEDT IS NOT NULL THEN 1 ELSE 2 END,  -- Completed records first
                   t.HRS DESC,                                          -- Higher activity first
                   t.TOUCH DESC,                                        -- More interactions first
                   t.EXTRDT DESC                                        -- Recent first
           ) as validation_rank
    FROM ENTITYDEV.TRANTRAIL t
    WHERE t.EXTRDT IS NOT NULL 
      AND t.STATUS IS NOT NULL
      AND t.ROID IS NOT NULL
      AND t.TINSID IS NOT NULL
      AND t.HRS > 0                    -- Must have actual work hours
      AND t.NAICSCD IS NOT NULL        -- Must have industry classification
      AND (t.EMPTOUCH > 0 OR t.EMPHRS > 0)  -- Must have employee involvement
) ranked_validation
WHERE validation_rank <= 25  -- 25 records per organization
ORDER BY ROID, validation_rank
FETCH FIRST 400 ROWS ONLY;

-- =====================================================

-- SUMMARY QUERY: Check diversity of selected sample
-- Run this after your main query to validate diversity
SELECT 
    'ROID Distribution' as metric,
    COUNT(DISTINCT ROID) as unique_values,
    COUNT(*) as total_records
FROM your_selected_sample
UNION ALL
SELECT 
    'Geographic Distribution',
    COUNT(DISTINCT ZIPCDE),
    COUNT(*)
FROM your_selected_sample
UNION ALL  
SELECT 
    'Status Distribution',
    COUNT(DISTINCT STATUS),
    COUNT(*)
FROM your_selected_sample
UNION ALL
SELECT 
    'Industry Distribution',
    COUNT(DISTINCT NAICSCD),
    COUNT(*)
FROM your_selected_sample
WHERE NAICSCD IS NOT NULL;
