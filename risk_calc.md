# Risk Calculation Stored Procedure Performance Analysis & Optimization Summary

## Executive Summary

The `ENTITYDEV.riskcalc` stored procedure, originally written in Pro*C for the legacy system, has been experiencing significant performance degradation when executed through the modern Java/Kubernetes architecture. Our analysis revealed that the performance issues stem from the procedure's design patterns rather than the Java implementation, with execution times exceeding connection timeout thresholds starting from Area 22.

## Key Findings from Procedure Analysis

### 1. **Cursor-Based Row-by-Row Processing**
- The procedure uses explicit cursors (`entcur1`, `entcur2`) with nested loops
- Each row is fetched and processed individually rather than in sets
- This approach was common in Pro*C implementations but doesn't leverage modern Oracle optimizations

### 2. **Extensive Hardcoded Business Logic**
- Over 100+ hardcoded account numbers in multiple IN clauses
- Hundreds of IF-THEN-ELSE statements with specific value checks
- Business rules embedded directly in code rather than data-driven architecture

### 3. **Inefficient DML Operations**
- Multiple individual UPDATE statements executed sequentially
- No use of bulk operations or set-based processing
- Each UPDATE potentially performs full table scans without proper indexing

### 4. **Performance Metrics**
- Areas 0-20: Complete within seconds
- Area 21: ~30 minutes execution time
- Area 22+: Exceeding 1-hour threshold, causing connection timeouts

## Optimization Steps Implemented

### 1. **Parallel Processing Wrapper Procedure**

Created a wrapper procedure to enable parallel DML execution:

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
- Allows the existing procedure to benefit from parallel execution without code modifications

### 2. **Strategic Index Creation**

Implemented the following indexes to optimize query performance:

#### a. **Function-Based Indexes**
- `idx_entmod_type_decode`: Optimizes the DECODE(type,...) conditions
- `idx_trantrail_segind_decode`: Optimizes the DECODE(segind,...) conditions

#### b. **Composite Indexes**
- `idx_trantrail_composite`: Covers (status, segind, tinsid) for subquery optimization
- `idx_entmod_composite`: Covers (emodsid, status, type) for cursor query optimization

These indexes specifically target the most expensive operations identified in the execution plan.

### 3. **Existing Infrastructure Advantages**
- Confirmed that ENT table already has a primary key index on TINSID
- This existing index supports the numerous UPDATE operations

## Root Cause Analysis

The performance degradation is not attributable to the Java/Kubernetes infrastructure but rather to:

1. **Data Volume Growth**: Areas 22+ likely contain significantly more records than when the Pro*C version was originally deployed
2. **Sequential Processing Model**: The cursor-based approach doesn't scale with increased data volumes
3. **Lack of Set-Based Operations**: The procedure processes records individually rather than leveraging Oracle's set-based processing capabilities

## Connection Timeout Context

The timeout errors occurring from Area 22 onwards are symptoms of the underlying performance issues:
- Java/Kubernetes connection pools have reasonable timeout settings for normal operations
- The procedure's execution time exceeds these thresholds due to its processing methodology
- The legacy Pro*C system likely had different timeout configurations or data volumes

## Recommendations for Long-term Resolution

While the parallel wrapper and indexes provide immediate relief, the fundamental solution requires:

1. **Refactoring to Set-Based Operations**: Replace cursor loops with bulk MERGE statements
2. **Externalize Business Rules**: Move hardcoded values to configuration tables
3. **Implement Bulk Collection**: Use BULK COLLECT and FORALL for remaining cursor operations
4. **Consider Partitioning**: For large tables, implement partitioning strategies

## Conclusion

The performance issues are inherent to the stored procedure's design patterns, which were standard practice in Pro*C development but are not optimal for modern Oracle databases handling larger data volumes. The Java/Kubernetes infrastructure is correctly configured with appropriate timeouts for normal database operations. The implemented optimizations (parallel processing wrapper and strategic indexes) provide immediate performance improvements while maintaining compatibility with the existing codebase.
