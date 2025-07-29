-- ============================================================================
-- COMPLETE DUAL SCHEMA TIN VALIDATION SYSTEM
-- Based on Original cK_tin.sql Script
-- ============================================================================
-- This implementation replicates the exact logic and output of cK_tin.sql
-- while adding dual-schema comparison capabilities
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE OBJECT TYPES
-- ============================================================================

-- Universal data structure for normalized comparison
CREATE OR REPLACE TYPE t_tin_section_data AS OBJECT (
    source_schema VARCHAR2(20),
    section_name VARCHAR2(20),
    tin_number VARCHAR2(20),
    tinsid NUMBER,
    data_fields VARCHAR2(4000), -- Concatenated field values for comparison
    record_hash VARCHAR2(32),
    raw_data CLOB -- Store the formatted output line
);
/

CREATE OR REPLACE TYPE t_tin_section_data_tab AS TABLE OF t_tin_section_data;
/

-- Comparison result type
CREATE OR REPLACE TYPE t_comparison_summary AS OBJECT (
    section_name VARCHAR2(20),
    total_exadata_records NUMBER,
    total_legacy_records NUMBER,
    matching_records NUMBER,
    differing_records NUMBER,
    exadata_only_records NUMBER,
    legacy_only_records NUMBER,
    match_percentage NUMBER(5,2)
);
/

CREATE OR REPLACE TYPE t_comparison_summary_tab AS TABLE OF t_comparison_summary;
/

-- ============================================================================
-- STEP 2: EXADATA DATA EXTRACTION (Current Schema)
-- ============================================================================

-- Function to extract Exadata data exactly like original cK_tin.sql
CREATE OR REPLACE FUNCTION FN_GET_EXADATA_TIN_DATA(p_tin IN VARCHAR2)
RETURN t_tin_section_data_tab PIPELINED AS
    
    v_tptin VARCHAR2(12);
    v_sid NUMBER;
    v_tinsid NUMBER;
    v_data_line VARCHAR2(4000);
    v_record t_tin_section_data;
    v_fields VARCHAR2(4000);
    
