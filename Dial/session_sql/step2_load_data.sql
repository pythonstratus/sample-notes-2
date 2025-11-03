-- ============================================================
-- STEP 2: DISABLE CONSTRAINTS, INDEXES AND LOAD DATA
-- ============================================================
-- Run this script SECOND after completing Step 1
-- Make sure you have disconnected and reconnected your session
-- ============================================================

-- STEP 2-1: ENABLE PARALLEL DML FOR THE SESSION
ALTER SESSION ENABLE PARALLEL DML;
ALTER SESSION FORCE PARALLEL DML;

SELECT 'Parallel DML enabled' AS status FROM DUAL;

-- STEP 2-2: DISABLE TARGET TABLE CONSTRAINTS TEMPORARILY (FOR SPEED)
-- GET CONSTRAINT NAMES FIRST, THEN EXECUTE THE RETURN RESULTS

SELECT 'ALTER TABLE dialdev.icszips DISABLE CONSTRAINT ' || CONSTRAINT_NAME || ';' AS DISABLE_SQL
FROM ALL_CONSTRAINTS
WHERE OWNER = UPPER('dialdev')
AND TABLE_NAME = UPPER('icszips')
AND CONSTRAINT_TYPE IN ('P', 'U', 'R', 'C');

-- Copy and paste the output from above query here and execute:
-- (You'll need to manually run the generated ALTER TABLE statements)

SELECT 'Step 2-2: Constraints disabled (run generated statements above)' AS status FROM DUAL;

-- STEP 2-3: DISABLE TARGET TABLE INDEX TEMPORARILY (FOR SPEED)
-- GET INDEX NAMES FIRST, THEN EXECUTE THE RETURN RESULTS

SELECT 'ALTER INDEX dialdev.'|| INDEX_NAME||' UNUSABLE;' AS DISABLE_SQL
FROM ALL_INDEXES
WHERE OWNER = UPPER('dialdev')
AND TABLE_NAME = UPPER('icszips')
AND INDEX_TYPE NOT IN ('LOB', 'DOMAIN')
AND STATUS = 'VALID'
AND UNIQUENESS IN ('NONUNIQUE','NORMAL');

-- Copy and paste the output from above query here and execute:
-- (You'll need to manually run the generated ALTER INDEX statements)

SELECT 'Step 2-3: Indexes disabled (run generated statements above)' AS status FROM DUAL;

-- STEP 2-4: PARALLEL INSERT (ADJUST DEGREE BASED ON CPU CORES)
INSERT /*+ PARALLEL(dialdev.icszips, 8) APPEND */ INTO dialdev.icszips
SELECT /*+ PARALLEL(dial.icszips, 8) */ *
FROM dial.icszips;

COMMIT;

SELECT 'Step 2 Complete: Data loaded successfully' AS status FROM DUAL;
SELECT COUNT(*) AS total_rows_loaded FROM dialdev.icszips;

-- ============================================================
-- WAIT: Disconnect and reconnect before running Step 3
-- ============================================================
