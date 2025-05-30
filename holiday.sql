-- =====================================================
-- COMPLETE ORACLE SQL SCRIPTS FOR US HOLIDAYS TABLE
-- =====================================================

-- =====================================================
-- STEP 1: CREATE THE DIM_DATE TABLE
-- =====================================================

-- Drop table if it exists (for clean setup)
-- DROP TABLE DIM_DATE CASCADE CONSTRAINTS;

CREATE TABLE DIM_DATE (
    CALENDAR_DATE DATE NOT NULL,
    CALENDAR_DATE_ID NUMBER(8) NOT NULL,
    CALENDAR_YEAR NUMBER(4) NOT NULL,
    CALENDAR_MONTH NUMBER(2) NOT NULL,
    CALENDAR_DAY NUMBER(2) NOT NULL,
    DAY_OF_WEEK_NUM NUMBER(1) NOT NULL,
    DAY_OF_WEEK_NAME VARCHAR2(9) NOT NULL,
    DAY_OF_WEEK_SHORT VARCHAR2(3) NOT NULL,
    IS_WEEKEND_FLAG CHAR(1) DEFAULT 'N' NOT NULL,
    IS_FEDERAL_HOLIDAY_FLAG CHAR(1) DEFAULT 'N' NOT NULL,
    FEDERAL_HOLIDAY_NAME VARCHAR2(100),
    IS_ADHOC_HOLIDAY_FLAG CHAR(1) DEFAULT 'N' NOT NULL,
    ADHOC_HOLIDAY_NAME VARCHAR2(100),
    HOLIDAY_TYPE VARCHAR2(20),
    IS_BUSINESS_DAY_FLAG CHAR(1) DEFAULT 'Y' NOT NULL,
    PREVIOUS_BUSINESS_DAY DATE,
    NEXT_BUSINESS_DAY DATE,
    CONSTRAINT PK_DIM_DATE PRIMARY KEY (CALENDAR_DATE),
    CONSTRAINT CHK_WEEKEND_FLAG CHECK (IS_WEEKEND_FLAG IN ('Y', 'N')),
    CONSTRAINT CHK_FEDERAL_FLAG CHECK (IS_FEDERAL_HOLIDAY_FLAG IN ('Y', 'N')),
    CONSTRAINT CHK_ADHOC_FLAG CHECK (IS_ADHOC_HOLIDAY_FLAG IN ('Y', 'N')),
    CONSTRAINT CHK_BUSINESS_FLAG CHECK (IS_BUSINESS_DAY_FLAG IN ('Y', 'N'))
);

-- Create unique index on date ID
CREATE UNIQUE INDEX UQ_DIM_DATE_ID ON DIM_DATE(CALENDAR_DATE_ID);

-- Create performance indexes
CREATE INDEX IDX_DIM_DATE_YEAR ON DIM_DATE(CALENDAR_YEAR);
CREATE INDEX IDX_DIM_DATE_YEARMONTH ON DIM_DATE(CALENDAR_YEAR, CALENDAR_MONTH);
CREATE INDEX IDX_DIM_DATE_BUSINESS ON DIM_DATE(IS_BUSINESS_DAY_FLAG);
CREATE INDEX IDX_DIM_DATE_FEDERAL ON DIM_DATE(IS_FEDERAL_HOLIDAY_FLAG);

-- =====================================================
-- STEP 2: POPULATE BASE DATE DATA (2020-2030)
-- =====================================================

