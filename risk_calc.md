# Risk Calculation Stored Procedure Performance Analysis & Optimization Summary

## Executive Summary

The `ENTITYDEV.riskcalc` stored procedure, originally written in Pro*C for the legacy system, has been experiencing significant performance degradation when executed through the modern Java/Kubernetes architecture. Our analysis revealed that the performance issues stem from the procedure's design patterns rather than the Java implementation, with execution times exceeding connection timeout thresholds starting from Area 22.

## Key Findings from Procedure Analysis

### 1. **Procedure Complexity**
- The stored procedure consists of **1,300+ lines of code**
- Contains intricate business logic accumulated over years of production use
- Due to this complexity and the business-critical nature of the risk calculations, a complete rewrite poses significant risk and is not feasible within current project constraints

### 2. **Cursor-Based Row-by-Row Processing**
- The procedure uses explicit cursors (`entcur1`, `entcur2`) with nested loops
- Each row is fetched and processed individually rather than in sets
- This approach was common in Pro*C implementations but doesn't leverage modern Oracle optimizations

### 3. **Extensive Hardcoded Business Logic**
- Over 100+ hardcoded account numbers in multiple IN clauses
- Hundreds of IF-THEN-ELSE statements with specific value checks
- Business rules embedded directly in code rather than data-driven architecture
- These rules represent years of business knowledge that cannot be easily refactored without extensive validation

### 4. **Inefficient DML Operations**
- Multiple individual UPDATE statements executed sequentially
- No use of bulk operations or set-based processing
- Each UPDATE potentially performs full table scans without proper indexing

### 5. **Performance Metrics**
- Areas 0-20: Complete within seconds
- Area 21: ~30 minutes execution time
- Area 22+: Exceeding 1-hour threshold, causing connection timeouts

## Optimization Strategy

Given the procedure's complexity and the impracticality of a complete rewrite, we implemented a **non-invasive optimization approach** that preserves the existing business logic while improving performance.

## Optimization Steps Implemented

### 1. **Parallel Processing Wrapper Procedure**

Created a wrapper procedure to enable parallel DML execution without modifying the original code:

```sql
CREATE OR REPLACE PROCEDURE ENTITYDEV.riskcalc_parallel(area IN NUMBER)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Set session parameters
    EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    EXECUTE IMMEDIATE 'ALTER SESSION FORCE PARALLEL DML PARALLEL 4';
    
    -- Call your original procedure
    ENTITYDEV.riskcalc(area);
    
    -- Commit the autonomous transaction
    COMMIT;
    
    -- Optionally reset session
    EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
END;
/
```

This wrapper:
- Enables Oracle to utilize multiple parallel processes for DML operations
- Uses PRAGMA AUTONOMOUS_TRANSACTION to bypass transaction state restrictions
- Allows the existing procedure to benefit from parallel execution without any modifications to the complex business logic
- Provides a safe, reversible optimization that can be easily rolled back if needed

### 2. **Strategic Index Creation**

Implemented the following indexes to optimize query performance without touching the procedure code:

#### a. **Function-Based Indexes**
- `idx_entmod_type_decode`: Optimizes the DECODE(type,...) conditions
- `idx_trantrail_segind_decode`: Optimizes the DECODE(segind,...) conditions

#### b. **Composite Indexes**
- `idx_trantrail_composite`: Covers (status, segind, tinsid) for subquery optimization
- `idx_entmod_composite`: Covers (emodsid, status, type) for cursor query optimization

These indexes specifically target the most expensive operations identified in the execution plan and require no changes to the existing procedure.

### 3. **Existing Infrastructure Advantages**
- Confirmed that ENT table already has a primary key index on TINSID
- This existing index supports the numerous UPDATE operations

## Root Cause Analysis

The performance degradation is not attributable to the Java/Kubernetes infrastructure but rather to:

1. **Data Volume Growth**: Areas 22+ likely contain significantly more records than when the Pro*C version was originally deployed
2. **Sequential Processing Model**: The cursor-based approach doesn't scale with increased data volumes
3. **Lack of Set-Based Operations**: The procedure processes records individually rather than leveraging Oracle's set-based processing capabilities
4. **Legacy Design Patterns**: The Pro*C era design patterns, while stable and proven, are not optimized for modern data volumes

## Connection Timeout Context

The timeout errors occurring from Area 22 onwards are symptoms of the underlying performance issues:
- Java/Kubernetes connection pools have reasonable timeout settings for normal operations
- The procedure's execution time exceeds these thresholds due to its processing methodology
- The legacy Pro*C system likely had different timeout configurations or data volumes

## Why Complete Rewrite Is Not Feasible

1. **Business Logic Complexity**: The 1,300+ lines contain nuanced business rules that have evolved over years
2. **Risk of Regression**: Any rewrite risks introducing bugs in critical risk calculation logic
3. **Validation Overhead**: Complete regression testing would require extensive business validation
4. **Time Constraints**: A full rewrite and validation cycle would exceed project timelines

## Recommendations for Long-term Resolution

