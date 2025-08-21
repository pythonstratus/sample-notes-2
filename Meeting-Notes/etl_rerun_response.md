Hi Santosh,

Thanks for bringing up the ETL re-run capability during today's meeting. You're absolutely right that we should be able to re-run Weeklies and Dailies for any previous date. Here's a comprehensive guide on how to handle this:

**Prerequisites:**
- Ensure clean related data in the logload table before starting
- Verify system resources and dependencies are available
- Confirm target dates and scope of re-run with stakeholders

**Weekly Re-run Process:**

1. **Restore EntityDev Tables**
   ```
   JOB_NAME = restorefromsnapshotwithdate
   JOB_DATE = [target_date]
   ```
   This restores the EntityDev tables from the weekly pre-snapshot to your specified target date.

2. **Execute Weekly Processing**
   ```
   JOB_NAME = weekly
   JOB_DATE = [target_date]
   ```
   This runs the weekly ETL process for the target date.

**Daily Re-run Process:**

1. **Restore from Post-Snapshot**
   ```
   JOB_NAME = restorefrompostsnapshotwithdate
   JOB_DATE = [target_date]
   ```
   This restores EntityDev tables from the weekly post-snapshot, ensuring the starting point matches the weekly data state. Make sure the target date aligns with or falls after the weekly snapshot date.

2. **Execute Daily Processing**
   ```
   JOB_NAME = daily
   JOB_DATE = [target_date]
   ```
   This runs the daily ETL process for the target date.

**Additional Considerations:**
- **Data Validation:** Verify data integrity and completeness after each step
- **Monitoring:** Check job logs and status throughout the process
- **Dependencies:** Notify downstream systems about the re-run
- **Rollback Plan:** Have a rollback strategy ready in case issues arise

**Example Scenario:**
If you're re-running for Monday after resetting EntityDev tables to Sunday night, you would restore the weekly snapshot to Monday state, run the weekly job for Monday, then run daily jobs for Tuesday, Wednesday, and today to get current results that match Legacy.

Let me know if you need clarification on any of these steps or if you have specific dates you'd like to process.

Best regards,
Diane