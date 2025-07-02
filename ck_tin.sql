-- Oracle Stored Procedure to replace cK_tin.sql script
-- This procedure replicates the exact functionality and output format

CREATE OR REPLACE PROCEDURE SP_CK_TIN (
    p_tin IN VARCHAR2,
    p_find_tinsid IN VARCHAR2 DEFAULT NULL,
    p_request_tinsid IN VARCHAR2 DEFAULT NULL,
    -- Output cursors for each query section
    cur_ent OUT SYS_REFCURSOR,
    cur_trantrail OUT SYS_REFCURSOR,
    cur_entmod OUT SYS_REFCURSOR,
    cur_entact OUT SYS_REFCURSOR,
    cur_timetin OUT SYS_REFCURSOR,
    -- Status output
    p_status OUT VARCHAR2,
    p_message OUT VARCHAR2
) AS
    v_tptin VARCHAR2(12);
    v_sid NUMBER;
    v_tinsid NUMBER;
    v_count NUMBER := 0;
    
    -- Exception handling
    e_no_data_found EXCEPTION;
    e_invalid_tin EXCEPTION;
    
BEGIN
    -- Initialize status
    p_status := 'SUCCESS';
    p_message := 'Procedure executed successfully';
    
    -- Validate input TIN
    IF p_tin IS NULL OR LENGTH(TRIM(p_tin)) = 0 THEN
        p_status := 'ERROR';
        p_message := 'TIN parameter is required';
        RETURN;
    END IF;
    
    -- Set the TIN variable (equivalent to the script's :tptin)
    v_tptin := REPLACE(p_tin, '-', '');
    
    BEGIN
        -- Get TINSID from ENT table (equivalent to the script's logic)
        SELECT tinsid, rownum 
        INTO v_tinsid, v_count
        FROM ent 
        WHERE tin = v_tptin 
        AND rownum = 1;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_status := 'WARNING';
            p_message := 'No data found for TIN: ' || p_tin;
            -- Set cursors to empty result sets
            OPEN cur_ent FOR SELECT NULL FROM DUAL WHERE 1=0;
            OPEN cur_trantrail FOR SELECT NULL FROM DUAL WHERE 1=0;
            OPEN cur_entmod FOR SELECT NULL FROM DUAL WHERE 1=0;
            OPEN cur_entact FOR SELECT NULL FROM DUAL WHERE 1=0;
            OPEN cur_timetin FOR SELECT NULL FROM DUAL WHERE 1=0;
            RETURN;
    END;
    
    -- Query 1: ENT table data
    OPEN cur_ent FOR
        SELECT tin, tinsid, tpctrl, totassd, status, caseind, pyrind,
               casecode, subcode, assncft, assngrp, risk, arisk,
               extrdt
        FROM ent 
        WHERE tin = v_tptin;
    
    -- Query 2: TRANTRAIL data
    OPEN cur_trantrail FOR
        SELECT t.tinsid, roid, segind, t.status, t.assnfld, t.assnno, t.closedt,
               t.extrdt, flag1, flag2, 
               DECODE(t.tinsid, roid, t.assnno, t.closedt) AS dspcd,
               DECODE(dispcd, org, emphrs) AS calculated_field
        FROM trantrail t, ent e
        WHERE tin = v_tptin
        AND t.tinsid = e.tinsid
        ORDER BY 1,7,4,2;
    
    -- Query 3: ENTMOD data  
    OPEN cur_entmod FOR
        SELECT emodsid, tinsid, roid, m.type, mft, period, m.pyrind,
               m.status, assnno, m.clsdt,
               dispcode, m.extrdt, flag1, flag2, typeid, balance
        FROM entmod m, ent e
        WHERE tin = v_tptin
        AND emodsid = tinsid
        ORDER BY emodsid, extrdt, mft, period;
    
    -- Query 4: ENTACT data
    OPEN cur_entact FOR
        SELECT actsid, tinsid, roid, aroid, a.typcd, typeid, mft, period, 
               actdt, dispcode, rptcd, rptdef,
               a.extrdt, amount, cc, tc
        FROM entact a, ent e
        WHERE e.tin = v_tptin
        AND actsid = tinsid
        ORDER BY actsid, actdt;
    
    -- Query 5: TIMETIN data
    OPEN cur_timetin FOR
        SELECT timesid, tinsid, roid, rptdt, t.extrdt, code, t.subcode, hours,
               e.grade AS egrd, t.grade AS tgrd, e.risk AS ersk, t.risk AS trsk
        FROM timetin t, ent e
        WHERE tin = v_tptin
        AND timesid = tinsid
        ORDER BY 1,4,3;

EXCEPTION
    WHEN OTHERS THEN
        p_status := 'ERROR';
        p_message := 'Unexpected error: ' || SQLERRM;
        
        -- Close any open cursors and set to empty result sets
        IF cur_ent%ISOPEN THEN CLOSE cur_ent; END IF;
        IF cur_trantrail%ISOPEN THEN CLOSE cur_trantrail; END IF;
        IF cur_entmod%ISOPEN THEN CLOSE cur_entmod; END IF;
        IF cur_entact%ISOPEN THEN CLOSE cur_entact; END IF;
        IF cur_timetin%ISOPEN THEN CLOSE cur_timetin; END IF;
        
        OPEN cur_ent FOR SELECT NULL FROM DUAL WHERE 1=0;
        OPEN cur_trantrail FOR SELECT NULL FROM DUAL WHERE 1=0;
        OPEN cur_entmod FOR SELECT NULL FROM DUAL WHERE 1=0;
        OPEN cur_entact FOR SELECT NULL FROM DUAL WHERE 1=0;
        OPEN cur_timetin FOR SELECT NULL FROM DUAL WHERE 1=0;
        
END SP_CK_TIN;
/

-- Alternative version: Single cursor with UNION ALL (if you prefer one result set)
CREATE OR REPLACE PROCEDURE SP_CK_TIN_SINGLE (
    p_tin IN VARCHAR2,
    cur_result OUT SYS_REFCURSOR,
    p_status OUT VARCHAR2,
    p_message OUT VARCHAR2
) AS
    v_tptin VARCHAR2(12);
    v_tinsid NUMBER;
    
BEGIN
    p_status := 'SUCCESS';
    p_message := 'Procedure executed successfully';
    
    IF p_tin IS NULL OR LENGTH(TRIM(p_tin)) = 0 THEN
        p_status := 'ERROR';
        p_message := 'TIN parameter is required';
        RETURN;
    END IF;
    
    v_tptin := REPLACE(p_tin, '-', '');
    
    -- Single result set with section indicators
    OPEN cur_result FOR
        SELECT 'ENT' as section_name, 1 as section_order,
               TO_CHAR(tin) as col1, TO_CHAR(tinsid) as col2, 
               TO_CHAR(tpctrl) as col3, TO_CHAR(totassd) as col4,
               TO_CHAR(status) as col5, TO_CHAR(caseind) as col6,
               TO_CHAR(pyrind) as col7, TO_CHAR(casecode) as col8,
               TO_CHAR(subcode) as col9, TO_CHAR(assncft) as col10,
               TO_CHAR(assngrp) as col11, TO_CHAR(risk) as col12,
               TO_CHAR(arisk) as col13, TO_CHAR(extrdt) as col14,
               '' as col15, '' as col16
        FROM ent 
        WHERE tin = v_tptin
        
        UNION ALL
        
        SELECT 'TRANTRAIL' as section_name, 2 as section_order,
               TO_CHAR(t.tinsid) as col1, TO_CHAR(roid) as col2,
               TO_CHAR(segind) as col3, TO_CHAR(t.status) as col4,
               TO_CHAR(t.assnfld) as col5, TO_CHAR(t.assnno) as col6,
               TO_CHAR(t.closedt) as col7, TO_CHAR(t.extrdt) as col8,
               TO_CHAR(flag1) as col9, TO_CHAR(flag2) as col10,
               TO_CHAR(DECODE(t.tinsid, roid, t.assnno, t.closedt)) as col11,
               '' as col12, '' as col13, '' as col14, '' as col15, '' as col16
        FROM trantrail t, ent e
        WHERE tin = v_tptin AND t.tinsid = e.tinsid
        
        UNION ALL
        
        SELECT 'ENTMOD' as section_name, 3 as section_order,
               TO_CHAR(emodsid) as col1, TO_CHAR(tinsid) as col2,
               TO_CHAR(roid) as col3, TO_CHAR(m.type) as col4,
               TO_CHAR(mft) as col5, TO_CHAR(period) as col6,
               TO_CHAR(m.pyrind) as col7, TO_CHAR(m.status) as col8,
               TO_CHAR(assnno) as col9, TO_CHAR(m.clsdt) as col10,
               TO_CHAR(dispcode) as col11, TO_CHAR(m.extrdt) as col12,
               TO_CHAR(flag1) as col13, TO_CHAR(flag2) as col14,
               TO_CHAR(typeid) as col15, TO_CHAR(balance) as col16
        FROM entmod m, ent e
        WHERE tin = v_tptin AND emodsid = tinsid
        
        UNION ALL
        
        SELECT 'ENTACT' as section_name, 4 as section_order,
               TO_CHAR(actsid) as col1, TO_CHAR(tinsid) as col2,
               TO_CHAR(roid) as col3, TO_CHAR(aroid) as col4,
               TO_CHAR(a.typcd) as col5, TO_CHAR(typeid) as col6,
               TO_CHAR(mft) as col7, TO_CHAR(period) as col8,
               TO_CHAR(actdt) as col9, TO_CHAR(dispcode) as col10,
               TO_CHAR(rptcd) as col11, TO_CHAR(rptdef) as col12,
               TO_CHAR(a.extrdt) as col13, TO_CHAR(amount) as col14,
               TO_CHAR(cc) as col15, TO_CHAR(tc) as col16
        FROM entact a, ent e
        WHERE e.tin = v_tptin AND actsid = tinsid
        
        UNION ALL
        
        SELECT 'TIMETIN' as section_name, 5 as section_order,
               TO_CHAR(timesid) as col1, TO_CHAR(tinsid) as col2,
               TO_CHAR(roid) as col3, TO_CHAR(rptdt) as col4,
               TO_CHAR(t.extrdt) as col5, TO_CHAR(code) as col6,
               TO_CHAR(t.subcode) as col7, TO_CHAR(hours) as col8,
               TO_CHAR(e.grade) as col9, TO_CHAR(t.grade) as col10,
               TO_CHAR(e.risk) as col11, TO_CHAR(t.risk) as col12,
               '' as col13, '' as col14, '' as col15, '' as col16
        FROM timetin t, ent e
        WHERE tin = v_tptin AND timesid = tinsid
        
        ORDER BY section_order, col1, col7, col4, col2;

EXCEPTION
    WHEN OTHERS THEN
        p_status := 'ERROR';
        p_message := 'Unexpected error: ' || SQLERRM;
        OPEN cur_result FOR SELECT NULL FROM DUAL WHERE 1=0;
        
END SP_CK_TIN_SINGLE;
/

-- Example usage for the multi-cursor version:
/*
DECLARE
    cur_ent SYS_REFCURSOR;
    cur_trantrail SYS_REFCURSOR;
    cur_entmod SYS_REFCURSOR;
    cur_entact SYS_REFCURSOR;
    cur_timetin SYS_REFCURSOR;
    v_status VARCHAR2(20);
    v_message VARCHAR2(500);
BEGIN
    SP_CK_TIN(
        p_tin => '123456789',
        cur_ent => cur_ent,
        cur_trantrail => cur_trantrail,
        cur_entmod => cur_entmod,
        cur_entact => cur_entact,
        cur_timetin => cur_timetin,
        p_status => v_status,
        p_message => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
    
    -- Process each cursor as needed
    -- Note: You would typically fetch from these cursors in your calling application
END;
/
*/

-- Example usage for the single cursor version:
/*
DECLARE
    cur_result SYS_REFCURSOR;
    v_status VARCHAR2(20);
    v_message VARCHAR2(500);
BEGIN
    SP_CK_TIN_SINGLE(
        p_tin => '123456789',
        cur_result => cur_result,
        p_status => v_status,
        p_message => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
    
    -- Process the result cursor as needed
END;
/
*/
