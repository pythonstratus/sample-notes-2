# ETL Weekly Jobs: Technical Analysis & Recommendations

## Executive Summary

Our team has thoroughly verified that our Java code implementation for Weekly ETL jobs is compliant with the procedure code standards. However, during our testing, we've encountered significant database-related challenges that prevent successful execution of the Weekly ETL jobs. These issues stem primarily from the current snapshot-based architecture and cross-schema dependencies, not from our code implementation. This document outlines our key findings, supporting evidence, and recommended path forward.

## Key Issues Identified

### 1. Snapshot Methodology Limitations

The current Pre/Post snapshot approach is proving problematic for several critical reasons:

- **Data Structure Inconsistencies**: Significant structural differences exist between source tables and their snapshot counterparts, causing comparison failures
- **Timestamp Handling**: The snapshot creator adds timestamps to date fields while legacy tables don't have them, creating false differences
- **Count Discrepancies**: Numerous tables show inconsistent record counts between source tables and snapshots
- **Audit Trail Errors**: Persistent audit trail errors are preventing the completion of multiple ETL processes

### 2. Cross-Schema Dependencies

We've identified problematic cross-schema dependencies:

- Functions in ALS schema are being directly referenced by ENTITY Dev schema procedures
- The SIDs handling shows inconsistency - for example, CNT tables use different SID sourcing methods
- Oracle space management issues arise due to these cross-schema references

### 3. Data Reconciliation Problems

Our comparison analysis using custom functions reveals:

- **ARCHIVEINV table**: Source shows 5208 records vs. 5109 in the snapshot, with 142 records missing in the snapshot and 43 records in the snapshot missing from the source
- **ARCHIVECASEDSP table**: Source shows 13066 records vs. 12992 in the snapshot
- **E9HOLD table**: Case ID issues where records remain null due to missing TIN relationships

## Detailed Analysis

### Table Comparison Results

| Table Name | Source Count | Snapshot Count | Difference | Key Issues |
|------------|-------------|----------------|------------|------------|
| ARCHIVECASEDSP | 13066 | 12992 | -74 | Inconsistent record counts |
| ARCHIVEINV | 5208 | 5109 | -99 | 142 records missing in snapshot, 43 in snapshot not in source |
| CNT tables | - | - | >500 | SID/TNSID differences |
| ENTMOD | - | - | - | emodSID inconsistencies |
| ENTMOD_EOM | - | - | - | Source has 2 rows vs. 35 in snapshot |
| E9HOLD | - | - | - | Case ID blank, TIN issues |
| EOM_TRAIL | - | - | - | CLOSEDATE 03/29 data missing |
| SUM_ENT | - | - | - | Record differences |
| TINSUMMARY | - | - | - | Failed comparison |

### Schema and Function Dependencies

We identified critical cross-schema issues:

1. **Function References**:
   - Table iczips comes from procedure: ASSN_PROID
   - Table model_avg comes from procedure: UPDT_ENT_CONTROL
   - Both procedures lack update/insert handling for these tables

2. **SID Resolution**:
   - TNSIDs are inconsistently handled between schemas
   - For CNT tables, different SID sources are causing reconciliation failures

3. **Data Flow Issues**:
   - The E3 process cannot find certain data in ENT table that exists in E9TMP
   - E9 tables showing incorrect relationships to ENT data

## Impact to Testing and Progress

These database issues are severely hampering our testing capabilities:

1. Recurring audit trail errors prevent complete testing cycles
2. Space management issues when running Weekly and Daily jobs in parallel
3. Unable to validate correct data flow due to snapshot inconsistencies
4. Cross-schema references create unpredictable behavior
5. Structural differences between tables cause comparison failures

## Recommendations

### Alternative Approaches to Pre/Post Snapshots

Given the significant challenges with the current Pre/Post snapshot methodology, we recommend the following alternatives:

1. **Implement Change Data Capture (CDC) Approach**:
   - Rather than taking full table snapshots, track only the changes made during ETL processing
   - Set up change tracking on source tables before ETL execution
   - Create log tables to store only the modified records with operation type (INSERT/UPDATE/DELETE)
   - This reduces space requirements dramatically while still maintaining audit capability
   - Example implementation:
     ```sql
     CREATE TABLE ETL_CHANGE_LOG (
         TABLE_NAME VARCHAR2(100),
         OPERATION_TYPE VARCHAR2(10),
         RECORD_KEY VARCHAR2(200),
         OLD_VALUES CLOB,
         NEW_VALUES CLOB,
         CHANGE_TIMESTAMP TIMESTAMP,
         ETL_JOB_ID NUMBER
     );
     ```