INSERT INTO DIM_DATE (
    CALENDAR_DATE,
    CALENDAR_DATE_ID,
    CALENDAR_YEAR,
    CALENDAR_MONTH,
    CALENDAR_DAY,
    DAY_OF_WEEK_NUM,
    DAY_OF_WEEK_NAME,
    DAY_OF_WEEK_SHORT,
    IS_WEEKEND_FLAG
)
SELECT 
    dt AS CALENDAR_DATE,
    TO_NUMBER(TO_CHAR(dt, 'YYYYMMDD')) AS CALENDAR_DATE_ID,
    EXTRACT(YEAR FROM dt) AS CALENDAR_YEAR,
    EXTRACT(MONTH FROM dt) AS CALENDAR_MONTH,
    EXTRACT(DAY FROM dt) AS CALENDAR_DAY,
    TO_NUMBER(TO_CHAR(dt, 'D')) AS DAY_OF_WEEK_NUM,
    TRIM(TO_CHAR(dt, 'DAY')) AS DAY_OF_WEEK_NAME,
    TO_CHAR(dt, 'DY') AS DAY_OF_WEEK_SHORT,
    CASE 
        WHEN TO_CHAR(dt, 'DY') IN ('SAT', 'SUN') THEN 'Y' 
        ELSE 'N' 
    END AS IS_WEEKEND_FLAG
FROM (
    SELECT DATE '2020-01-01' + LEVEL - 1 AS dt
    FROM DUAL
    CONNECT BY LEVEL <= (DATE '2030-12-31' - DATE '2020-01-01' + 1)
);

COMMIT;

-- =====================================================
-- STEP 3: CREATE HOLIDAY CALCULATION FUNCTIONS
-- =====================================================

-- Function to calculate nth weekday of month
CREATE OR REPLACE FUNCTION get_nth_weekday(
    p_year NUMBER,
    p_month NUMBER,
    p_weekday VARCHAR2,
    p_nth NUMBER
) RETURN DATE IS
    v_first_day DATE;
    v_first_weekday DATE;
    v_result DATE;
BEGIN
    v_first_day := TO_DATE(p_year || '-' || LPAD(p_month, 2, '0') || '-01', 'YYYY-MM-DD');
    v_first_weekday := NEXT_DAY(v_first_day - 1, p_weekday);
    
    IF v_first_weekday < v_first_day THEN
        v_first_weekday := v_first_weekday + 7;
    END IF;
    
    v_result := v_first_weekday + (p_nth - 1) * 7;
    
    RETURN v_result;
END;
/

-- Function to calculate last weekday of month
CREATE OR REPLACE FUNCTION get_last_weekday(
    p_year NUMBER,
    p_month NUMBER,
    p_weekday VARCHAR2
) RETURN DATE IS
    v_last_day DATE;
    v_last_weekday DATE;
BEGIN
    v_last_day := LAST_DAY(TO_DATE(p_year || '-' || LPAD(p_month, 2, '0') || '-01', 'YYYY-MM-DD'));
    v_last_weekday := NEXT_DAY(v_last_day - 7, p_weekday);
    
    IF v_last_weekday > v_last_day THEN
        v_last_weekday := v_last_weekday - 7;
    END IF;
    
    RETURN v_last_weekday;
END;
/

-- =====================================================
-- STEP 4: POPULATE FEDERAL HOLIDAYS
-- =====================================================

-- Create a procedure to populate federal holidays for a given year
CREATE OR REPLACE PROCEDURE populate_federal_holidays(p_year NUMBER) AS
    v_holiday_date DATE;
    v_observed_date DATE;
    
    -- Helper function to get observed date
    FUNCTION get_observed_date(p_date DATE) RETURN DATE IS
    BEGIN
        IF TO_CHAR(p_date, 'DY') = 'SUN' THEN
            RETURN p_date + 1;  -- Observe on Monday
        ELSIF TO_CHAR(p_date, 'DY') = 'SAT' THEN
            RETURN p_date - 1;  -- Observe on Friday
        ELSE
            RETURN p_date;
        END IF;
    END;
    
