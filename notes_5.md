# ETL Archive File Processing Documentation

## Overview
This document outlines the process for handling archive source files within the ETL (Extract, Transform, Load) pipeline, specifically addressing the management of daily and weekly data extraction jobs.

## Process Requirements

### Prerequisites
Before executing daily and weekly ETL jobs, a cron job must be established to trigger the archive file processing workflow.

### File Management Workflow

#### 1. Source File Migration
- **Source Directory**: `/eftu/entity/incoming`
- **Destination Directory**: `/eftu/entity/ics/previous_extracts`
- **Action**: Copy all source files from incoming to previous_extracts directory

#### 2. File Naming Convention
Files are renamed using the `.YYYYMMDD` date pattern upon processing.

**Example**: 
- Original file: `E5.20250804`
- Processed file maintains the date suffix for tracking purposes

#### 3. Date Logic Implementation
The system implements the following date calculation logic:
- **Extract Date Calculation**: File content date + 1 day for E* files
- **Archive Date Calculation**: Extract date + 2 days for S1 files

**Example Scenario**:
- Daily run date: Tuesday, July 29, 2025
- E5 extract date: July 28, 2025
- Resulting filename: `E5.20250729`

#### 4. Archive File Handling
- **Condition**: If the source file is empty
- **Action**: The system defaults to using E1 extract date + 1 day for archive file dating

### Daily Operations Protocol

#### Pre-Processing Validation
Before initiating daily or weekly processing:
1. Verify input date-related files exist in `/eftu/entity/ics/previous_extracts`
2. If files exist:
   - Copy files to `/eftu/entity/ics/current_extracts`
   - Rename files by removing the `.YYYYMMDD` suffix
3. If files do not exist:
   - Display "files not exist" message
   - Halt daily and weekly processing

#### Source File Processing
- **Daily Processing**: Extract files from `/eftu/entity/ics/current_extracts`
- **Weekly Processing**: Extract files from `/eftu/entity/ics/current_extracts`
- **Important**: No archive or restore operations should be integrated into daily and weekly processing workflows

## Critical Notes

### Archive and Restore Operations
Archive files and file restoration from archives must be executed and completed prior to running any daily or weekly ETL processes. These operations are independent of the standard ETL workflow and serve as prerequisite steps.

### File Path Structure
- **Incoming Files**: `/eftu/entity/incoming`
- **Previous Extracts**: `/eftu/entity/ics/previous_extracts` 
- **Current Extracts**: `/eftu/entity/ics/current_extracts`

## Implementation Recommendations

1. **Automation**: Implement cron job scheduling for consistent daily and weekly execution
2. **Error Handling**: Establish robust error handling for missing files scenarios
3. **Logging**: Implement comprehensive logging for file operations and date calculations
4. **Validation**: Add file integrity checks before processing
5. **Monitoring**: Set up alerts for failed file operations or missing source files
