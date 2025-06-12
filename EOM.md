# CTRS EOM ETL Requirements Analysis

## Overview
Based on the provided documentation, this requirement is for developing a **Data ETL (Extract, Transform, Load) system for CTRS EOM (End of Month)** processing - a critical business process for data collection and reporting to regulatory bodies.

## Business Context

### Purpose
- **Primary Function**: Get data collection information from internal systems to CTRS (Congressional Travel Reporting System)
- **Regulatory Compliance**: Data is used by Commissioner, Congress, GAO, and upper-level directors
- **End-of-Month Process**: Monthly data compilation and validation workflow

### Key Stakeholders
- Group Managers (data accuracy verification)
- ICS Quality Analysts (IQAs) - perform secondary validation
- Revenue Officers (time entry verification)
- Management level users (not employees)

## ETL Job Types Identified

### Weekly Jobs (Referenced as E1, E2, E4, E6)
1. **S1** - ENTITY information pertinent to all accounts on ICS
2. **E1** - ENTITY Case Data
3. **E2** - ENTITY Module Data  
4. **E4** - Non-IDRS Modules
5. **E3** - Activity Records
6. **EA** - Module dispositions
7. **E9** - ENTITY Closing and Transfer Actions
8. **E6** - EOM data (special handling - empty except EOM weekend)

### Processing Scripts & Modules
- **c.procE6** - Load E6 extracts (called by c.runE6 - EOM data)
- **c.runARCHIVEINV** - Archive inventory records, creates SUM tables
- **c.runARCINV** - Manual EOM script execution
- **c.runCASEDSP** - Manual EOM script execution
- **Apecom Application Modules** - For approving group and area EOM
- **Eomrpt** - Month-End Reports generation

## Critical ETL Process Flow

### Basic Steps
1. **Weekly Time Verification** - Group Managers verify Revenue Officer time entries
2. **EOM Report Generation** - Generate and approve EOM reports
3. **Area End of Month** - IQAs certify time entries for their areas
4. **Form4872 Generation** - Forms generated for each group, transmitted to CTRS
5. **Report Generation** - Monthly and cumulative reports at group/area levels

### Key Reports Generated
- `mis_inv` - Inventory reports
- `mis_meas` - Measurement reports  
- `mis_bus` - Business reports
- `mis_targ` - Target reports
- `form4872` - Official CTRS transmission forms
- `mis_time` - Time reports

## Expected Outcomes

### 1. Modernized ETL System
- **Replace Legacy Code**: Move from current scripts to modern Spring Boot/Batch framework
- **UI-Based Management**: Web interface for scheduling and monitoring (matching your provided project structure)
- **Automated Scheduling**: Cron-based job scheduling with day-of-week controls

### 2. Job Categories Alignment
Your provided ETL Scheduler project structure aligns well:

```java
// Current project job types should be updated to match CTRS EOM requirements
public enum JobType {
    // Weekly jobs - map to CTRS data loads
    E1("e1", "Weekly", "ENTITY Case Data"),
    E2("e2", "Weekly", "ENTITY Module Data"), 
    E4("e4", "Weekly", "Non-IDRS Modules"),
    E6("e6", "Weekly", "EOM Data"),
    
    // Additional jobs identified from requirements
    S1("s1", "Weekly", "ENTITY Account Information"),
    E3("e3", "Weekly", "Activity Records"),
    EA("ea", "Weekly", "Module Dispositions"),
    E9("e9", "Weekly", "ENTITY Closing/Transfer Actions"),
    
    // EOM Processing jobs
    ARCHIVE_INV("archive-inv", "EOM", "Archive Inventory"),
    CASE_DSP("case-dsp", "EOM", "Case Disposition Processing"),
    FORM4872("form4872", "EOM", "CTRS Form Generation"),
    
    // Report generation
    EOM_REPORTS("eom-reports", "EOM", "End of Month Reports")
}
```

### 3. Compliance & Monitoring
- **Resource Monitoring**: System resource monitoring during EOM processing (mentioned in section VII)
- **Error Handling**: Robust error handling for critical compliance processes
- **Audit Trail**: Complete logging for regulatory compliance
- **User Access Control**: Role-based access (managers vs. employees)

### 4. Integration Points
- **CTRS System**: Direct integration for form transmission
- **ICS System**: Source system for entity data
- **Directory Integration**: File system integration (`d.entity/d.eom`, `d.REALIGN_2014/d.eom`, `d.utilities`)

## Technical Implementation Recommendations

### Database Schema Updates
Your current schema should be extended to include:
- EOM processing status tracking
- Form4872 generation history
- Compliance audit logs
- Group/Area hierarchical data

### API Endpoints
Additional endpoints needed beyond your current structure:
- `/api/eom/status` - EOM weekend processing status
- `/api/forms/4872` - Form generation and transmission
- `/api/compliance/audit` - Audit trail access
- `/api/groups/{groupId}/eom` - Group-specific EOM processing

This requirement represents a critical modernization effort to replace legacy EOM processing scripts with a modern, manageable, and auditable ETL system while maintaining strict compliance with regulatory reporting requirements.
