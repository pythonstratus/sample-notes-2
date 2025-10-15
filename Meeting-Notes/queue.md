# Meeting Summary: National Cues/Queue Concept

**Meeting Date:** October 15, 2025, 12:02 PM  
**Attendees:** Sara and team

---

## Overview and Context

This meeting focused on defining a completely new concept called "National Cues/Queue" that has never been built before. Requirements are not yet written, and the team is working to understand what can and can't be done within both legacy and modernization system constraints. This information is not available on SharePoint or the CCD website.

---

## Current System: International Case Assignment (Area 35)

### Key Differences from General Program

**General Program (Areas 21-27):**
- Case assignment is based on zip code alignment (dial and diap)
- Revenue officers only see cases within their assigned zip codes
- Each group has a separate, limited view

**International Program (Area 35):**
- NOT based on zip codes, but on countries
- All three international groups share ONE singular queue
- When any group member accesses case assignment, they ALL see the same cases
- No zip codes are listed or used in Area 35
- Applies to all international cases, including Puerto Rico (which has zip codes but falls under Area 35)
- System takes longer to load due to the large volume (~7,000 cases) that must be displayed

### Current Rules
- General program groups see cases based on zip code
- International groups only see international cases
- Visibility is restricted by group and area

---

## National Queue Concept: Core Goals and Features

### Primary Objective
**"Everybody, everywhere is gonna be able to see everything in the whole dial."**

- Eliminate all geographic and group-based restrictions
- Allow anyone to see everything (both international and domestic cases)
- Break geographic boundaries due to decreased staffing levels
  - Currently down to 1,300 revenue officers (from a higher number previously)
  - Not enough people to cover the entire country geographically

### Scale and Size
- Will contain **1.5 million records** total
- Default view will show priority 99 cases: approximately **10,000-12,000 cases initially**
- Users can change the view using a dropdown menu to see other priority levels

---

## National Queue Design Specifications

### Placement and Structure
- **Separate tab** to ensure managers are aware they're selecting cases outside their geographic zone
- Similar table structure to current case assignment, with modifications

### Column Layout (Updated in SharePoint)
The team emphasized: **"You have to follow these guides that we have here. You absolutely have to. This is the layout you should see in case assignment with absolute certainty."**

**Key Columns:**

1. **Potential Assignment Number (PRO ID)** - Far LEFT column
   - For domestic cases: Based on zip code alignment
   - For international cases: Should display "international" (no zip code alignment)

2. **Geographic Information**
   - Domestic cases: Zip code, city, state
   - International cases: Country (instead of zip code)
   - City, state, and country fields included

3. **Actual/Current Assignment Number** - Far RIGHT column
   - Shows where the case currently is (Q or hold file)
   - Examples: 2700, 7000, 1500-7000, 1100-7000, 3000, 500, 7000
   - In legacy, only shows last four digits
   - Speaker prefers to call this "current" meaning "actual"

4. **Shared Field Concept**
   - Potential and actual assignment numbers share a field
   - For general program and international (blue field): Shared between Q and hold file
   - For National Q: Q only

