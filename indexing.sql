-- Create these indexes if they don't exist
CREATE INDEX idx_entmod_risk_lookup ON entmod(
    tinsid, 
    status, 
    decode(segind,'A',1,'I',1,'C',1,0),
    tinsid
);

CREATE INDEX idx_trantrail_risk_lookup ON trantrail(
    tinsid, 
    status, 
    decode(type,'2',1,'F',1,'G',1,'I',1,0),
    e.tinsid,
    mft
);

-- For the estate_tax query
CREATE INDEX idx_ent_tinsid ON ent(tinsid);
CREATE INDEX idx_codetable ON codetable(codesid, code, dtchng);



CREATE OR REPLACE PROCEDURE ENTITYDEV.riskcalc_parallel(area IN NUMBER)
IS
BEGIN
    -- Set session parameters
    EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    EXECUTE IMMEDIATE 'ALTER SESSION FORCE PARALLEL DML PARALLEL 4';
    
    -- Call your original procedure
    ENTITYDEV.riskcalc(area);
    
    -- Optionally reset session
    EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
END;
/



-- First, check existing indexes
SELECT index_name, column_name, column_position
FROM user_ind_columns
WHERE table_name IN ('ENTMOD', 'TRANTRAIL', 'ENT')
ORDER BY table_name, index_name, column_position;

-- Then create these indexes in order of importance:

-- 1. Most critical - for all the UPDATE statements
CREATE UNIQUE INDEX idx_ent_tinsid ON ent(tinsid);

-- 2. For the TRANTRAIL subquery in entcur1
CREATE INDEX idx_trantrail_risk ON trantrail(
    status,
    segind,
    tinsid
);

-- 3. For ENTMOD main query
CREATE INDEX idx_entmod_risk ON entmod(
    tinsid,
    status
);

-- 4. For entcur2 
CREATE INDEX idx_entmod_entcur2 ON entmod(
    emodsid,
    status,
    type,
    period,
    mft
);
