I'll implement Option 2 by creating a getRecordCountForJob method. You should add this method to your DailyJobRunner class (or WeeklyJobRunner for weekly jobs) since it needs access to jdbcTemplate to execute the query.

Here's the implementation of the getRecordCountForJob method:

```java
/**
 * Gets the record count for a specific job by querying the appropriate table
 * 
 * @param jobCode the job code (e.g., "E5", "E3", etc.)
 * @return the record count for the job, or 0 if it couldn't be determined
 */
private int getRecordCountForJob(String jobCode) {
    try {
        // Determine which table to query based on job code
        String tableName = getTableNameForJobCode(jobCode);
        if (tableName == null || tableName.isEmpty()) {
            log.warning("Could not determine table name for job code: " + jobCode);
            return 0;
        }
        
        // Execute a count query on the appropriate table
        String sql = "SELECT COUNT(*) FROM " + tableName;
        Integer count = jdbcTemplate.queryForObject(sql, Integer.class);
        
        return count != null ? count : 0;
    } catch (Exception e) {
        log.warning("Error getting record count for job " + jobCode + ": " + e.getMessage());
        // Return a default value in case of error
        return 0;
    }
}

/**
 * Maps job codes to their primary table names for counting records
 * 
 * @param jobCode the job code
 * @return the name of the table to query for record count
 */
private String getTableNameForJobCode(String jobCode) {
    switch (jobCode) {
        case "E5":
            return "E5_RECORDS";
        case "E3":
            return "E3_RECORDS";
        case "E8":
            return "E8_RECORDS";
        case "E7":
            return "E7_RECORDS";
        case "EB":
            return "EB_RECORDS";
        // Add cases for weekly jobs if needed
        case "S1":
            return "S1_RECORDS";
        case "E1":
            return "E1_RECORDS";
        case "E2":
            return "E2_RECORDS";
        case "E4":
            return "E4_RECORDS";
        case "EA":
            return "EA_RECORDS";
        case "E9":
            return "E9_RECORDS";
        default:
            log.warning("Unknown job code: " + jobCode);
            return "";
    }
}
```

Then, update your job execution code in DailyJobRunner to use this method:

```java
case "E5":
    CompletableFuture<Void> e5Future = CompletableFuture.runAsync(() -> {
        try {
            log.info("Executing E5 job...");
            batchRunJobService.runE5Job();
            
            // Get record count after job execution
            int recordCount = getRecordCountForJob(jobCode);
            
            // Log job execution to LOGLOAD table
            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
        } catch (Exception e) {
            log.severe("Error executing E5 job: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("E5 job execution failed", e);
        }
    });
    e5Future.join(); // Wait for completion
    break;
```

You'll need to replace the table names in the getTableNameForJobCode method with your actual table names where records are stored for each job. The method I've provided assumes table names like E5_RECORDS, E3_RECORDS, etc., but you'll need to use the actual table names from your database schema.

This approach has several advantages:
1. It doesn't require modifying the BatchRunJobService
2. It gets the actual record count from the database
3. It's resilient to errors (returns 0 if counting fails)
4. It's easy to maintain if you add more job types

Let me know if you need any adjustments to this implementation!
