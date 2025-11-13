Subject: SIA Testing Approach and Timeline - Response to Your Questions

Hi Rick,

Following up on your questions from today's meeting about defining "done" for the SIA Case Assignment work, here's the testing approach and timeline from Kamal:

**Testing Duration:**
- 2 weeks (2 cycles) to ensure consistent behavior
- We need 1 more complete cycle (1 more week) to validate consistency across Monday/Wednesday/Friday processing days

**Daily Time Commitment:**
- **30 minutes maximum per day** for the next 2 weeks
- This time is tracked separately under a support ticket (not development effort)

**Testing Process:**
1. Production data files received by 11am daily from Sam
2. Run the job (takes a few minutes)
3. Compare output against legacy system/production results
4. Identify and fix any query discrepancies same-day
5. Retest immediately

**What Defines "Done":**
Production data validation showing 100% match between new code and legacy system across 2 complete weekly cycles. This directly addresses your question about whether production validation is part of our completion criteria - yes, it is.

**Context on Testing Approach:**
The iterative testing approach is necessary because there were no documented requirements for this component. Additionally, Sam asked us to revise the legacy code with an updated structure in Java rather than a straight port. Because of this, we need these continuous cycles to test the data with a detailed approach and ensure the restructured code produces identical results to the legacy system.

**Current Status:**
- Development is complete - no new code development needed
- We're in query tuning phase, ensuring all records are picked up correctly
- Previously relied on manual testing which created uncertainty; now using production data for validation

**Dependencies:**
- Daily production files from Sam by 11am (critical path)

This gives us a concrete timeline and clear exit criteria. Let me know if you need any additional details for sprint planning with Corey.

Thanks,
Santosh
