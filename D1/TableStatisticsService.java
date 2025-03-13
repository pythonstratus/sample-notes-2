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

import javax.sql.DataSource;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * Implementation of the Dial1_dothcp shell script functionality.
 * Gathers Oracle table statistics for DIAL tables.
 */
@Service
public class TableStatisticsService implements Tasklet {
    private static final Logger logger = LoggerFactory.getLogger(TableStatisticsService.class);
    
    private final JdbcTemplate jdbcTemplate;
    private final Map<String, String> dialEnv;
    
    @Value("${dial.statistics.sample.size:100}")
    private int sampleSize;
    
    @Value("${dial.statistics.tables:TINSUMMARY,DIALMOD2,DIALENT2,TALENT2,COREDIAL}")
    private String tablesList;
    
    @Value("${dial.statistics.log.directory:#{null}}")
    private String statisticsLogDirectory;
    
    @Value("${dial.oracle.sid}")
    private String oracleSid;
    
    @Value("${spring.datasource.username:DIAL}")
    private String dbOwner;
    
    private List<String> tablesToAnalyze;
    
    @Autowired
    public TableStatisticsService(DataSource dataSource, DialEnvironmentConfig config) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
        this.dialEnv = config.dialEnvironment(null);
        this.tablesToAnalyze = Arrays.asList(tablesList.split(","));
    }
    
    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        logger.info("Starting table statistics collection for SID: {}", oracleSid);
        
        String logDir = statisticsLogDirectory != null ? 
                         statisticsLogDirectory : 
                         dialEnv.getOrDefault("CONSOLDIR", "logs/statistics");
        
        Path logFileDialcopy = Paths.get(logDir, "dialcopy.out");
        Path logFileDialcopy2 = Paths.get(logDir, "dialcopy2.out");
        
        Files.createDirectories(logFileDialcopy.getParent());
        
        // Write to first log file
        try (var writer = Files.newBufferedWriter(logFileDialcopy, StandardCharsets.UTF_8, 
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
            
            writer.write("-- Table statistics collection started at " + 
                         LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
            writer.newLine();
            writer.write("-- Oracle SID: " + oracleSid);
            writer.newLine();
            writer.write("-- Database owner: " + dbOwner);
            writer.newLine();
            writer.newLine();
            
            // Collect statistics for all tables in the first pass
            for (String table : tablesToAnalyze) {
                collectTableStatistics(table, writer);
            }
        }
        
        // Write to second log file for different databases
        try (var writer = Files.newBufferedWriter(logFileDialcopy2, StandardCharsets.UTF_8, 
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
            
            writer.write("-- Table statistics collection (second pass) started at " + 
                         LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
            writer.newLine();
            writer.write("-- Oracle SID: " + oracleSid);
            writer.newLine();
            writer.write("-- Database owner: " + dbOwner);
            writer.newLine();
            writer.newLine();
            
            // Additional database connections would go here in a real implementation
            // This simulates the multiple executions of SQL*Plus in the shell script
        }
        
        logger.info("Table statistics collection completed for {} tables", tablesToAnalyze.size());
        return RepeatStatus.FINISHED;
    }
    
    private void collectTableStatistics(String tableName, java.io.Writer logWriter) {
        try {
            logger.info("Collecting statistics for table: {}", tableName);
            
            // Get table metadata
            String metadataSql = String.format(
                "SELECT COUNT(*) AS row_count, " +
                "TO_CHAR(NVL(MAX(LAST_ANALYZED), SYSDATE), 'YYYY-MM-DD HH24:MI:SS') AS last_analyzed " +
                "FROM ALL_TABLES WHERE OWNER = '%s' AND TABLE_NAME = '%s'", 
                dbOwner, tableName);
            
            Map<String, Object> tableMetadata = jdbcTemplate.queryForMap(metadataSql);
            
            // Get index count
            String indexSql = String.format(
                "SELECT COUNT(*) AS index_count FROM ALL_INDEXES " +
                "WHERE OWNER = '%s' AND TABLE_NAME = '%s'", 
                dbOwner, tableName);
            
            Integer indexCount = jdbcTemplate.queryForObject(indexSql, Integer.class);
            
            // Write statistics to log
            logWriter.write(String.format("-- Statistics for table %s:", tableName));
            logWriter.newLine();
            logWriter.write(String.format("-- Row count: %s", tableMetadata.get("row_count")));
            logWriter.newLine();
            logWriter.write(String.format("-- Index count: %s", indexCount));
            logWriter.newLine();
            logWriter.write(String.format("-- Last analyzed: %s", tableMetadata.get("last_analyzed")));
            logWriter.newLine();
            
            // Generate the actual Oracle statistics gathering command
            logWriter.write(String.format("EXEC DBMS_STATS.GATHER_TABLE_STATS(" +
                                          "ownname=>'%s', " +
                                          "tabname=>'%s', " +
                                          "cascade=>TRUE, " +
                                          "estimate_percent=>%s, " + 
                                          "method_opt=>'FOR ALL COLUMNS SIZE AUTO');", 
                                          dbOwner, tableName, "DBMS_STATS.AUTO_SAMPLE_SIZE"));
            logWriter.newLine();
            logWriter.newLine();
            
            // Execute the Oracle procedure for gathering stats
            executeStatisticsGathering(tableName);
            
            logger.info("Statistics collected for table: {}", tableName);
        } catch (Exception e) {
            logger.error("Error collecting statistics for table: {}", tableName, e);
        }
    }
    
    private void executeStatisticsGathering(String tableName) {
        try {
            String plsql = String.format(
                "BEGIN DBMS_STATS.GATHER_TABLE_STATS(" +
                "ownname => '%s', " +
                "tabname => '%s', " +
                "cascade => TRUE, " +
                "estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE, " +
                "method_opt => 'FOR ALL COLUMNS SIZE AUTO'); END;", 
                dbOwner, tableName);
            
            jdbcTemplate.execute(plsql);
            
            logger.debug("Executed statistics gathering for table: {}", tableName);
        } catch (Exception e) {
            logger.error("Failed to execute statistics gathering for table: {}", tableName, e);
        }
    }
    
    /**
     * Service method to manually trigger statistics collection
     */
    public void updateTableStatistics() {
        try {
            logger.info("Manually updating statistics for {} tables with sample size {}%", 
                      tablesToAnalyze.size(), sampleSize);
            
            for (String table : tablesToAnalyze) {
                logger.info("Manually updating statistics for table: {}", table);
                
                String plsql = String.format(
                    "BEGIN DBMS_STATS.GATHER_TABLE_STATS(" +
                    "ownname => '%s', " +
                    "tabname => '%s', " +
                    "cascade => TRUE, " +
                    "estimate_percent => %d, " +
                    "method_opt => 'FOR ALL COLUMNS SIZE AUTO'); END;", 
                    dbOwner, table, sampleSize);
                
                jdbcTemplate.execute(plsql);
            }
            
            logger.info("Manual statistics update completed");
        } catch (Exception e) {
            logger.error("Error during manual statistics update", e);
            throw new RuntimeException("Failed to update table statistics", e);
        }
    }
}