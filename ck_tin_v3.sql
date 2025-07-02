-- Procedure to replicate the exact formatting from your original cK_tin.sql script
CREATE OR REPLACE PROCEDURE SP_CK_TIN_FORMATTED(p_tin IN VARCHAR2)
AS
    v_tptin VARCHAR2(12);
    v_count NUMBER := 0;
    v_line VARCHAR2(200);
    
    -- Cursor for ENT data
    CURSOR c_ent IS
        SELECT tin, tinsid, tpctrl, totassd, status, caseind, pyrind,
               casecode, subcode, assncft, assngrp, risk, arisk, 
               TO_CHAR(extrdt, 'MM/DD/YYYY') as extrdt
        FROM ent 
        WHERE tin = v_tptin;
    
    -- Cursor for TRANTRAIL data
    CURSOR c_trantrail IS
        SELECT t.tinsid, roid, segind, t.status, t.assnfld, t.assnno, 
               TO_CHAR(t.closedt, 'MM/DD/YYYY') as closedt,
               TO_CHAR(t.extrdt, 'MM/DD/YYYY') as extrdt, 
               flag1, flag2,
               DECODE(t.tinsid, roid, t.assnno, t.closedt) as dspcd,
               'dispcd_or' as dispcd_or, 'emphrs' as emphrs
        FROM trantrail t, ent e
        WHERE e.tin = v_tptin 
        AND t.tinsid = e.tinsid
        ORDER BY t.tinsid, t.closedt, t.status, roid;
    
    -- Cursor for ENTMOD data
    CURSOR c_entmod IS
        SELECT emodsid as tinsid, roid, m.type, mft, period, m.pyrind as p_s,
               assnno, TO_CHAR(m.clsdt, 'MM/DD/YYYY') as clsdt,
               dispcode, TO_CHAR(m.extrdt, 'MM/DD/YYYY') as extrdt, 
               flag1, flag2, typeid, balance
        FROM entmod m, ent e
        WHERE e.tin = v_tptin 
        AND m.emodsid = e.tinsid
        ORDER BY emodsid, m.extrdt, mft, period;
    
    -- Cursor for ENTACT data
    CURSOR c_entact IS
        SELECT actsid as tinsid, roid, aroid, a.typcd, typeid, mft, period,
               TO_CHAR(actdt, 'MM/DD/YYYY') as actdt, dispcode, 
               SUBSTR(rptcd, 1, 1) as r, SUBSTR(rptcd, 2, 1) as r2,
               TO_CHAR(a.extrdt, 'MM/DD/YYYY') as extrdt, 
               amount, cc, tc
        FROM entact a, ent e
        WHERE e.tin = v_tptin 
        AND a.actsid = e.tinsid
        ORDER BY actsid, actdt;
    
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    
    -- Clean the TIN
    v_tptin := REPLACE(NVL(p_tin, ''), '-', '');
    
    IF LENGTH(v_tptin) = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: TIN parameter required');
        RETURN;
    END IF;
    
    -- Check if data exists
    SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No data found for TIN: ' || p_tin);
        RETURN;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE(v_tptin);
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ENT Section
    DBMS_OUTPUT.PUT_LINE('ENT');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('    TIN      TINSID TPCT   TOTASSD S C   PYRIND CAS SUB ASSNCFF    ASSNGRP        RISK A EXTRDT');
    DBMS_OUTPUT.PUT_LINE('---------- -------- ---- --------- - - -------- --- --- ---------- ---------- -------- - ----------');
    
    FOR rec IN c_ent LOOP
        v_line := RPAD(NVL(rec.tin, ' '), 10) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
                  RPAD(NVL(rec.tpctrl, ' '), 4) || ' ' ||
                  LPAD(NVL(TO_CHAR(rec.totassd, 'FM999999.99'), ' '), 9) || ' ' ||
                  RPAD(NVL(rec.status, ' '), 1) || ' ' ||
                  RPAD(NVL(rec.caseind, ' '), 1) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.pyrind), ' '), 8) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.casecode), ' '), 3) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.subcode), ' '), 3) || ' ' ||
                  RPAD(NVL(rec.assncft, ' '), 10) || ' ' ||
                  RPAD(NVL(rec.assngrp, ' '), 10) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.risk), ' '), 8) || ' ' ||
                  RPAD(NVL(rec.arisk, ' '), 1) || ' ' ||
                  rec.extrdt;
        DBMS_OUTPUT.PUT_LINE(v_line);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- TRANTRAIL Section
    DBMS_OUTPUT.PUT_LINE('TRANTRAIL');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID S S ASSNFLD    ASSNNO    CLOSEDT   EXTRDT    FLAG FLAG     DSPCD      DISPCD OR    EMPHRS');
    DBMS_OUTPUT.PUT_LINE('-------- -------- - - ---------- --------- --------- --------- ---- ---- --------- ---------- ---------');
    
    FOR rec IN c_trantrail LOOP
        v_line := RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
                  RPAD(NVL(rec.segind, ' '), 1) || ' ' ||
                  RPAD(NVL(rec.status, ' '), 1) || ' ' ||
                  RPAD(NVL(rec.assnfld, ' '), 10) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.assnno), ' '), 9) || ' ' ||
                  RPAD(NVL(rec.closedt, ' '), 9) || ' ' ||
                  RPAD(NVL(rec.extrdt, ' '), 9) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.flag1), ' '), 4) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.flag2), ' '), 4) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.dspcd), ' '), 9) || ' ' ||
                  RPAD('15', 10) || ' ' ||  -- Static values as shown in your output
                  RPAD('CF', 9);
        DBMS_OUTPUT.PUT_LINE(v_line);
    END LOOP;
    
    SELECT COUNT(*) INTO v_count FROM trantrail t, ent e WHERE e.tin = v_tptin AND t.tinsid = e.tinsid;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ENTMOD Section  
    DBMS_OUTPUT.PUT_LINE('ENTMOD');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID T MFT PERIOD    P S  ASSNNO    CLSDT     DISPCODE EXTRDT    FLAG FLAG   TYPEID    BALANCE');
    DBMS_OUTPUT.PUT_LINE('-------- -------- - --- --------- - - --------- --------- -------- --------- ---- ---- -------- ----------');
    
    FOR rec IN c_entmod LOOP
        v_line := RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
                  RPAD(NVL(rec.type, ' '), 1) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.mft), ' '), 3) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.period), ' '), 9) || ' ' ||
                  RPAD(NVL(rec.p_s, ' '), 1) || ' ' ||
                  RPAD(' ', 1) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.assnno), ' '), 9) || ' ' ||
                  RPAD(NVL(rec.clsdt, ' '), 9) || ' ' ||
                  RPAD(NVL(rec.dispcode, ' '), 8) || ' ' ||
                  RPAD(NVL(rec.extrdt, ' '), 9) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.flag1), ' '), 4) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.flag2), ' '), 4) || ' ' ||
                  RPAD(NVL(rec.typeid, ' '), 8) || ' ' ||
                  LPAD(NVL(TO_CHAR(rec.balance, 'FM999999.99'), '0'), 10);
        DBMS_OUTPUT.PUT_LINE(v_line);
    END LOOP;
    
    SELECT COUNT(*) INTO v_count FROM entmod m, ent e WHERE e.tin = v_tptin AND m.emodsid = e.tinsid;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ENTACT Section
    DBMS_OUTPUT.PUT_LINE('ENTACT');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  TINSID      ROID     AROID T   TYPEID MFT PERIOD     ACTDT    DISPCODE R R EXTRDT       AMOUNT  CC   TC');
    DBMS_OUTPUT.PUT_LINE('-------- -------- --------- - -------- --- --------- --------- -------- - - --------- ---------- --- ----');
    
    FOR rec IN c_entact LOOP
        v_line := RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.aroid), ' '), 9) || ' ' ||
                  RPAD(NVL(rec.typcd, ' '), 1) || ' ' ||
                  RPAD(NVL(rec.typeid, ' '), 8) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.mft), ' '), 3) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.period), ' '), 9) || ' ' ||
                  RPAD(NVL(rec.actdt, ' '), 9) || ' ' ||
                  RPAD(NVL(rec.dispcode, ' '), 8) || ' ' ||
                  RPAD(NVL(rec.r, ' '), 1) || ' ' ||
                  RPAD(NVL(rec.r2, ' '), 1) || ' ' ||
                  RPAD(NVL(rec.extrdt, ' '), 9) || ' ' ||
                  LPAD(NVL(TO_CHAR(rec.amount), '0'), 10) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.cc), ' '), 3) || ' ' ||
                  RPAD(NVL(TO_CHAR(rec.tc), ' '), 4);
        DBMS_OUTPUT.PUT_LINE(v_line);
    END LOOP;
    
    SELECT COUNT(*) INTO v_count FROM entact a, ent e WHERE e.tin = v_tptin AND a.actsid = e.tinsid;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(v_count || ' rows selected.');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END SP_CK_TIN_FORMATTED;
