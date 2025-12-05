# Email Response to Mark - DIAL Table Column Validation Update

**To:** Mark  
**From:** Santosh  
**Date:** December 5, 2025  
**Subject:** RE: DIAL Table Column Validation - Detailed Progress Update

---

Hi Mark,

Thank you for your follow-up on the DIAL table column validation. I wanted to provide you with a comprehensive update on our progress addressing the remaining column mismatches and the collaborative approach we've been taking with Sam.

## Background

As you know, the DIAL migration has achieved 99.92% data accuracy (approximately 11,000 records out of 15 million showing discrepancies). The root cause of these remaining mismatches stems from a fundamental technical challenge: the legacy C/Pro*C code processes records sequentially with state variables, while modern SQL operations produce non-deterministic results due to platform differences between the legacy M7 servers and the new Oracle Exadata environment.

Specifically, certain calculations in the TIN_SUMMARY table are **order-dependent**—the value assigned to a field depends on which record processes first when multiple records share the same TIN. SQL sorting with `ORDER BY` cannot reliably replicate the exact tie-breaking behavior of the legacy sequential processing.

## Sam's Collaboration & Solution

Sam has been actively working with our team to analyze the flag calculation logic embedded in the legacy code. Earlier this week, he provided us with an updated SQL script (`Tinsummary_Corrections.sql`) that addresses **five specific columns** in the TIN_SUMMARY table:

| Column | Issue Description | Sam's Solution |
|--------|-------------------|----------------|
| **STAT_FLAG** | ~88,000 record discrepancies due to order-dependent flag calculation during grouping | Corrected business logic for determining which record to select when grouping by TIN |
| **LFI_FLAG** | ~185,000 record discrepancies with similar root cause | Same grouping/selection logic correction applied |
| **PYR_FLAG** | Discrepancies in calculation based on MOD values | Proper maximum/minimum value selection logic implemented |
| **AGE_FLAG** | ~7,000 records with age class calculation differences | Corrected dependency-based calculation (O→2, P→1 logic) |
| **ENT_SEL_CD** | Entity selection code discrepancies | Already showing as correct in recent validation |

The key insight Sam provided was around the **business logic for maximum/minimum value selection**. The legacy code uses specific rules to determine whether to take the maximum or minimum value at different calculation points. Our initial implementation wasn't accounting for all the nuanced business rules—for example, in some cases the calculation requires taking the maximum value first, then the minimum in subsequent passes. Sam helped clarify the exact sequencing from the legacy Pro*C code.

## Current Status

1. **Implementation Complete**: Ganga has implemented all of Sam's corrections into our stored procedures
2. **Verification In Progress**: We restarted the validation job this morning after Ranjita fixed a minor ICS-related configuration issue that was causing ~500 additional differences
3. **Pending Validation**: Once the current run completes (estimated 2-5 minutes with our optimized stored procedures), we will run minus queries to confirm the matches

## Outstanding Item: TD_ACCOUNT Count

There is one additional issue separate from the five flag columns—the **TD_ACCOUNT count logic** in an existing stored procedure. This calculation is running but experiencing performance issues:

- The existing code (which we did not modify) is taking 5+ hours to execute and appears to be locking/deadlocking
- Ganga isolated this portion to allow the rest of the validation to complete
- We have a follow-up call scheduled with Sam today to discuss why the legacy count logic behaves differently in our environment

## Next Steps

1. Complete the current verification run
2. Provide minus query results or validation documentation demonstrating column alignment for the five corrected columns
3. Meet with Sam today to address the TD_ACCOUNT count issue
4. Apply any additional fixes and re-validate

## Code Cleanup (Parallel Track)

Once validation is confirmed, Paul will update all stored procedures and functions to follow proper naming conventions (procedures ending with `_PRC`, functions with `_FUNC`) and ensure proper error logging throughout.

---

I'm confident we are very close to full alignment on the DIAL tables. We will share the validation evidence as soon as our current verification run completes, which should be within the hour.

Please let me know if you need clarification on any specific table or column, or if you'd like to join our follow-up call with Sam.

Thank you,  
Santosh
