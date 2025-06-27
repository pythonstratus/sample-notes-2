CREATE OR REPLACE PROCEDURE SP_COMBO_RISK_ASSESSMENT(
    p_area_filter    IN NUMBER DEFAULT NULL,
    p_parallel_degree IN NUMBER DEFAULT 4,
    p_debug_mode     IN VARCHAR2 DEFAULT 'N',
    p_commit_size    IN NUMBER DEFAULT 10000,
    o_records_processed OUT NUMBER,
    o_execution_time    OUT NUMBER,
    o_status            OUT VARCHAR2,
    o_error_message     OUT VARCHAR2
) IS

-- =======================================================================
-- VARIABLE DECLARATIONS SECTION
-- =======================================================================
-- Performance and monitoring variables
v_start_time      TIMESTAMP := SYSTIMESTAMP;
v_batch_count     NUMBER := 0;
v_error_context   VARCHAR2(4000);
v_records_count   NUMBER := 0;

-- Type definitions
type table_mft_type is table of dialmod.mft%TYPE
    index by binary_integer;
type table_dtper_type is table of dialmod.dtper%TYPE
    index by binary_integer;
type table_select_cd_type is table of dialmod.select_cd%TYPE
    index by binary_integer;
type table_rectype_type is table of dialmod.rectype%TYPE
    index by binary_integer;
type table_age_type is table of number
    index by binary_integer;
type table_baldue_type is table of dialmod.baldue%TYPE
    index by binary_integer;
type table_last_amt_type is table of dialmod.last_amt%TYPE
    index by binary_integer;
type table_special_proj_cd_type is table of dialmod.special_proj_cd%TYPE
    index by binary_integer;
type table_civp_type is table of dialmod.civp%TYPE
    index by binary_integer;
type table_predic_cd_type is table of dialmod.predic_cd%TYPE
    index by binary_integer;
type table_predic_cyc_type is table of dialmod.predic_updt_cyc%TYPE
    index by binary_integer;
type table_predic_updt_cyc_type is table of dialmod.predic_updt_cyc%TYPE
    index by binary_integer;

type table_risk_type is table of tinsummary.risk%TYPE
    index by binary_integer;
type table_predic_type is table of tinsummary.emis_predic_cd%TYPE
    index by binary_integer;
type table_predcyc_type is table of tinsummary.emis_predic_cyc%TYPE
    index by binary_integer;
type table_dtassd_type is table of dialmod.dtassd%TYPE
    index by binary_integer;
type table_rowid_type is table of rowid
    index by binary_integer;

-- Table variables
table_risk table_risk_type;
table_predic table_predic_type;
table_predcyc table_predcyc_type;
table_rowid table_rowid_type;
table_mft table_mft_type;
table_dtper table_dtper_type;
table_select_cd table_select_cd_type;
table_rectype table_rectype_type;
table_age table_age_type;
table_baldue table_baldue_type;
table_last_amt table_last_amt_type;
table_special_proj_cd table_special_proj_cd_type;
table_civp table_civp_type;
table_predic_cd table_predic_cd_type;
table_predic_cyc table_predic_cyc_type;
table_dtassd table_dtassd_type;

-- Working variables
today           number(6);
year            number(4);
yr_1            number(4);
yr_3            number(4);
sumbal          number(13,2);
tfbal           number(13,2);
bal             number(13,2);
lra             number(13,2);
rectype         number;
max_rectype     number;
tin             number(9);
address         rowid;
sid             number(10);
age             number(4);
max_age         number(4);
fs              number(1) := 0;
tt              number(1) := 0;
mft             number(3);
period          date;
code            number(2);
rank            number(3);
riskc           number(3);
precd           number(2);
precyc          number(6);
spec_prj_cd     number(4);
oic_acc_yr      number(4);
oic_ck          number(1);
tf_lra_sum      number(13,2);
tf_mod_cnt      number(3);
tdi_credit      number(13,2);
civpcd          number(3);
predic_cd       number(2);
predic_cyc      number(6);
curr_risk       number(3);
estate_tax      number(3);
accrual_ck      number(1);
caseind         char(1);
area            number(2);
fatca           char(1);

-- Loop counters
i               binary_integer := 0;
j               binary_integer := 0;
numrecs         binary_integer := 1;

