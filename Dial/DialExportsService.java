package com.als.service;

import com.als.config.ApplicationConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;

/**
 * DialExportsService - Java conversion of Dial1_exports script
 * 
 * Original DIAL script: Dial1_exports
 * Purpose: Create the ALS export files - Cshell script that exports dial global tables
 * 
 * Original script comments:
 * # Dial1_exports : Cshell script that exports dial global tables.
 * # 01/15/97 (AJC) - Originally (step #2/step #2) of chkdial.csh created 8/11/97
 * # Revised 01/18/98
 * # Revised 02/13/08
 * # Revised 08/05/09
 * # Revised 11/05/09 - created two export files (dial, dial2)
 */
@Service
public class DialExportsService {
    
    private static final Logger logger = LoggerFactory.getLogger(DialExportsService.class);
    
    @Autowired
    private ApplicationConfig config;
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    /**
     * Main method to perform DIAL exports
     * 
     * Original DIAL: Complete Dial1_exports script (lines 1-50)
     */
    public void performDialExports() {
        try {
            logger.info("=== Starting DIAL Export Operations ===");
            
            // Original DIAL: Lines 10-12 - source DIAL.path, set pswd
            initializeExportConfiguration();
            
            // Original DIAL: Lines 13-19 - Step #1 create the als export files
            performStep1ExportFiles();
            
            // Original DIAL: Lines 20-50 - Export operations and validation
            executeExportOperations();
            
            logger.info("=== DIAL Export Operations Completed ===");
            
        } catch (Exception e) {
            logger.error("Error in DialExportsService.performDialExports()", e);
            throw new RuntimeException("Failed to perform DIAL exports", e);
        }
    }
    
    /**
     * Initialize export configuration
     * 
     * Original DIAL: Lines 10-12
     * set nonomatch
     * source DIAL.path
     * set pswd = '/als-ALS/app/execloc/d.common/DeclpRetr dial'
     */
    private void initializeExportConfiguration() {
        logger.info("Initializing DIAL export configuration");
        logToDiallog("--- Step #1 - Create ALS Export Files ---");
        
        // Set environment variable for NLS_LANG if needed
        // Original DIAL: setenv NLS_LANG American_America.WE8ISO8859P15
        logger.info("Setting NLS_LANG for export operations");
    }
    
