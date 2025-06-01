# US Holidays Table for Oracle Database

A comprehensive Oracle database solution for managing US federal holidays, business days, and custom holidays. This implementation provides a centralized calendar table (DIM_DATE) that serves as the single source of truth for all date-related business logic.

## 🎯 Features

- **Complete US Federal Holiday Coverage**: All 11 federal holidays with proper "in lieu of" observance rules
- **Historical Accuracy**: Handles holidays correctly from 1885 to 4099
- **Business Day Calculations**: Pre-calculated business day flags and next/previous business day lookups
- **Flexible Holiday Management**: Support for company-specific and ad-hoc holidays
- **ETL Integration**: Optimized for scheduling and date-based data processing
- **Performance Optimized**: Includes proper indexing and optional partitioning support

## 📋 Table of Contents

- [Installation](#installation)
- [Table Structure](#table-structure)
- [Usage Examples](#usage-examples)
- [Federal Holidays Included](#federal-holidays-included)
- [Maintenance](#maintenance)
- [ETL Integration](#etl-integration)
- [Troubleshooting](#troubleshooting)

## 🚀 Installation

### Prerequisites
- Oracle Database 11g or higher
- Appropriate privileges to create tables, indexes, and procedures

### Quick Start

1. **Create the DIM_DATE table**:
```sql
-- Run the table creation script
@create_dim_date_table.sql
```

2. **Populate base calendar data**:
```sql
-- Populates dates from 2020-2030
@populate_base_dates.sql
```

3. **Create helper functions**:
```sql
-- Functions for calculating nth weekday of month
@create_helper_functions.sql
```

4. **Load federal holidays**:
```sql
-- Populate all federal holidays with observance rules
BEGIN
    FOR year_num IN 2020..2030 LOOP
        populate_federal_holidays(year_num);
    END LOOP;
END;
/
```

5. **Update business day flags**:
```sql
-- Calculate IS_BUSINESS_DAY_FLAG
@update_business_flags.sql
```

## 📊 Table Structure

### Core Columns

| Column | Type | Description |
|--------|------|-------------|
| CALENDAR_DATE | DATE | Primary key - the actual date |
| CALENDAR_DATE_ID | NUMBER(8) | Numeric representation (YYYYMMDD) |
| DAY_OF_WEEK_NAME | VARCHAR2(9) | Full day name (e.g., 'MONDAY') |
| IS_WEEKEND_FLAG | CHAR(1) | 'Y' for Saturday/Sunday, 'N' otherwise |
| IS_FEDERAL_HOLIDAY_FLAG | CHAR(1) | 'Y' for observed federal holidays |
| FEDERAL_HOLIDAY_NAME | VARCHAR2(100) | Name of the federal holiday |
| IS_BUSINESS_DAY_FLAG | CHAR(1) | 'Y' for working days |
| PREVIOUS_BUSINESS_DAY | DATE | Previous working day |
| NEXT_BUSINESS_DAY | DATE | Next working day |

## 💡 Usage Examples

### Check if today is a business day
```sql
SELECT 
    CASE 
        WHEN IS_BUSINESS_DAY_FLAG = 'Y' THEN 'Yes - Process ETL'
        ELSE 'No - Holiday/Weekend'
    END AS can_run_etl
FROM DIM_DATE
WHERE CALENDAR_DATE = TRUNC(SYSDATE);
```

### Get all federal holidays for 2025
```sql
SELECT 
    CALENDAR_DATE,
    DAY_OF_WEEK_NAME,
    FEDERAL_HOLIDAY_NAME
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_FEDERAL_HOLIDAY_FLAG = 'Y'
ORDER BY CALENDAR_DATE;
```

### Calculate business days between dates
```sql
SELECT COUNT(*) AS business_days
FROM DIM_DATE
WHERE CALENDAR_DATE BETWEEN DATE '2025-01-01' AND DATE '2025-01-31'
  AND IS_BUSINESS_DAY_FLAG = 'Y';
```

### Find next business day
```sql
SELECT NEXT_BUSINESS_DAY
FROM DIM_DATE
WHERE CALENDAR_DATE = DATE '2025-07-04';
```

## 🇺🇸 Federal Holidays Included

1. **New Year's Day** - January 1
2. **Martin Luther King Jr. Day** - 3rd Monday in January
3. **Washington's Birthday** - 3rd Monday in February
4. **Memorial Day** - Last Monday in May
5. **Juneteenth** - June 19 (from 2021 onwards)
6. **Independence Day** - July 4
7. **Labor Day** - 1st Monday in September
8. **Columbus Day** - 2nd Monday in October
9. **Veterans Day** - November 11
10. **Thanksgiving Day** - 4th Thursday in November
11. **Christmas Day** - December 25
12. **Inauguration Day** - January 20 (every 4 years, DC area only)

### "In Lieu Of" Rules
- If a holiday falls on **Sunday**: Observed on Monday
- If a holiday falls on **Saturday**: Observed on Friday

## 🔧 Maintenance

### Annual Updates
Run this procedure each year to add new federal holidays:
```sql
EXEC populate_federal_holidays(2031);
```

### Adding Company-Specific Holidays
```sql
-- Add a company holiday
UPDATE DIM_DATE 
SET IS_ADHOC_HOLIDAY_FLAG = 'Y',
    ADHOC_HOLIDAY_NAME = 'Company Founder Day'
WHERE CALENDAR_DATE = DATE '2025-09-15';

-- Remember to update business day flags after adding holidays
UPDATE DIM_DATE
SET IS_BUSINESS_DAY_FLAG = 'N'
WHERE CALENDAR_DATE = DATE '2025-09-15';

-- Recalculate previous/next business days for affected dates
```

### Adding Day After Thanksgiving
```sql
UPDATE DIM_DATE 
SET IS_ADHOC_HOLIDAY_FLAG = 'Y',
    ADHOC_HOLIDAY_NAME = 'Day After Thanksgiving'
WHERE CALENDAR_DATE IN (
    SELECT CALENDAR_DATE + 1 
    FROM DIM_DATE 
    WHERE FEDERAL_HOLIDAY_NAME = 'Thanksgiving Day'
);
```

## 🔄 ETL Integration

### Scheduling Pattern
Instead of complex scheduler exclusions, use a two-tier approach:

1. **Schedule jobs to run daily**:
```sql
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'DAILY_ETL_JOB',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN check_and_run_etl; END;',
        repeat_interval => 'FREQ=DAILY',
        enabled => TRUE
    );
END;
/
```

2. **Check business day within the job**:
```sql
CREATE OR REPLACE PROCEDURE check_and_run_etl AS
    l_is_business_day CHAR(1);
BEGIN
    SELECT IS_BUSINESS_DAY_FLAG
    INTO l_is_business_day
    FROM DIM_DATE
    WHERE CALENDAR_DATE = TRUNC(SYSDATE);
    
    IF l_is_business_day = 'Y' THEN
        -- Execute main ETL logic
        run_main_etl_process;
    ELSE
        -- Log skip and exit
        DBMS_OUTPUT.PUT_LINE('Skipping ETL - Non-business day');
    END IF;
END;
/
```

### Utility Functions

**Get business days between two dates**:
```sql
SELECT get_business_days_between(
    DATE '2025-01-01', 
    DATE '2025-01-31'
) AS business_days
FROM DUAL;
```

**Add N business days to a date**:
```sql
SELECT add_business_days(
    DATE '2025-12-24', 
    2
) AS result_date
FROM DUAL;
```

## 🐛 Troubleshooting

### Common Issues

1. **ORA-00933: SQL command not properly ended**
   - Check for hidden characters in your SQL
   - Ensure proper semicolon placement
   - Try running statements individually

2. **Incorrect day abbreviations**
   - Verify your NLS_DATE_LANGUAGE setting:
   ```sql
   SELECT * FROM NLS_SESSION_PARAMETERS 
   WHERE PARAMETER = 'NLS_DATE_LANGUAGE';
   ```

3. **Missing holidays**
   - Ensure the populate_federal_holidays procedure completed successfully
   - Check that IS_BUSINESS_DAY_FLAG was updated after adding holidays

### Validation Queries

**Check data integrity**:
```sql
SELECT 
    'Total Days' AS METRIC, COUNT(*) AS COUNT
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
UNION ALL
SELECT 'Business Days', COUNT(*)
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025 AND IS_BUSINESS_DAY_FLAG = 'Y'
UNION ALL
SELECT 'Federal Holidays', COUNT(*)
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025 AND IS_FEDERAL_HOLIDAY_FLAG = 'Y';
```

**Verify weekend calculations**:
```sql
SELECT CALENDAR_DATE, DAY_OF_WEEK_NAME, IS_WEEKEND_FLAG
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND CALENDAR_MONTH = 1
  AND IS_WEEKEND_FLAG = 'Y'
ORDER BY CALENDAR_DATE;
```

## 📈 Performance Considerations

### Indexing Strategy
The following indexes are created by default:
- Primary key index on CALENDAR_DATE
- Unique index on CALENDAR_DATE_ID
- B-tree indexes on CALENDAR_YEAR, IS_BUSINESS_DAY_FLAG

### Partitioning (Optional)
For very large date ranges or when joining with large fact tables:
```sql
-- Partition by year
ALTER TABLE DIM_DATE 
PARTITION BY RANGE (CALENDAR_DATE)
INTERVAL (NUMTOYMINTERVAL(1, 'YEAR'))
(PARTITION p_initial VALUES LESS THAN (DATE '2020-01-01'));
```

## 🤝 Contributing

To add new features or holiday types:
1. Update the table structure if needed
2. Modify the populate_federal_holidays procedure
3. Update the business day calculation logic
4. Add appropriate test cases

## 📄 License

This implementation is provided as-is for use in Oracle database environments. Feel free to modify and extend based on your organization's needs.

## 🙏 Acknowledgments

- Based on Oracle best practices for calendar dimension tables
- Federal holiday rules from U.S. Office of Personnel Management (OPM)
- Inspired by Sean Stuber's PL/SQL holiday calculation approach
