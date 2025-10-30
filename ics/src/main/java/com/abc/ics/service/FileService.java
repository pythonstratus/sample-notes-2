package com.abc.ics.service;

import com.abc.ics.config.IcsZipConfigProperties;
import com.abc.ics.exception.FileValidationException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.io.FileUtils;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Service for handling file operations
 * Equivalent to file operations in the shell script
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class FileService {

    private final IcsZipConfigProperties config;

    /**
     * Validates that exactly one input file exists
     * Equivalent to: ls -C1 icszip.????????.dat
     * 
     * @return Path to the validated input file
     * @throws FileValidationException if validation fails
     */
    public Path validateAndGetInputFile() {
        log.info("========== {} ========== START =====", getCurrentTimestamp());
        log.info("Validating input files in directory: {}", config.getFile().getInputDirectory());

        try {
            Path inputDir = Paths.get(config.getFile().getInputDirectory());
            
            if (!Files.exists(inputDir) || !Files.isDirectory(inputDir)) {
                throw new FileValidationException("Input directory does not exist: " + inputDir);
            }

            // Find files matching pattern icszip.????????.dat
            List<Path> matchingFiles;
            try (Stream<Path> paths = Files.list(inputDir)) {
                matchingFiles = paths
                    .filter(Files::isRegularFile)
                    .filter(p -> {
                        String fileName = p.getFileName().toString();
                        return fileName.startsWith("icszip.") && 
                               fileName.endsWith(".dat") && 
                               fileName.length() == 20; // icszip.YYYYMMDD.dat
                    })
                    .collect(Collectors.toList());
            }

            log.info("Found {} matching file(s)", matchingFiles.size());

            if (matchingFiles.isEmpty()) {
                String errorMsg = String.format("ERROR: %s icszip.YYYYMMDD.dat not transferred.", 
                    getCurrentTimestamp());
                log.error(errorMsg);
                throw new FileValidationException("No input files found matching pattern: " + 
                    config.getFile().getInputFilePattern());
            }

            if (matchingFiles.size() > 1) {
                String errorMsg = String.format("ERROR: %s more than one icszip.YYYYMMDD.dat", 
                    getCurrentTimestamp());
                log.error(errorMsg);
                throw new FileValidationException(String.format(
                    "Multiple input files found (%d). Expected exactly one file.", 
                    matchingFiles.size()));
            }

            Path inputFile = matchingFiles.get(0);
            log.info("{} {} received.", getCurrentTimestamp(), inputFile.getFileName());
            
            return inputFile;

        } catch (IOException e) {
            log.error("Error accessing input directory", e);
            throw new FileValidationException("Error accessing input directory", e);
        }
    }

    /**
     * Copies the input file to working file name
     * Equivalent to: cp -p icszip.????????.dat icszip.dat
     * 
     * @param sourceFile Source file path
     * @return Path to the working file
     */
    public Path copyToWorkingFile(Path sourceFile) {
        try {
            Path workingFile = Paths.get(config.getFile().getInputDirectory(), 
                config.getFile().getWorkingFileName());
            
            Files.copy(sourceFile, workingFile, StandardCopyOption.REPLACE_EXISTING);
            log.info("Copied {} to {}", sourceFile.getFileName(), workingFile.getFileName());
            
            return workingFile;
            
        } catch (IOException e) {
            String errorMsg = String.format("ERROR: %s PROBLEM COPYING NEW FILE TO icszip.dat", 
                getCurrentTimestamp());
            log.error(errorMsg, e);
            throw new FileValidationException("Error copying file to working directory", e);
        }
    }

    /**
     * Extracts records for a specific area from the main file
     * Equivalent to: grep "^${area}" icszip.dat > icszip${area}.tmp
     * 
     * @param workingFile Main working file
     * @param area Area code to filter
     * @return Path to area-specific file
     */
    public Path extractAreaRecords(Path workingFile, Integer area) {
        try {
            Path areaFile = Paths.get(config.getFile().getInputDirectory(), 
                String.format("icszip%d.dat", area));
            
            List<String> allLines = Files.readAllLines(workingFile, StandardCharsets.UTF_8);
            String areaPrefix = area.toString();
            
            List<String> areaLines = allLines.stream()
                .filter(line -> line.startsWith(areaPrefix))
                .collect(Collectors.toList());
            
            Files.write(areaFile, areaLines, StandardCharsets.UTF_8);
            
            log.info("Extracted {} records for area {} to {}", 
                areaLines.size(), area, areaFile.getFileName());
            
            return areaFile;
            
        } catch (IOException e) {
            log.error("Error extracting records for area {}", area, e);
            throw new FileValidationException("Error extracting area records", e);
        }
    }

    /**
     * Archives the processed file
     * Equivalent to: cp -p icszip.????????.dat ${ARCDIR}
     * 
     * @param sourceFile File to archive
     */
    public void archiveFile(Path sourceFile) {
        try {
            Path archiveDir = Paths.get(config.getFile().getArchiveDirectory());
            
            if (!Files.exists(archiveDir)) {
                Files.createDirectories(archiveDir);
            }
            
            Path archiveFile = archiveDir.resolve(sourceFile.getFileName());
            Files.copy(sourceFile, archiveFile, StandardCopyOption.REPLACE_EXISTING);
            
            log.info("Archived file to {}", archiveFile);
            
        } catch (IOException e) {
            log.warn("Failed to archive file {}", sourceFile, e);
            // Don't throw exception - archiving is not critical
        }
    }

    /**
     * Checks if a file exists and is not empty
     * Equivalent to: if ( ! -z icszip.dat ) then
     * 
     * @param filePath File to check
     * @return true if file exists and is not empty
     */
    public boolean fileExistsAndNotEmpty(Path filePath) {
        try {
            return Files.exists(filePath) && Files.size(filePath) > 0;
        } catch (IOException e) {
            log.warn("Error checking file size for {}", filePath, e);
            return false;
        }
    }

    /**
     * Reads all lines from a file
     * 
     * @param filePath File to read
     * @return List of lines
     */
    public List<String> readAllLines(Path filePath) {
        try {
            return Files.readAllLines(filePath, StandardCharsets.UTF_8);
        } catch (IOException e) {
            log.error("Error reading file {}", filePath, e);
            throw new FileValidationException("Error reading file", e);
        }
    }

    /**
     * Gets current timestamp in format matching shell script
     * Equivalent to: `date +%m/%d/%y`
     * 
     * @return Formatted timestamp
     */
    public String getCurrentTimestamp() {
        return new SimpleDateFormat("MM/dd/yy").format(new Date());
    }

    /**
     * Gets current date-time for logging
     * Equivalent to: `date`
     * 
     * @return Formatted date-time
     */
    public String getCurrentDateTime() {
        return new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());
    }

    /**
     * Backs up the log file
     * Equivalent to: cp -p ${LOGFILE} ${LOGFILE}.backup
     */
    public void backupLogFile() {
        try {
            Path logFile = Paths.get(config.getLog().getDirectory(), 
                config.getLog().getMainLogFile());
            Path backupFile = Paths.get(logFile.toString() + ".backup");
            
            if (Files.exists(logFile)) {
                Files.copy(logFile, backupFile, StandardCopyOption.REPLACE_EXISTING);
                log.debug("Backed up log file to {}", backupFile);
            }
        } catch (IOException e) {
            log.warn("Failed to backup log file", e);
            // Non-critical operation
        }
    }
}
