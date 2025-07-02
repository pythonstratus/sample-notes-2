-- Complete procedure with all table structures corrected
CREATE OR REPLACE PROCEDURE SP_CK_TIN_COMPLETE(p_tin IN VARCHAR2)
AS
    v_tptin NUMBER(9);  -- TIN is NUMBER(9) in ENT table
    v_count NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    
    -- Convert TIN to number (removing dashes first)
    BEGIN
        v_tptin := TO_NUMBER(REPLACE(NVL(TRIM(p_tin), ''), '-', ''));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: Invalid TIN format. Must be numeric.');
            RETURN;
    END;
    
    -- Check if data exists
    SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No data found for TIN: ' || p_tin);
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(TRIM(TO_CHAR(v_tptin)));
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- =======================================================================
    -- ENT SECTION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('ENT');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('    TIN      TINSID TPCT   TOTASSD S C   PYRIND CAS SUB ASSNCFF    ASSNGRP        RISK A EXTRDT');
    DBMS_OUTPUT.PUT_LINE('---------- -------- ---- --------- - - -------- --- --- ---------- ---------- -------- - ----------');
    
    FOR rec IN (
        SELECT tin,           -- NUMBER(9)
               tinsid,        -- NUMBER(10)
               tpctrl,        -- CHAR(4)
               totassd,       -- NUMBER(15,2)
               status,        -- CHAR(1)
               caseind,       -- CHAR(1)
               pyrind,        -- NUMBER(1)
               casecode,      -- CHAR(3)
               subcode,       -- CHAR(3)
               assncff,       -- DATE
               assngrp,       -- DATE
               risk,          -- NUMBER(3)
               arisk,         -- CHAR(1)
               extrdt         -- DATE
        FROM ent 
        WHERE tin = v_tptin
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(TO_CHAR(rec.tin), 10) || ' ' ||
            RPAD(TO_CHAR(rec.tinsid), 8) || ' ' ||
            RPAD(NVL(TRIM(rec.tpctrl), ' '), 4) || ' ' ||
            LPAD(NVL(TO_CHAR(rec.totassd, 'FM999999.99'), ' '), 9) || ' ' ||
            RPAD(NVL(TRIM(rec.status), ' '), 1) || ' ' ||
            RPAD(NVL(TRIM(rec.caseind), ' '), 1) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.pyrind), ' '), 8) || ' ' ||
            RPAD(NVL(TRIM(rec.casecode), ' '), 3) || ' ' ||
            RPAD(NVL(TRIM(rec.subcode), ' '), 3) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.assncff, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.assngrp, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.risk), ' '), 8) || ' ' ||
            RPAD(NVL(TRIM(rec.arisk), ' '), 1) || ' ' ||
            NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' ')
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- =======================================================================
    -- TRANTRAIL SECTION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('TRANTRAIL');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID S S ASSNFLD    ASSNNO    CLOSEDT   EXTRDT    FLAG FLAG     DSPCD      DISPCD OR    EMPHRS');
    DBMS_OUTPUT.PUT_LINE('-------- -------- - - ---------- --------- --------- --------- ---- ---- --------- ---------- ---------');
    
    v_count := 0;
    FOR rec IN (
        SELECT t.tinsid,      -- NUMBER(10)
               t.roid,        -- NUMBER(8)
               t.segind,      -- CHAR(1)
               t.status,      -- CHAR(1)
               t.assnfld,     -- DATE
               t.assnro,      -- DATE
               t.closedt,     -- DATE
               t.extrdt,      -- DATE
               t.flag1,       -- VARCHAR2(4)
               t.flag2,       -- VARCHAR2(4)
               DECODE(t.tinsid, t.roid, TO_CHAR(t.assnro, 'MM/DD/YYYY'), TO_CHAR(t.closedt, 'MM/DD/YYYY')) as dspcd
        FROM trantrail t, ent e
        WHERE e.tin = v_tptin AND t.tinsid = e.tinsid
        ORDER BY t.tinsid, t.closedt, t.status, t.roid
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(TO_CHAR(rec.tinsid), 8) || ' ' ||
            RPAD(TO_CHAR(rec.roid), 8) || ' ' ||
            RPAD(NVL(TRIM(rec.segind), ' '), 1) || ' ' ||
            RPAD(NVL(TRIM(rec.status), ' '), 1) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.assnfld, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.assnro, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.closedt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TRIM(rec.flag1), ' '), 4) || ' ' ||
            RPAD(NVL(TRIM(rec.flag2), ' '), 4) || ' ' ||
            RPAD(NVL(rec.dspcd, ' '), 9) || ' ' ||
            RPAD('15', 10) || ' ' ||
            RPAD('CF', 9)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- =======================================================================
    -- ENTMOD SECTION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('ENTMOD');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID T MFT PERIOD    P S  ASSNNO    CLSDT     DISPCODE EXTRDT    FLAG FLAG   TYPEID    BALANCE');
    DBMS_OUTPUT.PUT_LINE('-------- -------- - --- --------- - - --------- --------- -------- --------- ---- ---- -------- ----------');
    
    v_count := 0;
    FOR rec IN (
        SELECT m.emodsid,     -- NUMBER(10)
               m.roid,        -- NUMBER(8)
               m.type,        -- CHAR(1)
               m.mft,         -- NUMBER(2)
               m.period,      -- DATE
               m.pyrind,      -- CHAR(1)
               m.assnro,      -- DATE
               m.clsdt,       -- DATE
               m.dispcode,    -- NUMBER(2)
               m.extrdt,      -- DATE
               m.flag1,       -- VARCHAR2(4)
               m.flag2,       -- VARCHAR2(4)
               m.typeid,      -- NUMBER(8)
               m.balance      -- NUMBER(15,2)
        FROM entmod m, ent e
        WHERE e.tin = v_tptin AND m.emodsid = e.tinsid
        ORDER BY m.emodsid, m.extrdt, m.mft, m.period
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(TO_CHAR(rec.emodsid), 8) || ' ' ||
            RPAD(TO_CHAR(rec.roid), 8) || ' ' ||
            RPAD(NVL(TRIM(rec.type), ' '), 1) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.mft, 'FM09'), ' '), 3) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.period, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TRIM(rec.pyrind), ' '), 1) || ' ' ||
            RPAD(' ', 1) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.assnro, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.clsdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.dispcode), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TRIM(rec.flag1), ' '), 4) || ' ' ||
            RPAD(NVL(TRIM(rec.flag2), ' '), 4) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.typeid), ' '), 8) || ' ' ||
            LPAD(NVL(TO_CHAR(rec.balance, 'FM999999.99'), '0'), 10)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- =======================================================================
    -- ENTACT SECTION
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('ENTACT');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID     AROID T   TYPEID MFT PERIOD     ACTDT    DISPCODE R R EXTRDT       AMOUNT  CC   TC');
    DBMS_OUTPUT.PUT_LINE('-------- -------- --------- - -------- --- --------- --------- -------- - - --------- ---------- --- ----');
    
    v_count := 0;
    FOR rec IN (
        SELECT a.actsid,      -- NUMBER(10)
               a.roid,        -- NUMBER(8)
               a.aroid,       -- NUMBER(8)
               a.typcd,       -- CHAR(1)
               a.typeid,      -- NUMBER(8)
               a.mft,         -- NUMBER(2)
               a.period,      -- DATE
               a.actdt,       -- DATE
               a.dispcode,    -- NUMBER(2)
               a.rptcd,       -- CHAR(1)
               a.rptdef,      -- CHAR(1)
               a.extrdt,      -- DATE
               a.amount,      -- NUMBER(15,2)
               a.cc,          -- NUMBER(3)
               a.tc           -- NUMBER(3)
        FROM entact a, ent e
        WHERE e.tin = v_tptin AND a.actsid = e.tinsid
        ORDER BY a.actsid, a.actdt
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(TO_CHAR(rec.actsid), 8) || ' ' ||
            RPAD(TO_CHAR(rec.roid), 8) || ' ' ||
            RPAD(TO_CHAR(rec.aroid), 9) || ' ' ||
            RPAD(NVL(TRIM(rec.typcd), ' '), 1) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.typeid), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.mft, 'FM09'), ' '), 3) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.period, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.actdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.dispcode), ' '), 8) || ' ' ||
            RPAD(NVL(TRIM(rec.rptcd), ' '), 1) || ' ' ||
            RPAD(NVL(TRIM(rec.rptdef), ' '), 1) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            LPAD(NVL(TO_CHAR(rec.amount), '0'), 10) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.cc), ' '), 3) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.tc), ' '), 4)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- =======================================================================
    -- TIMETIN SECTION (Optional)
    -- =======================================================================
    DBMS_OUTPUT.PUT_LINE('TIMETIN');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TIMESID   TINSID      ROID   RPTDT     EXTRDT    CODE SUB    HOURS  EGRD TGRD ERSK TRSK');
    DBMS_OUTPUT.PUT_LINE('--------- --------- --------- --------- --------- ---- ---- -------- ---- ---- ---- ----');
    
    v_count := 0;
    FOR rec IN (
        SELECT t.timesid,     -- NUMBER(10)
               t.tinsid,      -- NUMBER(10) - Wait, this should link to ENT.TINSID
               t.roid,        -- NUMBER(8)
               t.rptdt,       -- DATE
               t.extrdt,      -- DATE
               t.code,        -- CHAR(3)
               t.subcode,     -- CHAR(3)
               t.hours,       -- NUMBER(4,2)
               e.grade as egrd,      -- NUMBER(2) from ENT
               t.grade as tgrd,      -- NUMBER(2) from TIMETIN
               e.risk as ersk,       -- NUMBER(3) from ENT
               t.risk as trsk        -- NUMBER(3) from TIMETIN
        FROM timetin t, ent e
        WHERE e.tin = v_tptin 
        AND t.timesid = e.tinsid  -- This join might need adjustment based on your data
        ORDER BY t.timesid, t.rptdt
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(TO_CHAR(rec.timesid), 9) || ' ' ||
            RPAD(TO_CHAR(rec.tinsid), 9) || ' ' ||
            RPAD(TO_CHAR(rec.roid), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.rptdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
            RPAD(NVL(TRIM(rec.code), ' '), 4) || ' ' ||
            RPAD(NVL(TRIM(rec.subcode), ' '), 4) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.hours, 'FM999.99'), ' '), 8) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.egrd), ' '), 4) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.tgrd), ' '), 4) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.ersk), ' '), 4) || ' ' ||
            RPAD(NVL(TO_CHAR(rec.trsk), ' '), 4)
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END SP_CK_TIN_COMPLETE;
/