BEGIN
    -- New Year's Day (January 1)
    v_holiday_date := TO_DATE(p_year || '-01-01', 'YYYY-MM-DD');
    v_observed_date := get_observed_date(v_holiday_date);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'New Year''s Day' || 
            CASE WHEN v_observed_date != v_holiday_date THEN ' (Observed)' ELSE '' END,
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_observed_date;
    
    -- Martin Luther King Jr. Day (3rd Monday in January)
    v_holiday_date := get_nth_weekday(p_year, 1, 'MONDAY', 3);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Birthday of Martin Luther King, Jr.',
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_holiday_date;
    
    -- Washington's Birthday (3rd Monday in February)
    v_holiday_date := get_nth_weekday(p_year, 2, 'MONDAY', 3);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Washington''s Birthday',
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_holiday_date;
    
    -- Memorial Day (Last Monday in May)
    v_holiday_date := get_last_weekday(p_year, 5, 'MONDAY');
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Memorial Day',
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_holiday_date;
    
    -- Juneteenth (June 19) - Only from 2021 onwards
    IF p_year >= 2021 THEN
        v_holiday_date := TO_DATE(p_year || '-06-19', 'YYYY-MM-DD');
        v_observed_date := get_observed_date(v_holiday_date);
        UPDATE DIM_DATE 
        SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
            FEDERAL_HOLIDAY_NAME = 'Juneteenth National Independence Day' || 
                CASE WHEN v_observed_date != v_holiday_date THEN ' (Observed)' ELSE '' END,
            HOLIDAY_TYPE = 'FEDERAL'
        WHERE CALENDAR_DATE = v_observed_date;
    END IF;
    
    -- Independence Day (July 4)
    v_holiday_date := TO_DATE(p_year || '-07-04', 'YYYY-MM-DD');
    v_observed_date := get_observed_date(v_holiday_date);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Independence Day' || 
            CASE WHEN v_observed_date != v_holiday_date THEN ' (Observed)' ELSE '' END,
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_observed_date;
    
    -- Labor Day (1st Monday in September)
    v_holiday_date := get_nth_weekday(p_year, 9, 'MONDAY', 1);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Labor Day',
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_holiday_date;
    
    -- Columbus Day (2nd Monday in October)
    v_holiday_date := get_nth_weekday(p_year, 10, 'MONDAY', 2);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Columbus Day',
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_holiday_date;
    
    -- Veterans Day (November 11)
    v_holiday_date := TO_DATE(p_year || '-11-11', 'YYYY-MM-DD');
    v_observed_date := get_observed_date(v_holiday_date);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Veterans Day' || 
            CASE WHEN v_observed_date != v_holiday_date THEN ' (Observed)' ELSE '' END,
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_observed_date;
    
    -- Thanksgiving Day (4th Thursday in November)
    v_holiday_date := get_nth_weekday(p_year, 11, 'THURSDAY', 4);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Thanksgiving Day',
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_holiday_date;
    
    -- Christmas Day (December 25)
    v_holiday_date := TO_DATE(p_year || '-12-25', 'YYYY-MM-DD');
    v_observed_date := get_observed_date(v_holiday_date);
    UPDATE DIM_DATE 
    SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
        FEDERAL_HOLIDAY_NAME = 'Christmas Day' || 
            CASE WHEN v_observed_date != v_holiday_date THEN ' (Observed)' ELSE '' END,
        HOLIDAY_TYPE = 'FEDERAL'
    WHERE CALENDAR_DATE = v_observed_date;
    
    -- Inauguration Day (January 20, every 4 years after 1965, DC area only)
    -- 2025, 2029, etc.
    IF p_year = 2025 OR (p_year > 1965 AND MOD(p_year - 1965, 4) = 0) THEN
        v_holiday_date := TO_DATE(p_year || '-01-20', 'YYYY-MM-DD');
        -- Special rule: If Sunday, observe Monday; if Saturday, observe on Saturday (no change)
        IF TO_CHAR(v_holiday_date, 'DY') = 'SUN' THEN
            v_observed_date := v_holiday_date + 1;
        ELSE
            v_observed_date := v_holiday_date;
        END IF;
        
        UPDATE DIM_DATE 
        SET IS_FEDERAL_HOLIDAY_FLAG = 'Y',
            FEDERAL_HOLIDAY_NAME = 'Inauguration Day (DC Area)' || 
                CASE WHEN v_observed_date != v_holiday_date THEN ' (Observed)' ELSE '' END,
            HOLIDAY_TYPE = 'FEDERAL'
        WHERE CALENDAR_DATE = v_observed_date;
    END IF;
    
    COMMIT;
