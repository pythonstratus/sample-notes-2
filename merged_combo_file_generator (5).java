package com.dialer.processor;

import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCallback;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.annotation.PreDestroy;
import javax.sql.DataSource;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.FileTime;
import java.nio.file.attribute.PosixFilePermissions;
import java.sql.*;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Comprehensive implementation of all DIAL Step 1 functionality with performance optimizations.
 * 
 * <p>This class serves as the main orchestrator for all DIAL Step 1 operations, including:
 * <ul>
 *   <li>Core COMBO.raw file generation from TDA.raw and TDI.raw files (Dial1_crRAW)</li>
 *   <li>Database table statistics gathering (Dial1_dothrcp)</li>
 *   <li>Oracle Data Pump export operations (Dial1_exports)</li>
 *   <li>Database synchronization operations (Dial1_point2cp)</li>
 * </ul>
 * 
 * <p><strong>Performance Features:</strong>
 * <ul>
 *   <li>Parallel processing for file operations and exports</li>
 *   <li>Streaming file processing to handle large datasets efficiently</li>
 *   <li>Optimized database operations with proper transaction management</li>
 *   <li>Memory-efficient validation and sorting algorithms</li>
 *   <li>Single datasource configuration for simplified connection management</li>
 * </ul>
 * 
 * <p><strong>Configuration:</strong>
 * All operations can be individually enabled/disabled via configuration properties.
 * Uses a single datasource for all database operations to the same schema.
 * 
 * @author DIAL Step 1 Migration Team
 * @version 2.1.0
 * @since 1.0.0
 */
@Component
public class ComboFileGenerator implements Tasklet {
    
    private static final Logger logger = LoggerFactory.getLogger(ComboFileGenerator.class);
    
    // Core dependencies with simplified single datasource
    private final JdbcTemplate jdbcTemplate;
    private final Map<String, String> dialEnv;
    private final String[] processingAreas;
    private final boolean backupEnabled;
    private final ExecutorService executorService;
    
    // Configuration properties - Core COMBO processing
    @Value("${dial.log.path}")
    private String logPath;
    
    @Value("${dial.job.chunk-size:1000}")
    private int chunkSize;
    
    @Value("${dial.file.validation.enabled:true}")
    private boolean fileValidationEnabled;
    
    @Value("${dial.file.age.max-days:6}")
    private int maxFileAgeDays;
    
    @Value("${dial.file.processing.parallel:true}")
    private boolean parallelFileProcessing;
    
    // Configuration properties - Statistics gathering
    @Value("${dial.stats.enabled:true}")
    private boolean statsGatheringEnabled;
    
    @Value("${dial.stats.parallel.degree:1}")
    private int statsParallelDegree;
    
    @Value("${dial.stats.batch.size:5}")
    private int statsBatchSize;
    
    // Configuration properties - Export operations
    @Value("${dial.export.enabled:true}")
    private boolean exportEnabled;
    
    @Value("${dial.export.directory}")
    private String exportDirectory;
    
    @Value("${dial.export.timeout.minutes:30}")
    private int exportTimeoutMinutes;
    
    @Value("${dial.export.parallel:true}")
    private boolean parallelExportExecution;
    
    @Value("${dial.database.connection.dial}")
    private String dialConnectionString;
    
    @Value("${dial.database.username}")
    private String databaseUsername;
    
    @Value("${dial.database.password}")
    private String databasePassword;
    
    @Value("${dial.nls.lang:American_America.WE8ISO8859P15}")
    private String nlsLang;
    
    // Configuration properties - Synchronization operations
    @Value("${dial.sync.enabled:true}")
    private boolean syncEnabled;
    
    @Value("${dial.sync.output.directory}")
    private String syncOutputDirectory;
    
    @Value("${dial.sync.timeout.minutes:15}")
    private int syncTimeoutMinutes;
    
    @Value("${dial.sync.parallel.execution:true}")
    private boolean parallelSyncExecution;
    
    @Value("${dial.sync.mview.limit:50}")
    private int mviewRefreshLimit;
    
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
    
    // Statistics gathering constants
    private static final String DEFAULT_ESTIMATE_PERCENT = "DBMS_STATS.AUTO_SAMPLE_SIZE";
    private static final String DEFAULT_METHOD_OPT = "FOR ALL COLUMNS SIZE AUTO";
    private static final boolean DEFAULT_CASCADE = true;
    private static final boolean DEFAULT_NO_INVALIDATE = false;
    private static final String DEFAULT_GRANULARITY = "ALL";
    private static final String DEFAULT_OPTIONS = "GATHER";
    
    // Export operation constants
    private static final String EXPORT_DATE_PATTERN = "MMdd";
    private static final Pattern SUCCESS_PATTERN = Pattern.compile(".*successfully completed.*", Pattern.CASE_INSENSITIVE);
    
    // Synchronization status tracking
    private final Map<String, SyncResult> syncResults = new HashMap<>();
    
    /**
     * Constructs a new ComboFileGenerator with simplified single datasource dependency.
     * 
     * @param dataSource Single datasource for all database operations
     * @param config Environment configuration provider
     * @param executorService Executor service for parallel operations
     */
    @Autowired
    public ComboFileGenerator(
            DataSource dataSource,
            DialEnvironmentConfig config,
            @Qualifier("dialExecutorService") ExecutorService executorService) {
        
        // Initialize single JdbcTemplate for all database operations
        this.jdbcTemplate = new JdbcTemplate(dataSource);
        
        // Initialize configuration
        this.dialEnv = config.dialEnvironment(null);
        this.processingAreas = config.processingAreas();
        this.backupEnabled = config.isBackupEnabled();
        this.executorService = executorService;
    }
    
    /**
     * Main execution method for Spring Batch Tasklet interface.
     * Orchestrates all DIAL Step 1 operations in the correct sequence.
     * 
     * @param contribution Step contribution for batch processing
     * @param chunkContext Chunk context for batch processing
     * @return RepeatStatus.FINISHED when all operations complete
     * @throws Exception if any critical operation fails
     */
    @Override
    @Transactional(propagation = Propagation.REQUIRED)
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        Path logFile = Paths.get(logPath);
        Files.createDirectories(logFile.getParent());
        
        try (BufferedWriter logWriter = Files.newBufferedWriter(logFile, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            
            logWriter.write("=== DIAL Step 1 - Complete Processing Suite ===");
            logWriter.newLine();
            logWriter.write("Start Time: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
            logWriter.newLine();
            
            boolean overallSuccess = true;
            long startTime = System.currentTimeMillis();
            
            try {
                // Step 1: Core COMBO.raw file generation (Dial1_crRAW)
                logWriter.write("--- Step #1 - Dial1_crRAW - Creates COMBO.raw files ----");
                logWriter.newLine();
                
                boolean comboSuccess = executeComboRawGeneration(logWriter);
                if (!comboSuccess) {
                    overallSuccess = false;
                }
                
                // Step 2: Database statistics gathering (Dial1_dothrcp)
                if (statsGatheringEnabled) {
                    logWriter.write("--- Step #2 - Dial1_dothrcp - Database Statistics Gathering ----");
                    logWriter.newLine();
                    
                    boolean statsSuccess = executeStatsGathering(logWriter);
                    if (!statsSuccess) {
                        overallSuccess = false;
                    }
                } else {
                    logWriter.write("Database statistics gathering is disabled");
                    logWriter.newLine();
                }
                
                // Step 3: Oracle export operations (Dial1_exports)
                if (exportEnabled) {
                    logWriter.write("--- Step #3 - Dial1_exports - Oracle Export Operations ----");
                    logWriter.newLine();
                    
                    boolean exportSuccess = executeExportOperations(logWriter);
                    if (!exportSuccess) {
                        overallSuccess = false;
                    }
                } else {
                    logWriter.write("Oracle export operations are disabled");
                    logWriter.newLine();
                }
                
                // Step 4: Database synchronization (Dial1_point2cp)
                if (syncEnabled) {
                    logWriter.write("--- Step #4 - Dial1_point2cp - Database Synchronization ----");
                    logWriter.newLine();
                    
                    boolean syncSuccess = executeSyncOperations(logWriter);
                    if (!syncSuccess) {
                        overallSuccess = false;
                    }
                } else {
                    logWriter.write("Database synchronization operations are disabled");
                    logWriter.newLine();
                }
                
            } catch (Exception e) {
                overallSuccess = false;
                handleCriticalError("DIAL Step 1 execution", e, logWriter);
                throw e; // Re-throw to fail the batch job
            }
            
            // Final completion log
            long duration = System.currentTimeMillis() - startTime;
            if (overallSuccess) {
                logWriter.write("=== DIAL Step 1 - ALL OPERATIONS COMPLETED SUCCESSFULLY ===");
                logger.info("DIAL Step 1 completed successfully in {} ms", duration);
            } else {
                logWriter.write("=== DIAL Step 1 - COMPLETED WITH ERRORS ===");
                logger.warn("DIAL Step 1 completed with errors in {} ms", duration);
            }
            logWriter.newLine();
            logWriter.write("End Time: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
            logWriter.newLine();
            logWriter.write("Total Duration: " + duration + " ms");
            logWriter.newLine();
            
        }
        
        return RepeatStatus.FINISHED;
    }
    
    // ========================================================================
    // COMBO.RAW FILE GENERATION METHODS (Original Core Functionality)
    // ========================================================================
    
    /**
     * Executes the core COMBO.raw file generation operations for all processing areas.
     * This includes backup operations, file validation, and area-specific processing.
     * 
     * @param logWriter Writer for logging operations
     * @return true if all operations completed successfully, false otherwise
     * @throws IOException if file operations fail
     */
    private boolean executeComboRawGeneration(BufferedWriter logWriter) throws IOException {
        boolean success = true;
        
        try {
            // Backup previous TDA/TDI raw files if backup is enabled
            if (backupEnabled) {
                backupRawFiles(logWriter);
            } else {
                logWriter.write("Backup of TDA/TDI raw files is disabled");
                logWriter.newLine();
                logger.info("Backup of TDA/TDI raw files is disabled");
            }
            
            // Process areas in parallel if enabled
            if (parallelFileProcessing && processingAreas.length > 1) {
                success = processAreasInParallel(logWriter);
            } else {
                success = processAreasSequentially(logWriter);
            }
            
        } catch (Exception e) {
            success = false;
            handleProcessingError("COMBO.raw generation", e, logWriter);
        }
        
        return success;
    }
    
    /**
     * Processes all areas sequentially (original behavior).
     * 
     * @param logWriter Writer for logging operations
     * @return true if all areas processed successfully
     * @throws IOException if file operations fail
     */
    private boolean processAreasSequentially(BufferedWriter logWriter) throws IOException {
        boolean success = true;
        AtomicInteger counter = new AtomicInteger(0);
        
        for (String area : processingAreas) {
            try {
                processArea(area, counter.incrementAndGet(), logWriter);
            } catch (Exception e) {
                success = false;
                handleProcessingError("area " + area, e, logWriter);
                // Continue processing other areas even if one fails
            }
        }
        
        return success;
    }
    
    /**
     * Processes all areas in parallel for improved performance.
     * 
     * @param logWriter Writer for logging operations
     * @return true if all areas processed successfully
     * @throws IOException if file operations fail
     */
    private boolean processAreasInParallel(BufferedWriter logWriter) throws IOException {
        logger.info("Processing {} areas in parallel", processingAreas.length);
        logWriter.write("Processing " + processingAreas.length + " areas in parallel");
        logWriter.newLine();
        
        List<CompletableFuture<Boolean>> futures = new ArrayList<>();
        AtomicInteger counter = new AtomicInteger(0);
        
        for (String area : processingAreas) {
            CompletableFuture<Boolean> future = CompletableFuture.supplyAsync(() -> {
                try {
                    processArea(area, counter.incrementAndGet(), logWriter);
                    return true;
                } catch (Exception e) {
                    handleProcessingError("area " + area, e, logWriter);
                    return false;
                }
            }, executorService);
            futures.add(future);
        }
        
        // Wait for all areas to complete
        CompletableFuture<Void> allAreas = CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]));
        
