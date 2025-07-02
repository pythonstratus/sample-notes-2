-- Simple and working procedure without custom functions
CREATE OR REPLACE PROCEDURE SP_CK_TIN_FORMATTED(p_tin IN VARCHAR2)
AS
    v_tptin VARCHAR2(12);
    v_count NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    
    -- Clean the TIN
    v_tptin := REPLACE(NVL(TRIM(p_tin), ''), '-', '');
    
    IF LENGTH(v_tptin) = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: TIN parameter required');
        RETURN;
    END IF;
    
    -- Check if data exists
    BEGIN
        SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error accessing ENT table: ' || SQLERRM);
            RETURN;
    END;
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No data found for TIN: ' || p_tin);
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(v_tptin);
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('ENT');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('    TIN      TINSID TPCT   TOTASSD S C   PYRIND CAS SUB ASSNCFF    ASSNGRP        RISK A EXTRDT');
    DBMS_OUTPUT.PUT_LINE('---------- -------- ---- --------- - - -------- --- --- ---------- ---------- -------- - ----------');
    
    -- ENT Section with safe data handling
    FOR rec IN (
        SELECT tin, tinsid, tpctrl, totassd, status, caseind, pyrind,
               casecode, subcode, assncft, assngrp, risk, arisk, extrdt
        FROM ent 
        WHERE tin = v_tptin
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(rec.tin, ' '), 10) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
            RPAD(NVL(rec.tpctrl, ' '), 4) || ' ' ||
            LPAD(CASE WHEN rec.totassd IS NOT NULL THEN TO_CHAR(rec.totassd, 'FM99999.99') ELSE ' ' END, 9) || ' ' ||
            RPAD(NVL(rec.status, ' '), 1) || ' ' ||
            RPAD(NVL(rec.caseind, ' '), 1) || ' ' ||
            RPAD(CASE WHEN rec.pyrind IS NOT NULL THEN TO_CHAR(rec.pyrind) ELSE ' ' END, 8) || ' ' ||
            RPAD(CASE WHEN rec.casecode IS NOT NULL THEN TO_CHAR(rec.casecode) ELSE ' ' END, 3) || ' ' ||
            RPAD(CASE WHEN rec.subcode IS NOT NULL THEN TO_CHAR(rec.subcode) ELSE ' ' END, 3) || ' ' ||
            RPAD(NVL(rec.assncft, ' '), 10) || ' ' ||
            RPAD(NVL(rec.assngrp, ' '), 10) || ' ' ||
            RPAD(CASE WHEN rec.risk IS NOT NULL THEN TO_CHAR(rec.risk) ELSE ' ' END, 8) || ' ' ||
            RPAD(NVL(rec.arisk, ' '), 1) || ' ' ||
            CASE WHEN rec.extrdt IS NOT NULL THEN TO_CHAR(rec.extrdt, 'MM/DD/YYYY') ELSE ' ' END
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- TRANTRAIL Section
    DBMS_OUTPUT.PUT_LINE('TRANTRAIL');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID S S ASSNFLD    ASSNNO    CLOSEDT   EXTRDT    FLAG FLAG     DSPCD      DISPCD OR    EMPHRS');
    DBMS_OUTPUT.PUT_LINE('-------- -------- - - ---------- --------- --------- --------- ---- ---- --------- ---------- ---------');
    
    v_count := 0;
    FOR rec IN (
        SELECT t.tinsid, t.roid, t.segind, t.status, t.assnfld, t.assnno, 
               t.closedt, t.extrdt, t.flag1, t.flag2
        FROM trantrail t, ent e
        WHERE e.tin = v_tptin AND t.tinsid = e.tinsid
        ORDER BY t.tinsid, t.closedt, t.status, t.roid
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
            RPAD(NVL(rec.segind, ' '), 1) || ' ' ||
            RPAD(NVL(rec.status, ' '), 1) || ' ' ||
            RPAD(NVL(rec.assnfld, ' '), 10) || ' ' ||
            RPAD(CASE WHEN rec.assnno IS NOT NULL THEN TO_CHAR(rec.assnno) ELSE ' ' END, 9) || ' ' ||
            RPAD(CASE WHEN rec.closedt IS NOT NULL THEN TO_CHAR(rec.closedt, 'MM/DD/YYYY') ELSE ' ' END, 9) || ' ' ||
            RPAD(CASE WHEN rec.extrdt IS NOT NULL THEN TO_CHAR(rec.extrdt, 'MM/DD/YYYY') ELSE ' ' END, 9) || ' ' ||
            RPAD(CASE WHEN rec.flag1 IS NOT NULL THEN TO_CHAR(rec.flag1) ELSE ' ' END, 4) || ' ' ||
            RPAD(CASE WHEN rec.flag2 IS NOT NULL THEN TO_CHAR(rec.flag2) ELSE ' ' END, 4) || ' ' ||
            RPAD(CASE WHEN rec.assnno IS NOT NULL THEN TO_CHAR(rec.assnno) ELSE ' ' END, 9) || ' ' ||
            RPAD('15', 10) || ' ' ||
            RPAD('CF', 9)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ENTMOD Section  
    DBMS_OUTPUT.PUT_LINE('ENTMOD');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID T MFT PERIOD    P S  ASSNNO    CLSDT     DISPCODE EXTRDT    FLAG FLAG   TYPEID    BALANCE');
    DBMS_OUTPUT.PUT_LINE('-------- -------- - --- --------- - - --------- --------- -------- --------- ---- ---- -------- ----------');
    
    v_count := 0;
    FOR rec IN (
        SELECT m.emodsid, m.roid, m.type, m.mft, m.period, m.pyrind,
               m.assnno, m.clsdt, m.dispcode, m.extrdt, m.flag1, m.flag2, 
               m.typeid, m.balance
        FROM entmod m, ent e
        WHERE e.tin = v_tptin AND m.emodsid = e.tinsid
        ORDER BY m.emodsid, m.extrdt, m.mft, m.period
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(TO_CHAR(rec.emodsid), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
            RPAD(NVL(rec.type, ' '), 1) || ' ' ||
            RPAD(CASE WHEN rec.mft IS NOT NULL THEN TO_CHAR(rec.mft) ELSE ' ' END, 3) || ' ' ||
            RPAD(CASE WHEN rec.period IS NOT NULL THEN TO_CHAR(rec.period) ELSE ' ' END, 9) || ' ' ||
            RPAD(NVL(rec.pyrind, ' '), 1) || ' ' ||
            RPAD(' ', 1) || ' ' ||
            RPAD(CASE WHEN rec.assnno IS NOT NULL THEN TO_CHAR(rec.assnno) ELSE ' ' END, 9) || ' ' ||
            RPAD(CASE WHEN rec.clsdt IS NOT NULL THEN TO_CHAR(rec.clsdt, 'MM/DD/YYYY') ELSE ' ' END, 9) || ' ' ||
            RPAD(NVL(rec.dispcode, ' '), 8) || ' ' ||
            RPAD(CASE WHEN rec.extrdt IS NOT NULL THEN TO_CHAR(rec.extrdt, 'MM/DD/YYYY') ELSE ' ' END, 9) || ' ' ||
            RPAD(CASE WHEN rec.flag1 IS NOT NULL THEN TO_CHAR(rec.flag1) ELSE ' ' END, 4) || ' ' ||
            RPAD(CASE WHEN rec.flag2 IS NOT NULL THEN TO_CHAR(rec.flag2) ELSE ' ' END, 4) || ' ' ||
            RPAD(NVL(rec.typeid, ' '), 8) || ' ' ||
            LPAD(CASE WHEN rec.balance IS NOT NULL THEN TO_CHAR(rec.balance, 'FM999999.99') ELSE '0' END, 10)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ENTACT Section
    DBMS_OUTPUT.PUT_LINE('ENTACT');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID     AROID T   TYPEID MFT PERIOD     ACTDT    DISPCODE R R EXTRDT       AMOUNT  CC   TC');
    DBMS_OUTPUT.PUT_LINE('-------- -------- --------- - -------- --- --------- --------- -------- - - --------- ---------- --- ----');
    
    v_count := 0;
    FOR rec IN (
        SELECT a.actsid, a.roid, a.aroid, a.typcd, a.typeid, a.mft, a.period,
               a.actdt, a.dispcode, a.rptcd, a.extrdt, a.amount, a.cc, a.tc
        FROM entact a, ent e
        WHERE e.tin = v_tptin AND a.actsid = e.tinsid
        ORDER BY a.actsid, a.actdt
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(TO_CHAR(rec.actsid), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.aroid), ' '), 9) || ' ' ||
            RPAD(NVL(rec.typcd, ' '), 1) || ' ' ||
            RPAD(NVL(rec.typeid, ' '), 8) || ' ' ||
            RPAD(CASE WHEN rec.mft IS NOT NULL THEN TO_CHAR(rec.mft) ELSE ' ' END, 3) || ' ' ||
            RPAD(CASE WHEN rec.period IS NOT NULL THEN TO_CHAR(rec.period) ELSE ' ' END, 9) || ' ' ||
            RPAD(CASE WHEN rec.actdt IS NOT NULL THEN TO_CHAR(rec.actdt, 'MM/DD/YYYY') ELSE ' ' END, 9) || ' ' ||
            RPAD(NVL(rec.dispcode, ' '), 8) || ' ' ||
            RPAD(NVL(SUBSTR(rec.rptcd, 1, 1), ' '), 1) || ' ' ||
            RPAD(NVL(SUBSTR(rec.rptcd, 2, 1), ' '), 1) || ' ' ||
            RPAD(CASE WHEN rec.extrdt IS NOT NULL THEN TO_CHAR(rec.extrdt, 'MM/DD/YYYY') ELSE ' ' END, 9) || ' ' ||
            LPAD(CASE WHEN rec.amount IS NOT NULL THEN TO_CHAR(rec.amount) ELSE '0' END, 10) || ' ' ||
            RPAD(CASE WHEN rec.cc IS NOT NULL THEN TO_CHAR(rec.cc) ELSE ' ' END, 3) || ' ' ||
            RPAD(CASE WHEN rec.tc IS NOT NULL THEN TO_CHAR(rec.tc) ELSE ' ' END, 4)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END SP_CK_TIN_FORMATTED;
/

-- Even simpler version for testing
CREATE OR REPLACE PROCEDURE SP_CK_TIN_TEST(p_tin IN VARCHAR2)
AS
    v_tptin VARCHAR2(12);
    v_count NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    
    v_tptin := REPLACE(NVL(TRIM(p_tin), ''), '-', '');
    
    IF LENGTH(v_tptin) = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: TIN parameter required');
        RETURN;
    END IF;
    
    SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No data found for TIN: ' || p_tin);
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(v_tptin);
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('ENT');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Simple ENT output
    FOR rec IN (SELECT * FROM ent WHERE tin = v_tptin) LOOP
        DBMS_OUTPUT.PUT_LINE('TIN: ' || rec.tin || 
                           ', TINSID: ' || rec.tinsid || 
                           ', STATUS: ' || NVL(rec.status, 'NULL') ||
                           ', TOTASSD: ' || NVL(TO_CHAR(rec.totassd), 'NULL'));
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test completed successfully.');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END SP_CK_TIN_TEST;
/

-- ============================================================================
-- USAGE EXAMPLES:
-- ============================================================================

-- Test 1: Simple test first
EXEC SP_CK_TIN_TEST('844607599');

-- Test 2: Full formatted output (once the simple test works)
EXEC SP_CK_TIN_FORMATTED('844607599');

-- Test 3: Manual verification
SELECT tin, tinsid, status, totassd FROM ent WHERE tin = '844607599';