END;
/

-- Populate federal holidays for all years
BEGIN
    FOR year_num IN 2020..2030 LOOP
        populate_federal_holidays(year_num);
    END LOOP;
END;
/

-- =====================================================
-- STEP 5: ADD SAMPLE AD-HOC HOLIDAYS
-- =====================================================

-- Add some sample company holidays
UPDATE DIM_DATE 
SET IS_ADHOC_HOLIDAY_FLAG = 'Y',
    ADHOC_HOLIDAY_NAME = 'Company Founder''s Day',
    HOLIDAY_TYPE = CASE WHEN HOLIDAY_TYPE IS NULL THEN 'ADHOC' ELSE HOLIDAY_TYPE END
WHERE CALENDAR_DATE = DATE '2025-03-15';

UPDATE DIM_DATE 
SET IS_ADHOC_HOLIDAY_FLAG = 'Y',
    ADHOC_HOLIDAY_NAME = 'Day After Thanksgiving',
    HOLIDAY_TYPE = CASE WHEN HOLIDAY_TYPE IS NULL THEN 'ADHOC' ELSE HOLIDAY_TYPE END
WHERE CALENDAR_DATE IN (
    SELECT CALENDAR_DATE + 1 
    FROM DIM_DATE 
    WHERE FEDERAL_HOLIDAY_NAME = 'Thanksgiving Day'
    AND CALENDAR_YEAR BETWEEN 2020 AND 2030
);

COMMIT;

-- =====================================================
-- STEP 6: UPDATE BUSINESS DAY FLAGS
-- =====================================================

-- Update IS_BUSINESS_DAY_FLAG based on all holiday types
UPDATE DIM_DATE
SET IS_BUSINESS_DAY_FLAG = 
    CASE 
        WHEN IS_WEEKEND_FLAG = 'Y' 
          OR IS_FEDERAL_HOLIDAY_FLAG = 'Y' 
          OR IS_ADHOC_HOLIDAY_FLAG = 'Y'
        THEN 'N'
        ELSE 'Y'
    END;

COMMIT;

-- =====================================================
-- STEP 7: CALCULATE PREVIOUS/NEXT BUSINESS DAYS
-- =====================================================

-- Update NEXT_BUSINESS_DAY
MERGE INTO DIM_DATE d1
USING (
    SELECT 
        CALENDAR_DATE,
        LEAD(CALENDAR_DATE, 1) OVER (
            PARTITION BY IS_BUSINESS_DAY_FLAG 
            ORDER BY CALENDAR_DATE
        ) AS NEXT_BUS_DAY
    FROM DIM_DATE
    WHERE IS_BUSINESS_DAY_FLAG = 'Y'
) d2
ON (d1.CALENDAR_DATE = d2.CALENDAR_DATE)
WHEN MATCHED THEN
    UPDATE SET d1.NEXT_BUSINESS_DAY = d2.NEXT_BUS_DAY;

-- For non-business days, find the next business day
UPDATE DIM_DATE d1
SET NEXT_BUSINESS_DAY = (
    SELECT MIN(d2.CALENDAR_DATE)
    FROM DIM_DATE d2
    WHERE d2.CALENDAR_DATE > d1.CALENDAR_DATE
      AND d2.IS_BUSINESS_DAY_FLAG = 'Y'
)
WHERE IS_BUSINESS_DAY_FLAG = 'N';

