package com.dial.services.acquisition;

import com.dial.core.config.DialEnvironmentConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

/**
 * Implementation of the Dial1_crRAW shell script functionality.
 * Creates COMBO.raw files by processing TDA.raw and TDI.raw files.
 */
@Component
public class ComboFileGenerator implements Tasklet {
    private static final Logger logger = LoggerFactory.getLogger(ComboFileGenerator.class);
    
    private final JdbcTemplate jdbcTemplate;
    private final Map<String, String> dialEnv;
    private final String[] processingAreas;
    private final boolean backupEnabled;
    
    @Value("${dial.log.path}")
    private String logPath;
    
    @Value("${dial.job.chunk-size:1000}")
    private int chunkSize;
    
    @Value("${dial.file.validation.enabled:true}")
    private boolean fileValidationEnabled;
    
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
            
            // Process each area
            AtomicInteger counter = new AtomicInteger(0);
            Arrays.stream(processingAreas).forEach(area -> {
                try {
                    processArea(area, counter.incrementAndGet(), logWriter);
                } catch (Exception e) {
                    logger.error("Error processing area {}", area, e);
                    try {
                        logWriter.write("ERROR processing area " + area + ": " + e.getMessage());
                        logWriter.newLine();
                    } catch (IOException ioe) {
                        logger.error("Error writing to log", ioe);
                    }
                }
            });
            
            // Log completion
            logWriter.write("--- Step #1 - Creation of COMBO.raw files COMPLETED -----");
            logWriter.newLine();
            
