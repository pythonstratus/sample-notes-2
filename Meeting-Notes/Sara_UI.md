# Deep Dive Meeting Notes: SARA Column Order Review & System Requirements
**Date:** October 9, 2025, 1:04 PM  
**Attendees:** Sarah (Client), Islam, Santosh  
**Recorded by:** Minutes AI

---

## Executive Summary

This meeting covered three primary workstreams for the SARA system: (1) UI/UX refinements for column ordering and navigation elements, (2) calendar and data management improvements, and (3) comprehensive realignment functionality requirements. The session focused heavily on realignment processes, with detailed technical specifications for creating, moving, renaming, and collapsing organizational units (groups and territories) while maintaining IDRS compliance.

---

## 1. Column Ordering & Data Display

### Background & Context
- **Source Material:** PowerPoint in SharePoint > Mock Ups > Reports folder, specifically slide 46
- **Original Expert:** Mark Norman (retired earlier this year) suggested the initial column order
- **Current Issue:** Discrepancies exist across slides 46, 47, and 48

### Action Items
- Sarah to review emails from Mark Norman to confirm correct column order before development proceeds
- Column order is critical for managers evaluating data row by row
- Clarity needed before development begins to prevent rework

### Business Rationale
Proper column ordering aids in systematic data evaluation, particularly important for managers who review data sequentially.

---

## 2. UI/UX Elements & Navigation

### Links vs. Buttons Discussion

**Current Implementation:**
- "Previous week" and "next week" are styled as links (underlined)

**Design Philosophy:**
- **Links** = Actions that navigate the user to different views/pages
- **Buttons** = Actions that change data within the current table/view

**User Experience Concern:**
- Internal users associate underlined links with navigation to entirely different pages
- Current implementation may cause confusion

**Resolution:**
- Adjust styling to make links look more like buttons while maintaining semantic HTML structure
- Maintains accessibility while improving user familiarity

### Assignment Numbers as Links

**Current Design:**
- Assignment numbers display as clickable links
- Serves as the key to navigate to the next page

**Accessibility & Usability:**
- **508 Compliance:** Link serves as primary access point for keyboard users
- **Click Target:** Users can click anywhere on the row to navigate, not just the link
- **Navigation:** Clicking assignment number link takes user to that assignment's record

**Design Decision Rationale:**
- Balances accessibility requirements with usability
- Provides multiple interaction methods (entire row clickable, but semantically correct link for keyboard navigation)

---

## 3. Additional Functionality Requirements

### Non-Case Time Section
- **Requirement:** Add "non-case time" section underneath existing "case time" section
- **Purpose:** Monitor time spent on administrative tasks
- **Placement:** Directly below case time for logical grouping

### Export & Print Functionality

**Current State:**
- Existing report shows similar information in reports menu
- Question raised about PDF export capability

**Proposed Solution:**
- Link existing report to newly developed page
- Consolidate functionality into new page
- Add export capability from new interface
- Allow control switching (e.g., view specific person vs. entire group)

**Additional Requirements:**
- Add dropdowns for different granularity levels:
  - National
  - Area
  - Territory
  - Group

---

## 4. Weekly Time Verification Reports

### Current Limitations
- Multiple separate reports needed for different views
- No unified export functionality

### Proposed Enhancements

**Core Requirements:**
1. Make weekly time verification reports exportable
2. Add dropdown box to choose viewing level
3. Link to existing weekly time verification
4. Allow filtering at multiple levels
5. Enable data export from filtered views

**Assignment Number Dropdown:**
- Add dropdown labeled "Assignment Number" to weekly group view
- **Alternative Approach:** Allow direct input instead of dropdown due to large number of options at national level
- **User Guidance:** Implement hover feature showing input format:
  - Codes for area
  - Codes for territory
  - Codes for group
  - Individual RO codes
- **Special Case:** Inputting "0" displays national-level data

### Data Redundancy Review
- Reporting month and week information may be redundant (already in weekly time verification)
- Consider moving pay period information elsewhere on screen

---

## 5. CTRS Calendar Management

### Current Pain Point
- CTRS calendar requires annual updates with:
  - Number of weeks per month
  - Working days
  - Holidays
  - Hours per recording month
- Currently requires developer involvement for updates
- Diane experienced frustration doing this three times due to corrections and releases

### Proposed Solution