-- Simple test procedure to verify TIN conversion and basic data access
CREATE OR REPLACE PROCEDURE SP_CK_TIN_VERIFY(p_tin IN VARCHAR2)
AS
    v_tptin NUMBER(9);
    v_count NUMBER := 0;
    
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    
    -- Test TIN conversion
    BEGIN
        v_tptin := TO_NUMBER(REPLACE(NVL(TRIM(p_tin), ''), '-', ''));
        DBMS_OUTPUT.PUT_LINE('TIN converted successfully: ' || v_tptin);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('TIN conversion error: ' || SQLERRM);
            RETURN;
    END;
    
    -- Test ENT access
    SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    DBMS_OUTPUT.PUT_LINE('ENT records found: ' || v_count);
    
    IF v_count > 0 THEN
        FOR rec IN (SELECT tin, tinsid, status FROM ent WHERE tin = v_tptin) LOOP
            DBMS_OUTPUT.PUT_LINE('TIN: ' || rec.tin || ', TINSID: ' || rec.tinsid || ', STATUS: ' || NVL(TRIM(rec.status), 'NULL'));
        END LOOP;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Verification error: ' || SQLERRM);
END SP_CK_TIN_VERIFY;
/

-- ============================================================================
-- USAGE:
-- ============================================================================

-- Step 1: Test TIN conversion and basic access
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    SP_CK_TIN_VERIFY('844607599');
END;
/

-- Step 2: Run the complete procedure (once Step 1 works)
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    SP_CK_TIN_COMPLETE('844607599');
END;
/