-- Update PREVIOUS_BUSINESS_DAY
MERGE INTO DIM_DATE d1
USING (
    SELECT 
        CALENDAR_DATE,
        LAG(CALENDAR_DATE, 1) OVER (
            PARTITION BY IS_BUSINESS_DAY_FLAG 
            ORDER BY CALENDAR_DATE
        ) AS PREV_BUS_DAY
    FROM DIM_DATE
    WHERE IS_BUSINESS_DAY_FLAG = 'Y'
) d2
ON (d1.CALENDAR_DATE = d2.CALENDAR_DATE)
WHEN MATCHED THEN
    UPDATE SET d1.PREVIOUS_BUSINESS_DAY = d2.PREV_BUS_DAY;

-- For non-business days, find the previous business day
UPDATE DIM_DATE d1
SET PREVIOUS_BUSINESS_DAY = (
    SELECT MAX(d2.CALENDAR_DATE)
    FROM DIM_DATE d2
    WHERE d2.CALENDAR_DATE < d1.CALENDAR_DATE
      AND d2.IS_BUSINESS_DAY_FLAG = 'Y'
)
WHERE IS_BUSINESS_DAY_FLAG = 'N';

COMMIT;

-- =====================================================
-- STEP 8: TEST QUERIES
-- =====================================================

-- Test 1: View all 2025 federal holidays
SELECT 
    CALENDAR_DATE,
    DAY_OF_WEEK_NAME,
    FEDERAL_HOLIDAY_NAME,
    IS_BUSINESS_DAY_FLAG
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_FEDERAL_HOLIDAY_FLAG = 'Y'
ORDER BY CALENDAR_DATE;

-- Test 2: Check specific dates in 2025
SELECT 
    CALENDAR_DATE,
    DAY_OF_WEEK_SHORT,
    IS_WEEKEND_FLAG,
    IS_FEDERAL_HOLIDAY_FLAG,
    FEDERAL_HOLIDAY_NAME,
    IS_ADHOC_HOLIDAY_FLAG,
    ADHOC_HOLIDAY_NAME,
    IS_BUSINESS_DAY_FLAG
FROM DIM_DATE
WHERE CALENDAR_DATE IN (
    DATE '2025-01-01',  -- New Year's Day (Wednesday)
    DATE '2025-01-20',  -- MLK Day & Inauguration Day (Monday)
    DATE '2025-07-04',  -- Independence Day (Friday)
    DATE '2025-11-27',  -- Thanksgiving (Thursday)
    DATE '2025-11-28',  -- Day after Thanksgiving
    DATE '2025-12-25'   -- Christmas (Thursday)
)
ORDER BY CALENDAR_DATE;

-- Test 3: Count business days in each month of 2025
SELECT 
    CALENDAR_YEAR,
    CALENDAR_MONTH,
    TO_CHAR(TO_DATE(CALENDAR_MONTH, 'MM'), 'MONTH') AS MONTH_NAME,
    COUNT(*) AS TOTAL_DAYS,
    SUM(CASE WHEN IS_BUSINESS_DAY_FLAG = 'Y' THEN 1 ELSE 0 END) AS BUSINESS_DAYS,
    SUM(CASE WHEN IS_WEEKEND_FLAG = 'Y' THEN 1 ELSE 0 END) AS WEEKEND_DAYS,
    SUM(CASE WHEN IS_FEDERAL_HOLIDAY_FLAG = 'Y' THEN 1 ELSE 0 END) AS FEDERAL_HOLIDAYS
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
GROUP BY CALENDAR_YEAR, CALENDAR_MONTH
ORDER BY CALENDAR_MONTH;

-- Test 4: Find next/previous business days
SELECT 
    CALENDAR_DATE,
    DAY_OF_WEEK_SHORT,
    IS_BUSINESS_DAY_FLAG,
    PREVIOUS_BUSINESS_DAY,
    NEXT_BUSINESS_DAY,
    FEDERAL_HOLIDAY_NAME
FROM DIM_DATE
WHERE CALENDAR_DATE BETWEEN DATE '2025-07-03' AND DATE '2025-07-07'
ORDER BY CALENDAR_DATE;

