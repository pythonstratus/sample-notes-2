# DIAL Project - Master Document

## Table of Contents
1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Project Architecture](#project-architecture)
4. [Data Sources and Processing Requirements](#data-sources-and-processing-requirements)
5. [Model Score and Priority Calculation Requirements](#model-score-and-priority-calculation-requirements)
6. [Database Structure and Relationships](#database-structure-and-relationships)
7. [Functional Requirements](#functional-requirements)
8. [Organization and Area Assignment Rules](#organization-and-area-assignment-rules)
9. [Technical Requirements](#technical-requirements)
10. [Development Approach](#development-approach)
11. [Configuration](#configuration)
12. [Running the Application](#running-the-application)
13. [Monitoring and Logging](#monitoring-and-logging)
14. [Appendix](#appendix)

## Project Overview
Dial is a Java-based application built to modernize the existing DIAL (Data Integration and Analysis for Lien) system, which processes tax-related information, identifies entities, consolidates data, and performs risk assessment. The application will replace the legacy scripts and C programs with a maintainable Java solution using Spring Batch and Spring Boot frameworks while preserving all existing functionality.

### Purpose
This project aims to transform a complex data processing pipeline that handles tax information from multiple sources, links related taxpayer data, performs complex calculations, and populates several database tables with processed information.

### System Overview
The DIAL system is responsible for:
- Processing taxpayer information across multiple areas (MRI and SB/SE)
- Linking TDI and TDA data for taxpayers
- Creating entities based on specific business rules
- Calculating priority scores for cases that may require further investigation
- Assigning cases to appropriate Revenue Officers

## Technology Stack
- **Java 17**
- **Spring Boot 3.2.x**: Application framework
- **Spring Batch 5.x**: For batch processing of data files
- **Spring Data JPA**: For database interactions
- **PostgreSQL**: Database (configurable)
- **Maven**: Dependency management and build tool
- **Lombok**: To reduce boilerplate code
- **Logback**: For application logging

## Project Architecture

### File Processing Flow
1. **File Upload and Verification**
   - Process CSV and XML files from a designated location
   - Verify file formats against expected schemas
   - Log verification status

2. **Account Processing**
   - Extract account data from files
   - Validate extracted information
   - Process data through the AML Application
   - Update account assignment records

3. **Escalation and Assignment**
   - Implement logic for "DAL" and "DEML" processing
   - Route cases to appropriate teams
   - Generate tickets for Mainframe Group when required

4. **Prioritization**
   - Apply Model Rank and Alpha Rank algorithms
   - Sort cases based on priority metrics
   - Assign to investigation queues

### Component Design

#### 1. File Processors
- `CSVFileProcessor`: Handles CSV file reading and validation
- `XMLFileProcessor`: Handles XML file reading and validation

#### 2. Batch Jobs
- `FileIngestionJob`: Reads and validates input files
- `AccountExtractionJob`: Parses account data from validated files
- `AMLProcessingJob`: Processes accounts through AML application
- `PrioritizationJob`: Applies ranking algorithms to accounts
- `AssignmentJob`: Assigns cases to appropriate teams

#### 3. Service Layer
- `VerificationService`: Handles data verification logic
- `ExtractionService`: Manages data extraction processes
- `AMLIntegrationService`: Integrates with AML application
- `NotificationService`: Sends notifications to relevant developers
- `TicketingService`: Opens tickets for the Mainframe Group

#### 4. Data Models
- `Account`: Represents account information
- `Investigation`: Represents an investigation case
- `ProcessingResult`: Captures processing outcomes
- `Notification`: Models notification data
- `Ticket`: Models ticketing data

## Data Sources and Processing Requirements

### Input Files
1. The system receives 26 extract files, 2 for each MRI and SB/SE area.
2. One file contains TDI data (produced by TDI32 run).
3. One file contains TDA data (produced by TDA32 run).
4. Each record contains full entity (i.e., case) and module information.
5. For each area, there is a directory containing raw DIAL extract files:
   - Example: The SB Area 21 contains files with raw data including:
     - TDA.raw files
     - raw.ctl files
     - raw.log files
     - COMBO.raw files
     - CFF files (CFF21ent.0706, CFF21mod.0706, etc.)
     - QUEUE files (QUEUE21ent.0706, QUEUE21sum.0706, etc.)
     - MODEL files (MODEL21.0706, etc.)

### Data Processing Flow
1. **Data Linking**: TDI and TDA files for a given taxpayer are combined into a COMBO.raw file.
2. **Temporary Storage**: Data is loaded into a temporary table RAWDATA, containing taxpayer TIN and the entire data line received.
3. **Data Sorting**: RAWDATA is sorted by TIN and used to create area COMBO.raw files (critical step using Dial1_crRAW script).
4. **Entity Creation**: 
   - The system must create ENTITIES based on specific requirements.
   - Entities are split for a given TIN based on taxpayer name (e.g., "John & Jane" is separate from "John & Jill").
   - This is currently handled by C code with ALS_strcmpi function.

### Database Requirements
1. The system must populate two main tables with distinct purposes:
   - **TINSUMMARY** table: Contains case level indicators based on ENTITY application definition, predicated solely on TIN, file Source, and TIN Type.
   - **COREDIAL** table: Contains taxpayer information based on ALS application which creates separate entities based on a combination of TIN and Taxpayer Name. This means different name variations for the same TIN require separate lien documents.

### Data Transformation
1. COMBO.RAW files are parsed into .dat files for loading to the database using SQLLDR:
   - DIALENT.dat loads to DIALENT table
   - DIALMOD.dat loads to DIALMOD table
   - DIALSUM.dat loads to TINSUMMARY table
   - MODELS.dat loads to MODEL_SCORE table

## Model Score and Priority Calculation Requirements

### Model Score Processing
1. Weekly extract of Master File information on each taxpayer's collection potential must be incorporated.
2. Data is translated into an alpha character linked to priority ranking of the case (e.g., 101b).
3. Model scores fall into specific categories as outlined in extracted data:
   - Various score types like S-1040-TDAFP-CFF52, W-1040-TDAFP-CFF52, 1120-TDAFP-CFF52, etc.
4. The system must apply complicated formulas using proc_TDA.sql, proc_TDI.sql, and func_MODELBUCKET.sql.
5. Must use Oracle NTILE statistical tool to separate values into 20 buckets which become the basis for alpha values.

### Priority Score Calculation
1. The Dial6_risk script calculates priority scores for each QUEUE case.
2. Priority scores fall into 4 broad categories:
   - 99: Accelerated
   - 101, 103, 105, 107: High priority
   - 201-202: Medium priority
   - 301-302: Low priority
3. Priority scores are determined using multiple factors:
   - Balance Due
   - Accruals Due (from SIA)
   - Type of Case
   - Age
   - Last Amount Due
   - Available credits
   - Special Project Codes
   - Civil Penalty Codes
   - Offer in Compromise History
   - Related accounts closed as uncollectible
   - Potential ROID

### Officer Assignment Algorithm
1. The system calculates which Revenue Officer might be assigned each case.
2. In Loadial, fields populated include QTO (queue territory number), QGP (queue group number), and QRO (queue Revenue Officer number).
3. MRI area is mapped to SB/SE area using CALC_AREA function.
4. ICSASSIGN function determines Revenue Officer based on:
   - ZIP CODE
   - GRADE LEVEL
   - First letter of taxpayer's name

### ICS Priority Rankings
1. The process for DIAL QUEUE cases is replicated for open cases received in the ICS extracts by a stored procedure RISKCALC.
2. Some of the required information is extracted from the DIAL tables.

## Database Structure and Relationships

### Database Schema
1. The database schema is located in ClearCase, cm_i/als/entity/d.schema.
2. Scripts contain indexes and database constraints that prevent NULL values in specified fields and validate values in specified fields.

### Key Tables and Relationships
The system uses the following key tables and relationships:

1. **ENT**: Entity Info (E1) - Primary key: TINSID
2. **TRANTRAIL**: Case Info (E1) - Links to ENT via ENT.TINSID = TRANTRAIL.TINSID
3. **ENTMOD**: Module Info (E2 & E4) - Links to TRANTRAIL via TRAILMATCH function
4. **ENTACT**: Activities (E3) - Links to TRANTRAIL via TINSID = ACTSID and TRANTRAIL.ROID = ENTACT.ROID
5. **TIMETIN**: Case related time charges (E7) - Links to TRANTRAIL via TINSID = TIMESID and TRANTRAIL.ROID = TIMETIN.ROID
6. **TIMENON**: Non-Case related time charges (E8) - Links via ROID to ENTEMP via ENTEMP.ROID = TIMENON.ROID
7. **ENTEMP**: Employee Info (E5) - Keys: ROID, SEID
8. **ENTCODE**: Case, Sub and Time Codes (S1) - Key: CODE
9. **ENTMONTH**: EOM Month Info Manual (RPTMONTH)
10. **EOM**: EOM Completion Manual (RPTMNTH)
11. **TINSUMMARY**: Entity app entity info - DIAL TINSID
12. **EMISTIN**: Links to COREDIAL via TINSID = CORESID or EMISTIN = CORETIN
13. **EMISFS** = COREFS and EMIS EMISTIT = CORETT
14. **COREDIAL**: ALS app entity info - DIAL CORESID
15. **DIALENT**: Additional entity info - Links from DIAL ENTSID to COREDIAL via CORESID = ENTSID
16. **DIALMOD**: Module Info - Links from DIAL MODSID to COREDIAL via CORESID = MODSID

### Trailmatch Algorithm
The system implements a complex algorithm for linking Modules (ENTMOD) to cases (TRANTRAIL) with the following rules:

1. **First look for open TRANTRAIL**:
   - If module is open and ROID matches - it matches
   - If module is closed and module closed date >= TRANTRAIL ASSNRO date - it matches

2. **Second, look again for open TRANTRAIL**:
   - If module is open and ROID does not match - it matches
   - If module is closed and Module closed date is between TRANTRAIL ASSNRO and TRANTRAIL closed date - it matches

3. **Third, look for closed TRANTRAIL with matching ROID**:
   - Module closed date is between TRANTRAIL ASSNRO and TRANTRAIL closed date

4. **Fourth, look for closed TRANTRAIL without matching ROID**:
   - Module closed date is between TRANTRAIL ASSNRO and TRANTRAIL closed date

5. **Fifth, look for closed TRANTRAIL without matching ROID**:
   - Module closed before TRANTRAIL CLOSEDT
   - Regardless of module and TRANTRAIL ASSNRO dates
   - This catches modules repeatedly transferred while TRANTRAIL was open but is now closed

6. **Sixth, look for closed TRANTRAIL with matching ROID**:
   - Module closed before TRANTRAIL CLOSEDT
   - Regardless of module and TRANTRAIL ASSNRO dates
   - This catches modules repeatedly transferred while TRANTRAIL was open but is now closed

7. **Seventh, look for transferred or RTO TRANTRAIL**:
   - If module is either 'C' or 'X' and ASSNRO date is greater than the earlier of TRANTRAIL ASSNFLD or TRANTRAIL ASSNRO dates

8. **Eighth, if any 'X' modules**:
   - If module ASSNRO date is greater than the earlier of TRANTRAIL ASSNRO or TRANTRAIL ASSNFLD dates - matches

9. **Ninth - give up - no match**

## Functional Requirements

### Core Processing Steps
The system must implement the following steps currently handled by the Dialmenu script:

1. **Step 1a**: Copy DIAL tables, point users to copies
   - **Dial1_dothcp**: Copies all DIAL tables
   - **Dial1_pointcp**: Points users to copies of DIAL tables

2. **Step 1**: Create COMBO.raw files
   - **Dial1_crRAW**: Creates COMBO.raw files

3. **Step 2**: Check and backup CFF and QUEUE files
   - **Dial2_crdata1**: Checks and makes backup copies of prior CFF and QUEUE (X-files)
   - **Dial2_crdata2**: Drops all Oracle constraints
   - **Dial2_crdata3**: Runs Loadial COMBO.raw for all areas to parse data and update the COREDIAL table
   - **Dial2_chkload**: Checks Dialaud to see if Loadial TDA/TDI.raw ran
   - **Dial2_crdata4**: Checks that CFF and QUEUEs were created

4. **Step 3**: Consolidate data files
   - **Dial3_consol**: Consolidates all data files to a common load area
   - **Dial3_crdata4**: Checks that CFF and QUEUEs were created
   - **Dial3_consol**: Consolidates all data files to a common load area
   - **Traps duplicate ENTSIDS**

5. **Step 4**: SQL load of tables
   - **Dial4_load_ent**: Sqlload of DIALENT
   - **Dial4_load_mod**: Sqlload of DIALMOD
   - **Dial4_load_sum**: Sqlload of DIALSUM
   - **Dial4_load_sco**: Sqlload of MODELS (IM)

6. **Step 5**: Rebuild and analyze
   - **Dial5_indexes**: Rebuilds Indexes and Constraints
   - **Dial5_analyze**: Analyzes tables and Indexes
   - **Dial5_purge**: Purges Coredial

7. **Step 6**: Risk assessment
   - **Dial6_risk**: Assigns risk factors to all entities in TINSUMMARY

8. **Step 7**: Parse entity files
   - **Dial7_area**: Parses Entity files for MIS Area servers using Loadial -a
   - **Dial7_checkA**: Confirms that AREA files split properly
   - **Dial7_area_arc**: Archives, zips and transmits MIS Area files to the RO group servers
   - **Dial7_splitgrps**: Parses Entity files for RO groups in all Areas using Loadial -i
   - **Dial7_grp_arc**: Archives, zips and transmits RO group Entity files to the RO group servers
   - **Dial7_checkI**: Confirms that Entity files split properly

9. **Step 8**: Statistics and audit
   - **Dial8_loadcnt**: Runs Loadial -l to compile Dial statistics and loads DIALAUD table

10. **Step 9 & 10**: Database updates and completion
    - **Dial9_pt2real**: Points database synonyms to newly loaded DIAL tables
    - **Dial9_complete**: Done as part of Step 9 during Dialmenu -q
    - **Dial9_entries**: Done as part of Step 9 during Dialmenu -q
    - **Dial9_Arisk**: Updates Arisk in Tinsummary table
    - **Dial10_rmRAW**: Removes TDA/TDI raw file from DIALDIR for each area
    - **ALS_lock**: Unlock/Lock Entity menu
    - **ACS_risk**: Done as part of Step 9 during Dialmenu -q

### Data Processing Requirements
1. The system must parse entity data and store unique entity data only once, linking modules to entity records.
2. Must handle split entities for taxpayers with the same TIN but different name patterns.
3. Must ensure data integrity across the entire process.
4. Must maintain proper record linkage between TDI and TDA data.

## Organization and Area Assignment Rules

### Organization Determination
Organization (ORG) is determined by the following rules:
- **CF**: 21-27,35
- **CP**: 35,70-79
- **AD**: 21-27,35,99
- **MI**: 11-17,59,62
- **XX**: All others (ICS national & insolvency)

### Area Assignment Rules
For cases on the DIAL, an adjustment is made to the area (ASSIGN_AO) field using these rules:

1. If the area is between 21 and 27, no change is made.
2. If the area is 35 and the ULC (universal location code) is in 66,90, no change is made.
3. If the case is assigned to MRI, areas 11-15, the area is changed to the corresponding SB/SE area by referencing the ULC code in the DOMAP table.
4. If the case is assigned to TE or LM (area between 40 and 50 or area is 35 without a 35 ULC code), the corresponding SB/SE area is referenced from the ICSZIPS assignment grid.

## Technical Requirements

### Development Platform
1. The new system must be built using:
   - Java programming language
   - Spring Boot framework
   - Spring Batch for handling ETL processes
   - Relational database integration (Oracle)

### Performance Requirements
1. The system must handle significant data volumes (current extract example shows 2319518 records for one area).
2. Must maintain processing speed comparable to or better than the current implementation.
3. Must efficiently handle memory usage during data transformations.

### Data Integrity and Validation
1. Must validate input data formats and structures.
2. Must maintain the integrity of relationships between TINs, entities, and modules.
3. Must ensure proper sorting and linking of TDI and TDA data.
4. Must accurately perform risk assessments and priority calculations.

### Monitoring and Logging
1. Must provide detailed logs of processing steps.
2. Must report processing statistics and validation results.
3. Must identify and report anomalies in data processing.

## Development Approach

### Phase 1: Project Setup
1. Initialize Spring Boot application with required dependencies
2. Configure database connections and Spring Batch infrastructure
3. Create basic entity models and repositories
4. Set up testing framework

### Phase 2: Core Processing
1. Implement file readers for CSV and XML formats
2. Develop batch job configurations for file processing
3. Create services for data extraction and validation
4. Implement AML application integration

### Phase 3: Advanced Features
1. Develop prioritization algorithms
2. Implement notification system
3. Create ticketing integration
4. Build assignment logic

### Phase 4: Testing & Deployment
1. Unit tests for all components
2. Integration tests for the complete pipeline
3. Performance testing with sample datasets
4. Deployment configuration and documentation

## Configuration

The application will be configured using application properties:

```yaml
# Application Configuration
dial:
  file:
    input-directory: /path/to/input/files
    processed-directory: /path/to/processed/files
    error-directory: /path/to/error/files
  
  batch:
    chunk-size: 100
    max-threads: 4
    
  integration:
    aml-application:
      url: http://aml-app-endpoint
      timeout: 30000
      
  notification:
    enabled: true
    recipients: admin@example.com
```

## Running the Application

### Prerequisites
- Java 17+
- Maven 3.8+
- PostgreSQL (or other configured database)

### Build
```bash
mvn clean package
```

### Run
```bash
java -jar dial-project-1.0.0.jar
```

### With Custom Configuration
```bash
java -jar dial-project-1.0.0.jar --spring.config.location=file:/path/to/custom/application.yml
```

## Monitoring and Logging

### Monitoring Endpoints
The application will expose Spring Boot Actuator endpoints for monitoring:

- Health check: `/actuator/health`
- Metrics: `/actuator/metrics`
- Batch job information: `/actuator/batch`

### Logging Strategy
Logs will be written to:
- Console (for development)
- Rolling file (for production)
- Optionally integrated with centralized logging systems

## Appendix

### Key Database Tables
1. **RAWDATA**: Temporary table for initial data loading
2. **DIALENT**: Entity-level information
3. **DIALMOD**: Module-level information 
4. **TINSUMMARY**: Case level indicators based on TIN, file Source, and TIN Type
5. **COREDIAL**: Taxpayer information with entity separation based on name variations
6. **MODEL_SCORE**: Contains model scores for risk assessment
7. **DIALAUD**: Audit information for DIAL processing

### File Formats
1. **TDA.raw**: Tax Delinquency Assessment data
2. **TDI.raw**: Tax Delinquency Investigation data
3. **COMBO.raw**: Combined TDA and TDI data for a taxpayer
4. **CFF files**: Case Formation Factor files
5. **QUEUE files**: Queue assignment files
6. **MODEL files**: Risk model information

### Critical Business Rules
1. Entity separation based on TIN and name variations
2. Priority score calculation using multiple factors
3. Revenue Officer assignment logic based on ZIP, grade level, and name
4. Model score bucket determination using NTILE statistical function
