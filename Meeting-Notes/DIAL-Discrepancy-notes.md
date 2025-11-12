# DIAL Data Discrepancy - Master Notes
*Combined analysis from November 7 and November 12, 2025*

---

## Executive Summary
DIAL system has critical data discrepancies affecting approximately 56,000+ records across multiple components. Issues stem from incorrect sorting logic, missing code statements, and calculation inconsistencies between legacy and modernized systems. The problems impact extract loading, ENT assignments, and TIN summary calculations.

---

## Issue 1: Extract Loading Problem (29 Missing Records)

### Problem Statement
29 records with cubic indicator of 3 were not picked up from the 75-record production load into **DIALDEV** (not NADAV).

### Root Causes
- **Missing update statement** in the code for records with a load date
- **Missing break statement** causing file source 2 to be treated like file source 3
- **Case 2 not properly accounted for** in the switch logic

### Technical Details
- Query correctly identifies the data, but records aren't loading to the C extract
- Records with cubic indicators 1 and 2 (which should be excluded) require transmod set to -1
- Code uses 1900 load date as baseline
- Script performs bulk operation selecting into table data and iterating over the table
- Updates transmod and date when it's -1, but some items aren't being added because transmod doesn't hit the switch

### Required Actions
1. Add missing update statement for load date records
2. Add proper break statement for case 2 handling
3. Verify transmod update logic for all cubic indicator values

---

## Issue 2: DIAL ENT Table Logic Failure (~30,000 Records Affected)

### Problem Statement
ENT assignments are incorrect due to improper sorting order, affecting approximately 30,000 records.

### Root Cause
Data sorting order is reversed in some cases:
- **Expected**: Sort by TDA then TDI
- **Actual**: Sometimes sorting by TDI then TDA, causing mismatches

### Impact
- Incorrect ENT assignments affect related fields in both ENT and TIN summary tables
- Records that should be grouped together are being separated
- Staging data showing 5 records when it should parse down to 2 based on dependencies

### Technical Details
- TDI is never going to have the "I"
- Data pulled from cordial and dialend (dialend contains extract data - TI x rep)
- ENT type is calculated in the dialend table
- Data also needs to be pulled from tint summary (has TDI underscore and ENTD underscore)
- TDI XREF N type is null because it's raw data loading, not updated
- Script sometimes starts from a specific row instead of the top

### Edge Cases Identified
- Records from Area 13 appearing with different formatting (without leading zeros) compared to tin summary
- Data dispersed across different service center areas
- Order in which data is received affects how it's manipulated

---

## Issue 3: Stored Procedure Sorting Problems

### Problem Statement
The stored procedure's sorting logic doesn't work consistently across different record types (rectype), causing systematic failures.

### Specific Problems by Record Type

**Rectype 5:**
- Sorting by tax period (26 characters) creates conflicts
- Should come in as N type 1 and get set to A
- In legacy ENT, it's supposed to be 1A 1C, but should be both A's in the summary table
- Legacy is not putting fives on top (Richard and Marion come first)

**Rectype 2:**
- Putting TDAs on top causes issues for referral records
- Legacy sometimes puts zeros on top, creating mismatches
- First putting TDAs on top created an issue

**Core Constraint:**
- Cannot sort different cases differently within current procedure structure
- "I can't sort for the different cases different way"
- When ordering one way, other cases fail: "If you take this way, other things are not working correct"

### Technical Architecture
- Stored procedure has extensive logic in C file with case-by-case recovery
- TNT type and XF calculations stored in core dial table (dial core and ENT table) instead of pulling three times
- Dispatches to three separate procedures: load core, load ent, and load sum
- Uses partition/group by approach with descending by name
- Code does sort on name first, then sort on rectype

### Data Flow Issues
- Data in combo raw is not calculated in staging; it's the data that came in
- Two records with rec type 5:
  - First one comes through and is set to A and type of one
  - If second one comes through with same five, it will have same number and same A and I
- Thought process is to process first record and skip second, but second record still gets added to core dial

---

## Issue 4: TIN Summary Calculation Problems (~26,000 Records Affected)

