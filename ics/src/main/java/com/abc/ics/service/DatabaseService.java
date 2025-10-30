package com.abc.ics.service;

import com.abc.ics.config.IcsZipConfigProperties;
import com.abc.ics.exception.DatabaseOperationException;
import com.abc.ics.model.IcsZipRecord;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.BatchPreparedStatementSetter;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.io.BufferedReader;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.List;

/**
 * Service for handling Oracle database operations
 * Equivalent to SQL*Plus and SQL*Loader operations in the shell script
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class DatabaseService {

    private final JdbcTemplate jdbcTemplate;
    private final DataSource dataSource;
    private final IcsZipConfigProperties config;
    private final FileService fileService;

    /**
     * Tests Oracle database connection
     * Equivalent to: sqlplus -s /nolog << EOF ... connect dial/${pswd} ... exit
     * 
     * @return true if connection successful
     */
    public boolean testConnection() {
        try {
            jdbcTemplate.queryForObject("SELECT 1 FROM DUAL", Integer.class);
            log.info("Oracle database connection successful");
            return true;
        } catch (Exception e) {
            log.error("FATAL ERROR: Oracle instance is not available for zip code processing.", e);
            throw new DatabaseOperationException(
                "Oracle instance is not available for zip code processing.", e);
        }
    }

    /**
     * Deletes records from oldzips table for a specific area
     * Equivalent to: delete from oldzips where didocd = '${area}';
     * 
     * @param area Area code to delete
     * @return Number of records deleted
     */
    @Transactional
    public int deleteOldZipsForArea(Integer area) {
        String sql = "DELETE FROM oldzips WHERE didocd = ?";
        
        try {
            log.info("Area {}: Deleting previous zip code assignments from oldzips: {}", 
                area, fileService.getCurrentDateTime());
            
            int deletedCount = jdbcTemplate.update(sql, area.toString());
            
            log.info("Area {}: Deleted {} records from oldzips", area, deletedCount);
            
            return deletedCount;
            
        } catch (Exception e) {
            String errorMsg = String.format(
                "FATAL ERROR: Unable to delete oldzips records for district %d: %s", 
                area, fileService.getCurrentDateTime());
            log.error(errorMsg, e);
            throw new DatabaseOperationException(errorMsg, e);
        }
    }

    /**
     * Loads data from file into oldzips table for a specific area
     * Equivalent to: sqlldr dial/${pswd} icszip.ctl
     * 
     * This method reads the area-specific file and performs batch insert
     * 
     * @param areaFile Path to area-specific data file
     * @param area Area code
     * @return Number of records loaded
     */
    @Transactional
    public int loadDataToOldZips(Path areaFile, Integer area) {
        try {
            log.info("Area {}: Loading latest zip code assignments to oldzips: {}", 
                area, fileService.getCurrentDateTime());
            
            List<String> lines = fileService.readAllLines(areaFile);
            
            if (lines.isEmpty()) {
                log.warn("Area {}: No data to load", area);
                return 0;
            }

            // Parse records and perform batch insert
            List<IcsZipRecord> records = parseRecords(lines, area);
            int insertedCount = batchInsertToOldZips(records);
            
            log.info("Area {}: Loaded {} records to oldzips", area, insertedCount);
            
            // Check for bad records (this is a placeholder - implement based on your validation logic)
            checkForBadRecords(areaFile, area, lines.size(), insertedCount);
            
            return insertedCount;
            
        } catch (Exception e) {
            String errorMsg = String.format(
                "ERROR: Unable to load icszip%d.dat file: %s", 
                area, fileService.getCurrentDateTime());
            log.error(errorMsg, e);
            throw new DatabaseOperationException(errorMsg, e);
        }
    }

    /**
     * Parses lines from file into IcsZipRecord objects
     * This needs to be customized based on your actual file format
     * 
     * @param lines Lines from file
     * @param area Area code
     * @return List of parsed records
     */
    private List<IcsZipRecord> parseRecords(List<String> lines, Integer area) {
        return lines.stream()
            .map(line -> {
                // TODO: Customize this based on your actual file format
                // This is a placeholder implementation
                
                // Assuming format: areaCode|zipCode|additionalData
                String[] parts = line.split("\\|");
                
                return IcsZipRecord.builder()
                    .areaCode(area.toString())
                    .zipCode(parts.length > 1 ? parts[1] : "")
                    .additionalData(parts.length > 2 ? parts[2] : "")
                    .rawLine(line)
                    .build();
            })
            .toList();
    }

    /**
     * Performs batch insert of records into oldzips table
     * 
     * @param records Records to insert
     * @return Number of records inserted
     */
    private int batchInsertToOldZips(List<IcsZipRecord> records) {
        // TODO: Customize this SQL based on your actual oldzips table structure
        String sql = "INSERT INTO oldzips (didocd, zipcode, additional_data) VALUES (?, ?, ?)";
        
        int batchSize = config.getProcessing().getBatchSize();
        int totalInserted = 0;
        
        for (int i = 0; i < records.size(); i += batchSize) {
            int end = Math.min(i + batchSize, records.size());
            List<IcsZipRecord> batch = records.subList(i, end);
            
            int[] updateCounts = jdbcTemplate.batchUpdate(sql, new BatchPreparedStatementSetter() {
                @Override
                public void setValues(PreparedStatement ps, int index) throws SQLException {
                    IcsZipRecord record = batch.get(index);
                    ps.setString(1, record.getAreaCode());
                    ps.setString(2, record.getZipCode());
                    ps.setString(3, record.getAdditionalData());
                }

                @Override
                public int getBatchSize() {
                    return batch.size();
                }
            });
            
            totalInserted += updateCounts.length;
        }
        
        return totalInserted;
    }

    /**
     * Checks for bad records that couldn't be loaded
     * Equivalent to checking for .bad files from SQL*Loader
     * 
     * @param areaFile Area file
     * @param area Area code
     * @param totalLines Total lines in file
     * @param insertedCount Number of records inserted
     */
    private void checkForBadRecords(Path areaFile, Integer area, int totalLines, int insertedCount) {
        if (totalLines > insertedCount) {
            int badRecords = totalLines - insertedCount;
            log.warn("There were {} bad records loading data for district {}", badRecords, area);
            
            // Optionally write bad records to a separate file
            // This mimics the .bad file created by SQL*Loader
        }
    }

    /**
     * Executes the crzips.sql script
     * Equivalent to: @$EXECLOC/crzips
     * 
     * This procedure transforms data from oldzips to icszips table
     */
    @Transactional
    public void executeCrzipsScript() {
        try {
            log.info("Executing crzips procedure to load icszips from oldzips");
            
            Path scriptPath = Paths.get(config.getSql().getScriptDirectory(), 
                config.getSql().getCrzipsScriptName());
            
            if (!Files.exists(scriptPath)) {
                throw new DatabaseOperationException(
                    "crzips script not found at: " + scriptPath);
            }
            
            // Read and execute the SQL script
            String sqlScript = Files.readString(scriptPath, StandardCharsets.UTF_8);
            
            // Split script into individual statements (basic implementation)
            // For more complex scripts, consider using Spring's ScriptUtils
            executeSqlScript(sqlScript);
            
            log.info("Successfully executed crzips procedure");
            log.info("========== {} ========== LOAD TO ICSZIPS FINISH ===", 
                fileService.getCurrentDateTime());
            
        } catch (IOException e) {
            String errorMsg = String.format(
                "FATAL ERROR: Unable to load icszips from oldzips: %s", 
                fileService.getCurrentDateTime());
            log.error(errorMsg, e);
            throw new DatabaseOperationException(errorMsg, e);
        } catch (Exception e) {
            String errorMsg = String.format(
                "FATAL ERROR: Unable to load icszips from oldzips: %s", 
                fileService.getCurrentDateTime());
            log.error(errorMsg, e);
            throw new DatabaseOperationException(errorMsg, e);
        }
    }

    /**
     * Executes a multi-statement SQL script
     * Handles PL/SQL blocks and regular SQL statements
     * 
     * @param sqlScript SQL script content
     */
    private void executeSqlScript(String sqlScript) {
        Connection connection = null;
        try {
            connection = DataSourceUtils.getConnection(dataSource);
            
            // For simple scripts, use jdbcTemplate
            // For complex scripts with PL/SQL blocks, may need custom parsing
            
            // Split by semicolon, but be careful with PL/SQL blocks
            String[] statements = splitSqlScript(sqlScript);
            
            for (String statement : statements) {
                statement = statement.trim();
                if (!statement.isEmpty() && !statement.startsWith("--")) {
                    try (Statement stmt = connection.createStatement()) {
                        stmt.execute(statement);
                        log.debug("Executed statement: {}", 
                            statement.substring(0, Math.min(100, statement.length())));
                    }
                }
            }
            
        } catch (SQLException e) {
            log.error("Error executing SQL script", e);
            throw new DatabaseOperationException("Error executing SQL script", e);
        } finally {
            if (connection != null) {
                DataSourceUtils.releaseConnection(connection, dataSource);
            }
        }
    }

    /**
     * Splits SQL script into individual statements
     * Basic implementation - may need enhancement for complex PL/SQL
     * 
     * @param sqlScript SQL script
     * @return Array of SQL statements
     */
    private String[] splitSqlScript(String sqlScript) {
        // Simple split by semicolon
        // For production, consider using a proper SQL parser
        return sqlScript.split(";");
    }

    /**
     * Checks for Oracle extent errors (ORA-01605)
     * Equivalent to: grep "G05: Non-data dependent ORACLE error occurred"
     * 
     * @param logContent Log content to check
     * @return true if extent error found
     */
    public boolean hasExtentError(String logContent) {
        return logContent.contains("G05: Non-data dependent ORACLE error occurred") ||
               logContent.contains("ORA-01605");
    }
}
