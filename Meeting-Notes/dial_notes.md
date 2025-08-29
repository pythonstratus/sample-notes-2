# Master Email Notes - DIAL Job Scheduling

## Email Recipients
- **Primary:** Diane, Samuel
- **CC:** Team members as appropriate

## Email Subject
DIAL Job Scheduling Updates and Questions

## Key Message Points

### Current Technical Status
- DIAL running as Spring Boot web application on embedded Tomcat (not batch jobs)
- Cannot configure as proper cron jobs - jobs don't terminate
- End-to-end process needs splitting into separate batch jobs
- Spring Boot 3.1 upgrade planned for proper job configuration
- JDBC driver updated (8 → 10) for Unix compatibility

### Critical Questions Requiring Input

1. **Job Timing & Dependencies**
   - Reason for specific intervals (6-min gap between dial 2 at 2:40, dial 3 at 2:46)?
   - Are gaps due to expected long runtimes/delays?
   - Database concurrency concerns during processing

2. **Job Sequencing Approach**
   - Sequential jobs in one container vs. separate containers with time-based scheduling
   - Maintenance considerations for multiple containers

3. **Weekend Processing Timeline**
   - Friday cutoff → Saturday/Sunday processing → Monday data access
   - Backup timing for dining tables (Saturday before Sunday weeklies)
   - Impact on other apps (ALS RPT, dial rpt, entity) accessing data
   - Synonym switching strategy during data refresh

4. **Deployment Strategy**
   - End goal: continuous running vs. complete work and terminate?

### Technical Details to Include
- Nine-step process needs separation into individual batch jobs
- File dependencies between jobs (read → merge → write → database operations)
- Data access patterns and synonym management
- Transform project took 20-30 minutes per job (330k taxpayer records reference)

### Next Steps Pending Confirmation
- Remove embedded Tomcat configuration
- Split process into separate batch jobs
- Implement proper cron job structure
- Job dependency management

### Supporting Documents
- Include link to existing DIAL job schedule
- Reference Ranjitha's diet process document
- Mention DIAL programmer guide found in SharePoint

## Email Tone & Approach
- Professional, technical focus
- Seeking confirmation before proceeding with changes
- Emphasize need for their input on approach decisions
- Include technical context but keep business impact clear

## Follow-up Actions
- Wait for Diane/Samuel confirmation before Ganga proceeds
- Schedule follow-up meeting if needed for complex items
- Document decisions for implementation team
