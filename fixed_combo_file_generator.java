package com.dialer.processor;

import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCallback;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.FileTime;
import java.nio.file.attribute.PosixFilePermissions;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

/**
 * Implementation of the Dial1_crRAW shell script functionality.
 * Creates COMBO.raw files by processing TDA.raw and TDI.raw files.
 * 
 * Modified: Java version based on shell script analysis
 * Variables to modify: Increased to accommodate new record length of 660.
 * Modified variables for Jan. 2012 record length changes.
 * 
 * FIXED: All critical issues identified in DIAL Step 1 compliance review
 */
@Component
public class ComboFileGenerator implements Tasklet {
    
    private static final Logger logger = LoggerFactory.getLogger(ComboFileGenerator.class);
    
    private final JdbcTemplate jdbcTemplate;
    private final Map<String, String> dialEnv;
    private final String[] processingAreas;
    private final boolean backupEnabled;
    
    // Configuration properties
    @Value("${dial.log.path}")
    private String logPath;
    
    @Value("${dial.job.chunk-size:1000}")
    private int chunkSize;
    
    @Value("${dial.file.validation.enabled:true}")
    private boolean fileValidationEnabled;
    
    @Value("${dial.file.age.max-days:6}")
    private int maxFileAgeDays;
    
    // Constants from dial1_craw_java.java
    private static final String TDA_FILE = "TDA.raw";
    private static final String TDI_FILE = "TDI.raw";
    private static final String RAW_DAT_FILE = "raw.dat";
    private static final String COMBO_RAW_FILE = "COMBO.raw";
    
    // Record structure constants - DIAL Step 1 specifications
    private static final int TIN_LENGTH = 11;
    private static final int DATALINE_LENGTH = 660;
    private static final int TOTAL_RECORD_LENGTH = TIN_LENGTH + DATALINE_LENGTH + 1;
    
    // List cycle validation positions (159-164, 0-based indexing = 158-163)
    private static final int LIST_CYCLE_START = 158;
    private static final int LIST_CYCLE_END = 164;
    
