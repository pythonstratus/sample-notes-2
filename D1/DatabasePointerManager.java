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
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Implementation of the Dial1_point2cp shell script functionality.
 * Creates and maintains database synonym redirects.
 */
@Service
public class DatabasePointerManager implements Tasklet {
    private static final Logger logger = LoggerFactory.getLogger(DatabasePointerManager.class);
    
    private final JdbcTemplate jdbcTemplate;
    private final Map<String, String> dialEnv;
    private final Path dialPasswordFile;
    
    @Value("${dial.database.schemas:dialrpt,als,alsrpt}")
    private String databaseSchemas;
    
    @Value("${dial.database.source.schema:DIAL_CP}")
    private String sourceSchema;
    
    @Value("${dial.database.pointer.log:#{null}}")
    private String pointerLogPath;
    
    @Value("${dial.database.tables:#{null}}")
    private String databaseTables;
    
    @Value("${dial.database.exclude.tables:}")
    private String excludeTables;
    
    @Value("${dial.database.retry-attempts:3}")
    private int retryAttempts;
    
    @Value("${spring.datasource.username:DIAL}")
    private String dbUsername;
    
    @Value("${dial.oracle.sid}")
    private String oracleSid;
    
    private List<String> schemasList;
    private List<String> excludeTablesList;
    
