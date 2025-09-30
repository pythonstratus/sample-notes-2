# Leadership Call Summary - September 30, 2025

## Critical Issues

**Case Assignment Table Loading Problem**
- Case assignment group summary table failing to load on entity dev (Santosh's environment)
- Data exists but experiencing significant delays; detail tables also affected
- Brian confirmed issue unrelated to his recent work; suspects cache initialization problem
- **Action:** Meeting scheduled with Ravi and Bryan Abbe at 12:00 PM to investigate

**New ETL Repository Deployment**
- New repository operational; previous one decommissioned
- Pipeline created but blocked awaiting Nexus deployment token from CI/CD
- **Expected resolution:** Within next hour

## Work In Progress

**SIA Code Review Improvements**
- Implementing SQL injection security fixes (parameterization) - **ETA: 2 days**
- Removing SIA folder structure from root - **ETA: Thursday EOD**
- Daily progress updates being provided to Eddie
- Production testing preparation scheduled for tomorrow

**Sia Jobs Documentation**
- Documentation of testing procedures underway
- First extract near completion, pending Kamal's verification

**Data Validation & Testing - DIAL**
- Data loaded and ready for area-wise validation testing
- Must run on ECP (not locally) - local testing took 3 hours
- Legacy system comparison: new system significantly faster (hours vs. legacy's 13 days for all areas)
- Minor issue: DIALAUD temp table currently empty, but workaround identified

**Thomas's Update**
Completed Work:

Reviewed case 7-1s (ticket #175090) - discovered Brian had already fixed the "fixed square tabs" issue last week
Added reports folder functionality

Current Work:

Fixing zip code ticket issue identified during code review

Next Steps:

Plans to move on to case view fixes mentioned by Sarah
Expects these fixes won't take much time

Status: No blockers
**Paul's Update**
Completed Work:

Wrote CPR for story #1750481 to implement Prime React Table in check group lab table (submitted to Brian for review)
Raised PR for updating code in new DAO report based on "gonna last Jed" (currently under review)

Current Work:

Starting work today on story #17504-821-700483 to update page layout

Collaboration:

Received two stored procedures from Ganga, which he implemented and reviewed

Status: No blockers

## Team Updates

- Bug fixes and code reviews progressing on schedule
- Prime React Table implementation PR submitted for review
- Query results backend work completed; no anticipated blockers
- **Reminder:** Training completion required to avoid potential shutdown

## Pending Decisions

- Job status page naming conventions need business validation - will discuss at 11 AM call and potentially at next demo/deployment session

**No critical blockers reported across teams.**
