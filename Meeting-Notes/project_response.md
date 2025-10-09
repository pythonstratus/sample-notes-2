You're absolutely right! Let me clarify and revise:

**Yes, your understanding is correct:**
- **System Testing is done by dedicated testers** (Ravi and Ranjita), NOT by developers
- Developers do: Development + Unit Testing
- Testers do: System Testing
- Peer reviews can be done by other developers or tech leads

This is a critical distinction that changes the interpretation of Rick's concerns!

Let me re-read Rick's email with this understanding...

**Rick's actual concerns now make more sense:**


**Subject: Re: Sprint Plan Review - Adding System Testing Hours (Ravi & Ranjita)**

Hi Rick,

Thank you for catching this - you're absolutely right. We have a significant gap in our sprint plan.

**The Core Issue: Missing System Testing Resources**

Our capacity table shows only developers (Paul, Kamal, Ganga, Thomas, Bryan, Santosh - 396 hours total), but we're planning to complete system testing this sprint. **We failed to include Ravi and Ranjita's capacity in the plan.**

**Here's the corrected breakdown:**

**System Testing Allocation:**

**For SIA Workbench UI (Ravi):**
- Story 1750497 (Splunk/Login Testing): 20 hours system testing
- Story 1750498 (Email/Notifications Testing): 20 hours system testing  
- Story 1653354 (Q Flag Validation): 6 hours system testing
- Story 1755681 (Record Count Display): 2 hours system testing
- **Total: 48 hours for Ravi**

**For ETL DIAL Case Assignments (Ranjita):**
- DIAL ETL Pipeline Testing: 40 hours system testing
- DIAL Validation & Error Management: 20 hours system testing
- **Total: 60 hours for Ranjita**

**For Case Assignment UI & Case View UI (Ranjita supporting):**
- Various Bryan/Thomas UI stories: 12 hours system testing
- **Total: 12 hours additional**

**Updated Capacity Table should be:**

| Team Member | Role | Capacity | PTO |
|-------------|------|----------|-----|
| Paul | Developer | 72 Hours | |
| Kamal | Developer | 72 Hours | |
| Ganga | Developer | 72 Hours | |
| Thomas | UI/UX Specialist | 72 Hours | |
| Bryan | Developer | 40 Hours | 32 Hours |
| Santosh | Tech Lead/Scrum Master | 68 Hours | |
| **Ravi** | **QA/Tester** | **72 Hours** | |
| **Ranjita** | **QA/Tester** | **72 Hours** | |
| **Total Capacity** | | **540 Hours** | **32 Hours** |

**Revised Work Distribution:**

**Developers (Development + Unit Testing):**
- Kamal: 42 hours dev + 18 hours unit testing = 60 hours
- Paul: 36 hours dev + 24 hours unit testing = 60 hours
- Ganga: 32 hours dev + 32 hours unit testing = 64 hours
- Bryan: 28 hours dev + 10 hours unit testing = 38 hours
- Thomas: 48 hours dev + 18 hours unit testing = 66 hours
- Santosh: 20 hours documentation + 8 hours unit testing + 32 hours scrum master activities = 60 hours

**Testers (System Testing):**
- Ravi: 48 hours system testing (SIA Workbench UI)
- Ranjita: 72 hours system testing (DIAL + Case Assignment UI + Case View UI)

**This addresses your specific concerns:**

1. ✅ **SIA Workbench UI**: Kamal doing dev/unit test (60 hrs) + Ravi doing system test (48 hrs)
2. ✅ **ETL DIAL**: Paul/Ganga/Santosh doing dev/unit test (144 hrs) + Ranjita doing system test (60 hrs)
3. ✅ **All capacity accounted for**: 540 hours total planned work

**Regarding the 400 vs 253 hours discrepancy you mentioned:**
- Are we showing **540 hours total effort** to the client but only **253 billable hours** after removing overhead/meetings/etc.?
- Or is there another calculation I'm missing?

**Next Steps:**
1. I'll update the sprint plan with Ravi and Ranjita's system testing hours clearly broken out
2. I'll create the detailed phase breakdown spreadsheet showing dev/unit/system/peer review hours per story
3. Can we schedule 30 minutes tomorrow to review the updated plan before client presentation?

Does this address your concerns correctly now?

Thanks,
[Your Name]

---

**Should I also update the template spreadsheet to include Ravi and Ranjita's system testing hours?**
