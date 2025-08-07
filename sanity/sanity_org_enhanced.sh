#!/bin/csh -f

echo "Generating sanity org please wait..."
echo " "

set SRVTYPE = `uname -n`
source /als-ALS/app/execloc/d.als/ORA.path
set pw = '/als-ALS/app/execloc/d.common/DecipherIt als'

# Create output directory if it doesn't exist
set output_dir = "/tmp/sanity_org_reports"
mkdir -p $output_dir

# Set output filename with timestamp
set timestamp = `date +%Y%m%d_%H%M%S`
set csv_file = "${output_dir}/sanity_org_report_${timestamp}.csv"

echo "Generating sanity org report to: $csv_file"
echo " "

# Initialize CSV file with headers
echo "Report_Section,Organization,Status_Item,Count,Server_Type,Timestamp" > $csv_file

sqlplus -s als/{pw} << EOF1 > /dev/null
set linesize 25
set pagesize 100
set feedback off
break on report
compute sum of count(*) on report

-- Redirect output to temporary files for processing
spool ${output_dir}/ent_sanity_org_cnts.tmp

prompt SANITY ORG CF
prompt ENT CF Status Counts
select 'ENT,CF,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from ent where get_org(tinsid,status) = 'CF' group by status order by 1;

prompt TRANTRAIL CF Status Counts
select 'TRANTRAIL,CF,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from trantrail where org = 'CF' group by status order by 1;

prompt ENTMOD CF Status Counts
select 'ENTMOD,CF,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entmod where case_org(roid) = 'CF' group by status order by 1;

prompt ENTACT CF RPT Counts
select 'ENTACT,CF,' || rptdef || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entact where case_org(roid) = 'CF' group by rptdef order by 1;

prompt TIMETIN CF Code Counts
select 'TIMETIN,CF,' || code || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timetin where case_org(roid) = 'CF' group by code order by 1;

prompt TIMEMON CF Time Code Counts
select 'TIMEMON,CF,' || timecode || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timemon where case_org(roid) = 'CF' group by timecode order by 1;

prompt SANITY ORG CP
prompt ENT CP Status Counts
select 'ENT,CP,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from ent where get_org(tinsid,status) = 'CP' group by status order by 1;

prompt TRANTRAIL CP Status Counts
select 'TRANTRAIL,CP,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from trantrail where org = 'CP' group by status order by 1;

prompt ENTMOD CP Status Counts
select 'ENTMOD,CP,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entmod where case_org(roid) = 'CP' group by status order by 1;

prompt ENTACT CP RPT Counts
select 'ENTACT,CP,' || rptdef || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entact where case_org(roid) = 'CP' group by rptdef order by 1;

prompt TIMETIN CP Code Counts
select 'TIMETIN,CP,' || code || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timetin where case_org(roid) = 'CP' group by code order by 1;

prompt TIMEMON CP Time Code Counts
select 'TIMEMON,CP,' || timecode || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timemon where case_org(roid) = 'CP' group by timecode order by 1;

prompt SANITY ORG AD
prompt ENT AD Status Counts
select 'ENT,AD,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from ent where get_org(tinsid,status) = 'AD' group by status order by 1;

prompt TRANTRAIL AD Status Counts
select 'TRANTRAIL,AD,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from trantrail where org = 'AD' group by status order by 1;

prompt ENTMOD AD Status Counts
select 'ENTMOD,AD,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entmod where case_org(roid) = 'AD' group by status order by 1;

prompt ENTACT AD RPT Counts
select 'ENTACT,AD,' || rptdef || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entact where case_org(roid) = 'AD' group by rptdef order by 1;

prompt TIMETIN AD Code Counts
select 'TIMETIN,AD,' || code || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timetin where case_org(roid) = 'AD' group by code order by 1;

prompt TIMEMON AD Time Code Counts
select 'TIMEMON,AD,' || timecode || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timemon where case_org(roid) = 'AD' group by timecode order by 1;

prompt SANITY ORG XX
prompt ENT XX Status Counts
select 'ENT,XX,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from ent where get_org(tinsid,status) = 'XX' group by status order by 1;

prompt TRANTRAIL XX Status Counts
select 'TRANTRAIL,XX,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from trantrail where org = 'XX' group by status order by 1;

prompt ENTMOD XX Status Counts
select 'ENTMOD,XX,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entmod where case_org(roid) = 'XX' group by status order by 1;

prompt ENTACT XX RPT Counts
select 'ENTACT,XX,' || rptdef || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entact where case_org(roid) = 'XX' group by rptdef order by 1;

prompt TIMETIN XX Code Counts
select 'TIMETIN,XX,' || code || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timetin where case_org(roid) = 'XX' group by code order by 1;

prompt TIMEMON XX Time Code Counts
select 'TIMEMON,XX,' || timecode || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timemon where case_org(roid) = 'XX' group by timecode order by 1;

spool off
quit
EOF1

# Process the temporary file to create proper CSV
if (-f ${output_dir}/ent_sanity_org_cnts.tmp) then
    # Remove SQL*Plus formatting and extract only the CSV lines
    grep -E "^(ENT|TRANTRAIL|ENTMOD|ENTACT|TIMETIN|TIMEMON)," ${output_dir}/ent_sanity_org_cnts.tmp >> $csv_file
    
    # Clean up temporary file
    rm -f ${output_dir}/ent_sanity_org_cnts.tmp
endif

echo " "

# Server type detection with CSV output
if (${SRVTYPE} == "devdb.abc.com") then
    echo "*** DEVELOPMENT SERVER ***"
    echo "SERVER_INFO,ALL,DEVELOPMENT SERVER,1,$SRVTYPE,`date '+%Y-%m-%d %H:%M:%S'`" >> $csv_file
else if (${SRVTYPE} == "proddb.abc.com") then
    echo "*** PRODUCTION SERVER ***" 
    echo "SERVER_INFO,ALL,PRODUCTION SERVER,1,$SRVTYPE,`date '+%Y-%m-%d %H:%M:%S'`" >> $csv_file
else
    echo "*** TEST SERVER ***"
    echo "SERVER_INFO,ALL,TEST SERVER,1,$SRVTYPE,`date '+%Y-%m-%d %H:%M:%S'`" >> $csv_file
endif

echo " "

# Display the CSV file contents
cat ./ent_sanity_org_cnts.lst

echo " "

# Display the CSV file location and contents preview
echo "CSV org report generated: $csv_file"
echo "Contents preview:"
echo "=================="
head -20 $csv_file

echo " "
echo "Sanity org generation complete. CSV file ready for spreadsheet import."
echo "File location: $csv_file"

# Create organization summary
set summary_file = "${output_dir}/sanity_org_summary_${timestamp}.csv"
echo "Organization,Total_Records,Report_Date" > $summary_file

# Count records by organization
foreach org (CF CP AD XX)
    set org_count = `grep ",$org," $csv_file | awk -F',' '{sum += $4} END {print sum+0}'`
    echo "$org,$org_count,`date '+%Y-%m-%d %H:%M:%S'`" >> $summary_file
end

echo "Organization summary created: $summary_file"

echo " "
echo "To import into Excel/Google Sheets:"
echo "1. Open your spreadsheet application"
echo "2. Import/Open the CSV file: $csv_file" 
echo "3. Choose comma as delimiter"
echo "4. Data will be organized in columns: Report_Section, Organization, Status_Item, Count, Server_Type, Timestamp"
echo "5. Use filters and pivot tables to analyze by organization"