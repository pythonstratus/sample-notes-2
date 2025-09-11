CREATE OR REPLACE PROCEDURE crent_proc(
    p_record_id IN NUMBER,
    p_output OUT CLOB
) AS
    -- Cursor to fetch tax record data
    CURSOR tax_record_cur IS
        SELECT 
            ent_id,
            ent_type,
            gl_source,
            gbl,
            assacdt,
            zrp,
            dtassign,
            assacdt as assacdt2,
            rwms,
            repeat_val,
            large_val,
            initpyr,
            currpyr,
            fr944,
            fr1120,
            fr1065,
            dtxref,
            attornsf,
            dtdtagyc,
            nalp2ind,
            adbp,
            adtp2c,
            gcitp,
            gstry2,
            gctrycd,
            gfrwrind,
            gtta,
            btdslvic,
            penentcd,
            otdtaccyr,
            rbdbind,
            dcldcd,
            fr944_2,
            gfrwrind_2,
            frdcntretind,
            corinst,
            cpcassgnnum,
            pcassignmtacctdt,
            dcdstind
        FROM tax_records 
        WHERE record_id = p_record_id;
        
    rec tax_record_cur%ROWTYPE;
    v_output CLOB;
    
BEGIN
    -- Initialize CLOB
    DBMS_LOB.CREATETEMPORARY(v_output, TRUE);
    
    -- Open cursor and fetch record
    OPEN tax_record_cur;
    FETCH tax_record_cur INTO rec;
    
    IF tax_record_cur%FOUND THEN
        -- Build the formatted output string similar to Java version
        DBMS_LOB.APPEND(v_output, 
            'X10.0f|' || LPAD(NVL(rec.ent_id, ''), 12, '0') || '|%s|' || 
            LPAD(NVL(rec.ent_type, ''), 2, '0') || 'd|' || CHR(10));
            
        DBMS_LOB.APPEND(v_output,
            '|' || RPAD(NVL(rec.gl_source, ''), 12, ' ') || '.0f|' || CHR(10));
            
        DBMS_LOB.APPEND(v_output,
            '|' || RPAD(NVL(rec.gbl, ''), 5, ' ') || '|' || CHR(10));
            
        DBMS_LOB.APPEND(v_output,
            '|' || LPAD(NVL(TO_CHAR(rec.zrp), ''), 2, '0') || 'd|' || CHR(10));
            
        DBMS_LOB.APPEND(v_output,
            '|' || RPAD(NVL(rec.dtassign, ''), 8, ' ') || '|' || CHR(10));
            
        DBMS_LOB.APPEND(v_output,
            '|' || RPAD(NVL(rec.assacdt2, ''), 8, ' ') || '|' || CHR(10));
            
        DBMS_LOB.APPEND(v_output,
            '|' || LPAD(NVL(TO_CHAR(rec.rwms), ''), 7, '0') || 'd|' || CHR(10));
            
        -- Continue with repeat, large, initpyr values
        DBMS_LOB.APPEND(v_output,
            '|%s|%s|%s|%s|%s|' || 
            RPAD(NVL(TO_CHAR(rec.repeat_val), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.large_val), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.initpyr), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.currpyr), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.fr944), ''), 1, ' ') || '|' || CHR(10));
            
        -- Add fr1120, fr1065 data
        DBMS_LOB.APPEND(v_output,
            '|' || LPAD(NVL(TO_CHAR(rec.fr1120), ''), 12, '0') || 'd|' ||
            LPAD(NVL(TO_CHAR(rec.fr1065), ''), 12, '0') || 'd|' ||
            RPAD(NVL(rec.dtxref, ''), 8, ' ') || '|' ||
            RPAD(NVL(rec.attornsf, ''), 8, ' ') || '|' ||
            RPAD(NVL(rec.dtdtagyc, ''), 8, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.nalp2ind), ''), 1, ' ') || '|' || CHR(10));
            
        -- Continue with remaining fields
        DBMS_LOB.APPEND(v_output,
            '|%s|%s|%s|%s|%s|%s|' ||
            RPAD(NVL(TO_CHAR(rec.adbp), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.adtp2c), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.gcitp), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.gstry2), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.gctrycd), ''), 1, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.gfrwrind), ''), 1, ' ') || '|' || CHR(10));
            
        -- Add remaining numeric and character fields
        DBMS_LOB.APPEND(v_output,
            '|' || LPAD(NVL(TO_CHAR(rec.gtta), ''), 4, '0') || 'd|' ||
            LPAD(NVL(TO_CHAR(rec.btdslvic), ''), 4, '0') || 'd|' ||
            RPAD(NVL(TO_CHAR(rec.penentcd), ''), 1, ' ') || '|' || CHR(10));
            
        -- Final fields
        DBMS_LOB.APPEND(v_output,
            '|' || LPAD(NVL(TO_CHAR(rec.otdtaccyr), ''), 4, '0') || 'd|' ||
            LPAD(NVL(TO_CHAR(rec.rbdbind), ''), 10, '0') || 'd|' ||
            LPAD(NVL(TO_CHAR(rec.dcldcd), ''), 4, '0') || 'd|%s|%s|' ||
            RPAD(NVL(TO_CHAR(rec.frdcntretind), ''), 1, ' ') || '|' || CHR(10));
            
        -- Corporate data
        DBMS_LOB.APPEND(v_output,
            '|' || LPAD(NVL(rec.corinst, ''), 28, '0') || 'd|' ||
            LPAD(NVL(rec.cpcassgnnum, ''), 28, '0') || 'd|' ||
            RPAD(NVL(rec.pcassignmtacctdt, ''), 8, ' ') || '|' ||
            RPAD(NVL(TO_CHAR(rec.dcdstind), ''), 1, ' ') || '|' || CHR(10));
            
    END IF;
    
    CLOSE tax_record_cur;
    
    -- Return the formatted output
    p_output := v_output;
    
    -- Clean up temporary CLOB
    DBMS_LOB.FREETEMPORARY(v_output);
    
EXCEPTION
    WHEN OTHERS THEN
        IF tax_record_cur%ISOPEN THEN
            CLOSE tax_record_cur;
        END IF;
        
        IF DBMS_LOB.ISTEMPORARY(v_output) = 1 THEN
            DBMS_LOB.FREETEMPORARY(v_output);
        END IF;
        
        RAISE;
END crent_proc;
/


DECLARE
    v_output CLOB;
BEGIN
    crent_proc(12345, v_output);  -- Pass record ID
    
    -- Display or process the output
    DBMS_OUTPUT.PUT_LINE(SUBSTR(v_output, 1, 4000));
END;
/
