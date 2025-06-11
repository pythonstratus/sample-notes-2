-- Step 1: Enable parallel DML for the session
ALTER SESSION ENABLE PARALLEL DML;
ALTER SESSION FORCE PARALLEL DML;

-- Step 2: Disable target table constraints temporarily (for speed)
-- Get constraint names first
SELECT 'ALTER TABLE new_schema.entmod DISABLE CONSTRAINT ' || constraint_name || ';' as disable_sql
FROM all_constraints 
WHERE owner = 'NEW_SCHEMA' 
AND table_name = 'ENTMOD' 
AND constraint_type IN ('P', 'U', 'R', 'C');

-- Step 3: Parallel insert (adjust DEGREE based on CPU cores)
INSERT /*+ PARALLEL(new_schema.entmod, 4) APPEND */ INTO new_schema.entmod
SELECT /*+ PARALLEL(legacy_schema.entmod, 4) */ * 
FROM legacy_schema.entmod;

COMMIT;

-- Step 4: Re-enable constraints
SELECT 'ALTER TABLE new_schema.entmod ENABLE CONSTRAINT ' || constraint_name || ';' as enable_sql
FROM all_constraints 
WHERE owner = 'NEW_SCHEMA' 
AND table_name = 'ENTMOD' 
AND constraint_type IN ('P', 'U', 'R', 'C');

-- Step 5: Reset session
ALTER SESSION DISABLE PARALLEL DML;