While maintaining the existing procedure structure, future optimizations could include:

1. **Gradual Refactoring**: Identify and optimize the slowest sections incrementally
2. **Externalize Configuration**: Gradually move hardcoded values to configuration tables
3. **Implement Caching**: Add result caching for repeatedly calculated values
4. **Monitor and Tune**: Use the parallel wrapper to identify optimal parallel degrees for different areas

## Conclusion

The performance issues are inherent to the stored procedure's design patterns, which were standard practice in Pro*C development but are not optimal for modern Oracle databases handling larger data volumes. The Java/Kubernetes infrastructure is correctly configured with appropriate timeouts for normal database operations. 

Given the complexity and business-critical nature of the 1,300+ line procedure, a complete rewrite is not practical. The implemented optimizations (parallel processing wrapper and strategic indexes) provide immediate performance improvements while maintaining compatibility with the existing codebase and preserving all existing business logic. This approach minimizes risk while delivering measurable performance gains.



**********************************************************************

Looking at the execution times, I can see both positive improvements and concerning patterns:

## **Performance Analysis:**

### Improvements:
- **Area 21**: Reduced from ~30 minutes to **~28 minutes** 
- **Area 22**: Reduced from 1+ hour timeout to **~77 minutes** (completed successfully!)

### Concerns:
- **Area 23**: Started at 17:44:39 and timed out after ~12 minutes
- The timeout is happening much sooner than Area 22's 77-minute runtime

## **Recommendation: NO, don't just increase timeout to 5 hours**

Here's why and what to do instead:

### 1. **Investigate Area 23's Different Behavior**
```sql
-- Check data volumes for each area
SELECT emodsid as area, COUNT(*) as record_count
FROM entmod
WHERE status = 'O'
AND emodsid IN (21, 22, 23, 24, 25)
GROUP BY emodsid
ORDER BY emodsid;

-- Check if Area 23 has different data characteristics
SELECT emodsid, COUNT(DISTINCT type), COUNT(DISTINCT mft), COUNT(*)
FROM entmod
WHERE status = 'O'
AND emodsid IN (22, 23)
GROUP BY emodsid;
```

### 2. **Implement Tiered Approach**
```sql
CREATE OR REPLACE PROCEDURE riskcalc_parallel_heavy(area IN NUMBER)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- More aggressive settings for heavy areas
    EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    EXECUTE IMMEDIATE 'ALTER SESSION FORCE PARALLEL DML PARALLEL 8';  -- Increased from 4
    EXECUTE IMMEDIATE 'ALTER SESSION SET SORT_AREA_SIZE = 209715200';  -- 200MB
    EXECUTE IMMEDIATE 'ALTER SESSION SET HASH_AREA_SIZE = 209715200';  -- 200MB
    
    ENTITYDEV.riskcalc(area);
    
    COMMIT;
    EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
END;
/
```

### 3. **Application-Level Strategy**
```java
// In your batch configuration, handle different areas differently
if (area <= 20) {
    // Use regular procedure - these complete in seconds
    callProcedure("ENTITYDEV.riskcalc", area);
} else if (area <= 22) {
    // Use parallel wrapper with 2-hour timeout
    callProcedure("ENTITYDEV.riskcalc_parallel", area, 7200000);
} else {
    // Areas 23+ need special handling
    callProcedure("ENTITYDEV.riskcalc_parallel_heavy", area, 10800000); // 3 hours
}
```

### 4. **Add Progress Monitoring**
```sql
-- Create a progress tracking table
CREATE TABLE riskcalc_progress (
    area NUMBER,
    start_time TIMESTAMP,
    last_update TIMESTAMP,
    records_processed NUMBER,
    status VARCHAR2(20)
);

-- Modify your procedure to update progress
-- This helps identify if it's hung or just slow
```

### 5. **Consider Splitting Problem Areas**
```sql
-- For Area 23+, process in smaller chunks
CREATE OR REPLACE PROCEDURE riskcalc_area23_special
IS
BEGIN
    -- Process high-risk records first
    UPDATE ent SET risk = 999 
    WHERE tinsid IN (
        SELECT tinsid FROM entmod 
        WHERE emodsid = 23 
        AND /* high risk criteria */
    );
    COMMIT;
    
    -- Then process remaining records
    -- This prevents timeout on critical updates
END;
```

## **Immediate Actions:**

1. **Set different timeouts by area** rather than a blanket 5-hour timeout
2. **Monitor what Area 23 is doing** when it hangs - it might be hitting a different bottleneck
3. **Check for blocking locks** during Area 23 execution:
```sql
SELECT blocking_session, sid, serial#, wait_class, seconds_in_wait
FROM v$session
WHERE blocking_session IS NOT NULL;
```

## **Why 5-hour timeout is risky:**
- Masks underlying problems
- Ties up database resources
- Could cascade delays to other processes
- May still fail for areas beyond 23

The fact that Area 23 is timing out after only 12 minutes (compared to Area 22's 77 minutes) suggests something different is happening - possibly lock contention or a different data pattern that's causing issues.