            return RepeatStatus.FINISHED;
        }
    }
    
    private void backupRawFiles(BufferedWriter logWriter) throws IOException {
        logWriter.write("#------cp last weeks TDA/TDI rawfiles from RAW_DIR to RAW_BKUP ---------");
        logWriter.newLine();
        
        Path rawDir = Paths.get(dialEnv.get("RAW_DIR"));
        Path backupDir = Paths.get(dialEnv.get("RAW_BKUP"));
        
        Files.createDirectories(backupDir);
        
        // Delete existing backup files if they exist
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(backupDir, "*.????.z")) {
            for (Path file : stream) {
                Files.deleteIfExists(file);
            }
        }
        
        // Copy TDI files to backup
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(rawDir, "TDI.*.????.z")) {
            for (Path file : stream) {
                Path target = backupDir.resolve(file.getFileName());
                Files.copy(file, target, StandardCopyOption.REPLACE_EXISTING);
                Files.setPosixFilePermissions(target, PosixFilePermissions.fromString("rw-rw-rw-"));
            }
        }
        
        logger.info("Backup of TDA/TDI raw files completed from {} to {}", rawDir, backupDir);
    }
    
    private void processArea(String area, int areaCount, BufferedWriter logWriter) throws IOException {
        logWriter.write("********************************************************");
        logWriter.newLine();
        logWriter.write("--- Running byte_check on " + area + " ----------");
        logWriter.newLine();
        
        Path dialDir = Paths.get(dialEnv.get("ALSDIR"), area, "DIALDIR");
        Files.createDirectories(dialDir);
        
        // Check for TDA.raw and TDI.raw files
        Path tdaFile = dialDir.resolve("TDA.raw");
        Path tdiFile = dialDir.resolve("TDI.raw");
        
        if (fileValidationEnabled && (!Files.exists(tdaFile) || !Files.exists(tdiFile))) {
            logWriter.write("ERROR TDA/TDI.raw files are not current for " + area);
            logWriter.newLine();
            logger.error("TDA/TDI.raw files not found for area: {}", area);
            return;
        }
        
        // Check file sizes
        long tdaSize = Files.size(tdaFile);
        long tdiSize = Files.size(tdiFile);
        
        if (fileValidationEnabled && (tdaSize == 0 || tdiSize == 0)) {
            logWriter.write("ERROR with byte_check: " + dialDir + " TDA.raw or TDI.raw is empty or missing");
            logWriter.newLine();
            logger.error("Empty TDA/TDI.raw files for area: {}", area);
            return;
        }
        
        // Count lines in files
        long tdaLines = countLines(tdaFile);
        long tdiLines = countLines(tdiFile);
        
        logWriter.write("ls -l TDA.raw TDI.raw");
        logWriter.newLine();
        logWriter.write("TDA.raw size: " + tdaSize + " bytes, " + tdaLines + " lines");
        logWriter.newLine();
        logWriter.write("TDI.raw size: " + tdiSize + " bytes, " + tdiLines + " lines");
        logWriter.newLine();
        
        logger.info("Processing area: {} - TDA: {} lines, TDI: {} lines", area, tdaLines, tdiLines);
        
        // Create combo.raw file
        createComboRaw(area, tdaFile, tdiFile, logWriter);
    }
    
    private long countLines(Path file) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(file)) {
            return reader.lines().count();
        }
    }
    
    private void createComboRaw(String area, Path tdaFile, Path tdiFile, BufferedWriter logWriter) throws IOException {
        
        logWriter.write("--- Cat TDA.raw TDI.raw into raw.dat for " + area + "----");
        logWriter.newLine();
        
        // Concatenate TDA.raw and TDI.raw into raw.dat
        Path rawDat = Paths.get(dialEnv.get("DIALDIR"), "raw.dat");
        try (BufferedWriter writer = Files.newBufferedWriter(rawDat);
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
        
        // Create RAWDATA table
        logWriter.write("--- Creating Rawdata table for " + area + " ----");
        logWriter.newLine();
        
        try {
            // Use transaction to group operations
            jdbcTemplate.execute(conn -> {
                try (var stmt = conn.createStatement()) {
                    stmt.execute("DROP TABLE rawdata IF EXISTS");
                    stmt.execute("CREATE TABLE rawdata (tin VARCHAR(11), dataline VARCHAR(660))");
                    return null;
                }
            });
            
            // Create control file for SQL Loader
            Path ctlFile = Paths.get(dialEnv.get("DIALDIR"), "raw.ctl");
            try (BufferedWriter writer = Files.newBufferedWriter(ctlFile)) {
                writer.write("load data");
                writer.newLine();
                writer.write("infile 'raw.dat'");
                writer.newLine();
                writer.write("into table RAWDATA");
                writer.newLine();
                writer.write("(tin position(11:21), dataline position(001:660))");
                writer.newLine();
            }
            
            // Load data into table using Spring JDBC batch processing
            logWriter.write("--- Running sqlloader for " + area + " ----");
            logWriter.newLine();
            
            // Process in chunks based on configured chunk size
            List<Object[]> batchArgs = new ArrayList<>();
            try (BufferedReader reader = Files.newBufferedReader(rawDat)) {
                reader.lines()
                    .filter(l -> !l.isEmpty())
                    .forEach(l -> {
                        String tin = l.length() >= 21 ? l.substring(10, 21) : "";
                        batchArgs.add(new Object[]{tin, l});
                        
                        // When batch is full, execute it
                        if (batchArgs.size() >= chunkSize) {
                            jdbcTemplate.batchUpdate(
                                "INSERT INTO rawdata (tin, dataline) VALUES (?, ?)",
                                batchArgs
                            );
                            batchArgs.clear();
                            logger.debug("Loaded batch of {} records for area {}", chunkSize, area);
                        }
                    });
                
                // Execute any remaining items in the batch
                if (!batchArgs.isEmpty()) {
                    jdbcTemplate.batchUpdate(
                        "INSERT INTO rawdata (tin, dataline) VALUES (?, ?)",
                        batchArgs
                    );
                    logger.debug("Loaded final batch of {} records for area {}", batchArgs.size(), area);
                }
            }
            
            // Create COMBO.raw file from RAWDATA sorted by tin
            logWriter.write("--- Create COMBO.raw from rawdata sorted by tin ----");
            logWriter.newLine();
            
            List<String> datalines = jdbcTemplate.queryForList(
                "SELECT dataline FROM rawdata WHERE tin > 0 ORDER BY tin",
                String.class
            );
            
            Path comboRaw = Paths.get(dialEnv.get("DIALDIR"), "COMBO.raw");
            try (BufferedWriter writer = Files.newBufferedWriter(comboRaw)) {
                for (String dataline : datalines) {
                    writer.write(dataline);
                    writer.newLine();
                }
            }
            
            // Cleanup in the same transaction
            jdbcTemplate.execute("DROP TABLE rawdata");
            
            logger.info("Created COMBO.raw file with {} records for area {}", datalines.size(), area);
            
            // Rest of the method...
            
        } catch (Exception e) {
            logWriter.write("Error creating COMBO.raw: " + e.getMessage());
            logWriter.newLine();
            logger.error("Error creating COMBO.raw for area {}", area, e);
            throw e;
        }
    }
}