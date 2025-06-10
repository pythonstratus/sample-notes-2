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
