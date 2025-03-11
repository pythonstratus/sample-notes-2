import java.io.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

/**
 * ProcessE5Entity - Java implementation of the c.procE5 script
 * This class handles the loading and processing of E5 entity data
 */
public class ProcessE5Entity implements EntityProcessor {
    
    private String loadDir;      // Load directory where data files are located
    private String logDir;       // Log directory
    private String dbPassword;   // Database password
    private String jdbcUrl;      // JDBC connection URL
    private String dbUser;       // Database username (als)
    private String e5OutFile;    // E5 output file path
    private String e5BadFile;    // E5 bad records file path
    private String e5LogFile;    // E5 load log file path
    private String e5DatFile;    // E5 data file to load

    /**
     * Constructor for the E5 processing class
     * 
     * @param loadDir Directory containing the data files
     * @param logDir Directory for log files
     * @param dbUser Database username
     * @param dbPassword Database password
     * @param jdbcUrl JDBC URL for database connection
     */
    public ProcessE5Entity(String loadDir, String logDir, String dbUser, String dbPassword, String jdbcUrl) {
        this.loadDir = loadDir;
        this.logDir = logDir;
        this.dbUser = dbUser;
        this.dbPassword = dbPassword;
        this.jdbcUrl = jdbcUrl;
        
        // Set file paths
        this.e5OutFile = loadDir + "/E5.out";
        this.e5BadFile = loadDir + "/E5.bad";
        this.e5LogFile = loadDir + "/loadE5.log";
        this.e5DatFile = loadDir + "/E5.dat";
    }
    
    /**
     * Get the entity code
     * 
     * @return the entity code (E5)
     */
    @Override
    public String getEntityCode() {
        return "E5";
    }
    
    /**
     * Get the output file path
     * 
     * @return the path to the output file
     */
    @Override
    public String getOutputFilePath() {
        return e5OutFile;
    }
    
    /**
     * Process the E5 entity extract
     * 
     * @return true if processing was successful, false otherwise
     */
    @Override
    public boolean process() throws Exception {
        try {
            // Start logging
            writeToFile(e5OutFile, "Begin process E5..........." + getCurrentDateTime() + "\n\n");
            
            // First, use JDBC to directly load data using prepared statements
            // This replaces the SQL*Loader operation from the shell script
            boolean loadSuccess = loadE5DataFile();
            if (!loadSuccess) {
                writeToFile(e5OutFile, "ERROR: Failed to load E5 data\n");
                return false;
            }
            
            // Check for bad records in E5.bad file
            int badRecords = checkForBadRecords();
            if (badRecords > 0) {
                writeToFile(e5OutFile, "ERROR: E5 sqldr - " + badRecords + " records in E5.bad\n");
                return false;
            }
            
            // Run the SQL operations
            boolean sqlSuccess = executeE5SqlOperations();
            if (!sqlSuccess) {
                writeToFile(e5OutFile, "ERROR: SQL operations failed\n");
                return false;
            }
            
            // Create LOGLOAD record
            boolean logSuccess = createLogloadRecord();
            if (!logSuccess) {
                writeToFile(e5OutFile, "ERROR: Failed to create LOGLOAD record\n");
                return false;
            }
            
            // Complete processing
            writeToFile(e5OutFile, "End process E5..........." + getCurrentDateTime() + "\n");
            writeToFile(e5OutFile, "PROCESS COMPLETE\n");
            
            return true;
        } catch (Exception e) {
            try {
                writeToFile(e5OutFile, "ERROR: Exception in E5 processing: " + e.getMessage() + "\n");
                e.printStackTrace();
            } catch (IOException ioe) {
                // Can't even write to output file
                System.err.println("Error writing to output file: " + ioe.getMessage());
            }
            return false;
        }
    }
    
