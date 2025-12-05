-- First, bulk compute all the counts you need
INSERT INTO temp_counts (rowid_val, tdacnt, tdicnt)
SELECT t.rowid,
       CASE WHEN DECODE(t.ent_tdi_xref,'A',1,'C',1,0) = 1 THEN
           (SELECT COUNT(*) FROM coredial c, dialmod 
            WHERE c.grnum BETWEEN t.start_grnum AND t.end_grnum
            AND c.coresid = t.modsid AND c.coretin = t.emistin
            AND c.corefs = t.emisfs AND c.corett = t.emistt
            AND rectype = 5)
       ELSE 0 END,
       CASE WHEN DECODE(t.ent_tdi_xref,'I',1,'C',1,0) = 1 THEN
           (SELECT COUNT(*) FROM coredial c, dialmod 
            WHERE c.grnum BETWEEN t.start_grnum AND t.end_grnum
            AND c.coresid = t.modsid AND c.coretin = t.emistin  
            AND c.corefs = t.emisfs AND c.corett = t.emistt
            AND rectype = 0)
       ELSE 0 END
FROM tinsummary t
WHERE t.rowid IN (SELECT table_rowid(level) FROM dual CONNECT BY level <= numrecs-1);

-- Then do a simple bulk update
FORALL lp_cnt IN 1 .. (numrecs - 1)
    UPDATE tinsummary SET 
        risk = table_risk(lp_cnt),
        emis_predic_cd = table_predic(lp_cnt),
        emis_predic_cyc = table_predcyc(lp_cnt),
        tdacnt = (SELECT tdacnt FROM temp_counts WHERE rowid_val = table_rowid(lp_cnt)),
        tdicnt = (SELECT tdicnt FROM temp_counts WHERE rowid_val = table_rowid(lp_cnt))
    WHERE rowid = table_rowid(lp_cnt);



MERGE INTO tinsummary t
USING (
    SELECT /*+ PARALLEL(4) */
           ts.rowid as rid,
           ts.risk_val,
           ts.predic_val,
           ts.predcyc_val,
           COALESCE(a.tdacnt, 0) as tdacnt,
           COALESCE(i.tdicnt, 0) as tdicnt
    FROM (SELECT table_rowid(level) as rw, table_risk(level) as risk_val, 
                 table_predic(level) as predic_val, table_predcyc(level) as predcyc_val
          FROM dual CONNECT BY level <= numrecs-1) src
    JOIN tinsummary ts ON ts.rowid = src.rw
    LEFT JOIN (
        SELECT modsid, emistin, emisfs, emistt, start_grnum, end_grnum, COUNT(*) as tdacnt
        FROM coredial c, dialmod
        WHERE rectype = 5
        GROUP BY modsid, emistin, emisfs, emistt, start_grnum, end_grnum
    ) a ON ...
    LEFT JOIN (...) i ON ...
) src
ON (t.rowid = src.rid)
WHEN MATCHED THEN UPDATE SET ...



Questions to Help Optimize Further

How many distinct combinations of (modsid, emistin, emisfs, emistt, grnum range) exist? If it's much smaller than 15M, pre-aggregating is the key win.
Are there indexes on coredial(coresid, coretin, corefs, corett, grnum, rectype)?
Can you share the full procedure? I'd like to see how the arrays (table_risk, table_rowid, etc.) are populated - there may be opportunities to optimize the entire flow.

Given your recent performance wins (34 hours → 5 minutes), a similar approach here - moving the correlated logic into set-based operations - should yield dramatic improvements.
