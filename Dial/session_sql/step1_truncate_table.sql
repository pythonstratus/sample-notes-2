-- ============================================================
-- STEP 1: NOLOGGING AND TRUNCATE TABLE
-- ============================================================
-- Run this script FIRST and wait for completion before Step 2
-- ============================================================

ALTER TABLE dialdev.icszips NOLOGGING;
COMMIT;

-- Small delay to ensure operation completes
SELECT 'Step 1a: NOLOGGING applied' AS status FROM DUAL;

TRUNCATE TABLE dialdev.icszips;
COMMIT;

SELECT 'Step 1 Complete: Table truncated successfully' AS status FROM DUAL;

-- ============================================================
-- WAIT: Disconnect and reconnect before running Step 2
-- ============================================================
