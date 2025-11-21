SELECT 
    TIN,
    RECTYPE,
    NAMELINE,
    TAXPRD,
    
    -- Show the composite sort key
    NAMELINE || 
    CASE 
        WHEN RECTYPE = 5 THEN '1'
        WHEN RECTYPE = 0 THEN '2'
        ELSE '3'
    END AS COMPOSITE_KEY,
    
    ROW_NUMBER() OVER (
        ORDER BY
            TIN,
            NAMELINE || 
            CASE 
                WHEN RECTYPE = 5 THEN '1'
                WHEN RECTYPE = 0 THEN '2'
                ELSE '3'
            END,
            TAXPRD DESC NULLS LAST,
            ROWID
    ) AS PROCESSING_SEQUENCE

FROM DIAL_STAGING
WHERE TIN IN (1488893, 1506400)
ORDER BY PROCESSING_SEQUENCE;
```

**Expected results:**
```
TIN      | RECTYPE | NAMELINE                  | TAXPRD | COMPOSITE_KEY              | PROC_SEQ
---------|---------|---------------------------|--------|----------------------------|----------
1488893  | 5       | ROBERT W CURRIER          | 201812 | ROBERT W CURRIER1          | 1
1488893  | 0       | ROBERT W & EDITH J CURRIER| 201712 | ROBERT W & EDITH J CURRIER2| 2
1506400  | 5       | NOLANDO BRICE             | 202112 | NOLANDO BRICE1             | 3
1506400  | 0       | NOLANDO BRICE             | 202312 | NOLANDO BRICE2             | 4
1506400  | 5       | NOLANDO N BRICE           | 201512 | NOLANDO N BRICE1           | 5




SELECT 
    TIN,
    RECTYPE,
    NAMELINE,
    TAXPRD,
    FILESOURCECD,
    TINTYPE,
    ASSIGNMENTAO,
    ASSIGNMENTTO,
    MODTYPEIND,
    ROWID
FROM DIAL_STAGING
WHERE TIN IN (1488893, 1506400)
ORDER BY TIN, RECTYPE, TAXPRD DESC;






# DIAL Sorting Issue - Status Update for Rick

Hi Rick,

Here's a summary of the data sorting challenge we've been working through and our path forward:

## Problem Overview
- **Issue:** DIAL entity type calculations depend on precise record ordering that differs between legacy M7 and modern Exadata platforms
- **Impact:** Currently seeing ~11,000 discrepancies (99.92% accuracy) due to non-deterministic sorting behavior
- **Root Cause:** Legacy C code uses procedural, multi-pass sorting logic that cannot be directly replicated in declarative SQL

## What We've Discovered

**Platform Differences:**
- ✓ Confirmed NLS settings are identical between M7 and Exadata
- ✓ Identified that Exadata's query optimizer uses different execution strategies (hash-based vs. sort-based)
- ✓ Found that tie-breaking behavior differs between platforms when records have identical sort keys

**Legacy Logic Complexity:**
- Legacy code performs conditional, multi-pass sorting that changes strategy based on data patterns
- Some TINs require RECTYPE priority (all Type 5 records before Type 0)
- Other TINs require NAMELINE grouping first, then RECTYPE within each name group
- This conditional logic is embedded in 20+ year old C code with implicit platform dependencies

**Technical Constraints:**
- SQL ORDER BY cannot replicate conditional sorting logic (if/else branching mid-sort)
- Legacy approach was designed for procedural file processing, not set-based database operations
- Modern database architecture doesn't support the legacy's sequential processing patterns

## Solutions Being Evaluated

**Approach 1: Enhanced SQL with Deterministic Tie-Breakers**
- Add explicit ROWID-based ordering to eliminate non-determinism
- Expected to reduce discrepancies by 70-80%
- Quick to implement (1-2 days)

**Approach 2: Move Complex Sorting to Java Layer** ⭐ **[RECOMMENDED]**
- Implement the conditional sorting logic in Java before database insert
- Java can replicate the procedural C logic that SQL cannot
- Separates business logic (sorting rules) from data access (SQL)
- Aligns with modern application architecture patterns
- Timeline: 1-2 weeks development + testing

**Approach 3: Business Validation of Remaining Variance**
- Validate which fields are operationally critical
- Accept minimal variance (0.08%) for non-material fields if business approves
- Fastest path to go-live (1 week)

## Why Java Instead of SQL?

The legacy design was optimized for:
- Sequential file processing (record-by-record)
- Procedural control flow (if/else, loops, conditional branching)
- Platform-specific behavior (M7 SPARC architecture)

Modern database architecture requires:
- Set-based operations (process all records simultaneously)
- Declarative queries (describe what, not how)
- Platform-independent SQL

**The mismatch is architectural, not a coding error.** Java provides the procedural capabilities needed to replicate legacy sorting while maintaining clean database design.

## Recommended Path Forward

1. **This Week:** Implement Approach 1 (SQL enhancements) for quick wins
2. **Next Sprint:** Develop Approach 2 (Java sorting layer) as permanent solution
3. **Parallel Track:** Prepare Approach 3 (business validation) as contingency

**Expected Outcome:**
- Approach 1 gets us to 99.97-99.99% accuracy (reduction to <1,000 discrepancies)
- Approach 2 targets 100% accuracy while maintaining architectural integrity
- Approach 3 provides business sign-off path if perfect match proves infeasible

## Resource Needs
- Ganga: SQL optimization (Approach 1) - 2 days
- Samuel/Paul: Java implementation (Approach 2) - 1-2 weeks
- Santosh: Business coordination (Approach 3) - ongoing

Please share with Brian if he needs visibility into the technical approach and architectural considerations.

Let me know if you need any clarification or want to discuss the recommended path.

Thanks,
Santosh

---

**Note:** The Java approach is not a workaround—it's proper architectural separation between business logic (sorting rules) and data persistence (database). Legacy embedded all logic in database procedures; modern architecture externalizes business rules to the application layer.
