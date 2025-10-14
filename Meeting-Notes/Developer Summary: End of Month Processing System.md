# Developer Summary: End of Month Processing System

## Context
This is a Java/React application for IRS time tracking end-of-month processing. The system has two levels: **Group** (most users) and **Area** (6-7 IQAs nationwide who oversee multiple groups).

## Key Technical Requirements

### Group End of Month Page

**Input Validation:**
- Search field limited to 6-digit group numbers only
- Use input masking/validation on the React frontend

**Weekly Verification Flow:**
The critical UX requirement is forcing users to review each week sequentially before completion:

1. Display weeks 1-5 as clickable links (not checkboxes)
2. When a week is clicked, display that week's data table on the right side
3. "Complete Weekly Time Verification" button stays disabled/grayed until ALL weeks have been viewed
4. "Approve & Next" button per week - clicking it:
   - Automatically marks that week as reviewed (no manual checkbox)
   - Advances to next week
5. After all weeks approved, show "Generate End of Month" and "Approve End of Month" buttons

**Layout:**
- Left side: Week selection and end-of-month controls (primary interaction area)
- Right side: Time verification table display

### Critical Data Persistence Issue ⚠️

**Sara's Constraint:** "The information cannot be stored"

**What needs tracking:**
- Which weeks the user has clicked through/reviewed (for UI state management)
- Weekly time verification completion status (this IS currently stored)

**Proposed Solutions for Developer:**

**Option 1: Session-Based State (Recommended)**
```java
// Backend: Store state in HTTP session during active workflow
@SessionScope
public class EndOfMonthSession {
    private Set<Integer> reviewedWeeks;
    private String groupNumber;
    // Expires when user completes or abandons process
}
```

**Option 2: React State Management**
```javascript
// Frontend: Keep reviewed weeks in component state
// No backend persistence needed during workflow
const [reviewedWeeks, setReviewedWeeks] = useState(new Set());
const [currentWeek, setCurrentWeek] = useState(1);
```

**Option 3: Temporary Database Table**
```sql
-- Temporary workflow tracking (cleared after completion)
CREATE TABLE eom_workflow_state (
    user_id VARCHAR,
    group_number VARCHAR(6),
    reviewed_weeks JSON,
    created_timestamp TIMESTAMP,
    -- Auto-delete after 24 hours or on completion
);
```

Since only the **completion** of weekly verification is historically recorded (not the click-through process), I recommend **Option 2** (React state) for the "which weeks have been viewed" tracking during the active session. This data doesn't need persistence—it's just workflow enforcement.

### Report Generation

**Generate End of Month:**
- Creates 2 reports (hours + weekly)
- Downloads immediately

**Approve End of Month:**
- Creates 4 additional reports (6 total)
- Shows confirmation message
- **Exception to non-persistence rule:** These approved reports ARE stored permanently and must remain unchanged even if underlying data changes

### Area End of Month (IQA Only)

**Validation Flow:**
1. Area number: 2-digit input validation
2. Display all groups in area with completion status:
   - Complete: Normal display
   - Incomplete: Red text with asterisk (*)
3. "Select All" button disabled if ANY group incomplete
4. After approval: "Approve" button changes to "Undo"
5. Undoing area approval allows managers to make corrections

### Data Model Considerations

**Historical Reporting:**
- End of month reports are immutable snapshots
- Must be retrievable years later in original state
- If time corrections occur, new EOM overwrites old (not typical versioning)
- No purging requirement—keep indefinitely

**API Design Suggestion:**
```java
// Snapshot pattern
@Entity
public class EndOfMonthReport {
    @Id
    private String reportId;
    private String groupNumber;
    private LocalDate reportMonth;
    private byte[] reportData; // Frozen snapshot
    private LocalDateTime approvedTimestamp;
    private boolean isAreaApproved;
    // Immutable after approval
}
```

## Questions for Sara/Santosh:

1. **Clarify the "cannot be stored" constraint:** Does this mean:
   - A) No database writes during the workflow (use session/React state)?
   - B) No historical record of the review process (only store final approval)?
   - C) Something else?

2. **Week review tracking:** Should the system remember if a user partially completed the workflow and returns later, or reset each session?

3. **Report storage format:** Binary blobs, database rows, or file system storage?

Let me know if you need the second screenshot analyzed, or if you'd like me to generate React component examples or Java entity classes!