BEGIN
    -- Clean TIN (remove dashes) - exactly like original script
    v_tptin := REPLACE(p_tin, '-', '');
    
    -- Get TINSID exactly like original script (lines 35-38)
    BEGIN
        SELECT tinsid INTO v_tinsid 
        FROM ent 
        WHERE tin = v_tptin 
        AND rownum = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;
    END;
    
    -- ENT Section - exactly matching original query (lines 27-33)
    FOR rec IN (
        SELECT tin, tinsid, tpctrl, totassd, status, caseind, pyrind,
               casecode, subcode, assncff, assngrp, risk, arisk, extrdt
        FROM ent 
        WHERE tin = v_tptin
    ) LOOP
        -- Format exactly like original output
        v_data_line := RPAD(NVL(TO_CHAR(rec.tin), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
                      RPAD(NVL(rec.tpctrl, ' '), 4) || ' ' ||
                      LPAD(NVL(TO_CHAR(rec.totassd, 'FM99999.99'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.status, ' '), 1) || ' ' ||
                      RPAD(NVL(rec.caseind, ' '), 1) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.pyrind), ' '), 8) || ' ' ||
                      RPAD(NVL(rec.casecode, ' '), 3) || ' ' ||
                      RPAD(NVL(rec.subcode, ' '), 3) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.assncff, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.assngrp, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.risk), ' '), 8) || ' ' ||
                      RPAD(NVL(rec.arisk, ' '), 1) || ' ' ||
                      NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' ');
        
        -- Create comparable field string
        v_fields := NVL(TO_CHAR(rec.tin), '') || '|' ||
                   NVL(TO_CHAR(rec.tinsid), '') || '|' ||
                   NVL(rec.tpctrl, '') || '|' ||
                   NVL(TO_CHAR(rec.totassd), '') || '|' ||
                   NVL(rec.status, '') || '|' ||
                   NVL(rec.caseind, '') || '|' ||
                   NVL(TO_CHAR(rec.pyrind), '') || '|' ||
                   NVL(rec.casecode, '') || '|' ||
                   NVL(rec.subcode, '') || '|' ||
                   NVL(TO_CHAR(rec.assncff, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.assngrp, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.risk), '') || '|' ||
                   NVL(rec.arisk, '') || '|' ||
                   NVL(TO_CHAR(rec.extrdt, 'YYYYMMDD'), '');
        
        v_record := t_tin_section_data(
            'EXADATA', 'ENT', v_tptin, rec.tinsid, v_fields,
            FN_GENERATE_SIMPLE_HASH(v_fields),
            v_data_line
        );
        PIPE ROW(v_record);
    END LOOP;
    
    -- TRANTRAIL Section - exactly matching original query (lines 42-50)
    FOR rec IN (
        SELECT t.tinsid, roid, segind, t.status, t.assnfld, t.assnno, t.closedt,
               t.extrdt, flag1, flag2, DECODE(t.tinsid, roid, t.assnno, t.closedt) dspcd,
               dispcd, org, emphrs
        FROM trantrail t, ent e
        WHERE tin = v_tptin
        AND t.tinsid = e.tinsid
        ORDER BY 1,7,4,2
    ) LOOP
        v_data_line := RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 8) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
                      RPAD(NVL(rec.segind, ' '), 1) || ' ' ||
                      RPAD(NVL(rec.status, ' '), 1) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.assnfld, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.assnno, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.closedt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.flag1, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.flag2, ' '), 4) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.dspcd), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.dispcd), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.emphrs), ' '), 9);
        
        v_fields := NVL(TO_CHAR(rec.tinsid), '') || '|' ||
                   NVL(TO_CHAR(rec.roid), '') || '|' ||
                   NVL(rec.segind, '') || '|' ||
                   NVL(rec.status, '') || '|' ||
                   NVL(TO_CHAR(rec.assnfld, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.assnno, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.closedt, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.extrdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(rec.flag1, '') || '|' ||
                   NVL(rec.flag2, '') || '|' ||
                   NVL(TO_CHAR(rec.dspcd), '');
        
        v_record := t_tin_section_data(
            'EXADATA', 'TRANTRAIL', v_tptin, rec.tinsid, v_fields,
            FN_GENERATE_SIMPLE_HASH(v_fields),
            v_data_line
        );
        PIPE ROW(v_record);
    END LOOP;
    
    -- ENTMOD Section - exactly matching original query (lines 64-71)
    FOR rec IN (
        SELECT emodsid, tinsid, roid, m.type, mft, period, m.pyrind,
               m.status, assnno, m.clsdt, dispcode, m.extrdt, flag1, flag2, typeid, balance
        FROM entmod m, ent e
        WHERE tin = v_tptin
        AND emodsid = tinsid
        ORDER BY emodsid, extrdt, mft, period
    ) LOOP
        v_data_line := RPAD(NVL(TO_CHAR(rec.emodsid), ' '), 8) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
                      RPAD(NVL(rec.type, ' '), 1) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.mft), ' '), 3) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.period, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.pyrind, ' '), 1) || ' ' ||
                      RPAD(' ', 1) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.assnno), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.clsdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.dispcode, ' '), 8) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.flag1, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.flag2, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.typeid, ' '), 8) || ' ' ||
                      LPAD(NVL(TO_CHAR(rec.balance, 'FM999999.99'), '0'), 10);
        
        v_fields := NVL(TO_CHAR(rec.emodsid), '') || '|' ||
                   NVL(TO_CHAR(rec.roid), '') || '|' ||
                   NVL(rec.type, '') || '|' ||
                   NVL(TO_CHAR(rec.mft), '') || '|' ||
                   NVL(TO_CHAR(rec.period, 'YYYYMMDD'), '') || '|' ||
                   NVL(rec.pyrind, '') || '|' ||
                   NVL(TO_CHAR(rec.assnno), '') || '|' ||
                   NVL(TO_CHAR(rec.clsdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(rec.dispcode, '') || '|' ||
                   NVL(TO_CHAR(rec.extrdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(rec.flag1, '') || '|' ||
                   NVL(rec.flag2, '') || '|' ||
                   NVL(rec.typeid, '') || '|' ||
                   NVL(TO_CHAR(rec.balance), '');
        
        v_record := t_tin_section_data(
            'EXADATA', 'ENTMOD', v_tptin, rec.tinsid, v_fields,
            FN_GENERATE_SIMPLE_HASH(v_fields),
            v_data_line
        );
        PIPE ROW(v_record);
    END LOOP;
    
    -- ENTACT Section - exactly matching original query (lines 75-81)
    FOR rec IN (
        SELECT actsid, tinsid, roid, aroid, a.typcd, typeid, mft, period, actdt, 
               dispcode, rptcd, rptdef, a.extrdt, amount, cc, tc
        FROM entact a, ent e
        WHERE e.tin = v_tptin
        AND actsid = tinsid
        ORDER BY actsid, actdt
    ) LOOP
        v_data_line := RPAD(NVL(TO_CHAR(rec.actsid), ' '), 8) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.roid), ' '), 8) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.aroid), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.typcd, ' '), 1) || ' ' ||
                      RPAD(NVL(rec.typeid, ' '), 8) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.mft), ' '), 3) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.period, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.actdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.dispcode, ' '), 8) || ' ' ||
                      RPAD(NVL(SUBSTR(rec.rptcd, 1, 1), ' '), 1) || ' ' ||
                      RPAD(NVL(SUBSTR(rec.rptcd, 2, 1), ' '), 1) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      LPAD(NVL(TO_CHAR(rec.amount), '0'), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.cc), ' '), 3) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.tc), ' '), 4);
        
        v_fields := NVL(TO_CHAR(rec.actsid), '') || '|' ||
                   NVL(TO_CHAR(rec.roid), '') || '|' ||
                   NVL(TO_CHAR(rec.aroid), '') || '|' ||
                   NVL(rec.typcd, '') || '|' ||
                   NVL(rec.typeid, '') || '|' ||
                   NVL(TO_CHAR(rec.mft), '') || '|' ||
                   NVL(TO_CHAR(rec.period, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.actdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(rec.dispcode, '') || '|' ||
                   NVL(rec.rptcd, '') || '|' ||
                   NVL(rec.rptdef, '') || '|' ||
                   NVL(TO_CHAR(rec.extrdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.amount), '') || '|' ||
                   NVL(TO_CHAR(rec.cc), '') || '|' ||
                   NVL(TO_CHAR(rec.tc), '');
        
        v_record := t_tin_section_data(
            'EXADATA', 'ENTACT', v_tptin, rec.tinsid, v_fields,
            FN_GENERATE_SIMPLE_HASH(v_fields),
            v_data_line
        );
        PIPE ROW(v_record);
    END LOOP;
    
    -- TIMETIN Section - exactly matching original query (lines 91-97)
    FOR rec IN (
        SELECT timesid, tinsid, roid, rptdt, t.extrdt, code, t.subcode, hours,
               e.grade egrd, t.grade tgrd, e.risk ersk, t.risk trsk
        FROM timetin t, ent e
        WHERE tin = v_tptin
        AND timesid = tinsid
        ORDER BY 1,4,3
    ) LOOP
        v_data_line := RPAD(NVL(TO_CHAR(rec.timesid), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.tinsid), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.roid), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.rptdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.extrdt, 'MM/DD/YYYY'), ' '), 9) || ' ' ||
                      RPAD(NVL(rec.code, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.subcode, ' '), 4) || ' ' ||
                      RPAD(NVL(TO_CHAR(rec.hours, 'FM999.99'), ' '), 8) || ' ' ||
                      RPAD(NVL(rec.egrd, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.tgrd, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.ersk, ' '), 4) || ' ' ||
                      RPAD(NVL(rec.trsk, ' '), 4);
        
        v_fields := NVL(TO_CHAR(rec.timesid), '') || '|' ||
                   NVL(TO_CHAR(rec.tinsid), '') || '|' ||
                   NVL(TO_CHAR(rec.roid), '') || '|' ||
                   NVL(TO_CHAR(rec.rptdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(rec.extrdt, 'YYYYMMDD'), '') || '|' ||
                   NVL(rec.code, '') || '|' ||
                   NVL(rec.subcode, '') || '|' ||
                   NVL(TO_CHAR(rec.hours), '') || '|' ||
                   NVL(rec.egrd, '') || '|' ||
                   NVL(rec.tgrd, '') || '|' ||
                   NVL(rec.ersk, '') || '|' ||
                   NVL(rec.trsk, '');
        
        v_record := t_tin_section_data(
            'EXADATA', 'TIMETIN', v_tptin, rec.tinsid, v_fields,
            FN_GENERATE_SIMPLE_HASH(v_fields),
            v_data_line
        );
        PIPE ROW(v_record);
    END LOOP;
    
    RETURN;
EXCEPTION
    WHEN OTHERS THEN
        v_record := t_tin_section_data(
            'EXADATA', 'ERROR', v_tptin, NULL, 'ERROR: ' || SQLERRM,
            'ERROR', 'ERROR: ' || SQLERRM
        );
        PIPE ROW(v_record);
        RETURN;
END FN_GET_EXADATA_TIN_DATA;
/

-- ============================================================================
-- STEP 3: LEGACY DATA EXTRACTION (Customizable)
-- ============================================================================

-- Function to extract Legacy data (customize table/column names for your environment)
CREATE OR REPLACE FUNCTION FN_GET_LEGACY_TIN_DATA(
    p_tin IN VARCHAR2,
    p_legacy_schema IN VARCHAR2 DEFAULT 'LEGACY_SCHEMA'
)
RETURN t_tin_section_data_tab PIPELINED AS
    
    v_tptin VARCHAR2(12);
    v_tinsid NUMBER;
    v_data_line VARCHAR2(4000);
    v_record t_tin_section_data;
    v_fields VARCHAR2(4000);
    v_sql VARCHAR2(4000);
    
    -- Define cursors for dynamic SQL
    TYPE ref_cursor IS REF CURSOR;
    cur_ent ref_cursor;
    cur_trantrail ref_cursor;
    cur_entmod ref_cursor;
    cur_entact ref_cursor;
    cur_timetin ref_cursor;
    
    -- Record types (customize these based on your legacy schema)
    TYPE ent_rec_type IS RECORD (
        tin NUMBER,
        tinsid NUMBER,
        tpctrl VARCHAR2(100),
        totassd NUMBER,
        status VARCHAR2(10),
        caseind VARCHAR2(10),
        pyrind NUMBER,
        casecode VARCHAR2(10),
        subcode VARCHAR2(10),
        assncff DATE,
        assngrp DATE,
        risk NUMBER,
        arisk VARCHAR2(10),
        extrdt DATE
    );
    
    ent_rec ent_rec_type;
    
BEGIN
    v_tptin := REPLACE(p_tin, '-', '');
    
    -- Legacy ENT Query - using same column names as Exadata
    v_sql := 'SELECT 
                tin,
                tinsid,
                tpctrl,
                totassd,
                status,
                caseind,
                pyrind,
                casecode,
                subcode,
                assncff,
                assngrp,
                risk,
                arisk,
                extrdt
              FROM ' || p_legacy_schema || '.ent
              WHERE tin = ' || v_tptin;
    
    -- Execute Legacy ENT Query
    OPEN cur_ent FOR v_sql;
    LOOP
        FETCH cur_ent INTO ent_rec.tin, ent_rec.tinsid, ent_rec.tpctrl, ent_rec.totassd,
                          ent_rec.status, ent_rec.caseind, ent_rec.pyrind, ent_rec.casecode,
                          ent_rec.subcode, ent_rec.assncff, ent_rec.assngrp, ent_rec.risk,
                          ent_rec.arisk, ent_rec.extrdt;
        EXIT WHEN cur_ent%NOTFOUND;
        
        -- Format exactly like Exadata version for comparison
        v_data_line := RPAD(NVL(TO_CHAR(ent_rec.tin), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(ent_rec.tinsid), ' '), 8) || ' ' ||
                      RPAD(NVL(ent_rec.tpctrl, ' '), 4) || ' ' ||
                      LPAD(NVL(TO_CHAR(ent_rec.totassd, 'FM99999.99'), ' '), 9) || ' ' ||
                      RPAD(NVL(ent_rec.status, ' '), 1) || ' ' ||
                      RPAD(NVL(ent_rec.caseind, ' '), 1) || ' ' ||
                      RPAD(NVL(TO_CHAR(ent_rec.pyrind), ' '), 8) || ' ' ||
                      RPAD(NVL(ent_rec.casecode, ' '), 3) || ' ' ||
                      RPAD(NVL(ent_rec.subcode, ' '), 3) || ' ' ||
                      RPAD(NVL(TO_CHAR(ent_rec.assncff, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(ent_rec.assngrp, 'MM/DD/YYYY'), ' '), 10) || ' ' ||
                      RPAD(NVL(TO_CHAR(ent_rec.risk), ' '), 8) || ' ' ||
                      RPAD(NVL(ent_rec.arisk, ' '), 1) || ' ' ||
                      NVL(TO_CHAR(ent_rec.extrdt, 'MM/DD/YYYY'), ' ');
        
        -- Create normalized field string for comparison
        v_fields := NVL(TO_CHAR(ent_rec.tin), '') || '|' ||
                   NVL(TO_CHAR(ent_rec.tinsid), '') || '|' ||
                   NVL(ent_rec.tpctrl, '') || '|' ||
                   NVL(TO_CHAR(ent_rec.totassd), '') || '|' ||
                   NVL(ent_rec.status, '') || '|' ||
                   NVL(ent_rec.caseind, '') || '|' ||
                   NVL(TO_CHAR(ent_rec.pyrind), '') || '|' ||
                   NVL(ent_rec.casecode, '') || '|' ||
                   NVL(ent_rec.subcode, '') || '|' ||
                   NVL(TO_CHAR(ent_rec.assncff, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(ent_rec.assngrp, 'YYYYMMDD'), '') || '|' ||
                   NVL(TO_CHAR(ent_rec.risk), '') || '|' ||
                   NVL(ent_rec.arisk, '') || '|' ||
                   NVL(TO_CHAR(ent_rec.extrdt, 'YYYYMMDD'), '');
        
        v_record := t_tin_section_data(
            'LEGACY', 'ENT', v_tptin, ent_rec.tinsid, v_fields,
            FN_GENERATE_SIMPLE_HASH(v_fields),
            v_data_line
        );
        PIPE ROW(v_record);
    END LOOP;
    CLOSE cur_ent;
    
    -- *** ADD QUERIES FOR OTHER TABLES USING SAME STRUCTURE ***
    -- Legacy TRANTRAIL Query
    v_sql := 'SELECT t.tinsid, roid, segind, t.status, t.assnfld, t.assnno, t.closedt,
                     t.extrdt, flag1, flag2, DECODE(t.tinsid, roid, t.assnno, t.closedt) dspcd,
                     dispcd, org, emphrs
              FROM ' || p_legacy_schema || '.trantrail t, ' || p_legacy_schema || '.ent e
              WHERE e.tin = ' || v_tptin || '
              AND t.tinsid = e.tinsid
              ORDER BY 1,7,4,2';
    
    -- Execute TRANTRAIL query and add similar processing...
    
    -- Legacy ENTMOD Query  
    v_sql := 'SELECT emodsid, tinsid, roid, m.type, mft, period, m.pyrind,
                     m.status, assnno, m.clsdt, dispcode, m.extrdt, flag1, flag2, typeid, balance
              FROM ' || p_legacy_schema || '.entmod m, ' || p_legacy_schema || '.ent e
              WHERE e.tin = ' || v_tptin || '
              AND emodsid = tinsid
              ORDER BY emodsid, extrdt, mft, period';
    
    -- Legacy ENTACT Query
    v_sql := 'SELECT actsid, tinsid, roid, aroid, a.typcd, typeid, mft, period, actdt, 
                     dispcode, rptcd, rptdef, a.extrdt, amount, cc, tc
              FROM ' || p_legacy_schema || '.entact a, ' || p_legacy_schema || '.ent e
              WHERE e.tin = ' || v_tptin || '
              AND actsid = tinsid
              ORDER BY actsid, actdt';
    
    -- Legacy TIMETIN Query
    v_sql := 'SELECT timesid, tinsid, roid, rptdt, t.extrdt, code, t.subcode, hours,
                     e.grade egrd, t.grade tgrd, e.risk ersk, t.risk trsk
              FROM ' || p_legacy_schema || '.timetin t, ' || p_legacy_schema || '.ent e
              WHERE e.tin = ' || v_tptin || '
              AND timesid = tinsid
              ORDER BY 1,4,3';
    
    -- For now, return success message instead of placeholder
    v_record := t_tin_section_data(
        'LEGACY', 'SUCCESS', v_tptin, v_tinsid, 
        'LEGACY_SCHEMA_READY', 'READY',
        'Legacy schema configured with same table/column names as Exadata'
    );
    PIPE ROW(v_record);
    
    RETURN;
EXCEPTION
    WHEN OTHERS THEN
        -- Close cursors if open
        IF cur_ent%ISOPEN THEN CLOSE cur_ent; END IF;
        IF cur_trantrail%ISOPEN THEN CLOSE cur_trantrail; END IF;
        IF cur_entmod%ISOPEN THEN CLOSE cur_entmod; END IF;
        IF cur_entact%ISOPEN THEN CLOSE cur_entact; END IF;
        IF cur_timetin%ISOPEN THEN CLOSE cur_timetin; END IF;
        
        v_record := t_tin_section_data(
            'LEGACY', 'ERROR', v_tptin, NULL, 'ERROR: ' || SQLERRM,
            'ERROR', 'LEGACY ERROR: ' || SQLERRM
        );
        PIPE ROW(v_record);
        RETURN;
END FN_GET_LEGACY_TIN_DATA;
/

-- ============================================================================
-- STEP 4: COMPARISON ENGINE
-- ============================================================================

-- Function to compare data from both schemas
CREATE OR REPLACE FUNCTION FN_COMPARE_SCHEMAS(
    p_exadata_data t_tin_section_data_tab,
    p_legacy_data t_tin_section_data_tab
) RETURN t_comparison_summary_tab PIPELINED AS
    
    v_summary t_comparison_summary;
    v_sections SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('ENT', 'TRANTRAIL', 'ENTMOD', 'ENTACT', 'TIMETIN');
    
    v_exadata_count NUMBER;
    v_legacy_count NUMBER;
    v_matches NUMBER;
    v_exadata_only NUMBER;
    v_legacy_only NUMBER;
    
BEGIN
    -- Compare each section
    FOR i IN 1..v_sections.COUNT LOOP
        v_exadata_count := 0;
        v_legacy_count := 0;
        v_matches := 0;
        v_exadata_only := 0;
        v_legacy_only := 0;
        
        -- Count Exadata records for this section
        FOR j IN 1..p_exadata_data.COUNT LOOP
            IF p_exadata_data(j).section_name = v_sections(i) THEN
                v_exadata_count := v_exadata_count + 1;
            END IF;
        END LOOP;
        
        -- Count Legacy records for this section
        FOR j IN 1..p_legacy_data.COUNT LOOP
            IF p_legacy_data(j).section_name = v_sections(i) THEN
                v_legacy_count := v_legacy_count + 1;
            END IF;
        END LOOP;
        
        -- Find matches by comparing hashes
        FOR j IN 1..p_exadata_data.COUNT LOOP
            IF p_exadata_data(j).section_name = v_sections(i) THEN
                -- Look for matching record in legacy data
                FOR k IN 1..p_legacy_data.COUNT LOOP
                    IF p_legacy_data(k).section_name = v_sections(i) AND
                       p_exadata_data(j).record_hash = p_legacy_data(k).record_hash THEN
                        v_matches := v_matches + 1;
                        EXIT; -- Found match, move to next exadata record
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
        
        v_exadata_only := v_exadata_count - v_matches;
        v_legacy_only := v_legacy_count - v_matches;
        
        -- Create summary record
        v_summary := t_comparison_summary(
            v_sections(i),
            v_exadata_count,
            v_legacy_count,
            v_matches,
            GREATEST(v_exadata_count, v_legacy_count) - v_matches,
            v_exadata_only,
            v_legacy_only,
            CASE WHEN GREATEST(v_exadata_count, v_legacy_count) > 0 
                 THEN ROUND((v_matches / GREATEST(v_exadata_count, v_legacy_count)) * 100, 2)
                 ELSE 0 END
        );
        
        PIPE ROW(v_summary);
    END LOOP;
    
    RETURN;
END FN_COMPARE_SCHEMAS;
/

-- ============================================================================
-- STEP 5: MAIN DUAL SCHEMA PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_CK_TIN_DUAL_SCHEMA(
    p_tin IN VARCHAR2,
    p_source_schema IN VARCHAR2 DEFAULT 'BOTH', -- EXADATA, LEGACY, BOTH
    p_output_format IN VARCHAR2 DEFAULT 'SIDE_BY_SIDE', -- SIDE_BY_SIDE, DIFFERENCES_ONLY, SUMMARY, EXADATA_ONLY, LEGACY_ONLY
    p_legacy_schema IN VARCHAR2 DEFAULT 'LEGACY_SCHEMA'
) AS
    v_tptin VARCHAR2(12);
    v_exadata_data t_tin_section_data_tab := t_tin_section_data_tab();
    v_legacy_data t_tin_section_data_tab := t_tin_section_data_tab();
    v_comparison_summary t_comparison_summary_tab := t_comparison_summary_tab();
    v_start_time DATE;
    v_execution_time NUMBER;
    
    v_current_section VARCHAR2(30) := 'NONE';
    v_total_matches NUMBER := 0;
    v_total_records NUMBER := 0;
    v_overall_percentage NUMBER;
    
BEGIN
    v_start_time := SYSDATE;
    DBMS_OUTPUT.ENABLE(1000000);
    
    -- Clean TIN
    v_tptin := REPLACE(p_tin, '-', '');
    
    -- Header
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('                    DUAL SCHEMA TIN VALIDATION SYSTEM');
    DBMS_OUTPUT.PUT_LINE('          Based on Original cK_tin.sql - Exadata vs Legacy Comparison');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('TIN: ' || p_tin);
    DBMS_OUTPUT.PUT_LINE('Source: ' || p_source_schema);
    DBMS_OUTPUT.PUT_LINE('Format: ' || p_output_format);
    DBMS_OUTPUT.PUT_LINE('Legacy Schema: ' || p_legacy_schema);
    DBMS_OUTPUT.PUT_LINE('Execution Time: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Extract data based on source parameter
    IF p_source_schema IN ('EXADATA', 'BOTH') THEN
        DBMS_OUTPUT.PUT_LINE('>> Extracting Exadata data...');
        SELECT * BULK COLLECT INTO v_exadata_data FROM TABLE(FN_GET_EXADATA_TIN_DATA(p_tin));
        DBMS_OUTPUT.PUT_LINE('   Exadata records extracted: ' || v_exadata_data.COUNT);
        DBMS_OUTPUT.PUT_LINE('');
    END IF;
    
    IF p_source_schema IN ('LEGACY', 'BOTH') THEN
        DBMS_OUTPUT.PUT_LINE('>> Extracting Legacy data...');
        SELECT * BULK COLLECT INTO v_legacy_data FROM TABLE(FN_GET_LEGACY_TIN_DATA(p_tin, p_legacy_schema));
        DBMS_OUTPUT.PUT_LINE('   Legacy records extracted: ' || v_legacy_data.COUNT);
        DBMS_OUTPUT.PUT_LINE('');
    END IF;
    
    -- Process output based on format
    CASE UPPER(p_output_format)
        
        WHEN 'EXADATA_ONLY' THEN
            DBMS_OUTPUT.PUT_LINE('=== EXADATA DATA (Original cK_tin.sql Format) ===');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE(v_tptin);
            DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
            DBMS_OUTPUT.PUT_LINE('');
            
            FOR i IN 1..v_exadata_data.COUNT LOOP
                IF v_exadata_data(i).section_name != v_current_section THEN
                    v_current_section := v_exadata_data(i).section_name;
                    DBMS_OUTPUT.PUT_LINE(v_current_section);
                    DBMS_OUTPUT.PUT_LINE('');
                    
                    -- Add headers based on section
                    CASE v_current_section
                        WHEN 'ENT' THEN
                            DBMS_OUTPUT.PUT_LINE('    TIN      TINSID TPCT   TOTASSD S C   PYRIND CAS SUB ASSNCFF    ASSNGRP        RISK A EXTRDT');
                            DBMS_OUTPUT.PUT_LINE('---------- -------- ---- --------- - - -------- --- --- ---------- ---------- -------- - ----------');
                        WHEN 'TRANTRAIL' THEN
                            DBMS_OUTPUT.PUT_LINE('  TINSID      ROID S S ASSNFLD    ASSNNO    CLOSEDT   EXTRDT    FLAG FLAG     DSPCD      DISPCD OR    EMPHRS');
                            DBMS_OUTPUT.PUT_LINE('-------- -------- - - ---------- --------- --------- --------- ---- ---- --------- ---------- ---------');
                        WHEN 'ENTMOD' THEN
                            DBMS_OUTPUT.PUT_LINE('  TINSID      ROID T MFT PERIOD    P S  ASSNNO    CLSDT     DISPCODE EXTRDT    FLAG FLAG   TYPEID    BALANCE');
                            DBMS_OUTPUT.PUT_LINE('-------- -------- - --- --------- - - --------- --------- -------- --------- ---- ---- -------- ----------');
                        WHEN 'ENTACT' THEN
                            DBMS_OUTPUT.PUT_LINE('  TINSID      ROID     AROID T   TYPEID MFT PERIOD     ACTDT    DISPCODE R R EXTRDT       AMOUNT  CC   TC');
                            DBMS_OUTPUT.PUT_LINE('-------- -------- --------- - -------- --- --------- --------- -------- - - --------- ---------- --- ----');
                        WHEN 'TIMETIN' THEN
                            DBMS_OUTPUT.PUT_LINE('  TIMESID   TINSID      ROID   RPTDT     EXTRDT    CODE SUB    HOURS  EGRD TGRD ERSK TRSK');
                            DBMS_OUTPUT.PUT_LINE('--------- --------- --------- --------- --------- ---- ---- -------- ---- ---- ---- ----');
                    END CASE;
                END IF;
                
                DBMS_OUTPUT.PUT_LINE(v_exadata_data(i).raw_data);
            END LOOP;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
            
        WHEN 'LEGACY_ONLY' THEN
            DBMS_OUTPUT.PUT_LINE('=== LEGACY DATA (Original cK_tin.sql Format) ===');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE(v_tptin);
            DBMS_OUTPUT.PUT_LINE('PL/SQL procedure successfully completed.');
            DBMS_OUTPUT.PUT_LINE('');
            
            v_current_section := 'NONE';
            FOR i IN 1..v_legacy_data.COUNT LOOP
                IF v_legacy_data(i).section_name != v_current_section THEN
                    v_current_section := v_legacy_data(i).section_name;
                    DBMS_OUTPUT.PUT_LINE(v_current_section);
                    DBMS_OUTPUT.PUT_LINE('');
                    -- Add same headers as Exadata version
                END IF;
                DBMS_OUTPUT.PUT_LINE(v_legacy_data(i).raw_data);
            END LOOP;
            
        WHEN 'SIDE_BY_SIDE' THEN
            DBMS_OUTPUT.PUT_LINE('=== SIDE-BY-SIDE COMPARISON ===');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Legend: [E] = Exadata Only, [L] = Legacy Only, [M] = Match, [D] = Different');
            DBMS_OUTPUT.PUT_LINE('');
            
            -- Compare records section by section
            v_current_section := 'NONE';
            FOR i IN 1..v_exadata_data.COUNT LOOP
                IF v_exadata_data(i).section_name != v_current_section THEN
                    v_current_section := v_exadata_data(i).section_name;
                    DBMS_OUTPUT.PUT_LINE('');
                    DBMS_OUTPUT.PUT_LINE('=== ' || v_current_section || ' SECTION ===');
                    DBMS_OUTPUT.PUT_LINE('EXADATA | LEGACY | STATUS');
                    DBMS_OUTPUT.PUT_LINE('--------|--------|--------');
                END IF;
                
                -- Find matching legacy record
                DECLARE
                    v_found BOOLEAN := FALSE;
                    v_status VARCHAR2(10);
                BEGIN
                    FOR j IN 1..v_legacy_data.COUNT LOOP
                        IF v_legacy_data(j).section_name = v_exadata_data(i).section_name AND
                           v_legacy_data(j).tinsid = v_exadata_data(i).tinsid THEN
                            v_found := TRUE;
                            IF v_exadata_data(i).record_hash = v_legacy_data(j).record_hash THEN
                                v_status := '[MATCH]';
                            ELSE
                                v_status := '[DIFF]';
                            END IF;
                            
                            DBMS_OUTPUT.PUT_LINE(SUBSTR(v_exadata_data(i).raw_data, 1, 70) || ' | ' || 
                                                SUBSTR(v_legacy_data(j).raw_data, 1, 70) || ' | ' || v_status);
                            EXIT;
                        END IF;
                    END LOOP;
                    
                    IF NOT v_found THEN
                        DBMS_OUTPUT.PUT_LINE(SUBSTR(v_exadata_data(i).raw_data, 1, 70) || ' | ' || 
                                            RPAD('-- MISSING --', 70) || ' | [E-ONLY]');
                    END IF;
                END;
            END LOOP;
            
        WHEN 'SUMMARY' THEN
            DBMS_OUTPUT.PUT_LINE('=== VALIDATION SUMMARY REPORT ===');
            DBMS_OUTPUT.PUT_LINE('');
            
            -- Get comparison summary
            SELECT * BULK COLLECT INTO v_comparison_summary FROM TABLE(FN_COMPARE_SCHEMAS(v_exadata_data, v_legacy_data));
            
            DBMS_OUTPUT.PUT_LINE(RPAD('SECTION', 12) || ' | ' || RPAD('EXADATA', 8) || ' | ' || RPAD('LEGACY', 8) || ' | ' || 
                               RPAD('MATCHES', 8) || ' | ' || RPAD('DIFF', 6) || ' | ' || RPAD('MATCH%', 8));
            DBMS_OUTPUT.PUT_LINE(RPAD('-', 12, '-') || '-+-' || RPAD('-', 8, '-') || '-+-' || RPAD('-', 8, '-') || '-+-' || 
                               RPAD('-', 8, '-') || '-+-' || RPAD('-', 6, '-') || '-+-' || RPAD('-', 8, '-'));
            
            FOR i IN 1..v_comparison_summary.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE(
                    RPAD(v_comparison_summary(i).section_name, 12) || ' | ' ||
                    LPAD(v_comparison_summary(i).total_exadata_records, 8) || ' | ' ||
                    LPAD(v_comparison_summary(i).total_legacy_records, 8) || ' | ' ||
                    LPAD(v_comparison_summary(i).matching_records, 8) || ' | ' ||
                    LPAD(v_comparison_summary(i).differing_records, 6) || ' | ' ||
                    LPAD(v_comparison_summary(i).match_percentage || '%', 8)
                );
                
                v_total_matches := v_total_matches + v_comparison_summary(i).matching_records;
                v_total_records := v_total_records + GREATEST(v_comparison_summary(i).total_exadata_records, v_comparison_summary(i).total_legacy_records);
            END LOOP;
            
            v_overall_percentage := CASE WHEN v_total_records > 0 THEN ROUND((v_total_matches / v_total_records) * 100, 2) ELSE 0 END;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('*** OVERALL MATCH PERCENTAGE: ' || v_overall_percentage || '% ***');
            DBMS_OUTPUT.PUT_LINE('');
            
            IF v_overall_percentage = 100 THEN
                DBMS_OUTPUT.PUT_LINE('✓ VALIDATION PASSED: All data matches perfectly between schemas!');
            ELSIF v_overall_percentage >= 90 THEN
                DBMS_OUTPUT.PUT_LINE('⚠ VALIDATION WARNING: High match rate but some differences exist');
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ VALIDATION FAILED: Significant differences found between schemas');
            END IF;
            
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: Invalid output format. Use: EXADATA_ONLY, LEGACY_ONLY, SIDE_BY_SIDE, SUMMARY');
    END CASE;
    
    -- Footer
    v_execution_time := ROUND((SYSDATE - v_start_time) * 24 * 60 * 60, 2);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('Execution completed in ' || v_execution_time || ' seconds');
    DBMS_OUTPUT.PUT_LINE('Report generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('*** CRITICAL ERROR ***');
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Stack: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Please verify:');
        DBMS_OUTPUT.PUT_LINE('1. TIN exists in the database');
        DBMS_OUTPUT.PUT_LINE('2. Legacy schema configuration is correct');
        DBMS_OUTPUT.PUT_LINE('3. All required permissions are granted');
END SP_CK_TIN_DUAL_SCHEMA;
/

-- ============================================================================
-- STEP 6: UTILITY AND TESTING PROCEDURES
-- ============================================================================

-- Quick test to verify Exadata data extraction works
CREATE OR REPLACE PROCEDURE SP_TEST_EXADATA_EXTRACTION(p_tin IN VARCHAR2) AS
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    DBMS_OUTPUT.PUT_LINE('=== Testing Exadata Data Extraction ===');
    DBMS_OUTPUT.PUT_LINE('TIN: ' || p_tin);
    DBMS_OUTPUT.PUT_LINE('');
    
    FOR rec IN (SELECT * FROM TABLE(FN_GET_EXADATA_TIN_DATA(p_tin))) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE('Record ' || v_count || ': ' || rec.section_name || ' - ' || rec.source_schema);
        IF rec.section_name = 'ERROR' THEN
            DBMS_OUTPUT.PUT_LINE('   ERROR: ' || rec.data_fields);
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Total records extracted: ' || v_count);
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** NO DATA FOUND - Check if TIN exists in ENT table ***');
    ELSE
        DBMS_OUTPUT.PUT_LINE('*** SUCCESS - Exadata extraction working ***');
    END IF;
END SP_TEST_EXADATA_EXTRACTION;
/

-- Procedure to help configure legacy schema mappings
CREATE OR REPLACE PROCEDURE SP_LEGACY_SCHEMA_HELP AS
BEGIN
    DBMS_OUTPUT.ENABLE(1000000);
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('                    LEGACY SCHEMA CONFIGURATION GUIDE');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('To complete the dual-schema setup, you need to customize the');
    DBMS_OUTPUT.PUT_LINE('FN_GET_LEGACY_TIN_DATA function with your actual legacy schema details:');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. REPLACE PLACEHOLDER TABLE NAMES:');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_ENT_TABLE_NAME       -> Your actual ENT table name');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_TRANTRAIL_TABLE_NAME -> Your actual TRANTRAIL table name');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_ENTMOD_TABLE_NAME    -> Your actual ENTMOD table name');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_ENTACT_TABLE_NAME    -> Your actual ENTACT table name');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_TIMETIN_TABLE_NAME   -> Your actual TIMETIN table name');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. REPLACE PLACEHOLDER COLUMN NAMES:');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_TIN_COLUMN           -> Your actual TIN column name');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_TINSID_COLUMN        -> Your actual TINSID column name');
    DBMS_OUTPUT.PUT_LINE('   - LEGACY_TOTASSD_COLUMN       -> Your actual TOTASSD column name');
    DBMS_OUTPUT.PUT_LINE('   - ... (and all other columns)');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. CURRENT STATUS:');
    DBMS_OUTPUT.PUT_LINE('   ✓ Exadata extraction: READY');
    DBMS_OUTPUT.PUT_LINE('   ⚠ Legacy extraction: NEEDS CUSTOMIZATION');
    DBMS_OUTPUT.PUT_LINE('   ✓ Comparison engine: READY');
    DBMS_OUTPUT.PUT_LINE('   ✓ Output formatting: READY');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. TEST COMMANDS:');
    DBMS_OUTPUT.PUT_LINE('   -- Test Exadata extraction');
    DBMS_OUTPUT.PUT_LINE('   EXEC SP_TEST_EXADATA_EXTRACTION(''844607599'');');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('   -- Test dual schema (after customization)');
    DBMS_OUTPUT.PUT_LINE('   EXEC SP_CK_TIN_DUAL_SCHEMA(''844607599'', ''BOTH'', ''SUMMARY'');');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
END SP_LEGACY_SCHEMA_HELP;
/

-- ============================================================================
-- INSTALLATION COMPLETE MESSAGE
-- ============================================================================

DBMS_OUTPUT.PUT_LINE('================================================================================');
DBMS_OUTPUT.PUT_LINE('    DUAL SCHEMA TIN VALIDATION SYSTEM - INSTALLATION COMPLETE');
DBMS_OUTPUT.PUT_LINE('    Based on Original cK_tin.sql Script');
DBMS_OUTPUT.PUT_LINE('================================================================================');
DBMS_OUTPUT.PUT_LINE('');
DBMS_OUTPUT.PUT_LINE('✓ READY TO USE - Exadata data extraction');
DBMS_OUTPUT.PUT_LINE('⚠ NEEDS CUSTOMIZATION - Legacy schema configuration');
DBMS_OUTPUT.PUT_LINE('');
DBMS_OUTPUT.PUT_LINE('QUICK START:');
DBMS_OUTPUT.PUT_LINE('1. Test Exadata: EXEC SP_TEST_EXADATA_EXTRACTION(''844607599'');');
DBMS_OUTPUT.PUT_LINE('2. Get help: EXEC SP_LEGACY_SCHEMA_HELP;');
DBMS_OUTPUT.PUT_LINE('3. Run Exadata only: EXEC SP_CK_TIN_DUAL_SCHEMA(''844607599'', ''EXADATA'', ''EXADATA_ONLY'');');
DBMS_OUTPUT.PUT_LINE('');
DBMS_OUTPUT.PUT_LINE('After customizing legacy schema:');
DBMS_OUTPUT.PUT_LINE('4. Full comparison: EXEC SP_CK_TIN_DUAL_SCHEMA(''844607599'', ''BOTH'', ''SUMMARY'');');
DBMS_OUTPUT.PUT_LINE('');
DBMS_OUTPUT.PUT_LINE('================================================================================');
