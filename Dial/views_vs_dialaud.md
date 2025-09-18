# Email to Core DIAL Development Team - Critical Dependencies Analysis

**Subject:** URGENT: DIALAUD Table Dependencies and View Inconsistencies - Action Required

**To:** Core DIAL Development Team

Hi Team,

Following up on our ETL dependency discussions with Sarah and the subsequent technical analysis with Steve Fu, we've identified critical dependencies that need immediate attention before proceeding with any performance optimizations.

## Critical Issue Summary

**DIALAUD Table Dependency Analysis:**
Our modernized DIAL processing updates specific DIALAUD columns (CFFDT, QUEDT, CFFENTCNT, CFFMODCNT, QUEENTCNT, QUEMODCNT per area) as validated by stakeholder testing. However, we need to verify that the LOADDT column and other fields required by legacy views and functions are also being properly updated.

## Specific Dependencies Identified

**Legacy Views Still Referencing DIALAUD:**
- `EVIEW.sql:958` - Contains: `(SELECT MAX (LOADDT) FROM DIAL.DIALAUD)`
- `MVIEW.sql:991` - Contains: `(SELECT MAX (LOADDT) FROM DIAL.DIALAUD)`

**Functions Still Using DIALAUD:**
- `func_CURRPER_DIALLOAD.sql:15` - Uses `decode(to_char((select max(loaddt) from dialaud))`
- `func_Q_RISK_BR.sql:242` - References DIALAUD for load date calculations

## Area 35 Sequencing Requirements

**Critical Processing Order:**
- Area 35 MUST be processed last on the dial side
- Queue RISK calculation in `combo_risk.sql` assumes Area 35 is the final area
- Special 99C processing for TDA with 30+ modules only triggers when reaching Area 35
- This validates Sarah's concerns about area processing dependencies

## Entity Environment Discovery

**Important Finding:**
When we examined MVIEW and EVIEW in the ENTITY environment, we discovered they are available but contain **incorrect database links pointing to DIALDEV** instead of the appropriate environment-specific database.

**Environment Linking Issue:**
- Views exist in ENTITY but reference DIALDEV database links
- This suggests environment-specific configuration problems
- Need to verify correct database linking across all environments

## Immediate Action Items

**1. DIALAUD Column Gap Analysis:**
- [ ] **We know our modern ETL updates:** CFFDT, QUEDT, CFFENTCNT, CFFMODCNT, QUEENTCNT, QUEMODCNT (per area)
- [ ] **Critical gap:** Legacy views need LOADDT - is this being updated by our modern ETL?
- [ ] **Missing columns:** Identify what other DIALAUD columns legacy systems expect but aren't in our validation list

**2. View Analysis:**
- [ ] **REQUEST: Can you please share the current `view_EVIEW.sql` and `view_MVIEW.sql` files?**
- [ ] We need to analyze the complete view definitions to understand full dependencies
- [ ] Verify environment-specific database links are correctly configured

**3. Data Integrity Verification:**
- [ ] **Confirm our modern ETL properly updates all DIALAUD columns used by legacy components**
- [ ] **Verify LOADDT column is correctly populated for EVIEW/MVIEW queries**
- [ ] **Test that dependent functions receive expected DIALAUD data**

**4. Area Processing Strategy:**
- [ ] Confirm Area 35 sequencing requirements with business team
- [ ] Ensure any performance optimizations maintain required processing order
- [ ] Test combo_risk.sql behavior with proposed changes

## Performance vs. Compatibility Trade-offs

**Current Situation:**
- Our performance testing showed excellent results (237M records in 3 minutes)
- **Stakeholder validation confirms we update specific DIALAUD columns (count-related fields per area)**
- **Critical question:** Do we update LOADDT which is essential for EVIEW/MVIEW MAX(LOADDT) queries?
- Legacy views and functions may require additional DIALAUD columns beyond our current scope

**Risk Assessment:**
- Legacy views may expect DIALAUD columns that our modern ETL doesn't update
- Views with incorrect database links may cause production issues
- Area 35 sequencing violations could affect risk calculations
- LOADDT or other critical columns may not be populated as expected by dependent systems

## Next Steps

1. **Immediate:** Please share view_EVIEW.sql and view_MVIEW.sql files for analysis
2. **This Week:** Complete dependency audit and environment link verification
3. **By Friday:** Propose technical approach for resolving DIALAUD conflicts
4. **Following Week:** Present options to business team with risk/benefit analysis

## Discussion Points for Next Team Meeting

- Which specific DIALAUD columns does our modern ETL update vs. what legacy systems expect?
- Are we populating LOADDT correctly for the MAX(LOADDT) queries in EVIEW/MVIEW?
- How do we handle environment-specific database links correctly?
- What's our strategy for Area 35 sequencing requirements?
- Timeline for verifying DIALAUD compatibility before performance optimization

This analysis confirms Sarah's concerns about hidden dependencies and validates her cautious approach. We need to resolve these technical debt issues before proceeding with major architectural changes.

Please prioritize the view file sharing and dependency analysis. This is blocking our optimization efforts and needs immediate attention.

Thanks for your focus on this critical issue.

**Best regards,**
[Your Name]

**CC:** Sarah Vainer (for visibility on technical findings)