**Self-Service Calendar Management:**
- Create CTRS calendar within the system
- Allow manual input by authorized users
- Eliminate need for developer involvement in annual updates
- Data should populate throughout application once updated

**Required Calendar Data Fields:**
- Fiscal month
- Posting cycles
- Dates for each week
- Work days per period
- Holidays
- Hours for recording month

**Frequency:** Process repeated 12 times annually (one per month)

**Reference:** Sarah sent email with detailed requirements on needed data fields

---

## 6. Outstanding Technical Issues

### Lottery Issue
- Lottery was changed but same issue persists
- Requires follow-up investigation

### Outlook Issue
- Outlook stuck on gray screen with circling icon
- Blocking productivity, needs immediate attention

---

## 7. Realignment Functionality - Comprehensive Requirements

### Overview & Research
Sarah reviewed multiple sources:
- Recordings of previous sessions
- Excel sheet (SROC)
- PowerPoint presentation

### Nine Core Realignment Actions

1. **Company rename**
2. **Add employee**
3. **Move employee** (not usually processed in practice)
4. **Add a group**
5. **Collapse a group**
6. **Move a group**
7. **Add a territory**
8. **Collapse a territory**
9. **Move a territory**
10. **Add an area**
11. **Collapse an area**

*Note: Meeting focused primarily on group and territory operations*

### Session Focus
- Group and territory work (items 4-9 above)
- Filter added to demonstrate: FC North Atlantic view

---

## 8. Create Group or Territory Functionality

### User Interface Flow

**Entry Point:**
- User clicks link to "Create group or territory"

**Conditional Display:**
- If creating territory: Hide certain fields, possibly add link to add groups to dropdown

**Form Fields Required:**
- Territory number (4 digits - validation required)
- POD number
- POD name
- State
- Type
- Local contact name
- Phone number

### UI Improvements Needed

**Button Changes:**
- Change "Create group or territory" to just "Create"
- Make it a button instead of link for clarity

**Navigation Enhancement:**
- Add additional box for territory selection
- Enable drill-down to see all groups within a territory

---

## 9. Edit/Rename Functionality

### Access & Flow
- Clicking rename/edit opens form with all current information pre-populated

### Business Rules & Constraints

**Immutable Fields:**
- Organization cannot be changed during editing
- Territory number doesn't allow organization changes

**Changeable Fields:**
- Area can be changed

**Cascading Changes:**
- If area changes (e.g., North Atlantic to Central), first two digits of territory number must automatically update
- Territory number validation based on area
- Group number validation based on territory and area
- Auto ID updates based on group, territory, and area hierarchy

**Authority:**
- Nicole decides what numbers to assign for new organizational units

---

## 10. Naming Conventions & Number Structure

### Territory & Group Numbers

**Territory:**
- 4 digits total
- First 2 digits = Area code
- Must align with parent area

**Group:**
- 6 digits total
- Must align with parent territory and area
- Exception noted: "Group Denver doesn't have the last two digits" (clarification needed)

### POD Name Convention
- POD name usually matches group name
- Names may change over time (example: Baltimore renamed to Kansas City)

### Group Type & Organization Relationship
- Relationship exists between group type and organization code
- **Advisory groups:** Can only use third and fourth digits as 96, 97, or 98

---

## 11. IDRS Rules & Assignment Numbers - CRITICAL COMPLIANCE

### IDRS System Background
- IDRS = Mainframe system that owns the rules for assignment numbers
- All SARA functionality must comply with IDRS validation rules

### Assignment Number Structure & Rules

**First Two Digits (Area/Organization):**
- SBSE, field organization, and AO: Can only be **21-27 and 35**
- Field ICS, SBSC, and WI users: Must be in areas **21-27 and 35**

**Third and Fourth Digits (Territory):**
- **Cannot be:** 00, 70-89, or 94-99
- **Field Collection must be:** 01-94

**Fifth and Sixth Digits (Group/Branch):**
- **Field Collection:** Must be 10-58
- **Queue cases:** Use 70
- **Exempt organizations (Advisory CISO):** Use 96-97
- **Offer and compromise groups:** Must use 85
- **Insolvency:** Uses 94, 95, 98, and 99

### Validation Requirements
System must enforce these rules during:
- Group creation
- Territory creation
- Group/territory moves
- Any reassignment operations

---

## 12. Database Updates & Data Management

### Non-Historical Database Architecture
- Database is **not historical** - old records are not retained
- Changes are applied universally across all tables