### What NOT to Display
- **NO hold file information** in the far-right column
- **NO "cold file"** cases in international view
- **NO hold file cases** in the national queue
- **NO "date assigned Q"** field (speaker doesn't think the date is important; users can check details if needed)

### Priority and Sorting
- Cases sorted by priority
- **Internal Revenue Manual requirement:** Revenue officer managers MUST select the highest priority cases first
- Hold file cases might be higher priority than queue cases, but they won't be shown in the national queue

---

## Technical Challenges and Proposed Solutions

### Issue 1: Simultaneous Case Selection
**Problem:** Multiple managers (especially on Monday mornings) might select the same case at the same time in the national queue.

**Proposed Solutions:**
1. **Lock mechanism:** "Once you click on the button, you pick, we might need to lock it in the system"
2. First person to pick gets the case
3. Others receive a notification that it's already been picked
4. System needs to determine how to resolve conflicts (error message or automatic handling)

**Examples Referenced:**
- **Ticketmaster model:** Put a lock on items with a timer; if timer runs out, releases the hold
- **Nordstrom Rack/Amazon model:** Item appears available until you try to add to cart, then shows if someone else selected it

### Issue 2: Page Refresh and Real-Time Updates
**Problem:** After someone picks a case, other users' screens won't automatically reflect that it's been picked.

**Concerns:**
- Security implications of automatic refreshing
- Performance concerns with 1,300+ users potentially viewing 10,000-20,000 rows simultaneously
- "Every time we're doing a refresh is going to go back to the server"

**Proposed Solutions:**
1. Manual refresh button (with training for employees)
2. Update availability only when user attempts to add case (like Amazon)
3. Refresh data upon server request when entering a case
4. Automatic refresh with idle timeout (if screen idle for more than 5 minutes)
5. Cases should "fall off the list" when selected (speaker's preference: "I was hoping that when a case is picked, it should just fall off for others")

**Deferred to experts:** Sam and Santosh to provide input on security and performance feasibility

### Issue 3: Database Conflict
When a case is picked, "the database is going to fight who's going to get it" - needs resolution mechanism

---

## Dropdown Filter Specifications

### Purpose
Acts as a filtering mechanism on the table with **37 priority options**

### Sample Options Mentioned
- Priority 99H
- I NEF egregious
- 941 MD high
- High B listed
- MD (mentioned as "just in mind")
- Million dollar (K China)
- Medium priority

### Design Requirements
- Medium priority should be at the bottom of the list (least likely to be selected)
- Speaker would "almost rather hide it behind a scrolly bar"
- **Dropdown should look the same in mod, SIP, and national queues**

---

## Additional Technical Details

### QPIC Indicator
- Speaker suggests turning off the "S" thing in the national queue
- Cases should fall off the list if selected

### Source, Screw Indicator, and Cute Pic
- Speaker is working on these elements
- Some components were built in early 2023; much has changed since then
- Updates needed to reflect current requirements

### Case Selection Process
- User must select the case in ICS, not in entity
- System should show the entire mix of available cases (queue and hold file combined)
- Separating queue and hold file indicates a different action

### Detail Screen
- When you go deeper into a case (e.g., picked the Switzerland case)
- Shows additional information beyond the main table view

---

## Program Types and Scope

- **General program** = Domestic program (not yet fully implemented for national queue)
- **International program** (hasn't been done yet for national queue)
- Speaker will fix these distinctions

---

## Next Steps and Timeline

### Immediate Actions
1. **Speaker's commitments:**
   - Get mockups "in tip-top shape" before needed
   - Write up requirements today
   - Update requirements in SharePoint
   - Add requirements to mockups for Sara's reference
   - Send notes by end of week

2. **Team focus:**
   - Get tables ready
   - Wait for written requirements by end of week

### Tomorrow's Session
- Review mockups of features/capabilities discussed in the past two weeks
- Show updates to previous mockups

### Sara's Action Item
- Send screenshot of the most recent Mind with the national queue tab
- Speaker will use this for design purposes
- Speaker wants to annotate with circles: "This does this, and then circle something else and I'll be like that does that"

### End of Week Deliverable
- Written requirements for the national queue
- Speaker prefers to provide requirements "so that Sarah knows what is ultimately important"

---

## Key Quotes

- **On staffing crisis:** "Right now we're down to 1,300, 1,300. And so we don't have enough people to work the whole country. We just don't."

- **On scope:** "Everybody, everywhere is gonna be able to see everything in the whole dial."

- **On layout importance:** "You have to follow these guides that we have here. You absolutely have to. This is the layout you should see in case assignment with absolute certainty."

- **On priority:** "The Internal Revenue Manual says a revenue officer manager has to select the highest priority cases first."

- **On case falling off:** "I was hoping that when a case is picked, it should just fall off for others."
