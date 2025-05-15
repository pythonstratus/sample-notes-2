# Solution for c.runARCHIVEINV Script Variable Inconsistency

## Executive Summary
The issue in the c.runARCHIVEINV process relates to variable name inconsistencies between the shell script (c.runARCHIVEINV) and the SQL script (mk_arch_INV.sql). Specifically, there's a mismatch between the variables being passed from the shell script and those being referenced in the SQL queries. The shell script uses `STRTDT` and `ENDDT`, while some portions of the SQL script are attempting to reference undefined variables called `timestart` and `timeend`.

## Background

### Script Purpose
The c.runARCHIVEINV script is part of an End-of-Month (EOM) processing workflow that:
- Creates archive inventory tables in an Oracle database
- Populates these tables with employee data
- Uses date parameters to filter records appropriately

### Current Implementation
1. The shell script (c.runARCHIVEINV) retrieves three key date variables from the ENTMONTH table:
   - RPTMNTH (report month)
   - STRTDT (start date)
   - ENDDT (end date)

2. These variables are passed to the mk_arch_INV.sql script as bind variables:
   - `:startro` and `:endro` (for ID ranges)
   - `:startdt` and `:enddt` (for date ranges)
   - `:rptmnth` (for the report month)

3. The SQL script successfully uses these variables in many places, for example:
   ```sql
   where
       extrdt between :startdt and :enddt and
       roid between :startro and :endro
   ```

## Problem Identified
Based on the error message and code review, some portions of the mk_arch_INV.sql script are attempting to reference `:timestart` and `:timeend` variables, which are not defined or passed from the shell script. This causes SQL errors when those sections of code execute, resulting in "table mismatch during the testing" as mentioned in the initial problem statement.

## Recommended Solution

### Option 1: Modify the SQL Script (Preferred)
The cleanest approach is to modify the mk_arch_INV.sql script to ensure consistent variable naming:

1. Search for all instances of `:timestart` and `:timeend` in mk_arch_INV.sql
2. Replace them with `:startdt` and `:enddt` respectively
3. This will align with the variables that are already being properly set and passed from the shell script

### Option 2: Modify the Shell Script
If modifying the SQL script is not feasible:

1. Add these lines to the c.runARCHIVEINV script after the STRTDT and ENDDT are set:
   ```bash
   # Add timestart/timeend as aliases for STRTDT/ENDDT
   set timestart = ${STRTDT}
   set timeend = ${ENDDT}
   ```

2. Modify the sqlplus command to pass these additional variables to the SQL script:
   ```bash
   sqlplus -s /nolog << EOF >& ${MKARCHOUT}
   connect als/${PW}
   variable startro number;
   variable endro number;
   variable startdt varchar2(10);
   variable enddt varchar2(10);
   variable rptmnth varchar2(7);
   variable timestart varchar2(10);  # Added
   variable timeend varchar2(10);    # Added
   
   begin
     :startro := 21000000;
     :endro := 35999999;
     :startdt := '${STRTDT}';
     :enddt := '${ENDDT}';
     :rptmnth := '${RPTMNTH}';
     :timestart := '${STRTDT}';  # Added
     :timeend := '${ENDDT}';     # Added
   end;
   /
   
   @${LOADDIR}/mk_arch_INV
   
   EOF
   ```

## Implementation Steps

1. **Identify All Variable References**: 
   - Run a search for "timestart" and "timeend" in mk_arch_INV.sql to find all occurrences

2. **Make Code Changes**:
   - Implement either Option 1 or Option 2 (Option 1 is recommended)
   - Document the changes made

3. **Testing**:
   - Test the script with a small dataset first
   - Verify that no SQL errors occur related to undefined variables
   - Confirm that the archive tables are populated correctly

4. **Deployment**:
   - Schedule the change during a maintenance window
   - Have a rollback plan in case of unexpected issues
   - Update documentation to reflect the changes

## Long-term Recommendations

1. **Code Standards**: Implement a naming convention for bind variables to prevent similar issues in the future

2. **Error Handling**: Enhance the shell script to include better error handling that can detect and report SQL errors more specifically

3. **Documentation**: Maintain comprehensive documentation of all script variables and their purposes

4. **Version Control**: Ensure all scripts are under version control to track changes and facilitate rollbacks if needed

This solution addresses the immediate problem while also providing a path to prevent similar issues in the future.
