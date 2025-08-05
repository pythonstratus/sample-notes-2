#!/bin/csh -f

echo "Generating sanity please wait..."
echo " "

set SRVTYPE = `uname -n`
source /als-ALS/app/execloc/d.als/ORA.path
set pw = '/als-ALS/app/execloc/d.common/DecipherIt als'

# Create output directory if it doesn't exist
set output_dir = "/tmp/sanity_reports"
mkdir -p $output_dir

# Set output filename with timestamp
set timestamp = `date +%Y%m%d_%H%M%S`
set csv_file = "${output_dir}/sanity_report_${timestamp}.csv"

echo "Generating sanity report to: $csv_file"
echo " "

# Initialize CSV file with headers
echo "Report_Section,Status,Count,Server_Type,Timestamp" > $csv_file

sqlplus -s als/{pw} << EOF1 > /dev/null
set linesize 25
set pagesize 100
set feedback off
break on report
compute sum of count(*) on report

-- Redirect output to temporary files for processing
spool ${output_dir}/ent_sanity_cnts.tmp

prompt ENT Status Counts
select 'ENT,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from ent group by status order by 1;

prompt TRANTRAIL Status Counts  
select 'TRANTRAIL,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from trantrail group by status order by 1;

prompt ENTMOD Status Counts
select 'ENTMOD,' || status || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entmod group by status order by 1;

prompt ENTACT Status Counts
select 'ENTACT,' || rptdef || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from entact group by rptdef order by 1;

prompt TIMETIN Codes
select 'TIMETIN,' || code || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timetin group by code order by 1;

prompt TIMEMON Time Codes
select 'TIMEMON,' || timecode || ',' || count(*) || ',' || '$SRVTYPE' || ',' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') from timemon group by timecode order by 1;

spool off
quit
EOF1

# Process the temporary file to create proper CSV
if (-f ${output_dir}/ent_sanity_cnts.tmp) then
    # Remove SQL*Plus formatting and extract only the CSV lines
    grep -E "^(ENT|TRANTRAIL|ENTMOD|ENTACT|TIMETIN|TIMEMON)," ${output_dir}/ent_sanity_cnts.tmp >> $csv_file
    
    # Clean up temporary file
    rm -f ${output_dir}/ent_sanity_cnts.tmp
endif

echo " "

# Server type detection with CSV output
if (${SRVTYPE} == "devdb.abc.com") then
    echo "*** DEVELOPMENT SERVER ***"
    echo "SERVER_INFO,DEVELOPMENT SERVER,1,$SRVTYPE,`date '+%Y-%m-%d %H:%M:%S'`" >> $csv_file
else if (${SRVTYPE} == "proddb.abc.com") then
    echo "*** PRODUCTION SERVER ***" 
    echo "SERVER_INFO,PRODUCTION SERVER,1,$SRVTYPE,`date '+%Y-%m-%d %H:%M:%S'`" >> $csv_file
else
    echo "*** TEST SERVER ***"
    echo "SERVER_INFO,TEST SERVER,1,$SRVTYPE,`date '+%Y-%m-%d %H:%M:%S'`" >> $csv_file
endif

echo " "

# Display the CSV file location and contents
echo "CSV report generated: $csv_file"
echo "Contents preview:"
echo "=================="
head -20 $csv_file

echo " "
echo "Sanity generation complete. CSV file ready for spreadsheet import."
echo "File location: $csv_file"

# Optional: Create an Excel-compatible version using a simple conversion
set xlsx_file = "${output_dir}/sanity_report_${timestamp}.xlsx"

# If you have access to a CSV to Excel converter, uncomment below:
# python3 -c "
# import pandas as pd
# df = pd.read_csv('$csv_file')
# df.to_excel('$xlsx_file', index=False)
# print('Excel file created: $xlsx_file')
# " 2>/dev/null

echo "To import into Excel/Google Sheets:"
echo "1. Open your spreadsheet application"
echo "2. Import/Open the CSV file: $csv_file" 
echo "3. Choose comma as delimiter"
echo "4. Data will be organized in columns: Report_Section, Status, Count, Server_Type, Timestamp"