    /**
     * Load E5 data file into the E5TMP table
     * This replaces the SQL*Loader operation from the shell script
     */
    private boolean loadE5DataFile() throws SQLException, IOException {
        Connection conn = null;
        PreparedStatement truncateStmt = null;
        
        try {
            // Connect to database
            conn = DriverManager.getConnection(jdbcUrl, dbUser, dbPassword);
            
            // First truncate the E5TMP table
            writeToFile(e5OutFile, "Truncate E5TMP Table\n");
            truncateStmt = conn.prepareStatement("TRUNCATE TABLE E5TMP");
            truncateStmt.executeUpdate();
            
            // Now load the data - this is a direct replacement for SQL*Loader functionality
            // We'll use a custom function to read fixed-width data from E5.dat and insert into E5TMP
            List<E5Record> records = parseE5DataFile(e5DatFile);
            
            // Prepare the insert statement
            String insertSql = "INSERT INTO E5TMP (OUTPUTCD, EMPASGMTNUM, EMPNAME, EMPGRADECD, EMPTYPECD, " +
                              "TOUROFDUTY, EMPWORKAREA, TPSPODIND, CSUPODIND, PARAPODIND, MNGRPODIND, " +
                              "EMPPOSITTYPECD, FLEXPLACEIND, EMPUPDATEDT, ENTEXTRACTDT, EMPIDNUM, " +
                              "EMPTITLE, AREACD, PHONE, EXT, PREVID, SEID, EMAIL, ICSACC, EMPPODCD, " +
                              "GS9CNT, GS11CNT, GS12CNT, GS13CNT) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " +
                              "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
            
            PreparedStatement ps = conn.prepareStatement(insertSql);
            
            // Set auto-commit to false for batch processing
            conn.setAutoCommit(false);
            
            int batchSize = 0;
            int totalRecords = 0;
            
            // Process each record
            for (E5Record record : records) {
                ps.setString(1, record.outputcd);
                ps.setInt(2, record.empasgmtnum);
                ps.setString(3, record.empname);
                ps.setString(4, record.empgradecd);
                ps.setString(5, record.emptypecd);
                ps.setString(6, record.tourofduty);
                ps.setString(7, record.empworkarea);
                ps.setString(8, record.tpspodind);
                ps.setString(9, record.csupodind);
                ps.setString(10, record.parapodind);
                ps.setString(11, record.mngrpodind);
                ps.setString(12, record.empposittypecd);
                ps.setString(13, record.flexplaceind);
                ps.setDate(14, new java.sql.Date(record.empupdatedt.getTime()));
                ps.setDate(15, new java.sql.Date(record.entextractdt.getTime()));
                ps.setString(16, record.empidnum);
                ps.setString(17, record.emptitle);
                ps.setInt(18, record.areacd);
                ps.setInt(19, record.phone);
                ps.setInt(20, record.ext);
                ps.setInt(21, record.previd);
                ps.setString(22, record.seid);
                ps.setString(23, record.email);
                ps.setString(24, record.icsacc);
                ps.setString(25, record.emppodcd);
                ps.setInt(26, record.gs9cnt);
                ps.setInt(27, record.gs11cnt);
                ps.setInt(28, record.gs12cnt);
                ps.setInt(29, record.gs13cnt);
                
                ps.addBatch();
                batchSize++;
                totalRecords++;
                
                // Execute batch at specified size
                if (batchSize >= 1000) {
                    ps.executeBatch();
                    conn.commit();
                    batchSize = 0;
                }
            }
            
            // Execute remaining batch
            if (batchSize > 0) {
                ps.executeBatch();
                conn.commit();
            }
            
            // Create E5.bad file (empty) to indicate successful processing
            new File(e5BadFile).createNewFile();
            
            writeToFile(e5OutFile, "Loaded " + totalRecords + " records into E5TMP table\n");
            
            return true;
        } finally {
            if (truncateStmt != null) try { truncateStmt.close(); } catch (Exception e) { /* ignore */ }
            if (conn != null) try { conn.close(); } catch (Exception e) { /* ignore */ }
        }
    }
    