### Problem Statement
N type calculation in TIN summary is causing mismatches in approximately 26,000 records due to inconsistent sorting and calculation logic.

### Root Cause
N type is **calculated in the code**, not selected from existing rows, and the calculation logic has multiple failure points.

### Calculation Logic (Current Implementation)
```
Order is kept based on XREF:
- If previous record TIN ≠ current record TIN, and it's first time (null) → set to 1 and A
- If previous record TIN = current record TIN → remains 198
- If it is 0 → updates to 2 and 1
```

### Problematic Pattern
**Problem arises when:**
- Previous and current record TINs are the same
- BUT rec type is 0 for one record and 5 for another
- "So here this is the kind of records are causing problem"

### Sorting Inconsistencies
- Group by is done by name
- When records are grouped, rec type can be different
- "This red type sometime in the code depend on that XREF value...Sometimes they're picking this one, some cases they're picking this one"
- **Tax period ordering not working evenly for all records**
- Some records use tax period ID for date sorting, but sorting is sometimes incorrect
- Inconsistencies between ascending and descending order

### Technical Constraints
- Views were created using case statements to handle different record types
- SQL code cannot be put into the view because it is locally calculated
- Code originated from different system (Java code) with local variable declarations
- If rec type is 5, then entity type is 1
- Because of entity type, different orders are being selected

### Attempted Solutions
**Approach 1: LAG/LEAD SQL Implementation**
- Implemented SQL using "lag" (previous) and "lead" (next)
- Initial result: Fixed and reduced records to 10,000
- **Failed**: When trying to fix remaining 10,000, it went back to 1 million records
- Conclusion: "This approach is not the right solution"

**Approach 2: View-Based Calculation**
- Attempted to create views with case statements (rec type is 0 then TypeScript, otherwise don't use descending array sending)
- Limited by local calculation requirements
- Cannot fully implement in views due to calculation dependencies

### Open Questions
- **Entity type usage**: May not be required and could potentially be ignored if not being used elsewhere
- Issue occurring in only one table where calculation is manual and not based on record type
- Sam needs to confirm whether entity type is being used elsewhere

---

## Cross-Cutting Issues

### Pattern Matching Problem
- Order changes may not work; cases need careful examination
- "If the pattern matches, a solution can be found, but the pattern is not matching"
- Attempted case-based approach to avoid sorting or implement lengthy view, but pattern inconsistency prevents solution

### Data Sources and Validation
- Data pulled from multiple sources: cordial, dialend, tint summary, core dial
- Discrepancies exist between:
  - Legacy data (from last week's run)
  - Current staging data
  - DIALDEV loaded data
- Example: "Currently we only have one record in tint summary. But when I look at the int. Dial int data for Q, what would be two. I got nothing. Zero. But if I see Legacy, which is last week ran that we can find two records there."

---

## Documentation and Coordination

### Current Status
- Ranjita created robust document explaining order issue for entity
- Need for consolidated documentation to maintain team focus
- Previous lengthy discussion from last week covered same ground
- Team wants to avoid repeating previous discussions without progress

### Next Steps
1. **Immediate**: Fix sorting order in stored procedure to consistently sort by TDA then TDI
2. **Short-term**: Review and fix procedure logic to handle different rectypes appropriately
3. **Documentation**: Create master note so team can stay focused instead of going through emails
4. **Validation**: Identify specific TINs that are failing after fixes are implemented
5. **Decision needed**: Confirm with Sam whether entity type is required or can be ignored

---

## Impact Assessment

**Total Records Affected:**
- 29 records: Extract loading issue
- ~30,000 records: ENT table sorting issue
- ~26,000 records: TIN summary calculation issue
- **Total: ~56,000+ records with discrepancies**

**System Components Impacted:**
- C extract loading
- DIAL ENT table
- TIN summary table
- Core dial table
- Stored procedures (load core, load ent, load sum)

**Critical Dependencies:**
- Sorting logic must work consistently across all record types
- Cannot change sorting for one rectype without breaking others
- N type calculation depends on correct ordering
- Entity type calculation affects downstream processing
