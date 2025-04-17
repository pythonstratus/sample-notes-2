package gov.irs.sbse.os.ts.csp.alsentity.ale.util;

import gov.irs.sbse.os.ts.csp.alsentity.ale.Constants;
import gov.irs.sbse.os.ts.csp.alsentity.ale.model.TableValidationResult;
import gov.irs.sbse.os.ts.csp.alsentity.ale.repository.EntityRepository;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.DatabaseSnapshotService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.MaterializedViewService;

import org.springframework.batch.core.JobExecution;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.logging.Logger;
import java.util.stream.Collectors;

/**
 * Utility class for job execution with snapshot validation and restoration
 * This is a production version of functionality similar to IntegrationTestUtil
 */
public class JobExecutionUtil {

    private static final Logger log = Logger.getLogger(JobExecutionUtil.class.getName());
    
    private final Map<String, EntityRepository> entityRepos;
    private final DatabaseSnapshotService dbSnapshotService;
    private final MaterializedViewService materializedViewService;
    private final JdbcTemplate jdbcTemplate;
    
    private String jobCode;
    private List<String> tables;
    private String priorSnapshotDate;
    private String prefix;
    
    /**
     * Private constructor - use the builder() method to create instances
     */
    private JobExecutionUtil(
            Map<String, EntityRepository> entityRepos,
            DatabaseSnapshotService dbSnapshotService,
            MaterializedViewService materializedViewService,
            JdbcTemplate jdbcTemplate) {
        this.entityRepos = entityRepos;
        this.dbSnapshotService = dbSnapshotService;
        this.materializedViewService = materializedViewService;
        this.jdbcTemplate = jdbcTemplate;
    }
    
    /**
     * Create a builder for JobExecutionUtil
     * 
     * @param entityRepos Map of entity repositories
     * @param dbSnapshotService Database snapshot service
     * @param materializedViewService Materialized view service
     * @param jdbcTemplate JDBC template for direct database operations
     * @return A JobExecutionUtil builder
     */
    public static JobExecutionUtil builder(
            Map<String, EntityRepository> entityRepos,
            DatabaseSnapshotService dbSnapshotService,
            MaterializedViewService materializedViewService,
            JdbcTemplate jdbcTemplate) {
        return new JobExecutionUtil(entityRepos, dbSnapshotService, materializedViewService, jdbcTemplate);
    }
    
    /**
     * Set the job code
     * 
     * @param jobCode The job code (e.g., "E5", "S1", etc.)
     * @return This JobExecutionUtil for method chaining
     */
    public JobExecutionUtil forJob(String jobCode) {
        this.jobCode = jobCode;
        return this;
    }
    
    /**
     * Set the tables to process
     * 
     * @param tables List of table names
     * @return This JobExecutionUtil for method chaining
     */
    public JobExecutionUtil forTables(List<String> tables) {
        this.tables = tables;
        return this;
    }
    
    /**
     * Set the prior snapshot date
     * 
     * @param priorSnapshotDate Date of prior snapshot in format MMddyyyy
     * @return This JobExecutionUtil for method chaining
     */
    public JobExecutionUtil withPriorSnapshotDate(String priorSnapshotDate) {
        this.priorSnapshotDate = priorSnapshotDate;
        return this;
    }
    
    /**
     * Set the prefix (e.g., "DAILY" or "WEEKLY")
     * 
     * @param prefix The prefix
     * @return This JobExecutionUtil for method chaining
     */
    public JobExecutionUtil forPrefix(String prefix) {
        this.prefix = prefix;
        return this;
    }
    
    /**
     * Execute a job with validation and snapshot restoration
     * 
     * @param jobRunner The job to run
     * @return The JobExecution result
     * @throws Exception If any error occurs during execution
     */
    public JobExecution execute(Callable<Void> jobRunner) throws Exception {
        if (tables == null || tables.isEmpty()) {
            throw new IllegalStateException("No tables provided for job code: " + jobCode);
        }
        
        // Get unique tables (remove duplicates)
        List<String> uniqueTables = tables.stream().distinct().collect(Collectors.toList());
        
        // Validate and restore prior-day snapshot tables
        EntityRepository destRepo = entityRepos.get(Constants.DEST_REPO_KEY);
        for (String table : uniqueTables) {
            // Handle tables with DIAL. prefix
            if (table.startsWith("DIAL.")) {
                table = table.substring("DIAL.".length());
            }
            
            // Format the prior snapshot table name
            String priorSnapshotTableName = String.format("%s_%s_%s", table, prefix, Constants.PRE_SNAPSHOT, priorSnapshotDate);
            
            // Check if the prior snapshot exists
            String checkSQL = "SELECT COUNT(*) FROM all_tables WHERE table_name = '" + priorSnapshotTableName.toUpperCase() + "'";
            Integer snapshotCount = destRepo.queryForObject(checkSQL, Integer.class);
            
            if (snapshotCount == null || snapshotCount == 0) {
                throw new Exception("Required prior-day snapshot table " + priorSnapshotTableName + " does not exist.");
            }
        }
        
        // Restore prior snapshots
        for (String table : uniqueTables) {
            // Skip tables that should be ignored
            if ("ICSZIPS".equalsIgnoreCase(table) || "TINCURPART".equalsIgnoreCase(table) || table.startsWith("DIAL.")) {
                continue;
            }
            
            // Format snapshot table name
            String snapshotTable = String.format("%s_%s_%s", table, prefix, Constants.PRE_SNAPSHOT, priorSnapshotDate);
            
            // Restore snapshot
            boolean restored = dbSnapshotService.restoreSnapshotByDate(Constants.DEST_REPO_KEY, table, priorSnapshotDate, snapshotTable);
            if (!restored) {
                throw new Exception("Prior snapshot restoration failed for table " + table);
            }
        }
        
        // Execute the job
        try {
            // Call the job runner function
            jobRunner.call();
            log.info(String.format("Job executed successfully for job code {}", jobCode));
            
            // Return a JobExecution for compatibility with Spring Batch
            JobExecution jobExecution = new JobExecution(1L);
            return jobExecution;
        } catch (Exception e) {
            log.severe("Error executing job: " + e.getMessage());
            throw e;
        }
    }
}