    /**
     * Parse the E5 data file according to the loadE5.ctl fixed-width specifications
     */
    private List<E5Record> parseE5DataFile(String filePath) throws IOException {
        List<E5Record> records = new ArrayList<>();
        
        try (BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.length() < 206) {
                    // Log warning about invalid line length but continue processing
                    writeToFile(e5OutFile, "WARNING: Invalid line length in E5 data file: " + line.length() + "\n");
                    continue;
                }
                
                // Create a new record from the fixed-width line
                E5Record record = new E5Record();
                
                // Parse each field from the fixed-width format
                // This follows the positions defined in loadE5.ctl
                record.outpucd = line.substring(0, 2).trim();
                record.empasgmtnum = parseIntOrDefault(line.substring(2, 10).trim(), 0);
                record.empname = line.substring(10, 45).trim();
                record.empgradecd = line.substring(45, 47).trim();
                record.emptypecd = line.substring(47, 48).trim();
                record.tourofduty = line.substring(48, 49).trim();
                record.empworkarea = line.substring(49, 50).trim();
                record.tpspodind = line.substring(50, 51).trim();
                record.csupodind = line.substring(51, 52).trim();
                record.parapodind = line.substring(52, 53).trim();
                record.mngrpodind = line.substring(53, 54).trim();
                record.empposittypecd = line.substring(54, 55).trim();
                record.flexplaceind = line.substring(55, 56).trim();
                
                // Parse dates with special handling for "00000000" values
                String empUpdateDtStr = line.substring(56, 64).trim();
                if (empUpdateDtStr.equals("00000000")) {
                    empUpdateDtStr = "19000101";
                }
                record.empupdatedt = parseDate(empUpdateDtStr, "yyyyMMdd");
                
                String extractDtStr = line.substring(64, 72).trim();
                if (extractDtStr.equals("00000000")) {
                    extractDtStr = "19000101";
                }
                record.entextractdt = parseDate(extractDtStr, "yyyyMMdd");
                
                record.empidnum = line.substring(72, 82).trim();
                record.emptitle = line.substring(82, 107).trim();
                record.areacd = parseIntOrDefault(line.substring(107, 110).trim(), 0);
                record.phone = parseIntOrDefault(line.substring(110, 117).trim(), 0);
                record.ext = parseIntOrDefault(line.substring(117, 124).trim(), 0);
                record.previd = parseIntOrDefault(line.substring(124, 132).trim(), 0);
                record.seid = line.substring(132, 137).trim();
                record.email = line.substring(141, 186).trim();
                record.icsacc = line.substring(186, 187).trim();
                record.emppodcd = line.substring(187, 190).trim();
                record.gs9cnt = parseIntOrDefault(line.substring(190, 194).trim(), 0);
                record.gs11cnt = parseIntOrDefault(line.substring(194, 198).trim(), 0);
                record.gs12cnt = parseIntOrDefault(line.substring(198, 202).trim(), 0);
                record.gs13cnt = parseIntOrDefault(line.substring(202, 206).trim(), 0);
                
                records.add(record);
            }
        }
        
        return records;
    }
    
    /**
     * Utility method to parse an integer with a default value
     */
    private int parseIntOrDefault(String str, int defaultValue) {
        try {
            return Integer.parseInt(str);
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }
    
    /**
     * Utility method to parse a date from a string
     */
    private java.util.Date parseDate(String dateStr, String format) {
        try {
            java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat(format);
            return sdf.parse(dateStr);
        } catch (Exception e) {
            // Return epoch date as default
            return new java.util.Date(0);
        }
    }
    
    /**
     * Check for bad records in the E5.bad file
     * 
     * @return number of bad records found
     */
    private int checkForBadRecords() throws IOException {
        File badFile = new File(e5BadFile);
        if (!badFile.exists() || badFile.length() == 0) {
            return 0;
        }
        
        // Count lines in the bad file to determine number of bad records
        int lineCount = 0;
        try (BufferedReader reader = new BufferedReader(new FileReader(badFile))) {
            while (reader.readLine() != null) {
                lineCount++;
            }
        }
        
        return lineCount;
    }
    
    /**
     * Execute SQL operations needed for E5 processing
     */
    private boolean executeE5SqlOperations() throws SQLException, IOException {
        Connection conn = null;
        Statement stmt = null;
        
        try {
            // Connect to database
            conn = DriverManager.getConnection(jdbcUrl, dbUser, dbPassword);
            stmt = conn.createStatement();
            
            // Set NLS date format for consistency
            writeToFile(e5OutFile, "Setting NLS_DATE_FORMAT\n");
            stmt.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'MM/DD/YYYY HH24:MI:SS'");
            
            // Count before delete
            writeToFile(e5OutFile, "Count Before Delete EMPASGMTNUM From E5TMP Table\n");
            ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM E5TMP");
            if (rs.next()) {
                writeToFile(e5OutFile, "Count before: " + rs.getInt(1) + "\n");
            }
            rs.close();
            
            // Delete null empasgmtnum records
            writeToFile(e5OutFile, "Deleting EMPASGMTNUM from E5TMP Table\n");
            int deletedRows = stmt.executeUpdate("DELETE FROM E5TMP WHERE empasgmtnum IS NULL");
            writeToFile(e5OutFile, "Deleted " + deletedRows + " rows with NULL empasgmtnum\n");
            
            // Update empidnum
            writeToFile(e5OutFile, "Updating EMPIDNUM in E5TMP Table\n");
            int updatedRows = stmt.executeUpdate("UPDATE E5TMP SET empidnum = '99-999999' WHERE empidnum = '-'");
            writeToFile(e5OutFile, "Updated " + updatedRows + " rows with '-' empidnum\n");
            
            // Count after delete
            writeToFile(e5OutFile, "Count After Delete EMPASGMTNUM From E5TMP Table\n");
            rs = stmt.executeQuery("SELECT COUNT(*) FROM E5TMP");
            if (rs.next()) {
                writeToFile(e5OutFile, "Count after: " + rs.getInt(1) + "\n");
            }
            rs.close();
            
            // Get current date-time
            rs = stmt.executeQuery("SELECT TO_CHAR(SYSDATE, 'MM/DD/YYYY - HH:MI:SS AM') \"Date-Time\" FROM DUAL");
            if (rs.next()) {
                writeToFile(e5OutFile, "Current date-time: " + rs.getString(1) + "\n");
            }
            rs.close();
            
            // Update EACTIVE in ENTEMP
            writeToFile(e5OutFile, "Updating EACTIVE in ENTEMP Table\n");
            updatedRows = stmt.executeUpdate("UPDATE ENTEMP SET EACTIVE = 'N' WHERE ROID not like '85%'");
            writeToFile(e5OutFile, "Updated " + updatedRows + " rows setting EACTIVE to 'N'\n");
            
            // Count before merge
            writeToFile(e5OutFile, "Count Before Merge Of ENTEMP Table\n");
            rs = stmt.executeQuery("SELECT COUNT(*) FROM ENTEMP");
            if (rs.next()) {
                writeToFile(e5OutFile, "Count before merge: " + rs.getInt(1) + "\n");
            }
            rs.close();
            
            // Execute merge operation
            // This is a complex operation that merges E5TMP data into ENTEMP
            writeToFile(e5OutFile, "Merging into ENTEMP Table\n");
            String mergeSql = 
                "MERGE INTO ENTEMP a " +
                "USING (SELECT * FROM ALS.E5TMP WHERE EMPASGMTNUM not like '85%') b " +
                "ON (a.ROID = b.EMPASGMTNUM and nvl(a.SEID,'00000')=nvl(b.SEID, '00000')) " +
                "WHEN MATCHED THEN " +
                "  UPDATE SET a.NAME=b.EMPNAME, a.GRADE=b.EMPGRADECD, a.TYPE=b.EMPTYPECD, " +
                "    a.BADGE=b.EMPIDNUM, a.TITLE=b.EMPTITLE, a.AREACD=b.AREACD, " +
                "    a.PHONE=b.PHONE, a.EXT=b.EXT, a.EMAIL=b.EMAIL, " +
                "    a.POSTYPE=b.EMPPOSITTYPECD, a.AREA=b.EMPWORKAREA, " +
                "    a.TOUR=b.TOUROFDUTY, a.PODIND=b.MNGRPODIND, " +
                "    a.TPSIND=b.TPSPODIND, a.CSUIND=b.CSUPODIND, " +
                "    a.AIDEIND=b.PARAPODIND, a.FLEXIND=b.FLEXPLACEIND, " +
                "    a.EMPDT=b.EMPUPDATEDT, a.PREVID=b.PREVID, " +
                "    a.ICSACC=b.ICSACC, a.EACTIVE='Y', a.EXTRDT=b.ENTEXTRACTDT, " +
                "    a.PODCD=b.EMPPODCD, a.GS9CNT=b.GS9CNT, a.GS11CNT=b.GS11CNT, " +
                "    a.GS12CNT=b.GS12CNT, a.GS13CNT=b.GS13CNT " +
                "WHEN NOT MATCHED THEN " +
                "  INSERT (ROID, NAME, GRADE, TYPE, " +
                "    BADGE, TITLE, AREACD, PHONE, EXT, SEID, " +
                "    EMAIL, POSTYPE, AREA, TOUR, " +
                "    PODIND, TPSIND, CSUIND, AIDEIND, " +
                "    FLEXIND, EMPDT, PREVID, ICSACC, " +
                "    EACTIVE, EXTRDT, PODCD, " +
                "    GS9CNT, GS11CNT, GS12CNT, GS13CNT) " +
                "  VALUES (b.EMPASGMTNUM, b.EMPNAME, b.EMPGRADECD, b.EMPTYPECD, " +
                "    b.EMPIDNUM, b.EMPTITLE, b.AREACD, b.PHONE, b.EXT, b.SEID, " +
                "    b.EMAIL, b.EMPPOSITTYPECD, b.EMPWORKAREA, b.TOUROFDUTY, " +
                "    b.MNGRPODIND, b.TPSPODIND, b.CSUPODIND, b.PARAPODIND, " +
                "    b.FLEXPLACEIND, b.EMPUPDATEDT, b.PREVID, b.ICSACC, " +
                "    'Y', b.ENTEXTRACTDT, b.EMPPODCD, " +
                "    b.GS9CNT, b.GS11CNT, b.GS12CNT, b.GS13CNT)";
                
            int mergedRows = stmt.executeUpdate(mergeSql);
            writeToFile(e5OutFile, "Merged " + mergedRows + " rows\n");
            
            // Count after merge
            writeToFile(e5OutFile, "Count After Merge Of ENTEMP Table\n");
            rs = stmt.executeQuery("SELECT COUNT(*) FROM ENTEMP");
            if (rs.next()) {
                writeToFile(e5OutFile, "Count after merge: " + rs.getInt(1) + "\n");
            }
            rs.close();
            
            // Update UNIX values in ENTEMP
            writeToFile(e5OutFile, "Updating UNIX in ENTEMP\n");
            String unixUpdateSql = 
                "UPDATE ENTEMP a " +
                "set a.unix = (SELECT b.unix " +
                "              FROM ENTEMP b " +
                "              WHERE a.seid = b.seid and " +
                "                    b.unix is not NULL and rownum = 1) " +
                "WHERE a.eactive in ('Y','A') and " +
                "      a.seid not in ('99999', '00000','44444') and " +
                "      a.seid is not NULL and " +
                "      a.unix is NULL";
                
            updatedRows = stmt.executeUpdate(unixUpdateSql);
            writeToFile(e5OutFile, "Updated " + updatedRows + " rows with UNIX values\n");
            
            // Update POSTYPE and ELEVEL
            writeToFile(e5OutFile, "Updating POSTYPE in ENTEMP Table\n");
            updatedRows = stmt.executeUpdate(
                "UPDATE ENTEMP set postype = 'B', elevel = -2 " +
                "WHERE eactive = 'N' and postype not in ('B','V')"
            );
            writeToFile(e5OutFile, "Updated " + updatedRows + " rows with POSTYPE and ELEVEL\n");
            
            // Update ELEVEL in ENTEMP
            writeToFile(e5OutFile, "Updating ELEVEL in ENTEMP Table\n");
            updatedRows = stmt.executeUpdate(
                "UPDATE ENTEMP set elevel = setelevel(icsacc,title,postype) " +
                "WHERE ROID not like '85%'"
            );
            writeToFile(e5OutFile, "Updated " + updatedRows + " rows with ELEVEL\n");
            
            // Update PRIMARY_ROID
            writeToFile(e5OutFile, "Updating PRIMARY_ROID in ENTEMP Table\n");
            updatedRows = stmt.executeUpdate(
                "UPDATE ENTEMP set PRIMARY_ROID = 'N' " +
                "WHERE PRIMARY_ROID is NULL"
            );
            writeToFile(e5OutFile, "Updated " + updatedRows + " rows with PRIMARY_ROID\n");
            
            // Execute EMP_ORG procedure
            writeToFile(e5OutFile, "Running procedure EMP_ORG\n");
            CallableStatement callStmt = conn.prepareCall("{call emp_org}");
            callStmt.execute();
            callStmt.close();
            
            // Drop and recreate ENTEMP2 table
            writeToFile(e5OutFile, "Dropping ENTEMP2 Table\n");
            stmt.execute("DROP TABLE ENTEMP2");
            
            writeToFile(e5OutFile, "Creating ENTEMP2 Table\n");
            stmt.execute("CREATE TABLE ENTEMP2 TABLESPACE ENTITY AS (SELECT * FROM ENTEMP)");
            
            // Get current date-time again
            rs = stmt.executeQuery("SELECT TO_CHAR(SYSDATE, 'MM/DD/YYYY - HH:MI:SS AM') \"Date-Time\" FROM DUAL");
            if (rs.next()) {
                writeToFile(e5OutFile, "Current date-time: " + rs.getString(1) + "\n");
            }
            rs.close();
            
            return true;
        } finally {
            if (stmt != null) try { stmt.close(); } catch (Exception e) { /* ignore */ }
            if (conn != null) try { conn.close(); } catch (Exception e) { /* ignore */ }
        }
    }
    
    /**
     * Create a LOGLOAD record for tracking the E5 load
     */
    private boolean createLogloadRecord() throws SQLException, IOException {
        Connection conn = null;
        PreparedStatement ps = null;
        
        try {
            // Connect to database
            conn = DriverManager.getConnection(jdbcUrl, dbUser, dbPassword);
            
            // Set NLS date format
            Statement stmt = conn.createStatement();
            stmt.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'MM/DD/YYYY HH24:MI:SS'");
            
            // Get the extract date from E5TMP
            String extractDate = null;
            ResultSet rs = stmt.executeQuery("SELECT ENTEXTRACTDT FROM E5TMP WHERE ROWNUM = 1");
            if (rs.next()) {
                java.sql.Date date = rs.getDate(1);
                if (date != null) {
                    java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("MM/dd/yyyy");
                    extractDate = sdf.format(date);
                }
            }
            rs.close();
            
            if (extractDate == null) {
                writeToFile(e5OutFile, "ERROR: Could not determine extract date from E5TMP\n");
                return false;
            }
            
            // Get record count
            int recordCount = 0;
            rs = stmt.executeQuery("SELECT COUNT(*) FROM E5TMP");
            if (rs.next()) {
                recordCount = rs.getInt(1);
            }
            rs.close();
            stmt.close();
            
            // Format the current time
            LocalDateTime now = LocalDateTime.now();
            DateTimeFormatter timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss");
            String currentTime = now.format(timeFormatter);
            
            // Get hostname
            String hostname = "localhost";
            try {
                hostname = java.net.InetAddress.getLocalHost().getHostName();
            } catch (Exception e) {
                // Use default if hostname can't be determined
            }
            
            // Insert LOGLOAD record
            String insertSql = "INSERT INTO LOGLOAD VALUES (?, ?, TO_DATE(? || ' ' || ?, 'MM/DD/YYYY HH24:MI:SS'), ?, ?)";
            ps = conn.prepareStatement(insertSql);
            ps.setString(1, record.outpucd);
            ps.setString(2, extractDate);
            ps.setString(3, extractDate);
            ps.setString(4, currentTime);
            ps.setString(5, hostname);
            ps.setInt(6, recordCount);
            
            int inserted = ps.executeUpdate();
            writeToFile(e5OutFile, "Inserted " + inserted + " LOGLOAD record\n");
            
            return true;
        } finally {
            if (ps != null) try { ps.close(); } catch (Exception e) { /* ignore */ }
            if (conn != null) try { conn.close(); } catch (Exception e) { /* ignore */ }
        }
    }
    
    /**
     * Write text to a file
     */
    private void writeToFile(String filePath, String text) throws IOException {
        try (FileWriter fw = new FileWriter(filePath, true);
             BufferedWriter bw = new BufferedWriter(fw)) {
            bw.write(text);
        }
    }
    
    /**
     * Get current date and time formatted as "MM/dd/yyyy HH:mm:ss"
     */
    private String getCurrentDateTime() {
        LocalDateTime now = LocalDateTime.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MM/dd/yyyy HH:mm:ss");
        return now.format(formatter);
    }
    
    /**
     * Inner class to represent an E5 record with all its fields
     */
    private static class E5Record {
        String outputcd;
        int empasgmtnum;
        String empname;
        String empgradecd;
        String emptypecd;
        String tourofduty;
        String empworkarea;
        String tpspodind;
        String csupodind;
        String parapodind;
        String mngrpodind;
        String empposittypecd;
        String flexplaceind;
        java.util.Date empupdatedt;
        java.util.Date entextractdt;
        String empidnum;
        String emptitle;
        int areacd;
        int phone;
        int ext;
        int previd;
        String seid;
        String email;
        String icsacc;
        String emppodcd;
        int gs9cnt;
        int gs11cnt;
        int gs12cnt;
        int gs13cnt;
    }