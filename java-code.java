private void insertLogLoadRecord(String jobCode, String extractDate, int recordCount) {
    try {
        // Create a properly formatted date for Oracle
        // Oracle expects dates in a specific format, typically 'YYYY-MM-DD'
        // If extractDate is already in 'MMddyyyy' format, convert it to Oracle's expected format
        java.sql.Date sqlExtractDate;
        try {
            SimpleDateFormat inputFormat = new SimpleDateFormat("MMddyyyy");
            SimpleDateFormat oracleFormat = new SimpleDateFormat("yyyy-MM-dd");
            Date parsedDate = inputFormat.parse(extractDate);
            String formattedExtractDate = oracleFormat.format(parsedDate);
            sqlExtractDate = java.sql.Date.valueOf(formattedExtractDate);
        } catch (ParseException e) {
            // If parsing fails, use current date as fallback
            sqlExtractDate = new java.sql.Date(System.currentTimeMillis());
            log.warn("Failed to parse extract date: " + extractDate + ", using current date");
        }
        
        // Current date in SQL format
        java.sql.Date sqlLoadDate = new java.sql.Date(System.currentTimeMillis());
        
        // Get username
        String username = System.getProperty("user.name");
        if (username == null || username.isEmpty()) {
            username = "SYSTEM";
        }
        
        // SQL to insert a new record using proper date format for Oracle
        String sql = "INSERT INTO LOGLOAD (LOADNAME, EXTDT, LOADDT, UNIX, NUMREC) VALUES (?, ?, ?, ?, ?)";
        
        // Execute insert with properly formatted dates
        jdbcTemplate.update(sql, 
            jobCode, 
            sqlExtractDate,  // Use SQL Date object 
            sqlLoadDate,     // Use SQL Date object
            username, 
            recordCount);
            
        log.info("Successfully inserted LOGLOAD record for job " + jobCode + " with count " + recordCount);
        
    } catch (Exception e) {
        log.error("Error inserting LOGLOAD record for job " + jobCode + ": " + e.getMessage());
        e.printStackTrace();
    }
}