-- Test 5: Verify "in lieu of" observances
-- Check 2026 when July 4th falls on Saturday
SELECT 
    CALENDAR_DATE,
    DAY_OF_WEEK_NAME,
    IS_FEDERAL_HOLIDAY_FLAG,
    FEDERAL_HOLIDAY_NAME,
    IS_BUSINESS_DAY_FLAG
FROM DIM_DATE
WHERE CALENDAR_DATE BETWEEN DATE '2026-07-02' AND DATE '2026-07-06'
ORDER BY CALENDAR_DATE;

-- Test 6: Business days between two dates
SELECT 
    COUNT(*) AS BUSINESS_DAYS_COUNT
FROM DIM_DATE
WHERE CALENDAR_DATE BETWEEN DATE '2025-01-01' AND DATE '2025-01-31'
  AND IS_BUSINESS_DAY_FLAG = 'Y';

-- Test 7: Find all non-business days in Q1 2025
SELECT 
    CALENDAR_DATE,
    DAY_OF_WEEK_NAME,
    CASE 
        WHEN IS_WEEKEND_FLAG = 'Y' THEN 'Weekend'
        WHEN IS_FEDERAL_HOLIDAY_FLAG = 'Y' THEN FEDERAL_HOLIDAY_NAME
        WHEN IS_ADHOC_HOLIDAY_FLAG = 'Y' THEN ADHOC_HOLIDAY_NAME
    END AS REASON
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND CALENDAR_MONTH IN (1, 2, 3)
  AND IS_BUSINESS_DAY_FLAG = 'N'
ORDER BY CALENDAR_DATE;

-- Test 8: ETL scheduling query - Should job run today?
SELECT 
    CASE 
        WHEN IS_BUSINESS_DAY_FLAG = 'Y' THEN 'YES - Run ETL'
        ELSE 'NO - Skip ETL (' || 
            CASE 
                WHEN IS_WEEKEND_FLAG = 'Y' THEN 'Weekend'
                WHEN IS_FEDERAL_HOLIDAY_FLAG = 'Y' THEN FEDERAL_HOLIDAY_NAME
                WHEN IS_ADHOC_HOLIDAY_FLAG = 'Y' THEN ADHOC_HOLIDAY_NAME
            END || ')'
    END AS ETL_DECISION
FROM DIM_DATE
WHERE CALENDAR_DATE = TRUNC(SYSDATE);

-- Test 9: Find the last business day of each month in 2025
SELECT 
    CALENDAR_MONTH,
    TO_CHAR(MAX(CALENDAR_DATE), 'YYYY-MM-DD DAY') AS LAST_BUSINESS_DAY
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_BUSINESS_DAY_FLAG = 'Y'
GROUP BY CALENDAR_MONTH
ORDER BY CALENDAR_MONTH;

-- Test 10: Validate data integrity
SELECT 
    'Total Days' AS METRIC,
    COUNT(*) AS COUNT
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
UNION ALL
SELECT 
    'Business Days',
    COUNT(*)
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_BUSINESS_DAY_FLAG = 'Y'
UNION ALL
SELECT 
    'Weekend Days',
    COUNT(*)
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_WEEKEND_FLAG = 'Y'
UNION ALL
SELECT 
    'Federal Holidays',
    COUNT(*)
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_FEDERAL_HOLIDAY_FLAG = 'Y'
UNION ALL
SELECT 
    'Ad-hoc Holidays',
    COUNT(*)
FROM DIM_DATE
WHERE CALENDAR_YEAR = 2025
  AND IS_ADHOC_HOLIDAY_FLAG = 'Y';

-- =====================================================
-- USEFUL FUNCTIONS FOR ETL INTEGRATION
-- =====================================================

-- Function to get business days between two dates
CREATE OR REPLACE FUNCTION get_business_days_between(
    p_start_date DATE,
    p_end_date DATE
) RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM DIM_DATE
    WHERE CALENDAR_DATE BETWEEN p_start_date AND p_end_date
      AND IS_BUSINESS_DAY_FLAG = 'Y';
    
    RETURN v_count;