2. **Database Triggers for Validation**:
   - Implement temporary triggers during ETL that capture changes to critical tables
   - These triggers can log changes to dedicated audit tables without needing full snapshots
   - Triggers can be enabled only during ETL runs and disabled afterward
   - This provides granular visibility into exactly what changed without space overhead

3. **Materialized View Snapshots (Selective)**:
   - Instead of full table snapshots, create materialized views with only key columns
   - Include only columns needed for validation (not entire tables)
   - This provides a lightweight "fingerprint" of the table state that can be compared
   - Example:
     ```sql
     CREATE MATERIALIZED VIEW MV_ENT_VALIDATION AS
     SELECT TIN, TNSID, COUNT(*) AS RECORD_COUNT, 
            MAX(LAST_UPDATE) AS LAST_MODIFIED,
            SUM(CHECKSUM_VALUE) AS DATA_CHECKSUM
     FROM ENT
     GROUP BY TIN, TNSID;
     ```

4. **Row Hash Validation**:
   - Generate hash values for rows before and after ETL
   - Compare only the hash values rather than entire table contents
   - Store only record keys and their hash values, drastically reducing space requirements
   - Example:
     ```sql
     CREATE TABLE VALIDATION_HASHES (
         TABLE_NAME VARCHAR2(100),
         PRIMARY_KEY VARCHAR2(200),
         ROW_HASH VARCHAR2(64),
         SNAPSHOT_TIME TIMESTAMP
     );
     
     -- Before ETL
     INSERT INTO VALIDATION_HASHES
     SELECT 'ENT', TIN, 
            STANDARD_HASH(TIN||TNSID||[other columns]), 
            SYSTIMESTAMP
     FROM ENT;
     ```

5. **Differential Backup and Compare**:
   - Use Oracle's DBMS_COMPARISON package to perform table comparisons
   - This built-in utility can efficiently identify differences without requiring snapshots
   - Example:
     ```sql
     BEGIN
       DBMS_COMPARISON.CREATE_COMPARISON(
         comparison_name => 'compare_ent',
         schema_name => 'ENTITYDEV',
         object_name => 'ENT',
         dblink_name => NULL,
         remote_schema_name => 'ENTITYDEV', 
         remote_object_name => 'ENT_BACKUP',
         comparison_mode => 'ROW');
     END;
     ```

### Immediate Implementation Strategy

For immediate progress while a long-term solution is developed:

1. **Selective Snapshots**: 
   - Take snapshots of only the most critical tables rather than all tables
   - Focus validation efforts on tables with known issues (e.g., ARCHIVEINV, ARCHIVECASEDSP)

2. **Resolve Schema Dependencies**:
   - Move cross-schema functions to appropriate locations
   - Standardize SID/TNSID handling across all tables
   - Implement consistent timestamp handling

3. **Improve Space Management**:
   - Implement cleanup procedures to run after each test
   - Schedule Daily and Weekly jobs at different times to avoid space contention
   - Request temporary increase in tablespace allocation during testing phases

4. **Enhanced Testing Approach**:
   - Develop isolated test environments for Weekly vs. Daily jobs
   - Create specific test cases for known problematic tables
   - Implement automated structure verification before running jobs

## Supporting Documentation

[INSERT SCREENSHOT 1: Table comparison results showing failures]

[INSERT SCREENSHOT 2: Function comparison and structural differences]

[INSERT SCREENSHOT 3: Count discrepancies between tables and snapshots]

[INSERT SCREENSHOT 4: Audit trail errors]

[INSERT SCREENSHOT 5: Cross-schema references]

## Conclusion

The Java code implementation for Weekly ETL jobs has been properly developed and verified as compliant with procedure code standards. However, significant database architecture issues are preventing successful execution. We recommend addressing the foundational snapshot methodology and cross-schema references before proceeding with further testing. A different approach to validation that doesn't rely on full Pre/Post snapshots would significantly improve both space utilization and testing efficiency.
