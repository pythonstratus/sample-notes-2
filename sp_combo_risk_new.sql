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

-- *** COPY ALL TYPE DECLARATIONS FROM combo_risk.sql STARTING FROM LINE 131 ***
-- Copy from: "type table_mft_type is table of dialmod.mft%TYPE"
-- Copy to: "type table_predic_updt_cyc_type is table of dialmod.predic_updt_cyc%TYPE"
-- This includes lines 131-160 approximately

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
type table_predic_cyc_type is table of dialmod.predic_cyc_type%TYPE
    index by binary_integer;
type table_predic_updt_cyc_type is table of dialmod.predic_updt_cyc%TYPE
    index by binary_integer;

type table_risk_type is table of tinsummary.risk%TYPE
    index by binary_integer;
type table_predic_type is table of tinsummary.emis_predic_cd%TYPE
    index by binary_integer;
type table_predcyc_type is table of tinsummary.emis_predic_cyc%TYPE
    index by binary_integer;
--sp377 added DTASSD
type table_dtassd_type is table of dialmod.dtassd%TYPE
    index by binary_integer;

type table_rowid_type is table of rowid
    index by binary_integer;
i           binary_integer := 0;
j           binary_integer := 0;
numrecs     binary_integer := 1;

-- *** COPY ALL TABLE VARIABLES FROM combo_risk.sql STARTING FROM LINE 171 ***
-- Copy from: "table_risk table_risk_type;"
-- Copy to: "table_dtassd table_dtassd_type;"
-- This includes lines 171-187 approximately

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
--sp377 added DTASSD
table_dtassd table_dtassd_type;
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
risk            number(3);
precd           number(2);
precyc          number(6);
spec_proj_cd    number(4);
oic_acc_yr      number(4);
oic_ck          number(1);
tf_lra_sum      number(13,2);
tf_mod_cnt      number(3);
tdi_credit      number(13,2);
civp            number(3);
predic_cd       number(2);
predic_cyc      number(6);
curr_risk       number(3);
estate_tax      number(3);
accrual_ck      number(1);
caseind         char(1);
area            number(2);
fatca           char(1);

-- *** MISSING: ADD THE numrecs VARIABLE ***
numrecs         binary_integer := 1;

-- *** MISSING: ADD ALL OTHER VARIABLES FROM LINES 168-169 ***
i               binary_integer := 0;
j               binary_integer := 0;

-- *** COPY CURSOR DEFINITION FROM combo_risk.sql STARTING FROM LINE 249 ***
-- Copy the cur1 cursor definition EXACTLY as written
-- Copy from: "cursor cur1 is"
-- Copy to the complete WHERE clause ending with "corett = corett);"
-- This includes lines 249-264 approximately