    /**
     * Perform Step 1 export file creation
     * 
     * Original DIAL: Lines 13-19
     * date >> $CONSOLDIR/diallog
     * setenv NLS_LANG American_America.WE8ISO8859P15
     * cd $EXP_DIR
     * if ( -e dial.exp.????.Z && -e dial2.exp.????.Z) then
     *   /bin/rm dial.exp.????.Z >& /dev/null
     *   /bin/rm dial2.exp.????.Z >& /dev/null
     * endif
     */
    private void performStep1ExportFiles() throws IOException {
        String expDir = config.getExpDir();
        
        logToDiallog(LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        
        // Change to export directory
        Path expDirPath = Paths.get(expDir);
        if (!Files.exists(expDirPath)) {
            Files.createDirectories(expDirPath);
            logger.info("Created export directory: {}", expDir);
        }
        
        // Clean up old export files
        cleanupOldExportFiles(expDirPath);
    }
    
    /**
     * Clean up old export files
     * 
     * Original DIAL: Lines 21-25
     * if ( -e dial.exp.????.Z && -e dial2.exp.????.Z) then
     *   /bin/rm dial.exp.????.Z >& /dev/null
     *   /bin/rm dial2.exp.????.Z >& /dev/null
     * endif
     */
    private void cleanupOldExportFiles(Path expDirPath) throws IOException {
        logger.info("Cleaning up old export files");
        
        // Find and remove old dial.exp.*.Z files
        try {
            Files.list(expDirPath)
                 .filter(path -> {
                     String fileName = path.getFileName().toString();
                     return fileName.matches("dial\\.exp\\.\\d{4}\\.Z") || 
                            fileName.matches("dial2\\.exp\\.\\d{4}\\.Z");
                 })
                 .forEach(path -> {
                     try {
                         Files.deleteIfExists(path);
                         logger.info("Removed old export file: {}", path.getFileName());
                     } catch (IOException e) {
                         logger.warn("Could not remove old export file: {}", path, e);
                     }
                 });
        } catch (IOException e) {
            logger.warn("Error cleaning up old export files", e);
        }
    }
    
    /**
     * Execute main export operations
     * 
     * Original DIAL: Lines 26-50
     */
    private void executeExportOperations() throws IOException {
        // Original DIAL: Lines 27-38 - First export operation
        performFirstExport();
        
        // Original DIAL: Lines 39-50 - Second export operation  
        performSecondExport();
        
        // Log completion
        logToDiallog("---- Exports Completed ------------------");
    }
    
    /**
     * Perform first export operation
     * 
     * Original DIAL: Lines 27-38
     * cd $DIAL
     * exp dial/${pswd} PARFILE=EXP_PAR FILE=$EXP_DIR/dial.exp.`date +%m%d` >>& $CONSOLDIR/diallog
     * set cntexp = `grep "Export terminated successfully" $CONSOLDIR/diallog | wc -l`
     * if ($cntexp == 0) then
     *   echo "Exports terminated unsuccessfully" >> $CONSOLDIR/diallog
     *   exit
     * else
     *   cd $EXP_DIR
     *   set exp = dial.exp.????
     *   compress $exp
     *   cd $DIAL
     * endif
     */
    private void performFirstExport() throws IOException {
        logger.info("Performing first export operation (dial.exp)");
        
        String dialDir = config.getDialDir();
        String expDir = config.getExpDir();
        String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern("MMdd"));
        String exportFileName = "dial.exp." + dateStr;
        
        logToDiallog("Starting export: " + exportFileName);
        
        try {
            // Execute Oracle export equivalent
            // In a real implementation, this would use Oracle Data Pump or similar
            boolean exportSuccess = executeOracleExport("dial", "EXP_PAR", expDir + "/" + exportFileName);
            
            if (!exportSuccess) {
                logToDiallog("Exports terminated unsuccessfully");
                throw new RuntimeException("First export operation failed");
            } else {
                // Compress the export file
                compressExportFile(Paths.get(expDir, exportFileName));
                logToDiallog("First export completed and compressed successfully");
            }
            
        } catch (Exception e) {
            logToDiallog("Error during first export: " + e.getMessage());
            throw new RuntimeException("First export operation failed", e);
        }
    }
    
    /**
     * Perform second export operation
     * 
     * Original DIAL: Lines 39-50
     * exp dial/${pswd} PARFILE=EXP2_PAR FILE=$EXP_DIR/dial2.exp.`date +%m%d` >>& $CONSOLDIR/diallog
     * set cntexp = `grep "Export terminated successfully" $CONSOLDIR/diallog | wc -l`
     * if ($cntexp == 0) then
     *   echo "Exports terminated unsuccessfully" >> $CONSOLDIR/diallog
     *   exit
     * else
     *   cd $EXP_DIR
     *   set exp = dial2.exp.????
     *   compress $exp
     *   cd $DIAL
     * endif
     */
    private void performSecondExport() throws IOException {
        logger.info("Performing second export operation (dial2.exp)");
        
        String expDir = config.getExpDir();
        String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern("MMdd"));
        String exportFileName = "dial2.exp." + dateStr;
        
        logToDiallog("Starting export: " + exportFileName);
        