### Update Process Requirements

**When Updating Group Information:**
1. System must scan all tables where group number is used
2. Update group number across all occurrences
3. Changes affect all records, not just future records

**Realignment Impact:**
- Realignments do **not** affect CTRS
- Changing a group's territory updates it everywhere, including historical records

**Example Scenario:**
- Moving a group from one territory to another updates all records system-wide
- No preservation of previous organizational assignment in records

---

## 13. Confirmation & Audit Trail Requirements

### Confirmation Workflow

**Step 1: Pre-Action Confirmation**
- Display confirmation box summarizing all changes before processing
- User must explicitly approve changes

**Step 2: Confirmation Content Required:**
- Old name → New name
- Old number → New number
- All affected fields with before/after states

**Step 3: Post-Action Documentation**
- After confirmation, generate proof of processed SROC task
- **Delivery Method:** Email OR export file to user
- **Purpose:** Serves as documentation for completing SROC tasks across multiple systems

### Confirmation Page Specifications

**Design Preference:**
- Sarah prefers confirmation pop-up over maintaining historical database
- Alternative: Build dedicated confirmation page instead of email export
- *Note: Email messages sent through Splunk, requiring communication between tools*

**Confirmation Page Requirements:**
- Should resemble Nicole's spreadsheet format
- Must show:
  - What was done
  - When it was done
  - Literal proof of changes (before/after)
- Must be printable
- Must be savable as PDF

### Data Accuracy Display - CRITICAL

**Character-Level Accuracy:**
- Output must clearly show spaces or misspellings in data
- Example cited: "Prince George County" with two spaces between "Prince" and "George"
- **Solution:** Add character count to output

