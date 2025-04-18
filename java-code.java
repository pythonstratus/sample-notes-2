// Add this field to your DailyIntegrationTest class
@Autowired
private JdbcTemplate jdbcTemplate;

// Add this method to your test class
private void insertLogLoadRecord(String jobCode, String extractDate, int recordCount) {
    try {
        // Format current date as MMddyyyy for LOADDT
        String currentDate = new SimpleDateFormat("MMddyyyy").format(new Date());
        
        // Get current username for UNIX field
        String username = System.getProperty("user.name");
        if (username == null || username.isEmpty()) {
            username = "SYSTEM";
        }
        
        // SQL to insert a new record
        String sql = "INSERT INTO LOGLOAD (LOADNAME, EXTDT, LOADDT, UNIX, NUMREC) VALUES (?, ?, ?, ?, ?)";
        
        // Execute insert
        jdbcTemplate.update(sql, 
            jobCode, 
            extractDate, 
            currentDate, 
            username, 
            recordCount);
            
        // Log the successful insert
        log.info("Successfully inserted LOGLOAD record for job " + jobCode + " with count " + recordCount);
        
    } catch (Exception e) {
        log.error("Error inserting LOGLOAD record for job " + jobCode + ": " + e.getMessage());
        e.printStackTrace();
    }
}


case "E5":
    CompletableFuture<Void> e5Future = CompletableFuture.runAsync(() -> {
        try {
            batchRunJobService.runE5Job();
            
            // Query E5-specific tables to get record count
            Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM ENTEMP", Integer.class);
            
            // Insert record using our custom method
            insertLogLoadRecord("E5", priorSnapshotDate, recordCount != null ? recordCount : 0);
            
        } catch (Exception e) {
            log.warn("Error executing E5 job: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("E5 job execution failed", e);
        }
    });
    e5Future.join();
    break;
