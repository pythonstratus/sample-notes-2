# Manage Layout Feature - Developer Guide Summary

## Overview
The Manage Layout feature enables IRS users to customize data views across five view types: **Case, Modules, Activity, Time, and Employee**. Users can create, modify, save, and delete custom layouts that determine which columns appear in their views.

## Current Status
- **Original Estimate**: 300 hours
- **Target**: 50 hours (aggressive optimization needed)
- **Priority**: High - originally scheduled for completion in November, now carrying over to next sprint with 56+ stories

## Core Functionality

### 1. **Layout Types**
- **Pre-built Layouts** (provided by National HQ): Queue, Open, Default, Close, Statistical Report, AO Reports, AO Split Reports, RO Reports
- **Custom Layouts**: User-created layouts with personalized field selections and ordering

### 2. **Main User Interface Components**

#### Navigation Structure
- **Tab-based interface** with sections for:
  - Case Managed Layout
  - Modules
  - Activity  
  - Time
  - Employee
- **Search bar** for finding layouts by keyword
- **Create New Layout button** (right-aligned)

#### Layout Editor Modal
When clicking on any layout entry, a modal opens with:

**Left Panel - Available Fields:**
- Search bar for filtering available fields
- List of all available columns for that view type
- "Select All" option

**Right Panel - Selected Fields:**
- Display of currently selected columns
- Reorder controls (up/down arrows)
- "Remove All" option

**Control Buttons:**
- **Add field** (right arrow): Move from available to selected
- **Remove field** (left arrow): Move from selected back to available
- **Up/Down arrows**: Reorder selected fields

#### Action Buttons (Priority Order)
1. **Display** - Opens new tab showing data with selected columns
2. **Update** - Saves changes to existing layout
3. **Save As** - Creates new layout based on current configuration
4. **Cancel/Discard** - Abandons changes
5. **Reset Layout** - Returns to last saved state
6. **Delete Layout** - Permanently removes layout (with confirmation prompt)

### 3. **Save As Functionality**

When saving a new layout:
- **Auto-generated name format**: `new_[YYYY-MM-DD]_[original_layout_name]`
  - Example: `new_2024-11-26_closed_case_view`
- **Visibility Options**:
  - **Public**: Visible to entire group/organization
  - **Private**: Visible only to creator
- User can modify the suggested name before saving

### 4. **Display Functionality**
- When clicking "Display", system opens a **new tab**
- Tab shows data table with only the selected columns
- Column order matches the order defined in Selected Fields
- Data comes from current view context (Case View, Module View, etc.)

## Technical Architecture

### Frontend (React)
- Component-based UI with modal dialogs
- Drag-and-drop or arrow-based reordering
- Field selection using dual-list pattern
- Tab navigation for different view types
- Real-time search/filter on available fields

### Backend Services
- **Endpoints needed** for each view type (Case, Modules, Activity, Time, Employee)
- Service calls to retrieve available fields/columns
- Save/Update/Delete operations for custom layouts
- Query endpoints for displaying selected data

### Data Structure
- Fields are database columns
- Need SQL queries or metadata for available fields
- Excel sheet with all fields for all views (descriptions included)
- Currently uses React "add field" approach rather than direct SQL

### Roles & Permissions
- Public/Private visibility control
- Need to implement role-based access for public layouts
- Group/Organization-level sharing for public layouts

## Key Implementation Notes

### Must Replicate Across All 5 View Types
Each view type needs identical functionality:
1. Case View
2. Modules View  
3. Activity View
4. Time View
5. Employee View

### Critical User Flows

**Creating New Layout:**
1. Click "Create New Layout" button
2. Modal opens with all available fields
3. Search and select desired fields
4. Reorder as needed
5. Click "Save As"
6. Enter name and select Public/Private
7. Layout appears in saved layouts list

**Editing Existing Layout:**
1. Click on layout entry from list
2. Modal opens with current field selection
3. Add/remove/reorder fields
4. Click "Update" to save changes
5. Or click "Save As" to create variation

**Viewing Data:**
1. Select layout from list or create/edit one
2. Click "Display" button
3. New tab opens showing data table
4. Only selected columns appear in defined order

## Screenshots Needed for Developer Guide

To create the Word document, include screenshots of:

1. **Main Layout Management Screen** (showing tabs and Create button)
2. **Layout List View** (showing existing saved layouts)
3. **Edit Layout Modal - Overview** (full modal view)
4. **Available Fields Panel** (left side with search)
5. **Selected Fields Panel** (right side with reorder controls)
6. **Action Buttons** (Display, Update, Save As, etc.)
7. **Save As Dialog** (name input and Public/Private options)
8. **Delete Confirmation Dialog**
9. **Display Result** (new tab with data table)
10. **Pre-built Layouts Dropdown** (showing Queue, Open, Default, etc.)

## Development Priorities

### High Priority (Core 50-hour target):
- Layout CRUD operations (Create, Read, Update, Delete)
- Field selection and reordering UI
- Display functionality (new tab with data)
- Search/filter for available fields

### Medium Priority:
- Public/Private visibility controls
- Role-based permissions
- Search bar for finding layouts

### Lower Priority (may defer):
- Advanced UI polish
- Additional validation
- Complex permission scenarios

## Open Questions/Decisions Needed

1. **BOE Integration**: Team discussed using SAP Business Objects Enterprise (BOE) SDK for reporting, but decided to table this for now and focus on in-system viewing
2. **Data Source**: Confirm exact table structure and SQL queries for available fields
3. **Roles & Permissions**: Implementation approach for Public/Private layouts needs refinement

---

**Next Steps:**
1. Prepare comprehensive developer guide document with screenshots
2. Work with Paul on rapid development approach
3. Focus on Case View first, then replicate to other view types
4. Target completion within next sprint despite aggressive timeline

Would you like me to help you create the actual Word document with this structure? I can use the computer tools to create a properly formatted document that you can then add screenshots to.
