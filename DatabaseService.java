package com.abc.ics.service;

import com.abc.ics.exception.DatabaseOperationException;
import com.abc.ics.model.IcsZipRecord;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 * Service for database operations related to ICS zip code processing
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class DatabaseService {

    private final JdbcTemplate jdbcTemplate;
    
    // Field positions in pipe-delimited file (0-indexed)
    private static final int FIELD_DIDOCD = 0;      // Area code (21, 22, etc.)
    private static final int FIELD_DIZIPCD = 1;     // Zip code (00501, 00544, etc.)
    private static final int FIELD_GSLVL = 2;       // GS Level (11, 12, 13)
    private static final int FIELD_ROEMPID = 3;     // Employee ID (21061614, etc.)
    private static final int FIELD_ALPHABEG = 4;    // Alpha beginning (A, N)
    private static final int FIELD_ALPHAEND = 5;    // Alpha ending (Z, M)
    private static final int FIELD_BODCD = 6;       // BOD code (XX)
    private static final int FIELD_BODCLCD = 7;     // BOD class code (XXX)
    private static final int FIELD_ACSOIND = 8;     // ACSO indicator (0)
    
    private static final int EXPECTED_FIELD_COUNT = 9;

    /**
     * Parses records from the ICS zip file
     * 
     * @param filePath Path to the file
     * @return List of parsed ICS zip records
     * @throws IOException If file reading fails
     */
    public List<IcsZipRecord> parseRecords(Path filePath) throws IOException {
        List<IcsZipRecord> records = new ArrayList<>();
        int lineNumber = 0;
        int skippedRecords = 0;

        log.info("Starting to parse file: {}", filePath);

        try (BufferedReader reader = Files.newBufferedReader(filePath)) {
            String line;
            
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                
                // Skip empty lines
                if (line.trim().isEmpty()) {
                    continue;
                }

                try {
                    IcsZipRecord record = parseLine(line, lineNumber);
                    if (record != null) {
                        records.add(record);
                    } else {
                        skippedRecords++;
                    }
                } catch (Exception e) {
                    log.error("Error parsing line {}: {} - Error: {}", lineNumber, line, e.getMessage());
                    skippedRecords++;
                }
            }
        }

        log.info("Parsing complete. Total records: {}, Skipped: {}", records.size(), skippedRecords);
        return records;
    }

    /**
     * Parses a single line from the file
     * 
     * @param line Line to parse
     * @param lineNumber Line number for logging
     * @return Parsed IcsZipRecord or null if invalid
     */
    private IcsZipRecord parseLine(String line, int lineNumber) {
        // Split by pipe delimiter
        String[] fields = line.split("\\|", -1);  // -1 to include trailing empty strings

        // Validate field count
        if (fields.length < EXPECTED_FIELD_COUNT) {
            log.warn("Line {}: Invalid field count. Expected {}, got {}. Line: {}", 
                    lineNumber, EXPECTED_FIELD_COUNT, fields.length, line);
            return null;
        }

        try {
            // Parse numeric fields with validation
            String didocdStr = fields[FIELD_DIDOCD].trim();
            String dizipcdStr = fields[FIELD_DIZIPCD].trim();
            String gslvlStr = fields[FIELD_GSLVL].trim();
            String roempidStr = fields[FIELD_ROEMPID].trim();
            String acsoindStr = fields[FIELD_ACSOIND].trim();

            // Validate required numeric fields are not empty
            if (didocdStr.isEmpty() || dizipcdStr.isEmpty() || gslvlStr.isEmpty() || 
                roempidStr.isEmpty() || acsoindStr.isEmpty()) {
                log.warn("Line {}: One or more required numeric fields are empty", lineNumber);
                return null;
            }

            // Parse and validate numeric values
            Integer didocd = Integer.parseInt(didocdStr);
            Integer dizipcd = Integer.parseInt(dizipcdStr);
            Integer gslvl = Integer.parseInt(gslvlStr);
            Integer roempid = Integer.parseInt(roempidStr);
            Integer acsoind = Integer.parseInt(acsoindStr);

            // Validate DIDOCD is in valid range (21-27, 35)
            if (didocd < 21 || didocd > 35 || (didocd > 27 && didocd < 35)) {
                log.warn("Line {}: Invalid DIDOCD value: {}", lineNumber, didocd);
                return null;
            }

            // Create and populate the record
            IcsZipRecord record = new IcsZipRecord();
            record.setDidocd(didocd);
            record.setDizipcd(dizipcd);
            record.setGslvl(gslvl);
            record.setRoempid(roempid);
            record.setAlphabeg(fields[FIELD_ALPHABEG].trim());
            record.setAlphaend(fields[FIELD_ALPHAEND].trim());
            record.setBodcd(fields[FIELD_BODCD].trim());
            record.setBodclcd(fields[FIELD_BODCLCD].trim());
            record.setAcsoind(acsoind);

            return record;

        } catch (NumberFormatException e) {
            log.error("Line {}: Number format error - {}", lineNumber, e.getMessage());
            return null;
        }
    }

    /**
     * Batch inserts records into the OLDZIPS table
     * 
     * @param records List of ICS zip records to insert
     * @param area Area code for the records
     * @return Number of records inserted
     */
    @Transactional
    public int batchInsertToOldZips(List<IcsZipRecord> records, int area) {
        if (records == null || records.isEmpty()) {
            log.warn("No records to insert for area {}", area);
            return 0;
        }

        log.info("Starting batch insert of {} records for area {}", records.size(), area);

        String insertSql = 
            "INSERT INTO OLDZIPS " +
            "(DIZIPCD, DIDOCD, GSLVL, ROEMPID, ALPHABEG, ALPHAEND, BODCD, BODCLCD, ACSOIND) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

        try {
            int[] updateCounts = jdbcTemplate.batchUpdate(
                insertSql,
                records,
                records.size(),
                (ps, record) -> {
                    ps.setInt(1, record.getDizipcd());
                    ps.setInt(2, record.getDidocd());
                    ps.setInt(3, record.getGslvl());
                    ps.setInt(4, record.getRoempid());
                    ps.setString(5, record.getAlphabeg());
                    ps.setString(6, record.getAlphaend());
                    ps.setString(7, record.getBodcd());
                    ps.setString(8, record.getBodclcd());
                    ps.setInt(9, record.getAcsoind());
                }
            );

            int insertedCount = 0;
            for (int count : updateCounts) {
                if (count > 0) {
                    insertedCount++;
                }
            }

            log.info("Successfully inserted {} records for area {}", insertedCount, area);
            return insertedCount;

        } catch (Exception e) {
            log.error("Error during batch insert for area {}: {}", area, e.getMessage(), e);
            throw new DatabaseOperationException("Failed to insert records for area " + area, e);
        }
    }

    /**
     * Deletes records from OLDZIPS for a specific area
     * 
     * @param area Area code
     * @return Number of records deleted
     */
    @Transactional
    public int deleteOldZipsByArea(int area) {
        String deleteSql = "DELETE FROM OLDZIPS WHERE DIDOCD = ?";
        
        try {
            int deletedCount = jdbcTemplate.update(deleteSql, area);
            log.info("Deleted {} records from OLDZIPS for area {}", deletedCount, area);
            return deletedCount;
            
        } catch (Exception e) {
            log.error("Error deleting records for area {}: {}", area, e.getMessage(), e);
            throw new DatabaseOperationException("Failed to delete records for area " + area, e);
        }
    }

    /**
     * Executes the crzips Oracle procedure
     * 
     * @param scriptPath Path to the SQL script
     */
    @Transactional
    public void executeCrzipsProcedure(Path scriptPath) {
        log.info("Executing crzips procedure from script: {}", scriptPath);
        
        try {
            // Read the SQL script
            String sqlScript = Files.readString(scriptPath);
            
            // Execute using JDBC connection to support PL/SQL blocks
            Connection connection = jdbcTemplate.getDataSource().getConnection();
            
            try (CallableStatement stmt = connection.prepareCall(sqlScript)) {
                stmt.execute();
                log.info("Successfully executed crzips procedure");
            } finally {
                connection.close();
            }
            
        } catch (IOException e) {
            log.error("Error reading SQL script: {}", e.getMessage(), e);
            throw new DatabaseOperationException("Failed to read SQL script: " + scriptPath, e);
            
        } catch (SQLException e) {
            log.error("Error executing crzips procedure: {}", e.getMessage(), e);
            throw new DatabaseOperationException("Failed to execute crzips procedure", e);
        }
    }

    /**
     * Gets the count of records in OLDZIPS for a specific area
     * 
     * @param area Area code
     * @return Record count
     */
    public int getRecordCount(int area) {
        String countSql = "SELECT COUNT(*) FROM OLDZIPS WHERE DIDOCD = ?";
        
        try {
            Integer count = jdbcTemplate.queryForObject(countSql, Integer.class, area);
            return count != null ? count : 0;
            
        } catch (Exception e) {
            log.error("Error getting record count for area {}: {}", area, e.getMessage(), e);
            return 0;
        }
    }

    /**
     * Validates database connectivity
     * 
     * @return true if connection is valid
     */
    public boolean validateConnection() {
        try {
            jdbcTemplate.queryForObject("SELECT 1 FROM DUAL", Integer.class);
            log.info("Database connection validated successfully");
            return true;
            
        } catch (Exception e) {
            log.error("Database connection validation failed: {}", e.getMessage(), e);
            return false;
        }
    }
}