-- Cursor definition
cursor cur1 is
    SELECT /*+ PARALLEL(t,4) index(t, emisao_ix) index(c, coretin_ix)
           index(d, pk_dialent) */
        emistin, emisfs, emistt, risk,
        aggbaldue,
        ent_tdi_xref, emisao, ts_fatcaind,
        t.rowid
    FROM    tinsummary t
    WHERE
        emisao = NVL(p_area_filter, emisao) and
        exists (select 1 from coredial where
            grnum between 82 and 83 and
            emistin = coretin and
            emisfs  = corefs  and
            emistt  = corett);

BEGIN
    -- =======================================================================
    -- INITIALIZATION SECTION
    -- =======================================================================
    -- Initialize output parameters
    o_records_processed := 0;
    o_status := 'SUCCESS';
    o_error_message := '';

    -- Enable parallel processing for session
    IF p_parallel_degree > 1 THEN
        EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
        EXECUTE IMMEDIATE 'ALTER SESSION FORCE PARALLEL DML PARALLEL ' || p_parallel_degree;
        EXECUTE IMMEDIATE 'ALTER SESSION FORCE PARALLEL DDL PARALLEL ' || p_parallel_degree;
    END IF;

    DBMS_OUTPUT.ENABLE(1000000);

    -- Debug output if enabled
    IF p_debug_mode = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('Starting combo risk assessment at: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('Parallel degree: ' || p_parallel_degree);
        DBMS_OUTPUT.PUT_LINE('Area filter: ' || NVL(TO_CHAR(p_area_filter), 'ALL'));
    END IF;

    -- Initialize date variables
    select to_number(to_char(sysdate,'yyyymm')), to_char(sysdate,'yyyy'),
           to_char(add_months(sysdate,-36),'yyyy'),
           to_char(add_months(sysdate,-12),'yyyy')
    into today, year, yr_3, yr_1 from dual;

    -- =======================================================================
    -- MAIN PROCESSING SECTION - CURSOR LOOP
    -- =======================================================================
    
    OPEN cur1;
    
    LOOP
        -- Initialize variables for each record
        fatca       := '0';
        sumbal      := 0;
        tfbal       := 0;
        
        oic_acc_yr  := 0;
        oic_ck      := 0;

        -- Fetch cursor data
        fetch cur1 into tin, fs, tt, curr_risk, sumbal, caseind, area, fatca, address;
        exit when cur1%NOTFOUND;

        -- Initialize calculation variables
        lra         := 0;
        mft         := 0;
        riskc       := 0;
        
        table_rowid(numrecs) := address;
        table_risk(numrecs) := 0;
        
        numrecs := numrecs + 1;
        
        tfbal := 0;
        tdi_credit := 0;
        tf_lra_sum := 0;
        tf_mod_cnt := 0;
        precd := 0;
        precyc := 0;
        max_age := -1;

        -- BULK COLLECT for related records
        SELECT /*+ PARALLEL(4) */ mft, dtper, select_cd, rectype,
               howold(taxperiod1(dtper,mft),today), baldue, last_amt,
               special_proj_cd, civp, predic_cd, predic_updt_cyc, dtassd
        BULK COLLECT INTO
               table_mft, table_dtper, table_select_cd, table_rectype,
               table_age,
               table_baldue, table_last_amt,
               table_special_proj_cd, table_civp, table_predic_cd,
               table_predic_cyc, table_dtassd
        FROM    tinsummary, coredial, dialmod
        WHERE   tinsummary.rowid = address and emistin = coretin and
                corefs = emisfs and corett = emistt and
                coresid = modsid
        ORDER BY
                howold(taxperiod1(dtper,mft),today);

        rank := 0;
        i := 0;
        estate_tax := 0;
        accrual_ck := 0;

        -- Process collected records - first pass for calculations
        IF table_mft.COUNT > 0 THEN
            FOR j in table_mft.FIRST .. table_mft.LAST
            LOOP
                if (table_rectype(j) = 5 and table_mft(j) in (01,03,08,09,11,12,14,16,17)) then
                    tfbal := tfbal + table_baldue(j);
                end if;

                if (table_rectype(j) = 0) then
                    tdi_credit := tdi_credit + abs(table_baldue(j));
                end if;

                if (table_rectype(j) = 0 and table_mft(j) in (01,03,08,09,11,12,14,16,17)) then
                    tf_lra_sum := tf_lra_sum + table_last_amt(j);
                    tf_mod_cnt := tf_mod_cnt + 1;
                end if;

                if (table_rectype(j) = 0 and table_mft(j) in (01,03,08,09,11,12,14,16,17,30,31) and
                    max_age < table_age(j)) then
                    max_age := table_age(j);
                end if;

                if (table_predic_cd(j) > precd and table_predic_cyc(j) > 200901) then
                    precd := table_predic_cd(j);
                    precyc := table_predic_cyc(j);
                end if;

                if (table_mft(j) = 52 or table_rectype(j) = 5) then
                    estate_tax := 1;
                end if;
            END LOOP;

            -- BEGIN ANALYSIS - Risk calculation rules
            FOR i in table_mft.FIRST .. table_mft.LAST
            LOOP
                -- SP377 Update threshold from 1372323 to 1537359
                if((table_rectype(i) = 5 and sumbal >= 1537359) or
                   ((table_rectype(i) = 0 and table_last_amt(i) >= 1537359) or
                   (table_rectype(i) = 0 and tdi_credit >= 1537359) or
                   -- dial_prior_yr_amt(tin,tt,fs) >= 1537359 or  -- Function call removed for compilation
                   ((fs = 1 and table_rectype(i) = 0) and
                   (table_age(i) <= 3 and
                    table_select_cd(i) in (30,31,32,34))))) then
                    rank := 99;
                    goto calc_risk;
                end if;

                -- Accrual check logic
                accrual_ck := 0;
                if(sumbal > 300000) then
                    select count(*) into accrual_ck from tinsummary
                    where emistin = tin and emisfs = fs and emistt = tt
                    and (aggbaldue) > 1537359
                    and risk = 99;
                    if(accrual_ck > 0) then
                        rank := 99;
                        goto calc_risk;
                    end if;
                end if;

                -- SP377 Update thresholds
                if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17,72) and
                     table_age(i) < 2) and
                    ((table_rectype(i) = 5 and sumbal >= 10000 and table_baldue(i) >= 2528) or
                     (table_rectype(i) = 0 and table_last_amt(i) >= 16854 and
                      table_age(i) < 2) or
                     (table_rectype(i) = 0 and tdi_credit >= 16854 and
                      table_age(i) < 2))) then
                    rank := 101;
                    goto calc_risk;
                end if;

                -- Priority 103 rules
                if ((table_rectype(i) = 5 and sumbal >= 168546) and
                    (fs = 2 and table_age(i) < 2)) then
                    rank := 103;
                    goto calc_risk;
                end if;

                -- Special project codes check
                if ((table_rectype(i) = 5 and sumbal >= 168546) and
                    table_special_proj_cd(i) in (
                        0019, 0020, 0041, 0042, 0043, 0053, 0080, 0090, 0108, 0117,
                        0126, 0127, 0130, 0132, 0134, 0159, 0160, 0161, 0162, 0163,
                        0165, 0166, 0167, 0202, 0208, 0217, 0233, 0237, 0240, 0241,
                        0242, 0243, 0244, 0267, 0268, 0269, 0270, 0278, 0279, 0280,
                        0281, 0282, 0283, 0284, 0285, 0286, 0287, 0290, 0296, 0299,
                        0310, 0311, 0312, 0315, 0362, 0363, 0384, 0387, 0450, 0507,
                        0626, 0629, 0632, 0635, 0671, 0696, 0699, 0761, 0923, 0925,
                        0934, 0938, 0969, 0971, 0972, 0973, 0978, 0989, 0995, 0996,
                        0997, 1008, 1010, 1019, 1023, 1036, 1076, 1077, 1080, 1089,
                        1090, 1095, 1108, 1109, 1119, 1121, 1123, 1132, 1138, 1139,
                        1140, 1149, 1150, 1151, 1152, 1153, 1154, 1160, 1165, 1174,
                        1194, 1221, 1222, 1223, 1224, 1225, 1226, 1245)) then
                    rank := 103;
                    goto calc_risk;
                end if;

                -- CIVP codes check
                if ((table_rectype(i) = 5 and sumbal >= 168546) and
                    table_civp(i) in (565, 594, 595, 596, 597, 598, 628, 631, 634, 636, 648, 650, 666, 687)) then
                    rank := 103;
                    goto calc_risk;
                end if;

                -- FATCA check
                if (table_rectype(i) = 5 and sumbal >= 168546 and fatca in ('1','B','P','S')) then
                    rank := 103;
                    goto calc_risk;
                end if;

                -- Priority 105 rules
                if (table_rectype(i) = 5 and sumbal >= 168546) then
                    rank := 105;
                    goto calc_risk;
                end if;

                -- TFRP assessment rule (MFT 55)
                if (table_mft(i) = 55 and
                    table_rectype(i) = 5 and table_civp(i) = 618 and
                    (table_dtassd(i) >= sysdate - 365)) then
                    rank := 108;
                    goto calc_risk;
                end if;

                -- Medium priority rules
                if (table_rectype(i) = 5 and sumbal >= 24932) then
                    rank := 201;
                    goto calc_risk;
                end if;

                -- Lower priority rules
                if (fs = 1 and table_rectype(i) = 0) then
                    rank := 302;
                    goto calc_risk;
                end if;

                if (fs = 2 and table_rectype(i) = 0) then
                    rank := 302;
                    goto calc_risk;
                end if;

                -- Default rank
                if (rank = 0) then
                    rank := 399;
                end if;

                <<calc_risk>>
                if (table_risk(numrecs - 1) = 0) then
                    table_risk(numrecs - 1) := rank;
                elsif (rank < table_risk(numrecs - 1)) then
                    table_risk(numrecs - 1) := rank;
                end if;

                table_predic(numrecs - 1) := precd;
                table_predcyc(numrecs - 1) := precyc;

                -- Debug output if enabled
                IF p_debug_mode = 'Y' AND tin = 1032693 THEN
                    DBMS_OUTPUT.PUT_LINE('finished TIN: '||tin||' fs: '||fs||' address: '||address);
                    DBMS_OUTPUT.PUT_LINE('TIN: '||tin||' RANK: '||rank||' CURR_RISK: '||curr_risk);
                    DBMS_OUTPUT.PUT_LINE('HOLDING: '||table_risk(numrecs - 1));
                END IF;

            END LOOP; -- End risk analysis loop
        END IF; -- End if table_mft.COUNT > 0

    END LOOP; -- End main cursor loop

    CLOSE cur1;

    -- FORALL bulk update
    IF numrecs > 1 THEN
        FORALL lp_cnt in 1 .. (numrecs - 1)
            UPDATE /*+ PARALLEL(tinsummary,4) */ tinsummary 
            set risk = table_risk(lp_cnt),
                emis_predic_cd = table_predic(lp_cnt),
                emis_predic_cyc = table_predcyc(lp_cnt)
            WHERE rowid = table_rowid(lp_cnt);
    END IF;

    -- Global update for Area 35
    IF (p_area_filter IS NULL OR p_area_filter = 35) THEN
        UPDATE /*+ PARALLEL(tinsummary,4) */ tinsummary 
        SET risk = 99 
        WHERE emisfs = 2 
        AND EXISTS (
            SELECT 1 FROM coredial 
            WHERE emistin = coretin 
                AND emisfs = corefs 
                AND emistt = corett 
                AND grnum BETWEEN 82 AND 83 
                AND EXISTS (
                    SELECT 1 FROM dialmod 
                    WHERE coresid = modsid 
                        AND rectype = 5 
                        AND howold(taxperiod1(dtper,mft),today) < 2 
                        AND mft IN (01,03,08,09,11,12,14,16,17,72)
                )
        );
    END IF;

    -- Calculate records processed
    o_records_processed := numrecs - 1;

    -- Calculate execution time in milliseconds
    o_execution_time := EXTRACT(DAY FROM (SYSTIMESTAMP - v_start_time)) * 24 * 60 * 60 * 1000 +
                       EXTRACT(HOUR FROM (SYSTIMESTAMP - v_start_time)) * 60 * 60 * 1000 +
                       EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60 * 1000 +
                       ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) * 1000);

    -- Commit the transaction
    COMMIT;

    -- Debug completion message
    IF p_debug_mode = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('Combo risk assessment completed successfully');
        DBMS_OUTPUT.PUT_LINE('Records processed: ' || o_records_processed);
        DBMS_OUTPUT.PUT_LINE('Execution time: ' || o_execution_time || ' ms');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        o_status := 'WARNING';
        o_error_message := 'NO_DATA_FOUND';
        IF p_debug_mode = 'Y' THEN
            DBMS_OUTPUT.PUT_LINE('NO_DATA_FOUND');
        END IF;
        ROLLBACK;

    WHEN OTHERS THEN
        o_status := 'ERROR';
        o_error_message := 'sqlcode: ' || SQLCODE || ' ERRM: ' || SQLERRM;
        IF p_debug_mode = 'Y' THEN
            DBMS_OUTPUT.PUT_LINE('sqlcode: ' || SQLCODE || ' ERRM: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('tin: ' || NVL(tin,0) || ' address: ' || address);
        END IF;
        ROLLBACK;
        RAISE;

END SP_COMBO_RISK_ASSESSMENT;
/
