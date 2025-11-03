-- ============================================================
-- STEP 3: RE-ENABLE CONSTRAINTS AND INDEXES
-- ============================================================
-- Run this script THIRD after completing Step 2
-- Make sure you have disconnected and reconnected your session
-- ============================================================

-- STEP 3-1: RE-ENABLE CONSTRAINTS
SELECT 'ALTER TABLE dialdev.icszips ENABLE CONSTRAINT ' || CONSTRAINT_NAME || ';' AS ENABLE_SQL
FROM ALL_CONSTRAINTS
WHERE OWNER = UPPER('dialdev')
AND TABLE_NAME = UPPER('icszips')
AND CONSTRAINT_TYPE IN ('P', 'U', 'R', 'C');

-- Copy and paste the output from above query here and execute:
-- (You'll need to manually run the generated ALTER TABLE statements)

SELECT 'Step 3-1: Constraints re-enabled (run generated statements above)' AS status FROM DUAL;

-- STEP 3-2: REBUILD TARGET TABLE INDEX
SELECT 'ALTER INDEX dialdev.'|| INDEX_NAME||' REBUILD NOLOGGING ONLINE;' AS ENABLE_SQL
FROM ALL_INDEXES
WHERE OWNER = UPPER('dialdev')
AND TABLE_NAME = UPPER('icszips')
AND INDEX_TYPE NOT IN ('LOB', 'DOMAIN')
AND STATUS = 'UNUSABLE'
AND UNIQUENESS IN ('NONUNIQUE','NORMAL');

-- Copy and paste the output from above query here and execute:
-- (You'll need to manually run the generated ALTER INDEX statements)

SELECT 'Step 3-2: Indexes rebuilt (run generated statements above)' AS status FROM DUAL;

-- STEP 3-3: RESET SESSION
ALTER SESSION DISABLE PARALLEL DML;
ALTER TABLE dialdev.icszips LOGGING;

SELECT 'Step 3 Complete: All operations finished successfully' AS status FROM DUAL;

-- ============================================================
-- FINAL VERIFICATION
-- ============================================================
SELECT 'Final row count: ' || COUNT(*) AS verification FROM dialdev.icszips;
SELECT 'Constraint status check:' AS status FROM DUAL;
SELECT CONSTRAINT_NAME, STATUS FROM ALL_CONSTRAINTS 
WHERE OWNER = UPPER('dialdev') 
AND TABLE_NAME = UPPER('icszips');

SELECT 'Index status check:' AS status FROM DUAL;
SELECT INDEX_NAME, STATUS FROM ALL_INDEXES 
WHERE OWNER = UPPER('dialdev') 
AND TABLE_NAME = UPPER('icszips');

-- ============================================================
-- PROCESS COMPLETE
-- ============================================================
