-- ============================================================================
-- crzips.sql - ICS Zip Code Assignment Transformation Procedure
-- ============================================================================
-- Purpose: Transforms data from oldzips (staging) to icszips (production)
--          Applies business rules and constraint validation
--
-- Called by: ent_zip.csh (shell script) or ICS Zip Processor (Spring Boot)
-- 
-- Input:  oldzips table (populated by SQL*Loader or Spring Batch)
-- Output: icszips table (production-ready data)
--
-- TODO: Replace this template with your actual crzips procedure/script
-- ============================================================================

-- Set session parameters
SET ECHO OFF
SET FEEDBACK ON
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE 1000000

-- Log start
PROMPT ========== Starting crzips transformation ==========
PROMPT Timestamp: 
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;

-- ============================================================================
-- STEP 1: Backup or Drop existing icszips data (if needed)
-- ============================================================================
PROMPT Step 1: Preparing icszips table...

-- Option A: Truncate (faster, keeps structure)
-- TRUNCATE TABLE icszips;

-- Option B: Delete (slower, can rollback)
DELETE FROM icszips;

PROMPT Deleted existing records from icszips
PROMPT Rows deleted: 
SELECT SQL%ROWCOUNT FROM DUAL;

COMMIT;

-- ============================================================================
-- STEP 2: Data Validation (Optional)
-- ============================================================================
PROMPT Step 2: Validating data in oldzips...

-- Check for duplicate records
-- TODO: Add your validation logic
-- Example:
-- SELECT COUNT(*) 
-- FROM oldzips 
-- GROUP BY didocd, zipcode 
-- HAVING COUNT(*) > 1;

-- Check for invalid area codes
-- TODO: Add your validation
-- Example:
-- SELECT COUNT(*) 
-- FROM oldzips 
-- WHERE didocd NOT IN ('21','22','23','24','25','26','27','35');

-- ============================================================================
-- STEP 3: Transform and Load Data
-- ============================================================================
PROMPT Step 3: Loading data from oldzips to icszips...

-- TODO: Replace with your actual INSERT statement
-- This is a template - adjust columns based on your table structure

INSERT INTO icszips (
    didocd,
    zipcode,
    -- Add your additional columns here
    created_date,
    created_by
)
SELECT 
    didocd,
    zipcode,
    -- Add your additional column mappings here
    SYSDATE,
    'ICS_ZIP_PROCESSOR'
FROM oldzips
WHERE 1=1
    -- Add your business rule filters here
    -- Example: AND zipcode IS NOT NULL
    -- Example: AND didocd IN ('21','22','23','24','25','26','27','35')
;

PROMPT Rows inserted into icszips: 
SELECT SQL%ROWCOUNT FROM DUAL;

COMMIT;

-- ============================================================================
-- STEP 4: Post-Load Validation
-- ============================================================================
PROMPT Step 4: Validating loaded data...

-- Count records by area
PROMPT Record counts by area:
SELECT 
    didocd AS area_code,
    COUNT(*) AS record_count
FROM icszips
GROUP BY didocd
ORDER BY didocd;

-- Total count
PROMPT Total records in icszips:
SELECT COUNT(*) FROM icszips;

-- ============================================================================
-- STEP 5: Create/Update Statistics (Optional)
-- ============================================================================
PROMPT Step 5: Gathering table statistics...

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'ICSZIPS',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        cascade => TRUE
    );
END;
/

PROMPT Statistics gathered successfully

-- ============================================================================
-- COMPLETION
-- ============================================================================
PROMPT ========== crzips transformation completed successfully ==========
PROMPT End timestamp:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;

-- Exit (for SQL*Plus)
-- EXIT;

-- ============================================================================
-- NOTES FOR IMPLEMENTATION:
-- ============================================================================
-- 1. Update table structures to match your actual oldzips and icszips tables
-- 2. Add proper column mappings in the INSERT statement
-- 3. Implement business rules and data validations
-- 4. Add error handling as needed
-- 5. Consider adding indexes on icszips if not already present
-- 6. Test thoroughly in dev/test environments before production use
-- ============================================================================