END;
/

-- Function to add N business days to a date
CREATE OR REPLACE FUNCTION add_business_days(
    p_date DATE,
    p_days NUMBER
) RETURN DATE IS
    v_result DATE;
    v_days_to_add NUMBER := ABS(p_days);
    v_direction NUMBER := SIGN(p_days);
BEGIN
    IF p_days = 0 THEN
        RETURN p_date;
    END IF;
    
    SELECT CALENDAR_DATE
    INTO v_result
    FROM (
        SELECT CALENDAR_DATE,
               ROW_NUMBER() OVER (ORDER BY CALENDAR_DATE * v_direction) AS rn
        FROM DIM_DATE
        WHERE IS_BUSINESS_DAY_FLAG = 'Y'
          AND CALENDAR_DATE * v_direction > p_date * v_direction
    )
    WHERE rn = v_days_to_add;
    
    RETURN v_result;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

-- Test the functions
SELECT 
    get_business_days_between(DATE '2025-01-01', DATE '2025-01-31') AS JAN_BUSINESS_DAYS,
    add_business_days(DATE '2025-07-03', 1) AS NEXT_BUSINESS_DAY_AFTER_JULY3,
    add_business_days(DATE '2025-12-24', 2) AS TWO_BUSINESS_DAYS_AFTER_XMAS_EVE
FROM DUAL;

-- =====================================================
-- CLEANUP (if needed)
-- =====================================================
-- DROP TABLE DIM_DATE CASCADE CONSTRAINTS;
-- DROP FUNCTION get_nth_weekday;
-- DROP FUNCTION get_last_weekday;
-- DROP PROCEDURE populate_federal_holidays;
-- DROP FUNCTION get_business_days_between;
-- DROP FUNCTION add_business_days;


I'll provide you with a complete set of SQL queries to create and populate your US Holidays table in Oracle, including test queries.I've created a complete set of Oracle SQL scripts that you can run to implement your US Holidays table. Here's what's included:

## Script Components:

1. **Table Creation**: Creates the DIM_DATE table with all necessary columns and constraints
2. **Base Data Population**: Populates dates from 2020-2030 with weekday information
3. **Holiday Functions**: Helper functions to calculate nth weekday and last weekday of month
4. **Federal Holiday Procedure**: Automated procedure to populate all US federal holidays with proper observance rules
5. **Ad-hoc Holidays**: Sample company holidays including "Day After Thanksgiving"
6. **Business Day Calculations**: Updates business day flags and calculates previous/next business days
7. **Comprehensive Test Queries**: 10 different test queries to validate the data
8. **Utility Functions**: Helper functions for ETL integration

## Key Features:

- **2025 Holidays Included**: All federal holidays for 2025 are populated, including Inauguration Day
- **"In Lieu Of" Logic**: Properly handles weekend adjustments (Saturday holidays observed on Friday, Sunday holidays on Monday)
- **Historical Awareness**: Juneteenth only appears from 2021 onwards
- **Performance Optimized**: Includes proper indexes for common query patterns
- **ETL Ready**: Includes functions to calculate business days between dates and add business days

## 2025 Federal Holidays in the Table:
- New Year's Day: January 1 (Wednesday)
- Martin Luther King Jr. Day: January 20 (Monday)
- Inauguration Day: January 20 (Monday) - DC area
- Washington's Birthday: February 17 (Monday)
- Memorial Day: May 26 (Monday)
- Juneteenth: June 19 (Thursday)
- Independence Day: July 4 (Friday)
- Labor Day: September 1 (Monday)
- Columbus Day: October 13 (Monday)
- Veterans Day: November 11 (Tuesday)
- Thanksgiving: November 27 (Thursday)
- Christmas: December 25 (Thursday)

## To Run:
1. Execute the scripts in order (Steps 1-7)
2. Run the test queries to verify the data
3. Use the utility functions for your ETL processes

The table is now ready to serve as your centralized source for all date-related business logic!