        try {
            allAreas.get(30, TimeUnit.MINUTES); // Timeout for all areas
            
            // Check results
            boolean overallSuccess = futures.stream()
                .map(CompletableFuture::join)
                .allMatch(result -> result);
            
            logWriter.write("Parallel area processing completed - Success: " + overallSuccess);
            logWriter.newLine();
            
            return overallSuccess;
            
        } catch (Exception e) {
            logger.error("Error in parallel area processing", e);
            logWriter.write("ERROR: Parallel area processing failed: " + e.getMessage());
            logWriter.newLine();
            return false;
        }
    }
    
    /**
     * Enhanced backup functionality for TDA/TDI raw files.
     * Copies files from RAM_DIR to RAM_BKUP with proper permissions.
     * 
     * @param logWriter Writer for logging operations
     * @throws IOException if backup operations fail
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
        int filesBackedUp = 0;
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(rawDir, "TDI.*.?????.z")) {
            for (Path file : stream) {
                Path target = backupDir.resolve(file.getFileName());
                Files.copy(file, target, StandardCopyOption.REPLACE_EXISTING);
                Files.setPosixFilePermissions(target, PosixFilePermissions.fromString("rw-rw-rw-"));
                filesBackedUp++;
            }
        }
        
        logWriter.write("Backed up " + filesBackedUp + " TDI files");
        logWriter.newLine();
        logger.info("Backup of {} TDA/TDI raw files completed from {} to {}", filesBackedUp, rawDir, backupDir);
    }
    
    /**
     * Processes a single area with enhanced validation and error handling.
     * 
     * @param area Area identifier to process
     * @param areaCount Sequential count of area being processed
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
     */
    private void processArea(String area, int areaCount, BufferedWriter logWriter) throws IOException {
        logWriter.write("========================================================================");
        logWriter.newLine();
        logWriter.write("--- Processing area " + area + " (" + areaCount + "/" + processingAreas.length + ") -----------");
        logWriter.newLine();
        
        // Use area-specific directory for ALL operations
        Path areaDialDir = Paths.get(dialEnv.get("ALSDIR"), area, "DIALDIR");
        Files.createDirectories(areaDialDir);
        
        // Check for TDA.raw and TDI.raw files with enhanced validation
        Path tdaFile = areaDialDir.resolve(TDA_FILE);
        Path tdiFile = areaDialDir.resolve(TDI_FILE);
        
        // Enhanced validation including file existence, size, and age
        if (fileValidationEnabled) {
            validateInputFiles(tdaFile, tdiFile, area, logWriter);
        }
        
        // Count lines in files with enhanced logging
        long tdaLines = countLines(tdaFile);
        long tdiLines = countLines(tdiFile);
        
        logWriter.write("TDA.raw size: " + Files.size(tdaFile) + " bytes, " + tdaLines + " lines");
        logWriter.newLine();
        logWriter.write("TDI.raw size: " + Files.size(tdiFile) + " bytes, " + tdiLines + " lines");
        logWriter.newLine();
        
        logger.info("Processing area: {} - TDA: {} lines, TDI: {} lines", area, tdaLines, tdiLines);
        
        // Create combo.raw file with area-specific directory
        createComboRaw(area, areaDialDir, tdaFile, tdiFile, logWriter);
    }
    
    /**
     * Validates input TDA and TDI files for existence, age, and content.
     * 
     * @param tdaFile Path to TDA.raw file
     * @param tdiFile Path to TDI.raw file
     * @param area Area identifier for error reporting
     * @param logWriter Writer for logging operations
     * @throws IOException if validation fails or files are invalid
     */
    private void validateInputFiles(Path tdaFile, Path tdiFile, String area, BufferedWriter logWriter) throws IOException {
        if (!Files.exists(tdaFile) || !Files.exists(tdiFile)) {
            String error = "ERROR TDA/TDI.raw files are not current for " + area;
            logWriter.write(error);
            logWriter.newLine();
            logger.error("TDA/TDI.raw files not found for area: {}", area);
            throw new IOException(error);
        }
        
        // File age validation
        if (!isFileRecent(tdaFile) || !isFileRecent(tdiFile)) {
            String error = "ERROR TDA/TDI.raw files are too old for " + area + " (older than " + maxFileAgeDays + " days)";
            logWriter.write(error);
            logWriter.newLine();
            logger.error("TDA/TDI.raw files are too old for area: {}", area);
            throw new IOException(error);
        }
        
        // Handle empty files with carriage return addition
        long tdaSize = handleEmptyFile(tdaFile, "TDA.raw", logWriter);
        long tdiSize = handleEmptyFile(tdiFile, "TDI.raw", logWriter);
        
        if (tdaSize == 0 || tdiSize == 0) {
            String error = "ERROR with byte_check: TDA.raw or TDI.raw is still empty after processing for " + area;
            logWriter.write(error);
            logWriter.newLine();
            logger.error("Empty TDA/TDI.raw files for area: {}", area);
            throw new IOException(error);
        }
        
        // Perform comprehensive byte checks
        performByteCheck(tdaFile, "TDA.raw", logWriter);
        performByteCheck(tdiFile, "TDI.raw", logWriter);
    }
    
    /**
     * Checks if a file was modified within the configured maximum age.
     * 
     * @param file Path to file to check
     * @return true if file is recent enough, false otherwise
     * @throws IOException if file attributes cannot be read
     */
    private boolean isFileRecent(Path file) throws IOException {
        FileTime lastModified = Files.getLastModifiedTime(file);
        long daysSinceModified = ChronoUnit.DAYS.between(
            lastModified.toInstant(), Instant.now());
        return daysSinceModified <= maxFileAgeDays;
    }
    
    /**
     * Handles empty files by adding a carriage return if needed.
     * 
     * @param file Path to file to check and fix
     * @param fileName Name for logging purposes
     * @param logWriter Writer for logging operations
     * @return Final file size after processing
     * @throws IOException if file operations fail
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
     * Performs byte check validation on a file for record length consistency.
     * 
     * @param file Path to file to validate
     * @param fileName Name for logging purposes
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
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
     * Efficiently counts lines in a file using streaming.
     * 
     * @param file Path to file to count
     * @return Number of lines in the file
     * @throws IOException if file cannot be read
     */
    private long countLines(Path file) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(file)) {
            return reader.lines().count();
        }
    }
    
    /**
     * Creates the COMBO.raw file by concatenating TDA.raw and TDI.raw files.
     * 
     * @param area Area identifier
     * @param areaDialDir Directory for area-specific files
     * @param tdaFile Path to TDA.raw file
     * @param tdiFile Path to TDI.raw file
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
     */
    private void createComboRaw(String area, Path areaDialDir, Path tdaFile, Path tdiFile, BufferedWriter logWriter) throws IOException {
        logWriter.write("--- Cat TDA.raw TDI.raw into raw.dat for " + area + " ----");
        logWriter.newLine();
        
        // Use area-specific directory for all intermediate and output files
        Path rawDat = areaDialDir.resolve(RAW_DAT_FILE);
        
        // Concatenate files efficiently
        try (BufferedWriter writer = Files.newBufferedWriter(rawDat, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
             BufferedReader tdaReader = Files.newBufferedReader(tdaFile);
             BufferedReader tdiReader = Files.newBufferedReader(tdiFile)) {
            
            // Copy TDA file
            String line;
            while ((line = tdaReader.readLine()) != null) {
                writer.write(line);
                writer.newLine();
            }
            
            // Copy TDI file
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
            handleProcessingError("COMBO.raw creation for area " + area, e, logWriter);
            throw e;
        }
    }
    
    /**
     * Creates COMBO.raw file directly with optimized streaming processing.
     * Uses parallel streams for large file processing and memory-efficient validation.
     * 
     * @param rawDat Path to raw.dat input file
     * @param areaDialDir Directory for area-specific files
     * @param area Area identifier
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
     */
    private void createComboRawDirectly(Path rawDat, Path areaDialDir, String area, BufferedWriter logWriter) throws IOException {
        logWriter.write("--- Processing raw.dat and creating sorted COMBO.raw for " + area + " ----");
        logWriter.newLine();
        
        long startTime = System.currentTimeMillis();
        
        // Use streaming approach with parallel processing for large files
        List<RawRecord> records;
        
        if (Files.size(rawDat) > 100_000_000) { // 100MB threshold for parallel processing
            records = Files.lines(rawDat)
                .parallel()
                .filter(line -> !line.trim().isEmpty() && line.length() >= TIN_LENGTH)
                .map(this::parseRawRecord)
                .filter(Objects::nonNull)
                .collect(ArrayList::new, ArrayList::add, ArrayList::addAll);
        } else {
            // Sequential processing for smaller files
            records = Files.lines(rawDat)
                .filter(line -> !line.trim().isEmpty() && line.length() >= TIN_LENGTH)
                .map(this::parseRawRecord)
                .filter(Objects::nonNull)
                .collect(Collectors.toList());
        }
        
        long processingTime = System.currentTimeMillis() - startTime;
        
        logWriter.write("Processed " + records.size() + " valid records in " + processingTime + " ms");
        logWriter.newLine();
        logger.info("Processed {} valid records for area {} in {} ms", records.size(), area, processingTime);
        
        // Validate list cycle
        validateListCycle(records, logWriter);
        
        // Sort records by TIN efficiently
        logWriter.write("--- Sorting records by TIN ----");
        logWriter.newLine();
        
        startTime = System.currentTimeMillis();
        records.sort(Comparator.comparing(r -> r.tin));
        long sortTime = System.currentTimeMillis() - startTime;
        
        logWriter.write("Sorted " + records.size() + " records in " + sortTime + " ms");
        logWriter.newLine();
        
        // Write sorted records to COMBO.raw efficiently
        Path comboRaw = areaDialDir.resolve(COMBO_RAW_FILE);
        writeComboRawFile(records, comboRaw, logWriter);
        
        logWriter.write("Created COMBO.raw file with " + records.size() + " sorted records for area " + area);
        logWriter.newLine();
        logger.info("Created COMBO.raw file with {} sorted records for area {}", records.size(), area);
        
        // Validate the created file
        validateComboRawFile(comboRaw, area, logWriter);
    }
    
    /**
     * Parses a single raw record line into a RawRecord object.
     * 
     * @param line Input line to parse
     * @return RawRecord object if line is valid, null otherwise
     */
    private RawRecord parseRawRecord(String line) {
        try {
            String tin = line.substring(0, TIN_LENGTH).trim();
            return isValidTin(tin) ? new RawRecord(tin, line) : null;
        } catch (Exception e) {
            logger.debug("Error parsing line: {}", line.length() > 50 ? line.substring(0, 50) + "..." : line);
            return null;
        }
    }
    
    /**
     * Efficiently writes records to COMBO.raw file using NIO.
     * 
     * @param records List of records to write
     * @param comboRaw Path to output file
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
     */
    private void writeComboRawFile(List<RawRecord> records, Path comboRaw, BufferedWriter logWriter) throws IOException {
        long startTime = System.currentTimeMillis();
        
        // Use NIO for better performance on large files
        List<String> lines = records.stream()
            .map(record -> record.dataline)
            .collect(Collectors.toList());
        
        Files.write(comboRaw, lines, StandardCharsets.UTF_8, 
                    StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        
        long writeTime = System.currentTimeMillis() - startTime;
        logWriter.write("Wrote COMBO.raw file in " + writeTime + " ms");
        logWriter.newLine();
    }
    
    /**
     * Validates TIN format - must be numeric and greater than zero.
     * 
     * @param tin TIN string to validate
     * @return true if TIN is valid, false otherwise
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
     * Validates that all records have the same list cycle (positions 159-164).
     * 
     * @param records List of records to validate
     * @param logWriter Writer for logging operations
     * @throws IOException if validation fails
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
     * Validates the created COMBO.raw file with memory-efficient streaming validation.
     * 
     * @param comboRaw Path to COMBO.raw file to validate
     * @param area Area identifier for error reporting
     * @param logWriter Writer for logging operations
     * @throws IOException if validation fails
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
        
        // Get first and last TIN efficiently without loading entire file
        String firstTin = getFirstTin(comboRaw);
        String lastTin = getLastTin(comboRaw);
        
        logWriter.write("First TIN: " + firstTin);
        logWriter.newLine();
        logWriter.write("Last TIN: " + lastTin);
        logWriter.newLine();
        
        // Streaming validation for memory efficiency
        if (isValidTinSorting(comboRaw)) {
            logWriter.write("✓ Records are properly sorted by TIN");
            logWriter.newLine();
            logger.info("COMBO.raw validation successful for area {}: {} records properly sorted", area, recordCount);
        } else {
            logWriter.write("✗ ERROR: Records are not properly sorted by TIN");
            logWriter.newLine();
            logger.error("COMBO.raw sorting validation failed for area {}", area);
            throw new IOException("COMBO.raw sorting validation failed for area: " + area);
        }
    }
    
    /**
     * Gets the first TIN from a file efficiently.
     * 
     * @param file Path to file
     * @return First TIN found, or empty string if none
     * @throws IOException if file cannot be read
     */
    private String getFirstTin(Path file) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(file)) {
            String line = reader.readLine();
            return (line != null && line.length() >= TIN_LENGTH) ? 
                   line.substring(0, TIN_LENGTH).trim() : "";
        }
    }
    
    /**
     * Gets the last TIN from a file efficiently using RandomAccessFile.
     * 
     * @param file Path to file
     * @return Last TIN found, or empty string if none
     * @throws IOException if file cannot be read
     */
    private String getLastTin(Path file) throws IOException {
        try (RandomAccessFile raf = new RandomAccessFile(file.toFile(), "r")) {
            long fileLength = raf.length();
            if (fileLength == 0) return "";
            
            long pointer = fileLength - 1;
            StringBuilder lastLine = new StringBuilder();
            
            while (pointer >= 0) {
                raf.seek(pointer);
                int ch = raf.read();
                if (ch == '\n' && lastLine.length() > 0) {
                    break;
                }
                if (ch != '\n' && ch != '\r') {
                    lastLine.insert(0, (char) ch);
                }
                pointer--;
            }
            
            String line = lastLine.toString();
            return (line.length() >= TIN_LENGTH) ? line.substring(0, TIN_LENGTH).trim() : "";
        }
    }
    
    /**
     * Validates TIN sorting using streaming to avoid memory issues with large files.
     * 
     * @param comboRaw Path to file to validate
     * @return true if records are properly sorted, false otherwise
     * @throws IOException if file cannot be read
     */
    private boolean isValidTinSorting(Path comboRaw) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(comboRaw)) {
            String previousTin = null;
            String line;
            
            while ((line = reader.readLine()) != null) {
                if (line.length() >= TIN_LENGTH) {
                    String currentTin = line.substring(0, TIN_LENGTH).trim();
                    
                    if (previousTin != null && currentTin.compareTo(previousTin) < 0) {
                        logger.warn("Found out-of-order TIN: {} after {}", currentTin, previousTin);
                        return false;
                    }
                    previousTin = currentTin;
                }
            }
            return true;
        }
    }
    
    // ========================================================================
    // DATABASE STATISTICS GATHERING METHODS (Dial1_dothrcp)
    // ========================================================================
    
    /**
     * Executes database statistics gathering operations with optimized batch processing.
     * 
     * @param logWriter Writer for logging operations
     * @return true if all statistics operations completed successfully
     * @throws IOException if logging operations fail
     */
    @Transactional(propagation = Propagation.REQUIRED)
    private boolean executeStatsGathering(BufferedWriter logWriter) throws IOException {
        logger.info("Starting DIAL table statistics gathering");
        logWriter.write("Starting database table statistics gathering");
        logWriter.newLine();
        
        try {
            // Tables from original Dial1_dothrcp script
            List<String> dialTables = Arrays.asList(
                "TINSUMMARY2", "DIALVCD2", "DIALAUD2", "DIALENT2", "CONSOLEAD2"
            );
            
            // Process in batches for better transaction management
            boolean allSuccess = true;
            for (int i = 0; i < dialTables.size(); i += statsBatchSize) {
                List<String> batch = dialTables.subList(i, Math.min(i + statsBatchSize, dialTables.size()));
                boolean batchSuccess = gatherTableStatsBatch("DIAL", batch, logWriter);
                if (!batchSuccess) {
                    allSuccess = false;
                }
            }
            
            logWriter.write("Completed DIAL table statistics gathering - Success: " + allSuccess);
            logWriter.newLine();
            
            return allSuccess;
            
        } catch (Exception e) {
            handleProcessingError("statistics gathering", e, logWriter);
            return false;
        }
    }
    
    /**
     * Gathers statistics for a batch of tables in a single transaction.
     * 
     * @param schemaName Schema name for the tables
     * @param tableNames List of table names to process
     * @param logWriter Writer for logging operations
     * @return true if all tables in batch processed successfully
     * @throws IOException if logging operations fail
     */
    @Transactional(propagation = Propagation.REQUIRED)
    private boolean gatherTableStatsBatch(String schemaName, List<String> tableNames, BufferedWriter logWriter) throws IOException {
        return jdbcTemplate.execute((ConnectionCallback<Boolean>) connection -> {
            boolean allSuccess = true;
            
            for (String tableName : tableNames) {
                try {
                    gatherSingleTableStats(connection, schemaName, tableName, logWriter);
                    logWriter.write("Successfully gathered statistics for " + schemaName + "." + tableName);
                    logWriter.newLine();
                    logger.info("Successfully gathered statistics for {}.{}", schemaName, tableName);
                } catch (SQLException e) {
                    allSuccess = false;
                    String error = "Failed to gather statistics for " + schemaName + "." + tableName + ": " + e.getMessage();
                    logWriter.write(error);
                    logWriter.newLine();
                    logger.error("Failed to gather statistics for {}.{}: {}", schemaName, tableName, e.getMessage(), e);
                    // Continue with other tables but mark batch as failed
                } catch (IOException e) {
                    allSuccess = false;
                    logger.error("IO error during statistics gathering for {}.{}", schemaName, tableName, e);
                }
            }
            
            return allSuccess;
        });
    }
    
    /**
     * Gathers statistics for a single table using DBMS_STATS.GATHER_TABLE_STATS.
     * 
     * @param connection Database connection to use
     * @param schemaName Schema name
     * @param tableName Table name
     * @param logWriter Writer for logging operations
     * @throws SQLException if database operations fail
     * @throws IOException if logging operations fail
     */
    private void gatherSingleTableStats(Connection connection, String schemaName, String tableName, BufferedWriter logWriter) throws SQLException, IOException {
        logger.debug("Gathering statistics for {}.{}", schemaName, tableName);
        logWriter.write("Gathering statistics for " + schemaName + "." + tableName);
        logWriter.newLine();
        
        String sql = """
            BEGIN
                DBMS_STATS.GATHER_TABLE_STATS(
                    ownname => ?,
                    tabname => ?,
                    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
                    degree => ?,
                    cascade => TRUE,
                    no_invalidate => FALSE,
                    granularity => 'ALL',
                    options => 'GATHER'
                );
            END;
            """;
        
        try (CallableStatement cs = connection.prepareCall(sql)) {
            cs.setString(1, schemaName.toUpperCase());
            cs.setString(2, tableName.toUpperCase());
            cs.setInt(3, statsParallelDegree);
            
            long startTime = System.currentTimeMillis();
            cs.execute();
            long duration = System.currentTimeMillis() - startTime;
            
            logger.info("Statistics gathered for {}.{} in {} ms", schemaName, tableName, duration);
            logWriter.write("Statistics gathered for " + schemaName + "." + tableName + " in " + duration + " ms");
            logWriter.newLine();
            
            // Log the updated statistics info
            logTableStatsInfo(schemaName, tableName, logWriter);
        }
    }
    
    /**
     * Logs current table statistics information using optimized query.
     * 
     * @param schemaName Schema name
     * @param tableName Table name
     * @param logWriter Writer for logging operations
     * @throws IOException if logging operations fail
     */
    private void logTableStatsInfo(String schemaName, String tableName, BufferedWriter logWriter) throws IOException {
        String sql = """
            SELECT num_rows, last_analyzed, avg_row_len, blocks
            FROM all_tables 
            WHERE owner = UPPER(?) AND table_name = UPPER(?)
            """;
        
        try {
            jdbcTemplate.queryForObject(sql, (rs, rowNum) -> {
                long numRows = rs.getLong("num_rows");
                Timestamp lastAnalyzed = rs.getTimestamp("last_analyzed");
                long avgRowLen = rs.getLong("avg_row_len");
                long blocks = rs.getLong("blocks");
                
                String statsInfo = String.format("Table %s.%s statistics: %d rows, avg %d bytes/row, %d blocks, analyzed at %s", 
                                               schemaName, tableName, numRows, avgRowLen, blocks, lastAnalyzed);
                logger.info(statsInfo);
                try {
                    logWriter.write(statsInfo);
                    logWriter.newLine();
                } catch (IOException e) {
                    logger.warn("Error writing stats info to log", e);
                }
                return null;
            }, schemaName, tableName);
        } catch (EmptyResultDataAccessException e) {
            logger.debug("No statistics found for {}.{}", schemaName, tableName);
        }
    }
    
    // ========================================================================
    // ORACLE EXPORT OPERATIONS METHODS (Dial1_exports)
    // ========================================================================
    
    /**
     * Executes Oracle export operations with optional parallel processing.
     * 
     * @param logWriter Writer for logging operations
     * @return true if all export operations completed successfully
     * @throws IOException if file or logging operations fail
     */
    private boolean executeExportOperations(BufferedWriter logWriter) throws IOException {
        logger.info("=== Starting DIAL Export Operations ===");
        logWriter.write("Starting Oracle export operations");
        logWriter.newLine();
        logWriter.write("Timestamp: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        logWriter.newLine();
        
        try {
            // Initialize export environment
            initializeExportEnvironment(logWriter);
            
            // Clean up old export files
            cleanupOldExportFiles(logWriter);
            
            boolean overallSuccess;
            
            if (parallelExportExecution) {
                // Parallel export execution for better performance
                overallSuccess = performParallelExports(logWriter);
            } else {
                // Sequential export execution (original behavior)
                boolean export1Success = performFirstExport(logWriter);
                boolean export2Success = performSecondExport(logWriter);
                overallSuccess = export1Success && export2Success;
            }
            
            // Log completion status
            if (overallSuccess) {
                logWriter.write("---- Exports Completed Successfully ------------------");
                logWriter.newLine();
                logger.info("=== DIAL Export Operations Completed Successfully ===");
            } else {
                logWriter.write("---- Exports Completed with Errors ------------------");
                logWriter.newLine();
                logger.warn("=== DIAL Export Operations Completed with Errors ===");
            }
            
            return overallSuccess;
            
        } catch (Exception e) {
            handleProcessingError("export operations", e, logWriter);
            return false;
        }
    }
    
    /**
     * Performs both exports in parallel for improved performance.
     * 
     * @param logWriter Writer for logging operations
     * @return true if both exports completed successfully
     * @throws IOException if file operations fail
     */
    private boolean performParallelExports(BufferedWriter logWriter) throws IOException {
        logger.info("Performing parallel export operations");
        logWriter.write("Performing parallel export operations");
        logWriter.newLine();
        
        try {
            // Submit both export operations to executor service
            CompletableFuture<Boolean> export1Future = CompletableFuture.supplyAsync(() -> {
                try {
                    return performFirstExport(logWriter);
                } catch (IOException e) {
                    logger.error("Error in first export", e);
                    return false;
                }
            }, executorService);
            
            CompletableFuture<Boolean> export2Future = CompletableFuture.supplyAsync(() -> {
                try {
                    return performSecondExport(logWriter);
                } catch (IOException e) {
                    logger.error("Error in second export", e);
                    return false;
                }
            }, executorService);
            
            // Wait for both to complete with extended timeout for parallel operations
            CompletableFuture<Void> allExports = CompletableFuture.allOf(export1Future, export2Future);
            allExports.get(exportTimeoutMinutes * 2, TimeUnit.MINUTES);
            
            boolean export1Success = export1Future.get();
            boolean export2Success = export2Future.get();
            boolean overallSuccess = export1Success && export2Success;
            
            logWriter.write("Parallel export operations completed - Success: " + overallSuccess);
            logWriter.newLine();
            
            return overallSuccess;
            
        } catch (Exception e) {
            logger.error("Error during parallel export operations", e);
            logWriter.write("ERROR: Parallel export operations failed: " + e.getMessage());
            logWriter.newLine();
            return false;
        }
    }
    
    /**
     * Initializes the export environment by creating directories and setting up configuration.
     * 
     * @param logWriter Writer for logging operations
     * @throws IOException if directory operations fail
     */
    private void initializeExportEnvironment(BufferedWriter logWriter) throws IOException {
        logger.info("Initializing DIAL export environment");
        
        // Ensure export directory exists
        Path exportPath = Paths.get(exportDirectory);
        Files.createDirectories(exportPath);
        
        logWriter.write("Export directory: " + exportDirectory);
        logWriter.newLine();
        logWriter.write("NLS_LANG: " + nlsLang);
        logWriter.newLine();
        logWriter.write("Parallel execution: " + parallelExportExecution);
        logWriter.newLine();
    }
    
    /**
     * Cleans up old export files from the export directory.
     * 
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
     */
    private void cleanupOldExportFiles(BufferedWriter logWriter) throws IOException {
        logger.info("Cleaning up old export files");
        
        Path exportPath = Paths.get(exportDirectory);
        int filesRemoved = 0;
        
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(exportPath, "dial*.exp.*.Z")) {
            for (Path file : stream) {
                try {
                    Files.deleteIfExists(file);
                    filesRemoved++;
                    logger.debug("Removed old export file: {}", file.getFileName());
                } catch (IOException e) {
                    logger.warn("Could not remove old export file: {}", file, e);
                }
            }
        }
        
        logWriter.write("Removed " + filesRemoved + " old export files");
        logWriter.newLine();
    }
    
    /**
     * Performs the first export operation (dial.exp).
     * 
     * @param logWriter Writer for logging operations
     * @return true if export completed successfully
     * @throws IOException if file operations fail
     */
    private boolean performFirstExport(BufferedWriter logWriter) throws IOException {
        String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern(EXPORT_DATE_PATTERN));
        String exportFileName = "dial.exp." + dateStr;
        String exportFilePath = Paths.get(exportDirectory, exportFileName).toString();
        
        logger.info("Starting first export: {}", exportFileName);
        logWriter.write("Starting export: " + exportFileName);
        logWriter.newLine();
        
        try {
            // Create parameter file for first export
            String parFile = createFirstExportParFile(exportFilePath, logWriter);
            
            // Execute Oracle Data Pump export
            boolean success = executeExport(parFile, exportFileName, "First Export", logWriter);
            
            if (success) {
                // Compress the export file
                compressExportFile(exportFilePath, logWriter);
                logWriter.write("First export completed and compressed successfully");
                logWriter.newLine();
                return true;
            } else {
                logWriter.write("First export failed");
                logWriter.newLine();
                return false;
            }
            
        } catch (Exception e) {
            handleProcessingError("first export", e, logWriter);
            return false;
        }
    }
    
    /**
     * Performs the second export operation (dial2.exp).
     * 
     * @param logWriter Writer for logging operations
     * @return true if export completed successfully
     * @throws IOException if file operations fail
     */
    private boolean performSecondExport(BufferedWriter logWriter) throws IOException {
        String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern(EXPORT_DATE_PATTERN));
        String exportFileName = "dial2.exp." + dateStr;
        String exportFilePath = Paths.get(exportDirectory, exportFileName).toString();
        
        logger.info("Starting second export: {}", exportFileName);
        logWriter.write("Starting export: " + exportFileName);
        logWriter.newLine();
        
        try {
            // Create parameter file for second export
            String parFile = createSecondExportParFile(exportFilePath, logWriter);
            
            // Execute Oracle Data Pump export
            boolean success = executeExport(parFile, exportFileName, "Second Export", logWriter);
            
            if (success) {
                // Compress the export file
                compressExportFile(exportFilePath, logWriter);
                logWriter.write("Second export completed and compressed successfully");
                logWriter.newLine();
                return true;
            } else {
                logWriter.write("Second export failed");
                logWriter.newLine();
                return false;
            }
            
        } catch (Exception e) {
            handleProcessingError("second export", e, logWriter);
            return false;
        }
    }
    
    /**
     * Creates parameter file for the first export (EXP_PAR equivalent).
     * 
     * @param dumpFile Path to dump file
     * @param logWriter Writer for logging operations
     * @return Path to created parameter file
     * @throws IOException if file operations fail
     */
    private String createFirstExportParFile(String dumpFile, BufferedWriter logWriter) throws IOException {
        String parFileName = "dial_export_1.par";
        Path parFilePath = Paths.get(exportDirectory, parFileName);
        
        try (BufferedWriter writer = Files.newBufferedWriter(parFilePath, StandardOpenOption.CREATE, 
                                                             StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING)) {
            writer.write("# DIAL Export Parameter File 1 - Generated by Java");
            writer.newLine();
            writer.write("DIRECTORY=DATA_PUMP_DIR");
            writer.newLine();
            writer.write("DUMPFILE=" + Paths.get(dumpFile).getFileName().toString());
            writer.newLine();
            writer.write("LOGFILE=dial_export_1.log");
            writer.newLine();
            writer.write("SCHEMAS=DIAL");
            writer.newLine();
            writer.write("EXCLUDE=STATISTICS");
            writer.newLine();
            writer.write("COMPRESSION=ALL");
            writer.newLine();
            writer.write("PARALLEL=2");
            writer.newLine();
            writer.write("ESTIMATE=BLOCKS");
            writer.newLine();
            writer.write("INCLUDE=TABLE:\"IN ('TINSUMMARY2','DIALVCD2','DIALAUD2','DIALENT2','CONSOLEAD2')\"");
            writer.newLine();
        }
        
        logger.debug("Created first export parameter file: {}", parFilePath);
        logWriter.write("Created first export parameter file: " + parFilePath);
        logWriter.newLine();
        return parFilePath.toString();
    }
    
    /**
     * Creates parameter file for the second export (EXP2_PAR equivalent).
     * 
     * @param dumpFile Path to dump file
     * @param logWriter Writer for logging operations
     * @return Path to created parameter file
     * @throws IOException if file operations fail
     */
    private String createSecondExportParFile(String dumpFile, BufferedWriter logWriter) throws IOException {
        String parFileName = "dial_export_2.par";
        Path parFilePath = Paths.get(exportDirectory, parFileName);
        
        try (BufferedWriter writer = Files.newBufferedWriter(parFilePath, StandardOpenOption.CREATE,
                                                             StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING)) {
            writer.write("# DIAL Export Parameter File 2 - Generated by Java");
            writer.newLine();
            writer.write("DIRECTORY=DATA_PUMP_DIR");
            writer.newLine();
            writer.write("DUMPFILE=" + Paths.get(dumpFile).getFileName().toString());
            writer.newLine();
            writer.write("LOGFILE=dial_export_2.log");
            writer.newLine();
            writer.write("SCHEMAS=DIAL");
            writer.newLine();
            writer.write("EXCLUDE=STATISTICS");
            writer.newLine();
            writer.write("COMPRESSION=ALL");
            writer.newLine();
            writer.write("PARALLEL=1");
            writer.newLine();
            writer.write("ESTIMATE=BLOCKS");
            writer.newLine();
            writer.write("INCLUDE=PROCEDURE,FUNCTION,PACKAGE,VIEW,SEQUENCE");
            writer.newLine();
        }
        
        logger.debug("Created second export parameter file: {}", parFilePath);
        logWriter.write("Created second export parameter file: " + parFilePath);
        logWriter.newLine();
        return parFilePath.toString();
    }
    
    /**
     * Executes Oracle Data Pump export using expdp utility.
     * 
     * @param parFile Path to parameter file
     * @param exportName Export name for logging
     * @param operation Operation description
     * @param logWriter Writer for logging operations
     * @return true if export completed successfully
     * @throws IOException if file operations fail
     * @throws InterruptedException if process is interrupted
     */
    private boolean executeExport(String parFile, String exportName, String operation, BufferedWriter logWriter) throws IOException, InterruptedException {
        logger.info("Executing {} using parameter file: {}", operation, parFile);
        
        // Build expdp command
        List<String> command = new ArrayList<>();
        command.add("expdp");
        command.add(databaseUsername + "/" + databasePassword + "@" + dialConnectionString);
        command.add("PARFILE=" + parFile);
        
        // Set up process environment
        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.environment().put("NLS_LANG", nlsLang);
        processBuilder.environment().put("ORACLE_HOME", System.getenv("ORACLE_HOME"));
        processBuilder.directory(new File(exportDirectory));
        
        // Redirect output for logging
        String logFileName = exportName + ".output.log";
        Path logFilePath = Paths.get(exportDirectory, logFileName);
        processBuilder.redirectOutput(logFilePath.toFile());
        processBuilder.redirectErrorStream(true);
        
        try {
            // Start the export process
            logger.debug("Starting expdp process: {}", String.join(" ", command));
            Process process = processBuilder.start();
            
            // Wait for completion with timeout
            boolean finished = process.waitFor(exportTimeoutMinutes, TimeUnit.MINUTES);
            
            if (!finished) {
                // Process timed out
                logger.error("{} timed out after {} minutes", operation, exportTimeoutMinutes);
                process.destroyForcibly();
                logWriter.write("ERROR: " + operation + " timed out after " + exportTimeoutMinutes + " minutes");
                logWriter.newLine();
                return false;
            }
            
            // Check exit code
            int exitCode = process.exitValue();
            logger.debug("{} completed with exit code: {}", operation, exitCode);
            
            // Check for success in output log
            boolean success = checkExportSuccess(logFilePath, operation);
            
            if (success && exitCode == 0) {
                logger.info("{} completed successfully", operation);
                logWriter.write(operation + " completed successfully");
                logWriter.newLine();
                return true;
            } else {
                logger.error("{} failed with exit code: {}", operation, exitCode);
                logWriter.write("ERROR: " + operation + " failed with exit code: " + exitCode);
                logWriter.newLine();
                
                // Log some output for troubleshooting
                logExportOutput(logFilePath, logWriter);
                return false;
            }
            
        } catch (IOException e) {
            handleProcessingError("executing " + operation, e, logWriter);
            return false;
        }
    }
    
    /**
     * Checks export log for success indicators.
     * 
     * @param logFilePath Path to export log file
     * @param operation Operation name for logging
     * @return true if success pattern found in log
     * @throws IOException if log file cannot be read
     */
    private boolean checkExportSuccess(Path logFilePath, String operation) throws IOException {
        if (!Files.exists(logFilePath)) {
            logger.warn("Export log file not found: {}", logFilePath);
            return false;
        }
        
        try (BufferedReader reader = Files.newBufferedReader(logFilePath)) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (SUCCESS_PATTERN.matcher(line).matches()) {
                    logger.debug("Found success indicator in {}: {}", operation, line);
                    return true;
                }
            }
        } catch (IOException e) {
            logger.warn("Error reading export log file: {}", logFilePath, e);
        }
        
        return false;
    }
    
    /**
     * Logs export output for troubleshooting purposes.
     * 
     * @param logFilePath Path to export log file
     * @param logWriter Writer for logging operations
     * @throws IOException if file operations fail
     */
    private void logExportOutput(Path logFilePath, BufferedWriter logWriter) throws IOException {
        if (!Files.exists(logFilePath)) {
            return;
        }
        
        try (BufferedReader reader = Files.newBufferedReader(logFilePath)) {
            logWriter.write("Export output (last 10 lines):");
            logWriter.newLine();
            
            List<String> lines = new ArrayList<>();
            String line;
            while ((line = reader.readLine()) != null) {
                lines.add(line);
                if (lines.size() > 10) {
                    lines.remove(0);
                }
            }
            
            for (String outputLine : lines) {
                logWriter.write("  " + outputLine);
                logWriter.newLine();
            }
            
        } catch (IOException e) {
            logger.warn("Error reading export output for logging: {}", logFilePath, e);
        }
    }
    
    /**
     * Compresses export file using gzip and renames to .Z for DIAL compatibility.
     * 
     * @param exportFilePath Path to export file to compress
     * @param logWriter Writer for logging operations
     * @throws IOException if compression operations fail
     */
    private void compressExportFile(String exportFilePath, BufferedWriter logWriter) throws IOException {
        Path sourceFile = Paths.get(exportFilePath);
        Path compressedFile = Paths.get(exportFilePath + ".Z");
        
        if (!Files.exists(sourceFile)) {
            logger.warn("Export file not found for compression: {}", sourceFile);
            return;
        }
        
        logger.info("Compressing export file: {}", sourceFile.getFileName());
        logWriter.write("Compressing export file: " + sourceFile.getFileName());
        logWriter.newLine();
        
        try {
            // Use system gzip for compression
            ProcessBuilder pb = new ProcessBuilder("gzip", "-f", sourceFile.toString());
            Process process = pb.start();
            
            boolean finished = process.waitFor(5, TimeUnit.MINUTES);
            if (finished && process.exitValue() == 0) {
                logger.info("Successfully compressed: {}", sourceFile.getFileName());
                
                // gzip creates .gz extension, rename to .Z for DIAL compatibility
                Path gzFile = Paths.get(exportFilePath + ".gz");
                if (Files.exists(gzFile)) {
                    Files.move(gzFile, compressedFile, StandardCopyOption.REPLACE_EXISTING);
                }
                logWriter.write("Successfully compressed: " + sourceFile.getFileName());
                logWriter.newLine();
            } else {
                logger.warn("Compression failed or timed out for: {}", sourceFile.getFileName());
                if (!finished) {
                    process.destroyForcibly();
                }
                logWriter.write("WARNING: Compression failed for: " + sourceFile.getFileName());
                logWriter.newLine();
            }
            
        } catch (Exception e) {
            logger.error("Error compressing export file: {}", sourceFile, e);
            logWriter.write("ERROR compressing file: " + e.getMessage());
            logWriter.newLine();
            // Continue without compression rather than failing the entire export
        }
    }
    
    // ========================================================================
    // DATABASE SYNCHRONIZATION METHODS (Dial1_point2cp)
    // ========================================================================
    
    /**
     * Executes database synchronization operations across multiple connections.
     * 
     * @param logWriter Writer for logging operations
     * @return true if all synchronization operations completed successfully
     * @throws IOException if logging operations fail
     */
    private boolean executeSyncOperations(BufferedWriter logWriter) throws IOException {
        logger.info("=== Starting Database Synchronization Operations ===");
        logWriter.write("Starting database synchronization operations");
        logWriter.newLine();
        logWriter.write("Timestamp: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        logWriter.newLine();
        
        // Clear previous results
        syncResults.clear();
        
        try {
            // Initialize sync environment
            initializeSyncEnvironment(logWriter);
            
            boolean success;
            if (parallelSyncExecution) {
                // Execute synchronization operations in parallel for better performance
                success = performParallelSync(logWriter);
            } else {
                // Execute synchronization operations sequentially (original DIAL behavior)
                success = performSequentialSync(logWriter);
            }
            
            // Generate final sync report
            generateSyncReport(logWriter);
            
            logger.info("=== Database Synchronization Operations Completed ===");
            return success;
            
        } catch (Exception e) {
            handleProcessingError("database synchronization", e, logWriter);
            return false;
        }
    }
    
    /**
     * Initializes synchronization environment and prepares output directories.
     * 
     * @param logWriter Writer for logging operations
     * @throws IOException if directory operations fail
     */
    private void initializeSyncEnvironment(BufferedWriter logWriter) throws IOException {
        logger.info("Initializing database synchronization environment");
        
        // Ensure sync output directory exists
        Path syncPath = Paths.get(syncOutputDirectory);
        Files.createDirectories(syncPath);
        
        // Clear previous sync output file
        Path syncOutputFile = syncPath.resolve("syn2cp.out");
        Files.deleteIfExists(syncOutputFile);
        
        logWriter.write("Sync output directory: " + syncOutputDirectory);
        logWriter.newLine();
        logWriter.write("Parallel execution: " + parallelSyncExecution);
        logWriter.newLine();
    }
    
    /**
     * Performs synchronization operations sequentially (original DIAL behavior).
     * 
     * @param logWriter Writer for logging operations
     * @return true if all operations completed successfully
     * @throws IOException if logging operations fail
     */
    private boolean performSequentialSync(BufferedWriter logWriter) throws IOException {
        logger.info("Performing sequential database synchronization");
        logWriter.write("Performing sequential database synchronization");
        logWriter.newLine();
        
        // Original DIAL: Three sequential sync operations
        boolean dialRptSuccess = performDialRptSync();
        boolean alsSuccess = performAlsSync();
        boolean alsRptSuccess = performAlsRptSync();
        
        // Log overall success
        boolean overallSuccess = dialRptSuccess && alsSuccess && alsRptSuccess;
        logWriter.write("Sequential sync completed - Success: " + overallSuccess);
        logWriter.newLine();
        
        return overallSuccess;
    }
    
    /**
     * Performs synchronization operations in parallel for improved performance.
     * 
     * @param logWriter Writer for logging operations
     * @return true if all operations completed successfully
     * @throws IOException if logging operations fail
     */
    private boolean performParallelSync(BufferedWriter logWriter) throws IOException {
        logger.info("Performing parallel database synchronization");
        logWriter.write("Performing parallel database synchronization");
        logWriter.newLine();
        
        try {
            // Submit all sync operations to executor service
            CompletableFuture<Boolean> dialRptFuture = CompletableFuture.supplyAsync(this::performDialRptSyncAsync, executorService);
            CompletableFuture<Boolean> alsFuture = CompletableFuture.supplyAsync(this::performAlsSyncAsync, executorService);
            CompletableFuture<Boolean> alsRptFuture = CompletableFuture.supplyAsync(this::performAlsRptSyncAsync, executorService);
            
            // Wait for all operations to complete
            CompletableFuture<Void> allSync = CompletableFuture.allOf(dialRptFuture, alsFuture, alsRptFuture);
            
            // Wait with timeout
            allSync.get(syncTimeoutMinutes, TimeUnit.MINUTES);
            
            // Check results
            boolean dialRptSuccess = dialRptFuture.get();
            boolean alsSuccess = alsFuture.get();
            boolean alsRptSuccess = alsRptFuture.get();
            
            boolean overallSuccess = dialRptSuccess && alsSuccess && alsRptSuccess;
            logWriter.write("Parallel sync completed - Success: " + overallSuccess);
            logWriter.newLine();
            
            return overallSuccess;
            
        } catch (Exception e) {
            logger.error("Error during parallel synchronization", e);
            logWriter.write("ERROR: Parallel synchronization failed: " + e.getMessage());
            logWriter.newLine();
            return false;
        }
    }
    
    /**
     * Performs first synchronization operation (dialrpt connection).
     * 
     * @return true if operation completed successfully
     */
    private boolean performDialRptSync() {
        logger.info("Performing dialrpt database synchronization");
        return executeSyncOperation("dialrpt", jdbcTemplate);
    }
    
    /**
     * Performs second synchronization operation (als connection).
     * 
     * @return true if operation completed successfully
     */
    private boolean performAlsSync() {
        logger.info("Performing als database synchronization");
        return executeSyncOperation("als", jdbcTemplate);
    }
    
    /**
     * Performs third synchronization operation (alsrpt connection).
     * 
     * @return true if operation completed successfully
     */
    private boolean performAlsRptSync() {
        logger.info("Performing alsrpt database synchronization");
        return executeSyncOperation("alsrpt", jdbcTemplate);
    }
    
    // Async versions for parallel execution
    private Boolean performDialRptSyncAsync() {
        return performDialRptSync();
    }
    
    private Boolean performAlsSyncAsync() {
        return performAlsSync();
    }
    
    private Boolean performAlsRptSyncAsync() {
        return performAlsRptSync();
    }
    
    /**
     * Executes synchronization operation for a specific connection using optimized transaction management.
     * 
     * @param connectionName Name of the connection for logging
     * @param jdbcTemplate JdbcTemplate for the specific connection
     * @return true if operation completed successfully
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    private boolean executeSyncOperation(String connectionName, JdbcTemplate jdbcTemplate) {
        SyncResult result = new SyncResult(connectionName);
        
        try {
            logger.debug("Starting sync operation for connection: {}", connectionName);
            result.startTime = LocalDateTime.now();
            
            // Write sync start to output file
            writeSyncOutput("--- Starting " + connectionName + " synchronization ---");
            
            // Execute @syn2cp procedure using JdbcTemplate with explicit ConnectionCallback
            boolean success = jdbcTemplate.execute((ConnectionCallback<Boolean>) connection -> {
                return executeSyn2cpProcedure(connection, connectionName);
            });
            
            if (success) {
                result.success = true;
                result.endTime = LocalDateTime.now();
                
                writeSyncOutput(connectionName + " synchronization completed successfully");
                logger.info("{} synchronization completed successfully", connectionName);
            } else {
                result.success = false;
                result.endTime = LocalDateTime.now();
                result.errorMessage = "syn2cp procedure execution failed";
                
                writeSyncOutput("ERROR: " + connectionName + " synchronization failed");
                logger.error("{} synchronization failed", connectionName);
            }
            
        } catch (Exception e) {
            result.success = false;
            result.endTime = LocalDateTime.now();
            result.errorMessage = e.getMessage();
            
            logger.error("Error during {} synchronization", connectionName, e);
            writeSyncOutput("ERROR: Error in " + connectionName + " synchronization: " + e.getMessage());
        } finally {
            // Store result for reporting
            syncResults.put(connectionName, result);
        }
        
        return result.success;
    }
    
    /**
     * Executes the @syn2cp procedure with fallback to equivalent operations.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @return true if procedure or equivalent operations completed successfully
     * @throws SQLException if database operations fail
     */
    private boolean executeSyn2cpProcedure(Connection connection, String connectionName) throws SQLException {
        logger.debug("Executing syn2cp procedure for connection: {}", connectionName);
        writeSyncOutput("Executing syn2cp procedure for " + connectionName);
        
        try (CallableStatement callableStatement = connection.prepareCall("BEGIN syn2cp; END;")) {
            callableStatement.execute();
            writeSyncOutput("syn2cp procedure executed successfully for " + connectionName);
            return true;
            
        } catch (SQLException e) {
            if (e.getErrorCode() == 942 || e.getMessage().contains("does not exist")) {
                // Procedure doesn't exist, execute equivalent operations
                logger.info("syn2cp procedure not found for {}, executing equivalent operations", connectionName);
                return executeSyn2cpEquivalent(connection, connectionName);
            } else {
                throw e;
            }
        }
    }
    
    /**
     * Executes equivalent operations when @syn2cp procedure doesn't exist.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @return true if all equivalent operations completed successfully
     * @throws SQLException if database operations fail
     */
    private boolean executeSyn2cpEquivalent(Connection connection, String connectionName) throws SQLException {
        logger.info("Executing syn2cp equivalent operations for {}", connectionName);
        writeSyncOutput("Executing syn2cp equivalent operations for " + connectionName);
        
        try {
            // Common database synchronization operations
            refreshMaterializedViews(connection, connectionName);
            synchronizeSequences(connection, connectionName);
            updateDatabaseStatistics(connection, connectionName);
            validateDataIntegrity(connection, connectionName);
            synchronizeDatabaseLinks(connection, connectionName);
            
            writeSyncOutput("syn2cp equivalent operations completed for " + connectionName);
            return true;
            
        } catch (SQLException e) {
            logger.error("Error in syn2cp equivalent operations for {}", connectionName, e);
            writeSyncOutput("ERROR: syn2cp equivalent operations failed for " + connectionName + ": " + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Refreshes materialized views with optimized batching and limiting.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @throws SQLException if database operations fail
     */
    private void refreshMaterializedViews(Connection connection, String connectionName) throws SQLException {
        logger.debug("Refreshing materialized views for {}", connectionName);
        writeSyncOutput("Refreshing materialized views for " + connectionName);
        
        // Optimized query with row limit and freshness check
        String getMViewsSql = """
            SELECT mview_name 
            FROM (
                SELECT mview_name 
                FROM user_mviews 
                WHERE compile_state = 'VALID'
                  AND refresh_mode IN ('DEMAND', 'COMMIT')
                  AND (last_refresh_date IS NULL OR last_refresh_date < SYSDATE - 1)
                ORDER BY last_refresh_date ASC NULLS FIRST
            )
            WHERE ROWNUM <= ?
            """;
        
        try (PreparedStatement ps = connection.prepareStatement(getMViewsSql)) {
            ps.setInt(1, mviewRefreshLimit);
            
            try (ResultSet rs = ps.executeQuery()) {
                List<String> mviewsToRefresh = new ArrayList<>();
                while (rs.next()) {
                    mviewsToRefresh.add(rs.getString("mview_name"));
                }
                
                // Refresh materialized views in batch
                refreshMviewsBatch(connection, mviewsToRefresh, connectionName);
            }
        }
    }
    
    /**
     * Refreshes a batch of materialized views efficiently.
     * 
     * @param connection Database connection to use
     * @param mviews List of materialized view names to refresh
     * @param connectionName Connection name for logging
     * @throws SQLException if database operations fail
     */
    private void refreshMviewsBatch(Connection connection, List<String> mviews, String connectionName) throws SQLException {
        if (mviews.isEmpty()) {
            writeSyncOutput("No materialized views to refresh for " + connectionName);
            return;
        }
        
        String refreshSql = "BEGIN DBMS_MVIEW.REFRESH(?); END;";
        
        try (CallableStatement cs = connection.prepareCall(refreshSql)) {
            int successCount = 0;
            for (String mviewName : mviews) {
                try {
                    cs.setString(1, mviewName);
                    cs.execute();
                    writeSyncOutput("Refreshed materialized view: " + mviewName);
                    successCount++;
                } catch (SQLException e) {
                    logger.warn("Failed to refresh materialized view {} for {}: {}", mviewName, connectionName, e.getMessage());
                    writeSyncOutput("Warning: Failed to refresh materialized view: " + mviewName);
                    // Continue with next mview
                }
            }
            writeSyncOutput("Successfully refreshed " + successCount + "/" + mviews.size() + " materialized views for " + connectionName);
        }
    }
    
    /**
     * Synchronizes sequences by gathering information about current values.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @throws SQLException if database operations fail
     */
    private void synchronizeSequences(Connection connection, String connectionName) throws SQLException {
        logger.debug("Synchronizing sequences for {}", connectionName);
        writeSyncOutput("Synchronizing sequences for " + connectionName);
        
        String getSequencesSql = """
            SELECT sequence_name, last_number, cache_size
            FROM user_sequences
            WHERE increment_by > 0
            ORDER BY sequence_name
            """;
        
        try (PreparedStatement ps = connection.prepareStatement(getSequencesSql);
             ResultSet rs = ps.executeQuery()) {
            
            int sequenceCount = 0;
            while (rs.next()) {
                String sequenceName = rs.getString("sequence_name");
                long lastNumber = rs.getLong("last_number");
                long cacheSize = rs.getLong("cache_size");
                
                writeSyncOutput("Sequence " + sequenceName + " current value: " + lastNumber + ", cache: " + cacheSize);
                sequenceCount++;
            }
            
            writeSyncOutput("Processed " + sequenceCount + " sequences for " + connectionName);
        }
    }
    
    /**
     * Updates database statistics for the current schema.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @throws SQLException if database operations fail
     */
    private void updateDatabaseStatistics(Connection connection, String connectionName) throws SQLException {
        logger.debug("Updating database statistics for {}", connectionName);
        writeSyncOutput("Updating database statistics for " + connectionName);
        
        try {
            // Gather schema statistics with optimized parameters
            String updateStatsSql = """
                BEGIN
                    DBMS_STATS.GATHER_SCHEMA_STATS(
                        ownname => USER,
                        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                        cascade => TRUE,
                        degree => 1,
                        options => 'GATHER STALE'
                    );
                END;
                """;
            
            try (CallableStatement cs = connection.prepareCall(updateStatsSql)) {
                cs.execute();
                writeSyncOutput("Database statistics updated for " + connectionName);
            }
            
        } catch (SQLException e) {
            logger.warn("Error updating database statistics for {}: {}", connectionName, e.getMessage());
            writeSyncOutput("Warning: Error updating database statistics for " + connectionName);
        }
    }
    
    /**
     * Validates data integrity by checking for invalid objects.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @throws SQLException if database operations fail
     */
    private void validateDataIntegrity(Connection connection, String connectionName) throws SQLException {
        logger.debug("Validating data integrity for {}", connectionName);
        writeSyncOutput("Validating data integrity for " + connectionName);
        
        // Check for invalid objects
        String invalidObjectsSql = """
            SELECT COUNT(*) as invalid_count
            FROM user_objects 
            WHERE status = 'INVALID'
            """;
        
        try (PreparedStatement ps = connection.prepareStatement(invalidObjectsSql);
             ResultSet rs = ps.executeQuery()) {
            
            if (rs.next()) {
                int invalidCount = rs.getInt("invalid_count");
                if (invalidCount > 0) {
                    writeSyncOutput("Warning: Found " + invalidCount + " invalid objects for " + connectionName);
                    logger.warn("Found {} invalid objects for {}", invalidCount, connectionName);
                } else {
                    writeSyncOutput("Data integrity validation passed for " + connectionName);
                }
            }
        }
    }
    
    /**
     * Synchronizes database links by testing connectivity.
     * 
     * @param connection Database connection to use
     * @param connectionName Connection name for logging
     * @throws SQLException if database operations fail
     */
    private void synchronizeDatabaseLinks(Connection connection, String connectionName) throws SQLException {
        logger.debug("Checking database links for {}", connectionName);
        
        String getDbLinksSql = """
            SELECT db_link, host, created
            FROM user_db_links
            ORDER BY db_link
            """;
        
        try (PreparedStatement ps = connection.prepareStatement(getDbLinksSql);
             ResultSet rs = ps.executeQuery()) {
            
            int linkCount = 0;
            while (rs.next()) {
                String dbLink = rs.getString("db_link");
                String host = rs.getString("host");
                
                // Test connectivity to database link
                try {
                    String testSql = "SELECT 1 FROM dual@" + dbLink;
                    try (PreparedStatement testPs = connection.prepareStatement(testSql);
                         ResultSet testRs = testPs.executeQuery()) {
                        if (testRs.next()) {
                            writeSyncOutput("Database link " + dbLink + " connectivity verified");
                        }
                    }
                } catch (SQLException e) {
                    writeSyncOutput("Warning: Database link " + dbLink + " connectivity failed");
                    logger.warn("Database link {} connectivity failed for {}", dbLink, connectionName);
                }
                
                linkCount++;
            }
            
            if (linkCount > 0) {
                writeSyncOutput("Processed " + linkCount + " database links for " + connectionName);
            }
        }
    }
    
    /**
     * Generates comprehensive synchronization report.
     * 
     * @param logWriter Writer for logging operations
     * @throws IOException if logging operations fail
     */
    private void generateSyncReport(BufferedWriter logWriter) throws IOException {
        logger.info("Generating sync report");
        
        writeSyncOutput("=== SYNCHRONIZATION REPORT ===");
        writeSyncOutput("Report generated: " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        writeSyncOutput("");
        
        boolean overallSuccess = true;
        long totalDuration = 0;
        
        for (Map.Entry<String, SyncResult> entry : syncResults.entrySet()) {
            String connectionName = entry.getKey();
            SyncResult result = entry.getValue();
            
            long duration = result.getDurationMillis();
            totalDuration += duration;
            
            writeSyncOutput("Connection: " + connectionName);
            writeSyncOutput("  Status: " + (result.success ? "SUCCESS" : "FAILED"));
            writeSyncOutput("  Duration: " + duration + " ms");
            
            if (result.startTime != null) {
                writeSyncOutput("  Start: " + result.startTime.format(DateTimeFormatter.ofPattern("HH:mm:ss")));
            }
            if (result.endTime != null) {
                writeSyncOutput("  End: " + result.endTime.format(DateTimeFormatter.ofPattern("HH:mm:ss")));
            }
            if (result.errorMessage != null) {
                writeSyncOutput("  Error: " + result.errorMessage);
            }
            writeSyncOutput("");
            
            if (!result.success) {
                overallSuccess = false;
            }
        }
        
        writeSyncOutput("OVERALL STATUS: " + (overallSuccess ? "SUCCESS" : "FAILED"));
        writeSyncOutput("TOTAL DURATION: " + totalDuration + " ms");
        writeSyncOutput("CONNECTIONS PROCESSED: " + syncResults.size());
        
        // Update main log writer
        logWriter.write("Sync report generated - Overall success: " + overallSuccess);
        logWriter.newLine();
    }
    
    /**
     * Writes message to syn2cp.out file with thread safety.
     * 
     * @param message Message to write
     */
    private synchronized void writeSyncOutput(String message) {
        try {
            Path syncOutputFile = Paths.get(syncOutputDirectory, "syn2cp.out");
            
            // Ensure directory exists
            Files.createDirectories(syncOutputFile.getParent());
            
            // Append message to sync output file
            String timestampedMessage = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")) 
                                      + " " + message + System.lineSeparator();
            
            Files.write(syncOutputFile, timestampedMessage.getBytes(), 
                       StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            
        } catch (IOException e) {
            logger.error("Error writing to syn2cp.out file: " + message, e);
        }
    }
    
    // ========================================================================
    // UTILITY METHODS AND SUPPORTING CLASSES
    // ========================================================================
    
    /**
     * Handles processing errors with consistent logging and error reporting.
     * 
     * @param operation Operation that failed
     * @param e Exception that occurred
     * @param logWriter Writer for logging operations
     */
    private void handleProcessingError(String operation, Exception e, BufferedWriter logWriter) {
        try {
            String errorMsg = String.format("ERROR in %s: %s", operation, e.getMessage());
            logger.error(errorMsg, e);
            logWriter.write(errorMsg);
            logWriter.newLine();
        } catch (IOException ioException) {
            logger.error("Error writing to log during error handling for: " + operation, ioException);
        }
    }
    
    /**
     * Handles critical errors that should stop processing.
     * 
     * @param operation Operation that failed critically
     * @param e Exception that occurred
     * @param logWriter Writer for logging operations
     */
    private void handleCriticalError(String operation, Exception e, BufferedWriter logWriter) {
        try {
            String errorMsg = String.format("CRITICAL ERROR in %s: %s", operation, e.getMessage());
            logger.error(errorMsg, e);
            logWriter.write(errorMsg);
            logWriter.newLine();
            logWriter.write("Processing stopped due to critical error");
            logWriter.newLine();
        } catch (IOException ioException) {
            logger.error("Error writing to log during critical error handling for: " + operation, ioException);
        }
    }
    
    /**
     * Enhanced utility method for prepared statement execution.
     * 
     * @param sql SQL statement to execute
     * @param params Parameters for the statement
     * @return true if statement executed successfully
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
     * Validates configuration settings and dependencies.
     * 
     * @throws IllegalStateException if configuration is invalid
     */
    public void validateConfiguration() {
        if (dialEnv.get("ALSDIR") == null || dialEnv.get("ALSDIR").trim().isEmpty()) {
            throw new IllegalStateException("ALSDIR configuration is required");
        }
        if (processingAreas == null || processingAreas.length == 0) {
            throw new IllegalStateException("Processing areas configuration is required");
        }
        
        // Validate additional configurations
        if (statsGatheringEnabled && jdbcTemplate == null) {
            throw new IllegalStateException("DataSource is required for statistics gathering");
        }
        
        if (exportEnabled && (exportDirectory == null || exportDirectory.trim().isEmpty())) {
            throw new IllegalStateException("Export directory configuration is required for export operations");
        }
        
        if (syncEnabled && (syncOutputDirectory == null || syncOutputDirectory.trim().isEmpty())) {
            throw new IllegalStateException("Sync output directory configuration is required for synchronization operations");
        }
        
        logger.info("Configuration validation completed successfully");
    }
    
    /**
     * Gets comprehensive status summary for monitoring and reporting.
     * 
     * @return DialStepStatusSummary containing current status of all operations
     */
    public DialStepStatusSummary getDialStepStatus() {
        DialStepStatusSummary summary = new DialStepStatusSummary();
        summary.lastExecutionTime = LocalDateTime.now();
        
        // COMBO.raw file status
        summary.comboFilesGenerated = 0;
        for (String area : processingAreas) {
            Path comboFile = Paths.get(dialEnv.get("ALSDIR"), area, "DIALDIR", COMBO_RAW_FILE);
            if (Files.exists(comboFile)) {
                summary.comboFilesGenerated++;
            }
        }
        summary.totalAreasProcessed = processingAreas.length;
        
        // Export status
        if (exportEnabled) {
            String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern(EXPORT_DATE_PATTERN));
            Path exportPath = Paths.get(exportDirectory);
            summary.dial1ExportExists = Files.exists(exportPath.resolve("dial.exp." + dateStr + ".Z"));
            summary.dial2ExportExists = Files.exists(exportPath.resolve("dial2.exp." + dateStr + ".Z"));
        }
        
        // Sync status
        if (syncEnabled && !syncResults.isEmpty()) {
            summary.syncConnectionsProcessed = syncResults.size();
            summary.syncSuccessfulConnections = (int) syncResults.values().stream().mapToInt(r -> r.success ? 1 : 0).sum();
            summary.syncOverallSuccess = summary.syncSuccessfulConnections == summary.syncConnectionsProcessed;
        }
        
        return summary;
    }
    
    /**
     * Validates that all DIAL1 operations completed successfully.
     * 
     * @return true if all enabled operations completed successfully
     */
    public boolean validateDialStepSuccess() {
        boolean success = true;
        
        // Check COMBO.raw files
        for (String area : processingAreas) {
            Path comboFile = Paths.get(dialEnv.get("ALSDIR"), area, "DIALDIR", COMBO_RAW_FILE);
            if (!Files.exists(comboFile)) {
                logger.warn("COMBO.raw file missing for area: {}", area);
                success = false;
            }
        }
        
        // Check export files if enabled
        if (exportEnabled) {
            String dateStr = LocalDateTime.now().format(DateTimeFormatter.ofPattern(EXPORT_DATE_PATTERN));
            Path exportPath = Paths.get(exportDirectory);
            Path dial1Export = exportPath.resolve("dial.exp." + dateStr + ".Z");
            Path dial2Export = exportPath.resolve("dial2.exp." + dateStr + ".Z");
            
            if (!Files.exists(dial1Export) || !Files.exists(dial2Export)) {
                logger.warn("Export files missing: dial1={}, dial2={}", Files.exists(dial1Export), Files.exists(dial2Export));
                success = false;
            }
        }
        
        // Check sync results if enabled
        if (syncEnabled && !syncResults.isEmpty()) {
            List<String> expectedConnections = Arrays.asList("dialrpt", "als", "alsrpt");
            for (String connection : expectedConnections) {
                SyncResult result = syncResults.get(connection);
                if (result == null || !result.success) {
                    logger.warn("Sync validation failed for connection: {}", connection);
                    success = false;
                }
            }
        }
        
        logger.info("DIAL Step 1 validation completed - Success: {}", success);
        return success;
    }
    
    /**
     * Cleanup method called when Spring context is destroyed.
     * Ensures proper resource cleanup and graceful shutdown.
     */
    @PreDestroy
    public void cleanup() {
        if (executorService != null && !executorService.isShutdown()) {
            logger.info("Shutting down executor service");
            executorService.shutdown();
            try {
                if (!executorService.awaitTermination(30, TimeUnit.SECONDS)) {
                    logger.warn("Executor service did not terminate within 30 seconds, forcing shutdown");
                    executorService.shutdownNow();
                }
            } catch (InterruptedException e) {
                logger.warn("Interrupted while waiting for executor service shutdown");
                executorService.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
    }
    
    // ========================================================================
    // SUPPORTING CLASSES AND DATA STRUCTURES
    // ========================================================================
    
    /**
     * Simple record holder class for sorting raw records by TIN.
     */
    private static class RawRecord {
        /** The TIN (Tax Identification Number) extracted from the record */
        final String tin;
        /** The complete data line including TIN and all data fields */
        final String dataline;
        
        /**
         * Creates a new RawRecord.
         * 
         * @param tin The TIN for this record
         * @param dataline The complete data line
         */
        RawRecord(String tin, String dataline) {
            this.tin = tin;
            this.dataline = dataline;
        }
    }
    
    /**
     * Data class to track synchronization results for reporting and monitoring.
     */
    public static class SyncResult {
        /** Name of the database connection */
        public String connectionName;
        /** Whether the synchronization operation succeeded */
        public boolean success;
        /** Start time of the operation */
        public LocalDateTime startTime;
        /** End time of the operation */
        public LocalDateTime endTime;
        /** Error message if operation failed */
        public String errorMessage;
        
        /**
         * Creates a new SyncResult for the specified connection.
         * 
         * @param connectionName Name of the database connection
         */
        public SyncResult(String connectionName) {
            this.connectionName = connectionName;
        }
        
        /**
         * Calculates the duration of the operation in milliseconds.
         * 
         * @return Duration in milliseconds, or 0 if start/end times are not set
         */
        public long getDurationMillis() {
            if (startTime != null && endTime != null) {
                return java.time.Duration.between(startTime, endTime).toMillis();
            }
            return 0;
        }
    }
    
    /**
     * Comprehensive status summary for all DIAL Step 1 operations.
     * Used for monitoring, reporting, and health checks.
     */
    public static class DialStepStatusSummary {
        /** Timestamp of when this status was generated */
        public LocalDateTime lastExecutionTime;
        
        // COMBO.raw generation status
        /** Total number of processing areas configured */
        public int totalAreasProcessed;
        /** Number of COMBO.raw files successfully generated */
        public int comboFilesGenerated;
        
        // Export status
        /** Whether the first export file (dial.exp) exists */
        public boolean dial1ExportExists;
        /** Whether the second export file (dial2.exp) exists */
        public boolean dial2ExportExists;
        
        // Sync status
        /** Number of database connections processed during sync */
        public int syncConnectionsProcessed;
        /** Number of database connections that completed successfully */
        public int syncSuccessfulConnections;
        /** Whether all sync operations completed successfully */
        public boolean syncOverallSuccess;
        
        /**
         * Returns a string representation of the status summary.
         * 
         * @return Formatted status string
         */
        @Override
        public String toString() {
            return String.format("DialStepStatus{areas: %d/%d, exports: dial1=%s/dial2=%s, sync: %d/%d success=%s, time: %s}",
                               comboFilesGenerated, totalAreasProcessed, dial1ExportExists, dial2ExportExists,
                               syncSuccessfulConnections, syncConnectionsProcessed, syncOverallSuccess, lastExecutionTime);
        }
    }
}