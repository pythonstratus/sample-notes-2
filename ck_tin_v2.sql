-- Create object types for table function output
CREATE OR REPLACE TYPE t_tin_result AS OBJECT (
    section_name VARCHAR2(20),
    section_order NUMBER,
    tin VARCHAR2(20),
    tinsid NUMBER,
    col3 VARCHAR2(100),
    col4 VARCHAR2(100),
    col5 VARCHAR2(100),
    col6 VARCHAR2(100),
    col7 VARCHAR2(100),
    col8 VARCHAR2(100),
    col9 VARCHAR2(100),
    col10 VARCHAR2(100),
    col11 VARCHAR2(100),
    col12 VARCHAR2(100),
    col13 VARCHAR2(100),
    col14 VARCHAR2(100),
    col15 VARCHAR2(100),
    col16 VARCHAR2(100)
);
/

CREATE OR REPLACE TYPE t_tin_result_tab AS TABLE OF t_tin_result;
/

-- Table function that returns TIN data as a table
CREATE OR REPLACE FUNCTION FN_CK_TIN_TABLE(p_tin IN VARCHAR2)
RETURN t_tin_result_tab
PIPELINED
AS
    v_tptin VARCHAR2(12);
    v_count NUMBER := 0;
    
BEGIN
    -- Validate input
    IF p_tin IS NULL OR LENGTH(TRIM(p_tin)) = 0 THEN
        PIPE ROW(t_tin_result('ERROR', 0, 'TIN parameter is required', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
        RETURN;
    END IF;
    
    -- Clean the TIN (remove dashes)
    v_tptin := REPLACE(p_tin, '-', '');
    
    -- Check if TIN exists
    SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    
    IF v_count = 0 THEN
        PIPE ROW(t_tin_result('NO_DATA', 0, 'No data found for TIN: ' || p_tin, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
        RETURN;
    END IF;
    
    -- Return ENT data
    FOR rec IN (
        SELECT tin, tinsid, tpctrl, totassd, status, caseind, pyrind,
               casecode, subcode, assncft, assngrp, risk, arisk, 
               TO_CHAR(extrdt, 'YYYY-MM-DD') as extrdt
        FROM ent 
        WHERE tin = v_tptin
    ) LOOP
        PIPE ROW(t_tin_result(
            'ENT', 1, rec.tin, rec.tinsid, rec.tpctrl, TO_CHAR(rec.totassd), 
            rec.status, rec.caseind, rec.pyrind, rec.casecode, rec.subcode, 
            rec.assncft, rec.assngrp, rec.risk, rec.arisk, rec.extrdt, NULL, NULL
        ));
    END LOOP;
    
    -- Return TRANTRAIL data
    FOR rec IN (
        SELECT t.tinsid, roid, segind, t.status, t.assnfld, t.assnno, 
               TO_CHAR(t.closedt, 'YYYY-MM-DD') as closedt,
               TO_CHAR(t.extrdt, 'YYYY-MM-DD') as extrdt, 
               flag1, flag2,
               TO_CHAR(DECODE(t.tinsid, roid, t.assnno, t.closedt)) as dspcd
        FROM trantrail t, ent e
        WHERE e.tin = v_tptin 
        AND t.tinsid = e.tinsid
        ORDER BY t.tinsid, t.closedt, t.status, roid
    ) LOOP
        PIPE ROW(t_tin_result(
            'TRANTRAIL', 2, v_tptin, rec.tinsid, TO_CHAR(rec.roid), rec.segind,
            rec.status, rec.assnfld, TO_CHAR(rec.assnno), rec.closedt, 
            rec.extrdt, rec.flag1, rec.flag2, rec.dspcd, NULL, NULL, NULL, NULL
        ));
    END LOOP;
    
    -- Return ENTMOD data
    FOR rec IN (
        SELECT emodsid, tinsid, roid, m.type, mft, period, m.pyrind,
               m.status, assnno, TO_CHAR(m.clsdt, 'YYYY-MM-DD') as clsdt,
               dispcode, TO_CHAR(m.extrdt, 'YYYY-MM-DD') as extrdt, 
               flag1, flag2, typeid, TO_CHAR(balance) as balance
        FROM entmod m, ent e
        WHERE e.tin = v_tptin 
        AND m.emodsid = e.tinsid
        ORDER BY emodsid, m.extrdt, mft, period
    ) LOOP
        PIPE ROW(t_tin_result(
            'ENTMOD', 3, v_tptin, rec.tinsid, TO_CHAR(rec.emodsid), TO_CHAR(rec.roid),
            rec.type, rec.mft, TO_CHAR(rec.period), rec.pyrind, rec.status,
            TO_CHAR(rec.assnno), rec.clsdt, rec.dispcode, rec.extrdt, rec.flag1, rec.flag2, rec.balance
        ));
    END LOOP;
    
    -- Return ENTACT data
    FOR rec IN (
        SELECT actsid, tinsid, roid, aroid, a.typcd, typeid, mft, period,
               TO_CHAR(actdt, 'YYYY-MM-DD') as actdt, dispcode, rptcd, rptdef,
               TO_CHAR(a.extrdt, 'YYYY-MM-DD') as extrdt, 
               TO_CHAR(amount) as amount, cc, tc
        FROM entact a, ent e
        WHERE e.tin = v_tptin 
        AND a.actsid = e.tinsid
        ORDER BY actsid, actdt
    ) LOOP
        PIPE ROW(t_tin_result(
            'ENTACT', 4, v_tptin, rec.tinsid, TO_CHAR(rec.actsid), TO_CHAR(rec.roid),
            TO_CHAR(rec.aroid), rec.typcd, rec.typeid, rec.mft, TO_CHAR(rec.period),
            rec.actdt, rec.dispcode, rec.rptcd, rec.rptdef, rec.extrdt, rec.amount, TO_CHAR(rec.cc)
        ));
    END LOOP;
    
    -- Return TIMETIN data
    FOR rec IN (
        SELECT timesid, tinsid, roid, TO_CHAR(rptdt, 'YYYY-MM-DD') as rptdt,
               TO_CHAR(t.extrdt, 'YYYY-MM-DD') as extrdt, code, t.subcode, 
               TO_CHAR(hours) as hours,
               e.grade as egrd, t.grade as tgrd, e.risk as ersk, t.risk as trsk
        FROM timetin t, ent e
        WHERE e.tin = v_tptin 
        AND t.timesid = e.tinsid
        ORDER BY timesid, rptdt, code
    ) LOOP
        PIPE ROW(t_tin_result(
            'TIMETIN', 5, v_tptin, rec.tinsid, TO_CHAR(rec.timesid), TO_CHAR(rec.roid),
            rec.rptdt, rec.extrdt, rec.code, rec.subcode, rec.hours,
            rec.egrd, rec.tgrd, rec.ersk, rec.trsk, NULL, NULL, NULL
        ));
    END LOOP;
    
    RETURN;
    
EXCEPTION
    WHEN OTHERS THEN
        PIPE ROW(t_tin_result('ERROR', 0, 'Error: ' || SQLERRM, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
        RETURN;
END FN_CK_TIN_TABLE;
/

-- Simple version with better column names for each section
CREATE OR REPLACE FUNCTION FN_CK_TIN_SIMPLE(p_tin IN VARCHAR2)
RETURN t_tin_result_tab
PIPELINED
AS
    v_tptin VARCHAR2(12);
    v_count NUMBER := 0;
    
BEGIN
    -- Clean the TIN
    v_tptin := REPLACE(NVL(p_tin, ''), '-', '');
    
    IF LENGTH(v_tptin) = 0 THEN
        PIPE ROW(t_tin_result('ERROR', 0, 'TIN parameter required', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
        RETURN;
    END IF;
    
    -- Check if data exists
    BEGIN
        SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
        IF v_count = 0 THEN
            PIPE ROW(t_tin_result('INFO', 0, 'No data found for TIN: ' || p_tin, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            PIPE ROW(t_tin_result('ERROR', 0, 'Database error: ' || SQLERRM, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
            RETURN;
    END;
    
    -- ENT Section
    BEGIN
        FOR rec IN (SELECT * FROM ent WHERE tin = v_tptin) LOOP
            PIPE ROW(t_tin_result(
                'ENT', 1, rec.tin, rec.tinsid, rec.tpctrl, TO_CHAR(rec.totassd), 
                rec.status, rec.caseind, rec.pyrind, rec.casecode, rec.subcode, 
                rec.assncft, rec.assngrp, rec.risk, rec.arisk, 
                TO_CHAR(rec.extrdt, 'YYYY-MM-DD'), NULL, NULL
            ));
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            PIPE ROW(t_tin_result('ERROR', 1, 'ENT query error: ' || SQLERRM, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL));
    END;
    
    -- Add sections for other tables as needed...
    RETURN;
    
END FN_CK_TIN_SIMPLE;
/

-- Grant execute permissions (run if needed)
-- GRANT EXECUTE ON FN_CK_TIN_TABLE TO PUBLIC;

-- ============================================================================
-- USAGE EXAMPLES - Run these queries to test:
-- ============================================================================

-- Test 1: Basic functionality test
SELECT * FROM TABLE(FN_CK_TIN_SIMPLE('844607599'));

-- Test 2: Full data retrieval
SELECT * FROM TABLE(FN_CK_TIN_TABLE('844607599'));

-- Test 3: Formatted output by section
SELECT 
    section_name,
    CASE 
        WHEN section_name = 'ENT' THEN 'TIN: ' || tin || ', TINSID: ' || tinsid || ', STATUS: ' || col5
        WHEN section_name = 'TRANTRAIL' THEN 'TINSID: ' || tinsid || ', ROID: ' || col3 || ', STATUS: ' || col5
        WHEN section_name = 'ENTMOD' THEN 'EMODSID: ' || col3 || ', TYPE: ' || col5 || ', MFT: ' || col6
        WHEN section_name = 'ENTACT' THEN 'ACTSID: ' || col3 || ', ACTDT: ' || col9 || ', AMOUNT: ' || col15
        WHEN section_name = 'TIMETIN' THEN 'TIMESID: ' || col3 || ', RPTDT: ' || col5 || ', HOURS: ' || col9
        ELSE tin
    END as formatted_output
FROM TABLE(FN_CK_TIN_TABLE('844607599'))
ORDER BY section_order, tinsid;

-- Test 4: Count by section
SELECT section_name, COUNT(*) as record_count
FROM TABLE(FN_CK_TIN_TABLE('844607599'))
WHERE section_name NOT IN ('ERROR', 'NO_DATA', 'INFO')
GROUP BY section_name, section_order
ORDER BY section_order;

-- Test 5: Error handling test
SELECT * FROM TABLE(FN_CK_TIN_TABLE(''));

-- Test 6: Non-existent TIN test
SELECT * FROM TABLE(FN_CK_TIN_TABLE('999999999'));

-- ============================================================================
-- To see data in a more readable format, try this query:
-- ============================================================================
SELECT 
    RPAD(section_name, 12) || ' | ' ||
    RPAD(NVL(tin, 'N/A'), 12) || ' | ' ||
    RPAD(NVL(TO_CHAR(tinsid), 'N/A'), 10) || ' | ' ||
    RPAD(NVL(col3, 'N/A'), 15) || ' | ' ||
    RPAD(NVL(col4, 'N/A'), 15) || ' | ' ||
    RPAD(NVL(col5, 'N/A'), 10) as formatted_row
FROM TABLE(FN_CK_TIN_TABLE('844607599'))
ORDER BY section_order, tinsid;