    @Autowired
    public ComboFileGenerator(DataSource dataSource, DialEnvironmentConfig config) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
        this.dialEnv = config.dialEnvironment(null);
        this.processingAreas = config.processingAreas();
        this.backupEnabled = config.isBackupEnabled();
    }
    
    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        Path logFile = Paths.get(logPath);
        Files.createDirectories(logFile.getParent());
        
        try (BufferedWriter logWriter = Files.newBufferedWriter(logFile, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            
            logWriter.write("--- Step #1 - Dial1_crRAW - Creates COMBO.raw files ----");
            logWriter.newLine();
            logWriter.write(LocalDate.now().toString());
            logWriter.newLine();
            
            // Backup previous TDA/TDI raw files if backup is enabled
            if (backupEnabled) {
                backupRawFiles(logWriter);
            } else {
                logWriter.write("Backup of TDA/TDI raw files is disabled");
                logWriter.newLine();
                logger.info("Backup of TDA/TDI raw files is disabled");
            }
            
            // Process each area with enhanced error handling
            AtomicInteger counter = new AtomicInteger(0);
            boolean hasErrors = false;
            
            for (String area : processingAreas) {
                try {
                    processArea(area, counter.incrementAndGet(), logWriter);
                } catch (Exception e) {
                    hasErrors = true;
                    logger.error("Error processing area {}", area, e);
                    logWriter.write("ERROR processing area " + area + ": " + e.getMessage());
                    logWriter.newLine();
                    // Continue processing other areas even if one fails
                }
            }
            
            // Log completion
            if (hasErrors) {
                logWriter.write("--- Step #1 - Creation of COMBO.raw files COMPLETED WITH ERRORS -----");
            } else {
                logWriter.write("--- Step #1 - Creation of COMBO.raw files COMPLETED SUCCESSFULLY -----");
            }
            logWriter.newLine();
            
        }
        
        return RepeatStatus.FINISHED;
    }
    
    /**
     * Enhanced backup functionality from dial1_craw_java.java
     */
    private void backupRawFiles(BufferedWriter logWriter) throws IOException {
        logWriter.write("# -----cp last weeks TDA/TDI rawfiles from RAM_DIR to RAM_BKUP ----------");
        logWriter.newLine();
        
        Path rawDir = Paths.get(dialEnv.get("RAM_DIR"));
        Path backupDir = Paths.get(dialEnv.get("RAM_BKUP"));
        
        Files.createDirectories(backupDir);
        
        // Delete existing backup files if they exist
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(backupDir, "*.?????.z")) {
            for (Path file : stream) {
                Files.deleteIfExists(file);
            }
        }
        
        // Copy TDI files to backup
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(rawDir, "TDI.*.?????.z")) {
            for (Path file : stream) {
                Path target = backupDir.resolve(file.getFileName());
                Files.copy(file, target, StandardCopyOption.REPLACE_EXISTING);
                Files.setPosixFilePermissions(target, PosixFilePermissions.fromString("rw-rw-rw-"));
            }
        }
        
        logger.info("Backup of TDA/TDI raw files completed from {} to {}", rawDir, backupDir);
    }
    
    /**
     * FIXED: Enhanced area processing with proper per-area directory handling
     */
    private void processArea(String area, int areaCount, BufferedWriter logWriter) throws IOException {
        logWriter.write("========================================================================");
        logWriter.newLine();
        logWriter.write("--- Running byte_check on " + area + " -----------");
        logWriter.newLine();
        
        // FIXED: Use area-specific directory for ALL operations
        Path areaDialDir = Paths.get(dialEnv.get("ALSDIR"), area, "DIALDIR");
        System.out.println("areaDialDir::::" + areaDialDir);
        Files.createDirectories(areaDialDir);
        
        // Check for TDA.raw and TDI.raw files with enhanced validation
        Path tdaFile = areaDialDir.resolve(TDA_FILE);
        Path tdiFile = areaDialDir.resolve(TDI_FILE);
        
        // FIXED: Enhanced validation including file existence, size, and age
        if (fileValidationEnabled) {
            if (!Files.exists(tdaFile) || !Files.exists(tdiFile)) {
                logWriter.write("ERROR TDA/TDI.raw files are not current for " + area);
                logWriter.newLine();
                logger.error("TDA/TDI.raw files not found for area: {}", area);
                return;
            }
            
            // FIXED: Add file age validation
            if (!isFileRecent(tdaFile) || !isFileRecent(tdiFile)) {
                logWriter.write("ERROR TDA/TDI.raw files are too old for " + area + " (older than " + maxFileAgeDays + " days)");
                logWriter.newLine();
                logger.error("TDA/TDI.raw files are too old for area: {}", area);
                return;
            }
            
            long tdaSize = Files.size(tdaFile);
            long tdiSize = Files.size(tdiFile);
            
            // FIXED: Handle empty files with carriage return addition
            tdaSize = handleEmptyFile(tdaFile, "TDA.raw", logWriter);
            tdiSize = handleEmptyFile(tdiFile, "TDI.raw", logWriter);
            
            if (tdaSize == 0 || tdiSize == 0) {
                logWriter.write("ERROR with byte_check: " + areaDialDir + " TDA.raw or TDI.raw is still empty after processing");
                logWriter.newLine();
                logger.error("Empty TDA/TDI.raw files for area: {}", area);
                return;
            }
            
            // Perform comprehensive byte checks
            performByteCheck(tdaFile, "TDA.raw", logWriter);
            performByteCheck(tdiFile, "TDI.raw", logWriter);
        }
        
        // Count lines in files with enhanced logging
        long tdaLines = countLines(tdaFile);
        long tdiLines = countLines(tdiFile);
        
        logWriter.write("ls -l TDA.raw TDI.raw");
        logWriter.newLine();
        logWriter.write("TDA.raw size: " + Files.size(tdaFile) + " bytes, " + tdaLines + " lines");
        logWriter.newLine();
        logWriter.write("TDI.raw size: " + Files.size(tdiFile) + " bytes, " + tdiLines + " lines");
        logWriter.newLine();
        
        logger.info("Processing area: {} - TDA: {} lines, TDI: {} lines", area, tdaLines, tdiLines);
        
        // FIXED: Create combo.raw file with area-specific directory
        createComboRaw(area, areaDialDir, tdaFile, tdiFile, logWriter);
    }
    
    /**
     * FIXED: Add file age validation method
     */
    private boolean isFileRecent(Path file) throws IOException {
        FileTime lastModified = Files.getLastModifiedTime(file);
        long daysSinceModified = ChronoUnit.DAYS.between(
            lastModified.toInstant(), Instant.now());
        return daysSinceModified <= maxFileAgeDays;
    }
    
    /**
     * FIXED: Handle empty files by adding carriage returns
     */
    private long handleEmptyFile(Path file, String fileName, BufferedWriter logWriter) throws IOException {
        long fileSize = Files.size(file);
        if (fileSize == 0) {
            logWriter.write("Empty " + fileName + " detected, adding carriage return");
            logWriter.newLine();
            
            try (BufferedWriter writer = Files.newBufferedWriter(file, StandardCharsets.UTF_8,
                    StandardOpenOption.WRITE, StandardOpenOption.APPEND)) {
                writer.newLine();
            }
            
            fileSize = Files.size(file);
            logger.info("Added carriage return to empty {} file, new size: {} bytes", fileName, fileSize);
        }
        return fileSize;
    }
    
    /**
     * Enhanced byte check functionality from dial1_craw_java.java
     */
    private void performByteCheck(Path file, String fileName, BufferedWriter logWriter) throws IOException {
        long fileSize = Files.size(file);
        logger.debug("Byte check for {}: {} bytes", fileName, fileSize);
        
        // Check for record length consistency
        if (fileSize % TOTAL_RECORD_LENGTH != 0) {
            String warning = String.format("WARNING: %s file size (%d) not divisible by expected record length (%d)", 
                fileName, fileSize, TOTAL_RECORD_LENGTH);
            logWriter.write(warning);
            logWriter.newLine();
            logger.warn(warning);
        }
    }
    
    /**
     * Enhanced line counting utility
     */
    private long countLines(Path file) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(file)) {
            return reader.lines().count();
        }
    }
    
    /**
     * FIXED: Comprehensive createComboRaw method with proper area-specific directory handling
     */
    private void createComboRaw(String area, Path areaDialDir, Path tdaFile, Path tdiFile, BufferedWriter logWriter) throws IOException {
        logWriter.write("--- Cat TDA.raw TDI.raw into raw.dat for " + area + " ----");
        logWriter.newLine();
        
        // FIXED: Use area-specific directory for all intermediate and output files
        Path rawDat = areaDialDir.resolve(RAW_DAT_FILE);
        System.out.println("rawDat::::" + rawDat);
        
        try (BufferedWriter writer = Files.newBufferedWriter(rawDat, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
             BufferedReader tdaReader = Files.newBufferedReader(tdaFile);
             BufferedReader tdiReader = Files.newBufferedReader(tdiFile)) {
            
            String line;
            while ((line = tdaReader.readLine()) != null) {
                writer.write(line);
                writer.newLine();
            }
            
            while ((line = tdiReader.readLine()) != null) {
                writer.write(line);
                writer.newLine();
            }
        }
        
        // Create COMBO.raw file directly without database table
        logWriter.write("--- Creating COMBO.raw directly from raw.dat for " + area + " ----");
        logWriter.newLine();
        
        try {
            createComboRawDirectly(rawDat, areaDialDir, area, logWriter);
        } catch (Exception e) {
            logWriter.write("Error creating COMBO.raw: " + e.getMessage());
            logWriter.newLine();
            logger.error("Error creating COMBO.raw for area {}", area, e);
            throw e;
        }
    }
    
    /**
     * FIXED: Create COMBO.raw file directly with proper TIN validation and list cycle checking
     */
    private void createComboRawDirectly(Path rawDat, Path areaDialDir, String area, BufferedWriter logWriter) throws IOException {
        logWriter.write("--- Processing raw.dat and creating sorted COMBO.raw for " + area + " ----");
        logWriter.newLine();
        
        // Read all records from raw.dat and parse them
        List<RawRecord> records = new ArrayList<>();
        
        try (BufferedReader reader = Files.newBufferedReader(rawDat)) {
            String line;
            int lineNumber = 0;
            int validRecords = 0;
            int errorRecords = 0;
            
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                
                try {
                    if (!line.trim().isEmpty() && line.length() >= TIN_LENGTH) {
                        String tin = line.substring(0, TIN_LENGTH).trim();
                        String dataline = line;
                        
                        // FIXED: Proper TIN validation - numeric validation and not all zeros
                        if (isValidTin(tin)) {
                            records.add(new RawRecord(tin, dataline));
                            validRecords++;
                        }
                    }
                } catch (Exception e) {
                    errorRecords++;
                    logger.warn("Error processing line {} in raw.dat: {}", lineNumber, 
                               line.length() > 50 ? line.substring(0, 50) + "..." : line);
                }
            }
            
            logWriter.write("Processed " + lineNumber + " lines, " + validRecords + " valid records, " + 
                           errorRecords + " errors");
            logWriter.newLine();
            logger.info("Processed {} lines from raw.dat: {} valid records, {} errors", 
                       lineNumber, validRecords, errorRecords);
        }
        
        // FIXED: Add list cycle validation before sorting
        validateListCycle(records, logWriter);
        
        // Sort records by TIN (equivalent to ORDER BY tin in SQL)
        logWriter.write("--- Sorting records by TIN ----");
        logWriter.newLine();
        
        records.sort((r1, r2) -> r1.tin.compareTo(r2.tin));
        
        // FIXED: Write sorted records to COMBO.raw in area-specific directory
        Path comboRaw = areaDialDir.resolve(COMBO_RAW_FILE);
        
        try (BufferedWriter writer = Files.newBufferedWriter(comboRaw, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
            
            for (RawRecord record : records) {
                writer.write(record.dataline);
                writer.newLine();
            }
        }
        
        logWriter.write("Created COMBO.raw file with " + records.size() + " sorted records for area " + area);
        logWriter.newLine();
        logger.info("Created COMBO.raw file with {} sorted records for area {}", records.size(), area);
        
        // Validate the created file
        validateComboRawFile(comboRaw, area, logWriter);
    }
    
    /**
     * FIXED: Proper TIN validation - numeric and not all zeros
     */
    private boolean isValidTin(String tin) {
        if (tin == null || tin.trim().isEmpty()) {
            return false;
        }
        
        // Remove any non-digit characters (like dashes)
        String cleanTin = tin.replaceAll("[^0-9]", "");
        
        try {
            // Must be numeric and greater than 0
            long tinValue = Long.parseLong(cleanTin);
            return tinValue > 0;
        } catch (NumberFormatException e) {
            return false;
        }
    }
    
    /**
     * FIXED: Add list cycle validation method (positions 159-164)
     */
    private void validateListCycle(List<RawRecord> records, BufferedWriter logWriter) throws IOException {
        Set<String> listCycles = records.stream()
            .filter(r -> r.dataline.length() >= LIST_CYCLE_END)
            .map(r -> r.dataline.substring(LIST_CYCLE_START, LIST_CYCLE_END))
            .collect(Collectors.toSet());
        
        logWriter.write("--- List Cycle Validation (positions 159-164) ----");
        logWriter.newLine();
        
        if (listCycles.size() > 1) {
            String error = "ERROR: Multiple list cycles found in COMBO.raw: " + listCycles;
            logWriter.write(error);
            logWriter.newLine();
            logger.error(error);
            throw new IOException("List cycle validation failed: multiple cycles detected");
        } else if (listCycles.size() == 1) {
            String cycle = listCycles.iterator().next();
            logWriter.write("✓ Single list cycle validated: " + cycle);
            logWriter.newLine();
            logger.info("List cycle validation passed: {}", cycle);
        } else {
            logWriter.write("⚠ No list cycle data found in records");
            logWriter.newLine();
            logger.warn("No list cycle data found in records");
        }
    }
    
    /**
     * FIXED: Enhanced validation with additional checks
     */
    private void validateComboRawFile(Path comboRaw, String area, BufferedWriter logWriter) throws IOException {
        if (!Files.exists(comboRaw)) {
            throw new IOException("COMBO.raw file was not created for area: " + area);
        }
        
        long fileSize = Files.size(comboRaw);
        long recordCount = Files.lines(comboRaw).count();
        
        logWriter.write("--- Validation Results for COMBO.raw ----");
        logWriter.newLine();
        logWriter.write("File size: " + fileSize + " bytes");
        logWriter.newLine();
        logWriter.write("Record count: " + recordCount);
        logWriter.newLine();
        
        if (recordCount == 0) {
            logWriter.write("✗ WARNING: COMBO.raw file is empty");
            logWriter.newLine();
            logger.warn("COMBO.raw file is empty for area {}", area);
            return;
        }
        
        // Verify records are sorted by reading first few and last few TINs
        try (BufferedReader reader = Files.newBufferedReader(comboRaw)) {
            List<String> allLines = reader.lines().collect(Collectors.toList());
            
            if (!allLines.isEmpty()) {
                String firstTin = allLines.get(0).length() >= TIN_LENGTH ? 
                    allLines.get(0).substring(0, TIN_LENGTH).trim() : "";
                String lastTin = allLines.get(allLines.size() - 1).length() >= TIN_LENGTH ? 
                    allLines.get(allLines.size() - 1).substring(0, TIN_LENGTH).trim() : "";
                
                logWriter.write("First TIN: " + firstTin);
                logWriter.newLine();
                logWriter.write("Last TIN: " + lastTin);
                logWriter.newLine();
                
                // FIXED: Better sorting validation
                if (isValidTinSorting(allLines)) {
                    logWriter.write("✓ Records are properly sorted by TIN");
                    logWriter.newLine();
                    logger.info("COMBO.raw validation successful for area {}: {} records properly sorted", 
                               area, recordCount);
                } else {
                    logWriter.write("✗ ERROR: Records are not properly sorted by TIN");
                    logWriter.newLine();
                    logger.error("COMBO.raw sorting validation failed for area {}", area);
                    throw new IOException("COMBO.raw sorting validation failed for area: " + area);
                }
            }
        }
    }
    
    /**
     * FIXED: Comprehensive TIN sorting validation
     */
    private boolean isValidTinSorting(List<String> lines) {
        String previousTin = null;
        
        for (String line : lines) {
            if (line.length() >= TIN_LENGTH) {
                String currentTin = line.substring(0, TIN_LENGTH).trim();
                
                if (previousTin != null && currentTin.compareTo(previousTin) < 0) {
                    return false; // Found out-of-order TIN
                }
                previousTin = currentTin;
            }
        }
        
        return true;
    }
    
    /**
     * Simple record holder class for sorting
     */
    private static class RawRecord {
        final String tin;
        final String dataline;
        
        RawRecord(String tin, String dataline) {
            this.tin = tin;
            this.dataline = dataline;
        }
    }
    
    /**
     * Enhanced utility method for prepared statement execution (kept for potential future use)
     */
    public boolean executePreparedStatement(final String sql, final Object... params) {
        return jdbcTemplate.execute(sql, new PreparedStatementCallback<Boolean>() {
            @Override
            public Boolean doInPreparedStatement(PreparedStatement ps) throws SQLException {
                if (params != null) {
                    for (int i = 0; i < params.length; i++) {
                        ps.setObject(i + 1, params[i]);
                    }
                }
                return ps.execute();
            }
        });
    }
    
    /**
     * Configuration validation method from dial1_craw_java.java
     */
    public void validateConfiguration() {
        if (dialEnv.get("ALSDIR") == null || dialEnv.get("ALSDIR").trim().isEmpty()) {
            throw new IllegalStateException("ALSDIR configuration is required");
        }
        if (processingAreas == null || processingAreas.length == 0) {
            throw new IllegalStateException("Processing areas configuration is required");
        }
        logger.info("Configuration validation completed successfully");
    }
}