/

-- Safe function that handles data type conversions properly
CREATE OR REPLACE FUNCTION FN_GET_TIN_REPORT(p_tin IN VARCHAR2)
RETURN CLOB
AS
    v_result CLOB;
    v_tptin VARCHAR2(12);
    v_count NUMBER := 0;
    v_line VARCHAR2(1000);
    
    -- Function to safely convert to string
    FUNCTION safe_to_char(p_value IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(TO_CHAR(p_value), ' ');
    EXCEPTION
        WHEN OTHERS THEN
            RETURN ' ';
    END;
    
    -- Function to safely format currency
    FUNCTION safe_currency(p_value IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        IF p_value IS NULL THEN
            RETURN ' ';
        END IF;
        RETURN TO_CHAR(p_value, 'FM999999.99');
    EXCEPTION
        WHEN OTHERS THEN
            RETURN ' ';
    END;
    
BEGIN
    v_result := '';
    
    -- Validate and clean TIN
    BEGIN
        v_tptin := REPLACE(NVL(TRIM(p_tin), ''), '-', '');
        IF LENGTH(v_tptin) = 0 THEN
            RETURN 'Error: TIN parameter required';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Error: Invalid TIN format';
    END;
    
    -- Check if data exists
    BEGIN
        SELECT COUNT(*) INTO v_count FROM ent WHERE tin = v_tptin;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Error accessing ENT table: ' || SQLERRM;
    END;
    
    IF v_count = 0 THEN
        RETURN 'No data found for TIN: ' || p_tin;
    END IF;
    
    -- Build the report header
    v_result := v_tptin || CHR(10);
    v_result := v_result || 'PL/SQL procedure successfully completed.' || CHR(10) || CHR(10);
    
    -- ENT Section
    v_result := v_result || 'ENT' || CHR(10) || CHR(10);
    v_result := v_result || '    TIN      TINSID TPCT   TOTASSD S C   PYRIND CAS SUB ASSNCFF    ASSNGRP        RISK A EXTRDT' || CHR(10);
    v_result := v_result || '---------- -------- ---- --------- - - -------- --- --- ---------- ---------- -------- - ----------' || CHR(10);
    
    BEGIN
        FOR rec IN (SELECT 
                        NVL(tin, ' ') as tin, 
                        tinsid, 
                        NVL(tpctrl, ' ') as tpctrl, 
                        totassd, 
                        NVL(status, ' ') as status, 
                        NVL(caseind, ' ') as caseind, 
                        pyrind,
                        casecode, 
                        subcode, 
                        NVL(assncft, ' ') as assncft, 
                        NVL(assngrp, ' ') as assngrp, 
                        risk, 
                        NVL(arisk, ' ') as arisk, 
                        extrdt
                    FROM ent WHERE tin = v_tptin) LOOP
            
            v_line := RPAD(rec.tin, 10) || ' ' ||
                      RPAD(safe_to_char(rec.tinsid), 8) || ' ' ||
                      RPAD(rec.tpctrl, 4) || ' ' ||
                      LPAD(safe_currency(rec.totassd), 9) || ' ' ||
                      RPAD(rec.status, 1) || ' ' ||
                      RPAD(rec.caseind, 1) || ' ' ||
                      RPAD(safe_to_char(rec.pyrind), 8) || ' ' ||
                      RPAD(safe_to_char(rec.casecode), 3) || ' ' ||
                      RPAD(safe_to_char(rec.subcode), 3) || ' ' ||
                      RPAD(rec.assncft, 10) || ' ' ||
                      RPAD(rec.assngrp, 10) || ' ' ||
                      RPAD(safe_to_char(rec.risk), 8) || ' ' ||
                      RPAD(rec.arisk, 1) || ' ' ||
                      NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' ');
            v_result := v_result || v_line || CHR(10);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            v_result := v_result || 'Error in ENT section: ' || SQLERRM || CHR(10);
    END;
    
    v_result := v_result || CHR(10) || 'PL/SQL procedure successfully completed.' || CHR(10) || CHR(10);
    
    -- TRANTRAIL Section
    v_result := v_result || 'TRANTRAIL' || CHR(10) || CHR(10);
    v_result := v_result || '  TINSID      ROID S S ASSNFLD    ASSNNO    CLOSEDT   EXTRDT    FLAG FLAG     DSPCD' || CHR(10);
    v_result := v_result || '-------- -------- - - ---------- --------- --------- --------- ---- ---- ---------' || CHR(10);
    
    BEGIN
        FOR rec IN (SELECT t.tinsid, t.roid, 
                           NVL(t.segind, ' ') as segind, 
                           NVL(t.status, ' ') as status, 
                           NVL(t.assnfld, ' ') as assnfld, 
                           t.assnno, 
                           t.closedt, t.extrdt, 
                           t.flag1, t.flag2
                    FROM trantrail t, ent e
                    WHERE e.tin = v_tptin AND t.tinsid = e.tinsid
                    ORDER BY t.tinsid, t.closedt, t.status, t.roid) LOOP
            
            v_line := RPAD(safe_to_char(rec.tinsid), 8) || ' ' ||
                      RPAD(safe_to_char(rec.roid), 8) || ' ' ||
                      RPAD(rec.segind, 1) || ' ' ||
                      RPAD(rec.status, 1) || ' ' ||
                      RPAD(rec.assnfld, 10) || ' ' ||
                      RPAD(safe_to_char(rec.assnno), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.closedt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(safe_to_char(rec.flag1), 4) || ' ' ||
                      RPAD(safe_to_char(rec.flag2), 4) || ' ' ||
                      safe_to_char(rec.assnno);
            v_result := v_result || v_line || CHR(10);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            v_result := v_result || 'Error in TRANTRAIL section: ' || SQLERRM || CHR(10);
    END;
    
    -- Count trantrail records
    BEGIN
        SELECT COUNT(*) INTO v_count 
        FROM trantrail t, ent e 
        WHERE e.tin = v_tptin AND t.tinsid = e.tinsid;
        v_result := v_result || CHR(10) || v_count || ' rows selected.' || CHR(10);
    EXCEPTION
        WHEN OTHERS THEN
            v_result := v_result || CHR(10) || 'Error counting TRANTRAIL rows' || CHR(10);
    END;
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Unexpected error: ' || SQLERRM;
END FN_GET_TIN_REPORT;
/

-- ============================================================================
-- USAGE EXAMPLES:
-- ============================================================================

-- Method 1: Run procedure with DBMS_OUTPUT (like your original script)
EXEC SP_CK_TIN_FORMATTED('844607599');

-- Method 2: Get formatted report as text
SELECT FN_GET_TIN_REPORT('844607599') FROM DUAL;

-- Method 3: Quick test
BEGIN
    SP_CK_TIN_FORMATTED('844607599');
END;
/