        try {
            // Execute second Oracle export
            boolean exportSuccess = executeOracleExport("dial", "EXP2_PAR", expDir + "/" + exportFileName);
            
            if (!exportSuccess) {
                logToDiallog("Exports terminated unsuccessfully");
                throw new RuntimeException("Second export operation failed");
            } else {
                // Compress the export file
                compressExportFile(Paths.get(expDir, exportFileName));
                logToDiallog("Second export completed and compressed successfully");
            }
            
        } catch (Exception e) {
            logToDiallog("Error during second export: " + e.getMessage());
            throw new RuntimeException("Second export operation failed", e);
        }
    }
    
    /**
     * Execute Oracle export operation
     * 
     * Original DIAL: exp dial/${pswd} PARFILE=... FILE=...
     * 
     * In a real implementation, this would use:
     * - Oracle Data Pump (expdp) for modern Oracle versions
     * - Traditional export (exp) for older versions
     * - Or custom JDBC-based export logic
     */
    private boolean executeOracleExport(String schema, String parFile, String outputFile) {
        try {
            logger.info("Executing Oracle export - Schema: {}, ParFile: {}, Output: {}", schema, parFile, outputFile);
            
            // Simulate Oracle export operation
            // In a real implementation, this would:
            // 1. Read the parameter file to understand what to export
            // 2. Execute the appropriate Oracle Data Pump or export command
            // 3. Monitor the process for completion and errors
            
            // For demonstration, we'll simulate the export process
            simulateExportProcess(schema, parFile, outputFile);
            
            return true;
            
        } catch (Exception e) {
            logger.error("Oracle export failed for schema: {}", schema, e);
            return false;
        }
    }
    
    /**
     * Simulate the Oracle export process
     * In a real implementation, this would be replaced with actual Oracle export logic
     */
    private void simulateExportProcess(String schema, String parFile, String outputFile) throws InterruptedException {
        logger.info("Simulating export process for schema: {}", schema);
        
        // Simulate export time
        Thread.sleep(1000); // 1 second simulation
        
        // Create a dummy export file for demonstration
        try {
            Path outputPath = Paths.get(outputFile);
            Files.createDirectories(outputPath.getParent());
            
            String exportContent = String.format(
                "Export file created by Java DIAL Service\n" +
                "Schema: %s\n" +
                "Parameter File: %s\n" +
                "Export Date: %s\n" +
                "Status: Export terminated successfully\n",
                schema, parFile, LocalDateTime.now());
            
            Files.write(outputPath, exportContent.getBytes());
            
        } catch (IOException e) {
            throw new RuntimeException("Failed to create export file", e);
        }
    }
    
    /**
     * Compress export file
     * 
     * Original DIAL: compress $exp
     */
    private void compressExportFile(Path exportFile) throws IOException {
        if (!Files.exists(exportFile)) {
            logger.warn("Export file does not exist for compression: {}", exportFile);
            return;
        }
        
        logger.info("Compressing export file: {}", exportFile.getFileName());
        
        // In a real implementation, this would use actual compression
        // For demonstration, we'll rename the file to indicate compression
        Path compressedFile = Paths.get(exportFile.toString() + ".Z");
        
        try {
            Files.move(exportFile, compressedFile);
            logger.info("Export file compressed: {}", compressedFile.getFileName());
            
        } catch (IOException e) {
            logger.error("Failed to compress export file: {}", exportFile, e);
            throw e;
        }
    }
    
    /**
     * Validate export success by checking for success messages
     * 
     * Original DIAL: grep "Export terminated successfully" $CONSOLDIR/diallog | wc -l
     */
    private boolean validateExportSuccess() {
        try {
            String consolDir = config.getConsoldir();
            Path diallogFile = Paths.get(consolDir, "diallog");
            
            if (!Files.exists(diallogFile)) {
                return false;
            }
            
            // Count occurrences of success message
            long successCount = Files.lines(diallogFile)
                                   .filter(line -> line.contains("Export terminated successfully"))
                                   .count();
            
            logger.info("Found {} export success messages", successCount);
            return successCount > 0;
            
        } catch (IOException e) {
            logger.error("Error validating export success", e);
            return false;
        }
    }
    
    /**
     * Utility method to log messages to diallog file
     * 
     * Original DIAL: >> $CONSOLDIR/diallog
     */
    private void logToDiallog(String message) {
        try {
            String consolDir = config.getConsoldir();
            Path diallogFile = Paths.get(consolDir, "diallog");
            
            // Ensure directory exists
            Files.createDirectories(diallogFile.getParent());
            
            // Append message to diallog file
            String timestampedMessage = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")) 
                                      + " " + message + System.lineSeparator();
            
            Files.write(diallogFile, timestampedMessage.getBytes(), 
                       java.nio.file.StandardOpenOption.CREATE, 
                       java.nio.file.StandardOpenOption.APPEND);
            
        } catch (IOException e) {
            logger.error("Error writing to diallog file: " + message, e);
        }
    }
}