    @Autowired
    public DatabasePointerManager(DataSource dataSource, DialEnvironmentConfig config) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
        this.dialEnv = config.dialEnvironment(null);
        this.dialPasswordFile = config.dialDatabasePasswordFile();
    }
    
    /**
     * Initialize component after properties are set
     */
    @Autowired
    public void init() {
        this.schemasList = Arrays.asList(databaseSchemas.split(","))
                                .stream()
                                .map(String::trim)
                                .collect(Collectors.toList());
        
        this.excludeTablesList = Arrays.asList(excludeTables.split(","))
                                      .stream()
                                      .map(String::trim)
                                      .filter(s -> !s.isEmpty())
                                      .collect(Collectors.toList());
        
        logger.info("Initialized DatabasePointerManager with schemas: {}", schemasList);
        logger.info("Tables to exclude: {}", excludeTablesList);
    }
    
    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        logger.info("Starting database pointer update for {} schemas", schemasList.size());
        
        Path logFile = determineLogFilePath();
        Files.createDirectories(logFile.getParent());
        
        try (var writer = Files.newBufferedWriter(logFile, StandardCharsets.UTF_8, 
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
            
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
            writer.write("-- Database pointer update started at " + timestamp);
            writer.newLine();
            writer.write("-- Oracle SID: " + oracleSid);
            writer.newLine();
            writer.write("-- Source schema: " + sourceSchema);
            writer.newLine();
            writer.newLine();
            
            // Get list of tables to process
            List<String> tablesToProcess = getTablesForProcessing();
            writer.write("-- Tables to process: " + tablesToProcess.size());
            writer.newLine();
            writer.write("-- " + String.join(", ", tablesToProcess));
            writer.newLine();
            writer.newLine();
            
            int totalSynonyms = 0;
            int successCount = 0;
            
            // Process each schema
            for (String schema : schemasList) {
                int schemaSuccess = updateSynonymsForSchema(schema, tablesToProcess, writer);
                successCount += schemaSuccess;
                totalSynonyms += tablesToProcess.size();
            }
            
            timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
            writer.write("-- Database pointer update completed at " + timestamp);
            writer.newLine();
            writer.write(String.format("-- Summary: Updated %d of %d synonyms successfully", 
                                     successCount, totalSynonyms));
            writer.newLine();
        }
        
        logger.info("Database pointer update completed");
        return RepeatStatus.FINISHED;
    }
    
    private Path determineLogFilePath() {
        if (StringUtils.hasText(pointerLogPath)) {
            return Paths.get(pointerLogPath);
        } else {
            return Paths.get(dialEnv.getOrDefault("CONSOLDIR", "logs"), "syn2cp.out");
        }
    }
    
    private List<String> getTablesForProcessing() {
        // If tables are specified in properties, use those
        if (StringUtils.hasText(databaseTables)) {
            List<String> tables = Arrays.asList(databaseTables.split(","))
                                       .stream()
                                       .map(String::trim)
                                       .collect(Collectors.toList());
            logger.info("Using configured tables list: {}", tables);
            return tables;
        }
        
        // Otherwise query the database for tables
        return listDialTables();
    }
    
    private int updateSynonymsForSchema(String schema, List<String> tables, java.io.Writer logWriter) throws IOException {
        logger.info("Updating synonyms for schema: {}", schema);
        logWriter.write("-- Updating synonyms for schema: " + schema);
        logWriter.newLine();
        
        int successCount = 0;
        
        // For each table, create or replace synonym in the target schema
        for (String table : tables) {
            try {
                String updateSql = String.format(
                    "CREATE OR REPLACE SYNONYM %s.%s FOR %s.%s", 
                    schema, table, sourceSchema, table);
                
                // Execute the synonym creation
                executeWithRetry(updateSql, retryAttempts);
                
                logWriter.write(updateSql + ";");
                logWriter.newLine();
                
                successCount++;
                logger.debug("Updated synonym for table {} in schema {}", table, schema);
            } catch (Exception e) {
                logger.error("Error updating synonym for table {} in schema {}: {}", 
                           table, schema, e.getMessage());
                logWriter.write("-- Error updating " + schema + "." + table + ": " + e.getMessage());
                logWriter.newLine();
            }
        }
        
        logWriter.write(String.format("-- Completed synonym updates for schema: %s (%d of %d successful)", 
                                    schema, successCount, tables.size()));
        logWriter.newLine();
        logWriter.newLine();
        
        return successCount;
    }
    
    private void executeWithRetry(String sql, int retries) {
        int attempts = 0;
        Exception lastException = null;
        
        while (attempts < retries) {
            try {
                jdbcTemplate.execute(sql);
                return; // Success, exit the method
            } catch (Exception e) {
                lastException = e;
                attempts++;
                logger.warn("Attempt {} failed, retrying: {}", attempts, e.getMessage());
                
                // Wait before retry (with exponential backoff)
                try {
                    Thread.sleep(1000 * attempts);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("Interrupted during retry wait", ie);
                }
            }
        }
        
        // If we get here, all retries failed
        throw new RuntimeException("Failed after " + retries + " attempts", lastException);
    }
    
    private List<String> listDialTables() {
        logger.info("Querying database for tables in schema: {}", sourceSchema);
        
        try {
            List<String> tables = jdbcTemplate.query(
                "SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = ? ORDER BY TABLE_NAME",
                (rs, rowNum) -> rs.getString("TABLE_NAME"),
                sourceSchema
            );
            
            // Filter out excluded tables
            tables = tables.stream()
                .filter(tableName -> !excludeTablesList.contains(tableName))
                .collect(Collectors.toList());
            
            logger.info("Found {} tables in schema {}", tables.size(), sourceSchema);
            return tables;
        } catch (Exception e) {
            logger.error("Error retrieving tables from database", e);
            
            // Fallback to hardcoded list if database query fails
            logger.info("Using fallback table list");
            return Arrays.asList(
                "TINSUMMARY", "DIALMOD2", "DIALENT2", "TALENT2", "COREDIAL",
                "DIALENT", "DIALMOD", "DIALSUM", "MODELS"
            );
        }
    }
    
    /**
     * Service method to manually update database pointers
     * 
     * @param specificSchema Optional schema to update (null for all configured schemas)
     * @return Number of synonyms successfully updated
     */
    public int updateDatabasePointers(String specificSchema) {
        try {
            List<String> schemasToProcess = specificSchema != null ?
                    Arrays.asList(specificSchema) : schemasList;
            
            List<String> tablesToProcess = getTablesForProcessing();
            int totalSuccess = 0;
            
            for (String schema : schemasToProcess) {
                logger.info("Manually updating pointers for schema: {}", schema);
                
                java.io.StringWriter writer = new java.io.StringWriter();
                int schemaSuccess = updateSynonymsForSchema(schema, tablesToProcess, writer);
                totalSuccess += schemaSuccess;
                
                logger.info("Updated {}/{} synonyms for schema: {}", 
                          schemaSuccess, tablesToProcess.size(), schema);
            }
            
            logger.info("Manual database pointer update completed. " +
                      "Updated {}/{} synonyms successfully.", 
                      totalSuccess, schemasToProcess.size() * tablesToProcess.size());
            
            return totalSuccess;
        } catch (Exception e) {
            logger.error("Error during manual database pointer update", e);
            throw new RuntimeException("Failed to update database pointers", e);
        }
    }
    
    /**
     * Overloaded method to update all configured schemas
     * 
     * @return Number of synonyms successfully updated
     */
    public int updateDatabasePointers() {
        return updateDatabasePointers(null);
    }
    
    /**
     * Check if synonyms are valid for all schemas and tables
     * 
     * @return List of invalid synonyms in format "schema.table"
     */
    public List<String> validateDatabasePointers() {
        List<String> invalidSynonyms = new ArrayList<>();
        List<String> tablesToProcess = getTablesForProcessing();
        
        for (String schema : schemasList) {
            for (String table : tablesToProcess) {
                String checkSql = String.format(
                    "SELECT COUNT(*) FROM ALL_SYNONYMS WHERE OWNER = ? AND SYNONYM_NAME = ? " +
                    "AND TABLE_OWNER = ? AND TABLE_NAME = ?");
                
                try {
                    int count = jdbcTemplate.queryForObject(checkSql, Integer.class, 
                                                        schema, table, sourceSchema, table);
                    
                    if (count == 0) {
                        invalidSynonyms.add(schema + "." + table);
                    }
                } catch (Exception e) {
                    logger.warn("Error checking synonym {}.{}: {}", schema, table, e.getMessage());
                    invalidSynonyms.add(schema + "." + table + " (error)");
                }
            }
        }
        
        logger.info("Synonym validation completed. Found {} invalid synonyms", invalidSynonyms.size());
        return invalidSynonyms;
    }
}