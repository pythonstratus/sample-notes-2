-- Clean the temp table at start
EXECUTE IMMEDIATE 'TRUNCATE TABLE temp_counts';

-- Step 1: Pre-compute counts for all rows in one bulk operation
INSERT INTO temp_counts (rowid_val, tdacnt, tdicnt)
SELECT 
    ts.rowid,
    -- tdacnt: count when ent_tdi_xref is 'A' or 'C', rectype = 5
    CASE 
        WHEN DECODE(ts.ent_tdi_xref, 'A', 1, 'C', 1, 0) = 1 THEN
            (SELECT COUNT(*) 
             FROM coredial c, dialmod d
             WHERE c.grnum BETWEEN start_grnum AND end_grnum
               AND c.coresid = d.modsid
               AND c.coretin = ts.emistin
               AND c.corefs  = ts.emisfs
               AND c.corett  = ts.emistt
               AND d.rectype = 5)
        ELSE 0 
    END,
    -- tdicnt: count when ent_tdi_xref is 'I' or 'C', rectype = 0
    CASE 
        WHEN DECODE(ts.ent_tdi_xref, 'I', 1, 'C', 1, 0) = 1 THEN
            (SELECT COUNT(*) 
             FROM coredial c, dialmod d
             WHERE c.grnum BETWEEN start_grnum AND end_grnum
               AND c.coresid = d.modsid
               AND c.coretin = ts.emistin
               AND c.corefs  = ts.emisfs
               AND c.corett  = ts.emistt
               AND d.rectype = 0)
        ELSE 0 
    END
FROM tinsummary ts
WHERE ts.rowid IN (
    SELECT table_rowid(LEVEL) 
    FROM dual 
    CONNECT BY LEVEL <= (numrecs - 1)
);

-- Step 2: Bulk update using pre-computed counts
FORALL lp_cnt IN 1 .. (numrecs - 1)
    UPDATE tinsummary 
    SET risk            = table_risk(lp_cnt),
        emis_predic_cd  = table_predic(lp_cnt),
        emis_predic_cyc = table_predcyc(lp_cnt),
        tdacnt = (SELECT tc.tdacnt FROM temp_counts tc WHERE tc.rowid_val = table_rowid(lp_cnt)),
        tdicnt = (SELECT tc.tdicnt FROM temp_counts tc WHERE tc.rowid_val = table_rowid(lp_cnt))
    WHERE rowid = table_rowid(lp_cnt);

COMMIT;
