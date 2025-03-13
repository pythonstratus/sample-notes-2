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
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import javax.sql.DataSource;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.zip.GZIPOutputStream;

/**
 * Implementation of the Dial1_exports shell script functionality.
 * Creates ALS Export Files.
 */
@Service
public class ExportService implements Tasklet {
    private static final Logger logger = LoggerFactory.getLogger(ExportService.class);
    
    private final JdbcTemplate jdbcTemplate;
    private final Map<String, String> dialEnv;
    private final Path dialPasswordFile;
    
    @Value("${dial.export.timeout:300}")
    private int exportTimeout;
    
    @Value("${dial.export.files:dial.exp,dial2.exp}")
    private String exportFiles;
    
    @Value("${dial.export.directory:#{null}}")
    private String exportDirectory;
    
    @Value("${dial.export.compress:true}")
    private boolean compressExports;
    
    @Value("${dial.oracle.home}")
    private String oracleHome;
    
    @Value("${dial.oracle.sid}")
    private String oracleSid;
    
    @Value("${dial.log.path}")
    private String logPath;
    
    @Value("${dial.export.date.format:yyyyMMdd}")
    private String dateFormat;
    
    @Value("${dial.export.character.set:American_America.WE8ISO8859P15}")
    private String characterSet;
    
    @Autowired
    public ExportService(DataSource dataSource, DialEnvironmentConfig config) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
        this.dialEnv = config.dialEnvironment(null);
        this.dialPasswordFile = config.dialDatabasePasswordFile();
    }
    
    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        logger.info("Starting export process with timeout: {} seconds", exportTimeout);
        
        Path logFile = StringUtils.hasText(logPath) ? 
                Paths.get(logPath) : 
                Paths.get(dialEnv.getOrDefault("CONSOLDIR", "logs"), "diallog");
        
        Files.createDirectories(logFile.getParent());
        
        try (BufferedWriter logWriter = Files.newBufferedWriter(logFile, StandardCharsets.UTF_8, 
                StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
            
            logWriter.write("--- Step #1 - Create ALS Export Files -- " + timestamp);
            logWriter.newLine();
            logWriter.write("Oracle SID: " + oracleSid);
            logWriter.newLine();
            logWriter.write("Oracle Home: " + oracleHome);
            logWriter.newLine();
            
            // Set locale (equivalent to the setenv NLS_LANG line)
            System.setProperty("NLS_LANG", characterSet);
            
            // Determine export directory
            Path expDir = determineExportDirectory();
            Files.createDirectories(expDir);
            
            // Clean up any previous export files
            cleanupPreviousExports(expDir);
            
            // Perform exports
            List<String> exportFilesList = Arrays.asList(exportFiles.split(","));
            boolean allSucceeded = true;
            
            for (String exportFile : exportFilesList) {
                boolean success = performExport(expDir, exportFile.trim(), logWriter);
                allSucceeded = allSucceeded && success;
                
                if (!success) {
                    logger.error("Export failed for file: {}", exportFile);
                }
            }
            
            if (allSucceeded) {
                timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
                logWriter.write("--- Exports Completed ------------------ " + timestamp);
                logWriter.newLine();
            } else {
                logWriter.write("ERROR: One or more exports failed");
                logWriter.newLine();
                throw new RuntimeException("Export process failed for one or more files");
            }
        }
        
        logger.info("Export process completed");
        return RepeatStatus.FINISHED;
    }
    
    private Path determineExportDirectory() {
        if (StringUtils.hasText(exportDirectory)) {
            return Paths.get(exportDirectory);
        } else if (dialEnv.containsKey("EXP_DIR")) {
            return Paths.get(dialEnv.get("EXP_DIR"));
        } else {
            String baseDir = dialEnv.getOrDefault("DIAL", "/als-ALS/app/dial");
            return Paths.get(baseDir, "exports");
        }
    }
    
    private void cleanupPreviousExports(Path expDir) throws IOException {
        logger.info("Cleaning up previous export files in: {}", expDir);
        
        // Get the list of export files to clean up
        List<String> exportFilesList = Arrays.asList(exportFiles.split(","));
        
        for (String exportFile : exportFilesList) {
            String pattern = exportFile.trim() + ".????.*";
            try (var files = Files.newDirectoryStream(expDir, pattern)) {
                for (Path file : files) {
                    logger.debug("Deleting previous export file: {}", file);
                    Files.deleteIfExists(file);
                }
            }
        }
    }
    
    private boolean performExport(Path expDir, String exportFileName, BufferedWriter logWriter) throws IOException {
        logger.info("Performing export: {}", exportFileName);
        
        String today = LocalDate.now().format(DateTimeFormatter.ofPattern(dateFormat));
        Path exportFile = expDir.resolve(exportFileName + "." + today);
        
        // Prepare the parameter file name
        String exportParamFile = exportFileName.replace(".exp", "").toUpperCase() + "_PAR";
        
        // Check if parameter file exists
        Path paramFilePath = Paths.get(dialEnv.getOrDefault("DIAL", "."), "param", exportParamFile);
        if (!Files.exists(paramFilePath)) {
            logger.error("Parameter file not found: {}", paramFilePath);
            logWriter.write("ERROR: Parameter file not found: " + paramFilePath);
            logWriter.newLine();
            return false;
        }
        
        // Build the export command
        ProcessBuilder pb = buildExportProcess(exportParamFile, exportFile);
        
        logWriter.write("Starting export: " + exportFileName);
        logWriter.newLine();
        logWriter.write("Export file: " + exportFile);
        logWriter.newLine();
        logWriter.write("Parameter file: " + paramFilePath);
        logWriter.newLine();
        
        // Start the process
        Process process = pb.start();
        
        // Read export output asynchronously
        CompletableFuture<String> outputFuture = readProcessOutput(process);
        
        // Wait for process to complete
        boolean completed = waitForProcess(process, exportTimeout, logWriter);
        if (!completed) {
            return false;
        }
        
        // Check completion status
        String output = outputFuture.join();
        boolean success = process.exitValue() == 0 && (output.contains("Export terminated successfully") || 
                                                     output.contains("completed successfully"));
        
        // Log the output
        logWriter.write("Export output:");
        logWriter.newLine();
        logWriter.write(output);
        logWriter.newLine();
        
        logWriter.write(success ? 
                "Export completed successfully: " + exportFileName : 
                "Export failed: " + exportFileName);
        logWriter.newLine();
        
        if (success && compressExports) {
            // Compress the export file
            Path compressedFile = compressFile(exportFile);
            logWriter.write("Compressed export file: " + compressedFile);
            logWriter.newLine();
        }
        
        return success;
    }
    
    private ProcessBuilder buildExportProcess(String paramFile, Path exportFile) {
        // Get database password
        String password = readPasswordFromFile(dialPasswordFile);
        
        // Determine which Oracle export utility to use
        String exportTool = "expdp"; // Data Pump export (modern)
        
        // Build the command
        ProcessBuilder pb = new ProcessBuilder(
                exportTool,
                "dial/" + password,
                "PARFILE=" + paramFile,
                "DIRECTORY=DATA_PUMP_DIR",
                "DUMPFILE=" + exportFile.getFileName()
        );
        
        // Set environment variables
        Map<String, String> env = pb.environment();
        env.putAll(dialEnv);
        env.put("ORACLE_HOME", oracleHome);
        env.put("ORACLE_SID", oracleSid);
        env.put("NLS_LANG", characterSet);
        env.put("PATH", oracleHome + "/bin:" + env.getOrDefault("PATH", ""));
        
        // Set working directory
        pb.directory(Paths.get(dialEnv.getOrDefault("DIAL", ".")).toFile());
        
        // Redirect error stream to output stream
        pb.redirectErrorStream(true);
        
        return pb;
    }
    
    private CompletableFuture<String> readProcessOutput(Process process) {
        return CompletableFuture.supplyAsync(() -> {
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                    logger.debug("Export process output: {}", line);
                }
                return output.toString();
            } catch (IOException e) {
                logger.error("Error reading export output", e);
                throw new RuntimeException("Error reading export output", e);
            }
        });
    }
    
    private boolean waitForProcess(Process process, int timeoutSeconds, BufferedWriter logWriter) throws IOException {
        try {
            boolean completed = process.waitFor(timeoutSeconds, TimeUnit.SECONDS);
            if (!completed) {
                process.destroyForcibly();
                logWriter.write("Export timed out after " + timeoutSeconds + " seconds");
                logWriter.newLine();
                logger.error("Export timed out after {} seconds", timeoutSeconds);
                return false;
            }
            
            return true;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logWriter.write("Export was interrupted: " + e.getMessage());
            logWriter.newLine();
            logger.error("Export was interrupted", e);
            return false;
        }
    }
    
    private Path compressFile(Path file) throws IOException {
        Path compressedFile = Paths.get(file.toString() + ".gz");
        logger.info("Compressing file {} to {}", file, compressedFile);
        
        try (GZIPOutputStream gzos = new GZIPOutputStream(Files.newOutputStream(compressedFile));
             BufferedReader reader = Files.newBufferedReader(file)) {
            
            char[] buffer = new char[8192];
            int charsRead;
            StringBuilder writer = new StringBuilder();
            
            while ((charsRead = reader.read(buffer, 0, buffer.length)) != -1) {
                writer.append(buffer, 0, charsRead);
                gzos.write(writer.toString().getBytes(StandardCharsets.UTF_8));
                writer.setLength(0);
            }
        }
        
        // Set file permissions if on a POSIX-compliant system
        try {
            Files.setPosixFilePermissions(compressedFile, 
                    java.nio.file.attribute.PosixFilePermissions.fromString("rw-rw-rw-"));
        } catch (UnsupportedOperationException e) {
            logger.warn("Could not set POSIX file permissions (non-POSIX filesystem)");
        }
        
        return compressedFile;
    }
    
    private String readPasswordFromFile(Path passwordFile) {
        try {
            if (Files.exists(passwordFile)) {
                return Files.readString(passwordFile).trim();
            } else {
                logger.warn("Password file not found: {}, using default configuration", passwordFile);
                return jdbcTemplate.getDataSource().getConnection().getMetaData().getUserName();
            }
        } catch (Exception e) {
            logger.error("Error reading password file", e);
            throw new RuntimeException("Could not read database password file", e);
        }
    }
    
    /**
     * Service method to manually trigger export process
     * 
     * @param exportFileName Name of the export file to create (or null for all configured exports)
     * @return true if export was successful, false otherwise
     */
    public boolean executeExport(String exportFileName) {
        try {
            Path expDir = determineExportDirectory();
            Files.createDirectories(expDir);
            
            try (BufferedWriter logWriter = Files.newBufferedWriter(
                    Paths.get(logPath), StandardCharsets.UTF_8, 
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
                
                if (exportFileName == null) {
                    // Execute all configured exports
                    List<String> exportFilesList = Arrays.asList(exportFiles.split(","));
                    boolean allSucceeded = true;
                    
                    for (String file : exportFilesList) {
                        boolean success = performExport(expDir, file.trim(), logWriter);
                        allSucceeded = allSucceeded && success;
                    }
                    
                    return allSucceeded;
                } else {
                    // Execute specific export
                    return performExport(expDir, exportFileName, logWriter);
                }
            }
        } catch (Exception e) {
            logger.error("Error executing manual export", e);
            return false;
        }
    }
}