cursor cur1 is
    SELECT /*+ index(t, emisgao_ix) index(c, coretin_ix)
           index(d, pk_dialent) */
        emistin, emisfs, emistt, risk,
        aggbaldue,
        ent_tdi_xref,emisao, ts_fatcaind,
        t.rowid
    FROM    tinsummary t
    WHERE
        emisao = &1 and
        exists (select 1 from coredial where
            --grnum = 70 and
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

    -- *** MISSING: SET SERVEROUTPUT AND PAGESIZE EQUIVALENTS ***
    -- Note: These are session-level settings, equivalent to lines 88-89 in original script
    DBMS_OUTPUT.ENABLE(1000000);

    -- Debug output if enabled
    IF p_debug_mode = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('Starting combo risk assessment at: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('Parallel degree: ' || p_parallel_degree);
        DBMS_OUTPUT.PUT_LINE('Area filter: ' || NVL(TO_CHAR(p_area_filter), 'ALL'));
    END IF;

    -- =======================================================================
    -- MAIN PROCESSING SECTION
    -- =======================================================================
    -- *** COPY DATE INITIALIZATION FROM combo_risk.sql STARTING FROM LINE 277 ***
    -- Copy EXACTLY from: "select currper(), to_char(sysdate,'yyyy'),"
    -- Copy to: "into today, year, yr_3, yr_1 from dual;"
    -- This includes lines 277-282

    -- dbms_output.put_line('This is Sumbal: '||sumbal);
    -- dbms_output.put_line('This is Address: '||address);

    SELECT mft, dtper, select_cd, rectype,
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

    j := 0;
    for j in table_mft.FIRST .. table_mft.LAST
    LOOP

        if (table_rectype(j) = 5 and table_mft(j) in (01,03,08,09,11,12,14,16,17))
        then
            tfbal := tfbal + table_baldue(j);
        end if;

        if (table_rectype(j) = 0) then
            tdi_credit := tdi_credit + abs(table_baldue(j));
        end if;

        if (table_rectype(j) = 0 and table_mft(j) in (01,03,08,09,11,12,14,16,17))
        then
            tf_lra_sum := tf_lra_sum + table_last_amt(j);
            tf_mod_cnt := tf_mod_cnt + 1;
        end if;

        if (table_rectype(j) = 0 and table_mft(j) in (01,03,08,09,11,12,14,16,17,30,31) and
            max_age < table_age(j)) then
            max_age := table_age(j);
        end if;

        if (table_predic_cd(j) > precd and
            table_predic_cyc(j) > 200901) then
            precd := table_predic_cd(j);
            precyc := table_predic_cyc(j);
        end if;

        if (table_mft(j) = 52 or table_rectype(j) = 5) then
            estate_tax := 1;
        end if;

    END LOOP;

    -- BEGIN ANALYSIS
    for i in table_mft.FIRST .. table_mft.LAST
    LOOP

        --SP377 Update threshold from 1372323 to 1537359

        if((table_rectype(i) = 5 and sumbal >= 1537359)                      or
           ((table_rectype(i) = 0 and table_last_amt(i) >= 1537359)         or
           (table_rectype(i) = 0 and tdi_credit >= 1537359)                 or
           dial_prior_yr_amt(tin,tt,fs) >= 1537359 or
           ((fs = 1 and table_rectype(i) = 0) and
           (table_age(i) <= 3 and
            table_select_cd(i) in (30,31,32,34))))) then
            rank := 99;
            goto calc_risk;
        end if;

        -- ---------------------------------------------------------------
        --    Now look for cases that were accelerated last week based
        --    on accruals from SIA
        -- ---------------------------------------------------------------

        --SP377 Update threshold from 1372323 to 1537359

        accrual_ck := 0;
        if(sumbal > 300000) then
            select count(*) into accrual_ck from tinsummary2
            where emistin = tin and emisfs = fs and emistt = tt
            and (siabal + siaint + siaftp) > 1537359
            and risk = 99;
            if(accrual_ck > 0) then
                rank := 99;
                goto calc_risk;
            end if;
        end if;

        -- ---------------------------------------------------------------
        --    ENTITY version looks at subcodes
        -- SP377 Update administrative note to 108
        -- if(subcd in ('601','602','603','604') or fs = 6) then
        -- ---------------------------------------------------------------

        -- SP344 Remove below logic rectype = 5 and fs = 6 rank := 100
        -- Pri 100 per rule #2

        --  if(table_rectype(i) = 5 and fs = 6) then
        --    rank := 100;
        --    goto calc_risk;
        --  end if;

        --SP212 RISK 101 updates
        --sp261 PRI UPDATES
        --sp291 Pri 101 updates

        --SP377 Update threshold from 2257 to 2528
        --SP377 Update thresholds from 15045 to 16854

        if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17,72) and
             table_age(i) < 2) and
            ((table_rectype(i) = 5 and sumbal >= 10000 and table_baldue(i) >= 2528) or
             (table_rectype(i) = 0 and table_last_amt(i) >= 16854 and
              table_age(i) < 2)
             or
             (table_rectype(i) = 0 and tdi_credit >= 16854 and
              table_age(i) < 2))) then
            rank := 101;
            goto calc_risk;
        end if;

        --sp212 RISK 102 updates revert back to original programming
        --sp261 PRI UPDATES
        -- sp 291 Change to Priority 105 TDA Part / 107 TDI Part

        -- if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17) and
        --     table_age(i) < 2) and
        --     ((table_rectype(i) = 5 and table_baldue(i) >= 1500) or
        --     (table_rectype(i) = 0 and table_last_amt(i) >= 1500 and
        --      table_age(i) < 2) or
        --     (table_rectype(i) = 0 and tdi_credit >= 1500 and
        --          table_age(i) < 2))) then
        --     rank := 102;
        --     goto calc_risk;
        -- end if;

        --sp 291 End change to Priority 105 TDA Part / 107 TDI Part

        --sp291 update 103
        --SP377 Update thresholds from 150453 to 168546

        if ((table_rectype(i) = 5 and sumbal >= 168546) and
            (fs = 2 and table_age(i) < 2)) then
            rank := 103;
            goto calc_risk;
        end if;

        -- End add new rule for 103
        --SP377 Update threshold to 168546

        if ((table_rectype(i) = 5 and sumbal >= 168546) and
            table_special_proj_cd(i) in (
                0019,
                0020,
                0041,
                0042,
                0043,
                0053,
                0080,
                0090,
                0108,
                0117,
                0126,
                0127,
                0130,
                0132,
                0134,
                0159,
                0160,
                0161,
                0162,
                0163,
                0165,
                0166,
                0167,
                0202,
                0208,
                0217,
                0233,
                0237,
                0240,
                0241,
                0242,
                0243,
                0244,
                0267,
                0268,
                0269,
                0270,
                0278,
                0279,
                0280,
                0281,
                0282,
                0283,
                0284,
                0285,
                0286,
                0287,
                0290,
                0296,
                0299,
                0310,
                0311,
                0312,
                0315,
                0362,
                0363,
                0384,
                0387,
                0450,
                0507,
                0626,
                0629,
                0632,
                0635,
                0671,
                0696,
                0699,
                0761,
                0923,
                0925,
                0934,
                0938,
                0969,
                0971,
                0972,
                0973,
                0978,
                0989,
                0995,
                0996,
                0997,
                1008,
                1010,
                1019,
                1023,
                1036,
                1076,
                1077,
                1080,
                1089,
                1090,
                1095,
                1108,
                1109,
                1119,
                1121,
                1123,
                1132,
                1138,
                1139,
                1140,
                1149,
                1150,
                1151,
                1152,
                1153,
                1154,
                1160,
                1165,
                1174,
                1194,
                1221,
                1222,
                1223,
                1224,
                1225,
                1226,
                1245
            )) then
            rank := 103;
            goto calc_risk;
        end if;

        --    (decode(table_civp(i) = 628)) then

        --SP377 Update threshold to 168546

        if ((table_rectype(i) = 5 and sumbal >= 168546) and
            table_civp(i) in (
                565,
                594,
                595,
                596,
                597,
                598,
                628,
                631,
                634,
                636,
                648,
                650,
                666,
                687)) then
            rank := 103;
            goto calc_risk;
        end if;

        --SP377 Update threshold to 12578

        if ((table_rectype(i) = 5 and table_mft(i) in (55, 13) and
             ((caseind = 'C')
              or
              (caseind = 'A' and sumbal >= 12578)) and
             table_civp(i) in (
                 581,
                 606,
                 624,
                 626,
                 627,
                 628,
                 631,
                 633,
                 634,
                 636,
                 645,
                 648,
                 650,
                 714,
                 715,
                 716,
                 717,
                 718 ))) then
            rank := 103;
            goto calc_risk;
        end if;

        if ((table_rectype(i) = 5 and sumbal >= 67418) and
            (table_mft(i) in (51,52))) then
            rank := 103;
            goto calc_risk;
        end if;

        ---------------------------------------------------------------

        -- sp344 New Rule: all cases IMF/BMF with FATCA indicator
        -- and balance due greater than or equal to $150,453
        -- will receive priority 103 per Rule #4
        -- Note: Created placeholder variable until DIAL receives
        --       FATCA data in 2023.

        --SP377 Update threshold to 168546

        if (table_rectype(i) = 5 and sumbal >= 168546 and fatca in ('1','B','P','S')) then
            rank := 103;
            goto calc_risk;
        end if;

        ---------------------------------------------------------------

        -- OIC_ACC YR may be needed after this point
        -- sp291 delete logic and rule oic below

        --  if(oic_ck = 0) then
        --    select oic_acc_yr into oic_acc_yr
        --    from tinsummary, coredial, dialent
        --    where
        --      tinsummary.rowid = address and
        --      emistin = coretin   and
        --      emisfs = corefs     and
        --      emistt = corett     and
        --      coresid = entsid    and
        --      rownum = 1;
        --    oic_ck := 1;
        --  end if;

        --  if ((table_rectype(i) = 5 and sumbal >= 100000) and
        --      (oic_acc_yr > (year - 5))) then
        --    rank := 103;
        --    goto calc_risk;
        --  end if;

        -- sp291 end delete logic and rule oic above

        -- sp219 NO change for 103 rule below

        -- SP344 remove sel code 03 per rules #10 below

        if ((fs = 1 and table_rectype(i) = 0) and
            (table_age(i) <= 3 and
             table_select_cd(i) in (98))) then
            rank := 103;
            goto calc_risk;
        end if;

        -- sp291 end NO change 103 rule above

        -- sp291 update rule 103 below
        -- SP377 Update threshold to 67418

        if ((table_rectype(i) = 0 and table_mft(i) in (51,52)) and
            (table_last_amt(i) >= 67418 or tdi_credit >= 67418)) then
            rank := 103;
            goto calc_risk;
        end if;

        -- sp291 end update rule 103 above

        -- sp291 delete rule oic below

        --  if (table_rectype(i) = 0 and (
        --      table_last_amt(i) >= 100000 or tdi_credit >= 100000) and
        --      ((fs = 1 and table_age(i) <= 5 and
        --           table_select_cd(i) = 67))) then
        --      rank := 103;
        --      goto calc_risk;
        --  end if;

        -- sp291 end delete rule oic above

        -- sp291 BMF will need its own LRA and TDI credit separate from IMF below

        --  if (((fs = 2 and max_age < 2 and max_age ^= -1) or
        --       (fs = 1 and max_age < 3  and max_age ^= -1 and
        --        table_mft(i) in (30,31))) and
        --      ((table_rectype(i) = 0 and table_last_amt(i) >= 100000) or
        --       (table_rectype(i) = 0 and tdi_credit >= 100000))) then
        --      rank := 103;
        --      goto calc_risk;
        --  end if;

        --SP377 Update threshold to 168546

        if ((fs = 2 and max_age < 2 and max_age ^= -1) and
            ((table_rectype(i) = 0 and table_last_amt(i) >= 168546) or
             (table_rectype(i) = 0 and tdi_credit >= 168546))) then
            rank := 103;
            goto calc_risk;
        end if;

        -- SP377 Update threshold to 67418
        -- SP377 Remove LRA requirement, does not apply to IMF

        if ((fs = 1 and table_age(i) < 3 and table_mft(i) in (30,31)) and
            (table_rectype(i) = 0 and tdi_credit >= 67418)) then
            rank := 103;
            goto calc_risk;
        end if;

        -- sp291 END BMF/IMF separate LRA and TDI credit above

        -- sp291 Delete rule below this rule will goto Pri 103

        --  if ((table_rectype(i) = 5 and sumbal >= 40000) and
        --      (table_mft(i) in (51,52))) then
        --      rank := 104;
        --      goto calc_risk;
        --  end if;

        -- sp291 End Delete rule above ******************

        -- sp291 Delete OIC rule below

        --  if ((table_rectype(i) = 5 and sumbal >= 40000) and (oic_acc_yr >
        --      (year - 5))) then
        --      rank := 104;
        --      goto calc_risk;
        --  end if;

        -- sp291 End Delete OIC rule above ******************

        -- sp291 Delete rule below - replaced by rule 29 Pri 103

        --  if ((table_rectype(i) = 0 and table_mft(i) in (30,31) and
        --      table_age(i) < 3) and
        --      (table_last_amt(i) >= 40000 or tdi_credit >= 40000)) then
        --      rank := 104;
        --      goto calc_risk;
        --  end if;

        -- sp291 End Delete rule above ******************

        -- sp291 delete 104 below - replaced by rule 20 Pri 103

        --  if ((table_rectype(i) = 0 and table_mft(i) in (51,52)) and
        --      (table_last_amt(i) >= 40000 or tdi_credit >= 40000)) then
        --      rank := 104;
        --      goto calc_risk;
        --  end if;

        -- sp291 end delete 104 above

        -- sp291 Delete OIC rule below

        --  if (table_rectype(i) = 0 and (
        --      table_last_amt(i) >= 40000 or tdi_credit >= 40000) and
        --      ((fs = 1 and table_age(i) <= 5 and
        --           table_select_cd(i) = 67))) then
        --      rank := 104;
        --      goto calc_risk;
        --  end if;

        -- sp291 End delete OIC rule above

        -- SP212 added logic here for RISK 104
        -- sp291 Change Priority level to 103 add mft 31 and update to 54000 below
        -- SP377 Update threshold to 59000

        if (fs = 1 and table_mft(i) in (30,31) and sumbal >= 59000
            and (table_rectype(i) = 5 and table_age(i) < 3)
            and ALS_cnc(tin,fs,tt) = 0) then
            rank := 103;
            goto calc_risk;
        end if;

        -- sp291 End change Pri Level to 103 add mft 31 and update 54000 above

        -- sp291 Change priority to 105 from 102 remaining high priority TDA per Rule 9 below
        -- Update threshold to  $2257 and Add MFT 72
        -- SP377 Update threshold to 2528

        if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17,72) and
             table_age(i) < 2) and
             ((table_rectype(i) = 5 and table_baldue(i) >= 2528)) then
            rank := 105;
            goto calc_risk;
        end if;

        -- sp291 End change Priority to 105 from 102 for TDA Part Rule 9 above

        -- sp291 Update threshold to 150453 for Pri 105 below
        -- SP377 Update threshold to 168546

        if (table_rectype(i) = 5 and sumbal >= 168546) then
            rank := 105;
            goto calc_risk;
        end if;

        -- sp291 End update threshold to 150453 for Pri 105 above

        -- sp291 Update threshold to 37613  for Pri 105 below
        -- SP377 Update threshold to 42136

        if ((table_rectype(i) = 5 and sumbal >= 42136) and
            (table_mft(i) in (51,52))) then
            rank := 105;
            goto calc_risk;
        end if;

        -- sp291 End update threshold to 37613 for Pri 105 above

        -- sp291 Delete OIC rule below

        --  if ((table_rectype(i) = 5 and sumbal >= 25000) and (oic_acc_yr >
        --      (year - 5))) then
        --      rank := 105;
        --      goto calc_risk;
        --  end if;

        -- sp291 End delete OIC rule above

        -- sp291 Update and move to Pri 107 per Rule 33 below

        --  if (table_rectype(i) = 0 and
        --      (table_last_amt(i) >= 150453 or tdi_credit >= 150453)) then
        --      rank := 107;
        --      goto calc_risk;
        --  end if;

        -- sp291 End Update and move to Pri 107 per Rule 33 above

        -- sp291 Change pri from 102 to 107 (high priority TDI) below for Rule 10
        -- SP377 Update threshold to 2528

        if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17,72)) and
            ((table_rectype(i) = 0 and table_last_amt(i) >= 2528 and
              table_age(i) < 2) or
             (table_rectype(i) = 0 and tdi_credit >= 2528 and
              table_age(i) < 2))) then
            rank := 107;
            goto calc_risk;
        end if;

        -- sp291 End change pri from 102 to 107 (high priority TDI) above for Rule 10

        -- sp291 Change pri to 107 and update LRA / TDI to 150453 below for Rule 33
        -- SP377 Update threshold to 168546

        if (table_rectype(i) = 0 and
            (table_last_amt(i) >= 168546 or tdi_credit >= 168546)) then
            rank := 107;
            goto calc_risk;
        end if;

        -- sp291 End change pri to 107 and update LRA / TDI to 150453 above for Rule 33

        -- sp291 Change pri Level from 108 to 107 (remaining high pri TDI) and
        --       Update threshold to 15,045 for LRA and TDI credit and
        --       Add MFT 72 per Rule 40 per Rule 40 below
        -- SP377 Update threshold to 16854

        if (fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17,72) and
            table_rectype(i) = 0 and
            (table_last_amt(i) >= 16854 or tdi_credit >= 16854)) then
            rank := 107;
            goto calc_risk;
        end if;

        -- sp291 End Rule 40 changes above

        -- sp291 Change pri level from 108 to 107 (remaining high pri TDI) and
        --       Update threshold to 15,045 for tf_lra_sum and
        --       Add MFT 72 per Rule 41 below
        -- SP377 Update threshold to 16854

        if ( fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17,72) and
             table_rectype(i) = 0 and
             (tf_mod_cnt < 5 and tf_lra_sum >= 16854)) then
            rank := 107;
            goto calc_risk;
        end if;

        --SP377 New Rule add 108 MFT 55 with civil penalty 618  and 23 C date is sysdate - 365.

        if ( table_mft(i) = 55 and
             table_rectype(i) = 5 and table_civp(i) = 618 and
             (table_dtassd(i) >= sysdate - 365)) then
            rank := 108;
            goto calc_risk;
        end if;

        --SP377 End add new 108 ******************************************************************

        -- sp291 End Rule 41 changes above

        -- sp291 Delete rule per Rule 42 / 43 below

        --  if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17) and
        --       table_age(i) < 2) and
        --       ((table_rectype(i) = 5 and table_baldue(i) >= 1000) or
        --        (table_rectype(i) = 0 and table_last_amt(i) >= 1000 and
        --         max_age < 2 and max_age ^= -1) or
        --        (table_rectype(i) = 0 and tdi_credit >= 1000 and
        --         max_age < 2 and max_age ^= -1) )) then
        --       rank := 201;
        --       goto calc_risk;
        --  end if;

        -- sp291 End delete per rule 42 / 43 above

        -- sp291 Delete rule per Rule 44 / 45 below

        --  if ((fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17) and
        --       table_age(i) < 3) and
        --       ((table_rectype(i) = 5 and table_baldue(i) >= 1500) or
        --        (table_rectype(i) = 0 and table_last_amt(i) >= 1500 and
        --         max_age < 3 and max_age ^= -1) or
        --        (table_rectype(i) = 0 and tdi_credit >= 1500 and
        --         max_age < 3 and max_age ^= -1) )) then
        --       rank := 201;
        --       goto calc_risk;
        --  end if;

        -- sp291 End delete per rule 44 / 45 above

        -- sp291 Change pri level from 202 to 201  (medium pri TDA cases) and
        -- update thresholds to 22568 for sumbal per Rule 46 below
        -- SP377 Update threshold to 24932

        if (table_rectype(i) = 5 and sumbal >= 24932 and
            (table_mft(i) in (51,52))) then
            rank := 201;
            goto calc_risk;
        end if;

        -- sp291 End Rule 46 changes above

        -- Begin Add THE FS to need to check FS variable
        -- Priority updated to Level to 201 and
        -- update threshold to 22568 for sumbal per combined rules 57 and 59
        -- SP377 Update threshold to 24932

        if (table_rectype(i) = 5 and sumbal >= 24932) then
            rank := 201;
            goto calc_risk;
        end if;

        -- End Modify and Move combined Rules 57 and 59 above

        -- sp 291 Moved and modified Rule 61a from Pri 108 to Pri 201 below

        if (fs = 2 and table_rectype(i) = 5 and
            table_mft(i) in (01,03,08,09,11,12,14,16,17,72)) then
            rank := 201;
            goto calc_risk;
        end if;

        -- sp 291 End moved and modified Rule 61a from Pri 108 to Pri 201 above

        -- sp291 Modify and move Pri 206 and 207 below to combined
        --       Pri 201 for BOTH IMF and BMF top logic and change Pri 202 middle logic
        --       and comment out below per Rules 57,59,58 and 60

        --  if (fs = 1 and
        --      ((table_rectype(i) = 5 and sumbal >= 15000) or
        --       (table_rectype(i) = 0 and table_last_amt(i) >= 15000) or
        --       (table_rectype(i) = 0 and tdi_credit >= 15000))) then
        --      rank := 206;
        --      goto calc_risk;
        --  end if;

        --  if (fs = 2 and
        --      ((table_rectype(i) = 5 and sumbal >= 15000) or
        --       (table_rectype(i) = 0 and table_last_amt(i) >= 15000) or
        --       (table_rectype(i) = 0 and tdi_credit >= 15000))) then
        --      rank := 207;
        --      goto calc_risk;
        --  end if;

        -- sp 291 End combine for Pri 201 for BOTH IMF and BMF top and Pri 202 for middle logic
        --        and comment out above per Rules 57,59,58 and 60

        -- sp291 Modify for Rules 61a and 61b for Pri's 201 and 202 and
        --       comment out below per Rules 61a and 61b

        --  if (fs = 2 and table_mft(i) in (01,03,08,09,11,12,14,16,17)) then
        --      rank := 208;
        --      goto calc_risk;
        --  end if;

        -- sp291 End modify for Rules 61a and 61b for Pri's 201 and 202 and
        --        comment out above per Rules 61a and 61b

        -- sp291 Update threshold to 22568 for sumbal for Rule 62 below
        -- SP377 Update threshold to 24932

        if (table_rectype(i) = 5 and sumbal < 24932) then
            rank := 301;
            goto calc_risk;
        end if;

        -- sp291 End update threshold to 22568 for sumbal for Rule 62 above

        -- sp291 No change per Rule 63 below

        if (fs = 1 and table_rectype(i) = 0) then
            rank := 302;
            goto calc_risk;
        end if;

        -- sp 291 End of indicting no changes per Rule 63 above

        -- sp291 Pri 303 changed to Pri 302 per Rule 64 below

        if ( fs = 2 and table_rectype(i) = 0) then
            rank := 302;
            goto calc_risk;
        end if;

        -- sp291 End Pri 303 changed to Pri 302 per Rule 64 above

        if (rank = 0) then
            rank := 399;
        end if;

        <<calc_risk>>
        if (table_risk(numrecs - 1) = 0) then
            table_risk(numrecs - 1) := rank;
        elsif ( rank < table_risk(numrecs - 1) ) then
            table_risk(numrecs - 1) := rank;
        end if;

        table_predic(numrecs - 1) := precd;
        table_predcyc(numrecs - 1) := precyc;

        -- if(tin = 1032693) then
        -- dbms_output.put_line('finished TIN: '||tin||' fs: '||fs||' address: '||address);
        -- dbms_output.put_line('TIN: '||tin||' RANK: '||rank||' CURR_RISK: '||curr_risk);
        -- dbms_output.put_line('HOLDING: '||table_risk(numrecs - 1));
        -- dbms_output.put_line('mft: '||table_mft(i));
        -- dbms_output.put_line('prd: '||table_dtper(i));
        -- dbms_output.put_line('year: '||to_char(table_dtper(i),'yyyy'));
        -- dbms_output.put_line('rectype: '||table_rectype(i));
        -- dbms_output.put_line('select_cd: '||table_select_cd(i));
        -- dbms_output.put_line('age: '||table_age(i));
        -- dbms_output.put_line('last_amt: '||table_last_amt(i));
        -- dbms_output.put_line('civp: '||table_civp(i));
        -- dbms_output.put_line('special_proj_cd: '||table_special_proj_cd(i));
        -- dbms_output.put_line('sumbal: '||sumbal);
        -- dbms_output.put_line('max_age: '||max_age);
        -- tdicredit(tin,tt,fs));
        -- dbms_output.put_line('oic_acc_yr: '||oic_acc_yr);
        -- end if;

        END LOOP;

    END LOOP;

    IF numrecs > 1 THEN
        FORALL lp_cnt in 1 .. (numrecs - 1)
            UPDATE tinsummary set risk = table_risk(lp_cnt),
                   emis_predic_cd = table_predic(lp_cnt),
                   emis_predic_cyc = table_predcyc(lp_cnt),
                   tdacnt = (case when
                       decode(ent_tdi_xref,'A',1,'C',1,0) = 1 then
                       (select count(*) from coredial, dialmod where
                           --grnum = 70 and
                           grnum between 82 and 83 and
                           coresid = modsid and
                           coretin = emistin and
                           corefs  = emisfs  and
                           corett  = emistt  and
                           rectype = 5) else 0 end),
                   tdicnt = (case when
                       decode(ent_tdi_xref,'I',1,'C',1,0) = 1 then
                       (select count(*) from coredial, dialmod where
                           --grnum = 70 and
                           grnum between 82 and 83 and
                           coresid = modsid and
                           coretin = emistin and
                           corefs  = emisfs  and
                           corett  = emistt  and
                           rectype = 0) else 0 end)
            WHERE rowid = table_rowid(lp_cnt);
    END IF;
    -- SP253 Rule update BMF case with 30+ TDAs and at least one TDA is
    -- MFT 01, 03, 08, 09, 11, 12, 14, 16 or 17  Less than 2 years old.

    --  update tinsummary
    --  set risk = 99
    --  where
    --      emisfs = 2
    --  and tdacnt >= 30;

    -- ===================================================================
    -- NOTE: Global updates of cases is run
    ------- only once for the entire country
    ------- when Area 35 is processed.
    -- ===================================================================

    IF(area = 35) then

        update tinsummary set risk = 99 where
        tdacnt >= 30 and emisfs = 2 and
        exists (select 1 from coredial
        where
                emistin = coretin and
                emisfs  = corefs  and
                emistt  = corett  and
                --grnum   = 70      and
                grnum between 82 and 83 and
                exists (select 1 from dialmod
                where
                        coresid = modsid and
                        rectype = 5 and
                        howold(taxperiod1(dtper,mft),today) < 2 and
                        mft in (01,03,08,09,11,12,14,16,17,72)));

    END IF;

    -- =======================================================================
    -- COMPLETION SECTION
    -- =======================================================================
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
            DBMS_OUTPUT.PUT_LINE('tin: ' || tin || ' address: ' || address);
        END IF;
        ROLLBACK;
        RAISE;

END SP_COMBO_RISK_ASSESSMENT;
/

-- =======================================================================
-- GRANT PERMISSIONS (if needed)
-- =======================================================================
-- GRANT EXECUTE ON SP_COMBO_RISK_ASSESSMENT TO [your_user/role];

-- =======================================================================
-- EXAMPLE USAGE
-- =======================================================================
/*
DECLARE
    v_records NUMBER;
    v_time NUMBER;
    v_status VARCHAR2(50);
    v_error VARCHAR2(4000);
BEGIN
    SP_COMBO_RISK_ASSESSMENT(
        p_area_filter => NULL,        -- Process all areas
        p_parallel_degree => 4,       -- Use 4-way parallelism
        p_debug_mode => 'Y',          -- Enable debug output
        p_commit_size => 10000,       -- Batch size
        o_records_processed => v_records,
        o_execution_time => v_time,
        o_status => v_status,
        o_error_message => v_error
    );
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Records: ' || v_records);
    DBMS_OUTPUT.PUT_LINE('Time: ' || v_time || ' ms');
    IF v_error IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || v_error);
    END IF;
END;
/
*/