**Rationale (Sarah's quote):**
> "As long as we can see that we made that error...when I go back, hey, look at that export saying, oh shoot, I did my. You know, mistyped my letters."

**Purpose:** Enable users to catch their own errors immediately through visual verification

---

## 14. Move Operations

### Move Group Functionality

**Process:**
- User selects group to move from one territory to another
- System updates records across all tables
- Confirmation box displays before processing

**Impact:**
- Changes group assignment everywhere in system
- Updates all existing records (non-historical database)

### Move Territory Functionality
- Similar process to move group
- Updates all child groups automatically
- System-wide propagation of changes

---

## 15. Collapse Operations

### Business Context
- "Collapse" terminology should be retained
- Sarah's rationale (quote): "It's literally dramatic. It's like. Yeah, it's collapsing. No one's there."
- Conveys the finality of the action

### Collapse Group
- Removes group from active organizational structure
- Should be automatic process

### Collapse Territory
- Removes territory from active organizational structure
- Should be automatic process

### Ghost Territories
- **Exception noted:** Sometimes territories are left intact (as "ghosts") for future hiring
- System should accommodate this scenario

---

## 16. Complete Realignment Action List

### Actions to Implement in System

1. **Create a group**
2. **Create a territory**
3. **Move a group**
4. **Move a territory**
5. **Collapse a group**
6. **Collapse a territory**
7. **Change group type** (included in edit functionality)

### Actions NOT Usually Processed
- **Move individuals** - noted as not typically done in practice

---

## 17. Future Topics & Roadmap

### Upcoming Discussion Items
1. Alignment end-of-month reporting
2. BOE reports and query builders for staff
3. Additional collapse automation requirements

---

## 18. Team Structure & Development Approach

### Mobileforce Sessions
- Will be kept to smaller number
- Purpose: Give developers more time to code
- Reduces meeting overhead

### Core Team for Requirements Gathering
- **Santosh** - Business Analyst/Scrum Master (asking frequency questions about list changes)
- **New Business Analyst Scrum Master** - TBD name
- **Sarah** - Client/Product Owner
- **Islam** - Technical Lead/Development

### Development Documentation
- **Product Requirement Document (PRD):** Sarah will create with specifications
- **Technical Requirements:** Santos will translate PRD into technical specs
- **User Stories:** To be created later based on these notes

---

## 19. Outstanding Questions & Follow-Up Items

### Questions Raised by Santosh
- **Data Change Frequency:** How frequently does the organizational list change?
  - Important for caching strategy
  - Affects refresh cycles
  - Impacts performance optimization

### Items Requiring Clarification
1. Group Denver number structure exception (missing last two digits)
2. Lottery issue resolution
3. Outlook technical issue blocking productivity
4. Exact specifications for CTRS calendar email from Sarah

---

## 20. Action Items Summary

### Sarah (Client)
- [ ] Review Mark Norman emails for definitive column order
- [ ] Create Product Requirement Document for realignment functionality
- [ ] Provide CTRS calendar specifications (email sent, needs review)
- [ ] Confirm group type to organization relationship rules
- [ ] Clarify Group Denver numbering exception

### Islam (Development Lead)
- [ ] Adjust link styling to appear more button-like while maintaining accessibility
- [ ] Implement assignment number dropdown with hover guidance
- [ ] Design confirmation page matching Nicole's spreadsheet format
- [ ] Implement character count display in confirmation outputs
- [ ] Build IDRS validation rules into create/edit forms
- [ ] Resolve Outlook gray screen issue
- [ ] Investigate persistent lottery issue

### Santosh (Business Analyst)
- [ ] Document frequency of organizational list changes
- [ ] Translate PRD into technical requirements (as Santos)
- [ ] Participate in requirements gathering sessions
- [ ] Prepare for user story creation

### Team (Collective)
- [ ] Schedule follow-up sessions on:
  - Alignment end-of-month reporting
  - BOE reports and query builders
  - Collapse automation details
- [ ] Reduce Mobileforce session frequency to allow more development time

---

## 21. Key Technical Requirements Summary

### Validation Rules to Implement
1. Territory number: 4 digits, first 2 must match area
2. Group number: 6 digits, must align with territory and area
3. IDRS first two digits: 21-27 and 35 only
4. IDRS third/fourth digits: Cannot be 00, 70-89, or 94-99
5. Field Collection groups: 10-58
6. Advisory groups: 96-97
7. Insolvency: 94, 95, 98, 99
8. Offer/compromise: Must use 85

### System Behavior Requirements
1. Non-historical database - all updates apply universally
2. Cascading updates across all related tables
3. Pre-action confirmation with detailed change summary
4. Post-action audit trail (printable/savable)
5. Character-level accuracy display to catch typos
6. Auto-calculation of dependent fields (Auto ID based on hierarchy)
7. Support for "ghost territories" in collapse scenarios

---

## Notes for User Story Creation

### Epic 1: UI/UX Refinements
- Column ordering configuration
- Link vs button styling improvements  
- Assignment number navigation enhancements
- Weekly time verification dropdown filters
- Export and print functionality

### Epic 2: CTRS Calendar Management
- Self-service calendar input interface
- Annual data entry forms (12 monthly cycles)
- System-wide calendar data propagation
- Eliminate developer dependency for updates

### Epic 3: Realignment - Create Operations
- Create group form with validation
- Create territory form with validation
- IDRS rule enforcement
- Auto ID calculation
- POD information management

### Epic 4: Realignment - Edit/Move Operations
- Edit group functionality
- Edit territory functionality
- Move group with confirmation
- Move territory with confirmation
- Cascading updates across tables
- Area change with automatic number updates

### Epic 5: Realignment - Collapse Operations
- Collapse group functionality
- Collapse territory functionality
- Ghost territory support
- Automatic processing

### Epic 6: Confirmation & Audit Trail
- Pre-action confirmation dialogs
- Confirmation page design (Nicole's spreadsheet format)
- Character count display
- Print/PDF export capability
- Before/after state display
- Error visibility (spaces, typos)

### Epic 7: Reports & Export Enhancements
- Non-case time section addition
- Multi-level granularity dropdowns (national/area/territory/group)
- Unified export functionality
- Report consolidation
- Assignment number input with hover guidance

---

## Meeting Effectiveness Notes

**Strengths:**
- Comprehensive coverage of realignment requirements
- Detailed IDRS compliance rules documented
- Clear business rationale for design decisions
- Strong focus on user error detection and prevention

**Areas for Follow-Up:**
- Some technical issues (Outlook, lottery) mentioned but not resolved
- Group Denver numbering exception needs clarification
- Data change frequency question from Santosh needs answer for technical planning

**Documentation Quality:**
- Excellent detail on validation rules
- Clear examples provided (Prince George County spacing)
- Direct quotes captured for important design decisions
- Technical specifications well-defined for Santos to translate

---

**Document End**

*These notes prepared for user story creation and development planning. All action items should be tracked in project management system. Technical specifications require review by Santos for translation into development tasks.*
