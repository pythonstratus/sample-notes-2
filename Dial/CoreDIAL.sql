CREATE OR REPLACE PROCEDURE DIALDEV.LOAD_COREDIAL AS
    v_error_index NUMBER;
    v_error_code NUMBER;
    v_batch_id NUMBER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_rows_inserted NUMBER := 0;
    v_rows_rejected NUMBER := 0;
BEGIN
    v_start_time := SYSTIMESTAMP;
    
    -- Enable parallel DML for this session (Exadata optimized)
    EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    EXECUTE IMMEDIATE 'ALTER SESSION FORCE PARALLEL QUERY PARALLEL 16';
    
    -- Enable Exadata Smart Scan optimizations
    EXECUTE IMMEDIATE 'ALTER SESSION SET CELL_OFFLOAD_PROCESSING = TRUE';
    EXECUTE IMMEDIATE 'ALTER SESSION SET "_serial_direct_read" = TRUE';
    
    v_batch_id := v_batch_id + 1;
    
    -- Main Insert with Parallel Hint and Duplicate Handling (Exadata optimized)
    INSERT /*+ APPEND PARALLEL(COREDIAL_TMP, 16) PARALLEL(DIAL_STAGING, 16) */ 
    INTO COREDIAL_TMP (
        CORESID,
        CORETIN,
        COREFS,
        CORETT,
        GRNUM,
        RONUM,
        HACTL,
        NATP,
        OGRP,
        ONUM,
        ASSIGN_AO,
        ASSIGN_TO,
        ULC_CD,
        ULC_AO,
        CLC,
        SC,
        QTO,
        PROID
    )
    SELECT 
        ENTSID,
        TO_NUMBER(TIN),
        TO_NUMBER(FILESOURCECD),
        TO_NUMBER(TINTYPE),
        (ASSIGNMENTBRANCH || ASSIGNMENTGROUP) AS GRNUM,
        NAMECONTROL,
        NAMELINE,
        ASSIGNMENTAO,
        -- OGRP calculation
        CAST(
            (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 100) / 100) 
            AS INT
        ) AS OGRP,
        -- OGRNUM calculation  
        CAST(
            (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 10000) / 100) 
            AS INT
        ) AS OGRNUM,
        -- ASSIGN_AO calculation
        CAST(
            (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 10000) / 100) 
            AS INT
        ) AS ASSIGN_AO,
        -- QTO calculation
        DECODE(
            CAST(
                (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 1000000) / 10000
            ) AS INT),
            0,
            TO_NUMBER(TO_CHAR(FIXAO(PRIMARYULCCD, ASSIGNMENTAO, ENTSID), 'FM09')),
            CAST(
                (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 1000000) / 10000
            ) AS INT)
        ) AS QTO,
        -- HACTL calculation (TO_CHAR with FIXAO)
        TO_CHAR(
            CAST(
                (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 10000) / 100
            ) AS INT)
        ) AS HACTL,
        -- NATP calculation (TO_CHAR with FIXAO)
        TO_CHAR(
            CAST(
                (MOD(NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0), 100
            ) AS INT)
        ) AS NATP,
        ASSIGNMENTTO,
        PRIMARYULCCD,
        PRIMARYAOCD,
        COLLECTIONLOCCD,
        SCCD,
        zptp5E,
        GRADELEVELED,
        NVL(ICSASSIGN(zptp5E, SUBSTR(NAMECONTROL,1,1), GRADELEVELED),0) as PROID
    FROM (
        SELECT 
            ENTSID,
            TIN,
            FILESOURCECD,
            TINTYPE,
            ASSIGNMENTBRANCH,
            ASSIGNMENTGROUP,
            NAMECONTROL,
            NAMELINE,
            ASSIGNMENTAO,
            ASSIGNMENTTO,
            ASSIGNMENTEE,
            PRIMARYULCCD,
            PRIMARYAOCD,
            COLLECTIONLOCCD,
            SCCD,
            zptp5E,
            GRADELEVELED,
            ROW_NUMBER() OVER (
                PARTITION BY 
                    TIN,
                    FILESOURCECD,
                    TINTYPE,
                    ASSIGNMENTBRANCH,
                    ASSIGNMENTGROUP,
                    ASSIGNMENTAO,
                    ASSIGNMENTTO,
                    ASSIGNMENTEE,
                    NAMELINE
                ORDER BY ENTSID
            ) as rn
        FROM DIAL_STAGING
    ) src
    WHERE rn = 1;
    
    v_rows_inserted := SQL%ROWCOUNT;
    
    COMMIT;
    
    v_end_time := SYSTIMESTAMP;
    
    -- Log successful completion
    INSERT INTO AUDIT_COREDIAL (
        batch_id,
        CORESID,
        CORETIN,
        COREFS,
        CORETT,
        GRNUM,
        RONUM,
        HACTL,
        NATP,
        OGRP,
        ONUM,
        ASSIGN_AO,
        ASSIGN_TO,
        ULC_CD,
        ULC_AO,
        CLC,
        SC,
        QTO,
        PROID,
        ERROR_MESSAGE,
        ERR_DATE
    )
    VALUES (
        v_batch_id,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'Success: ' || v_rows_inserted || ' rows inserted in ' || 
        EXTRACT(SECOND FROM (v_end_time - v_start_time)) || ' seconds',
        SYSDATE
    );
    
    COMMIT;
    
    -- Disable parallel DML (optional, depends on your session management)
    EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
    
EXCEPTION
    WHEN OTHERS THEN
        v_error_code := SQLCODE;
        v_error_index := 1;
        
        -- Log the error
        INSERT INTO AUDIT_COREDIAL (
            batch_id,
            CORESID,
            CORETIN,
            COREFS,
            CORETT,
            GRNUM,
            RONUM,
            HACTL,
            NATP,
            OGRP,
            ONUM,
            ASSIGN_AO,
            ASSIGN_TO,
            ULC_CD,
            ULC_AO,
            CLC,
            SC,
            QTO,
            PROID,
            ERROR_MESSAGE,
            ERR_DATE
        )
        VALUES (
            v_batch_id,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            'Error Code: ' || v_error_code || ' - ' || SQLERRM,
            SYSDATE
        );
        
        COMMIT;
        
        -- Disable parallel DML
        EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
        
        RAISE;
END LOAD_COREDIAL;
/
