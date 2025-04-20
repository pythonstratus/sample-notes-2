package gov.irs.sbse.os.ts.csp.alsentity.ale.util;

import gov.irs.sbse.os.ts.csp.alsentity.ale.Constants;
import gov.irs.sbse.os.ts.csp.alsentity.ale.model.TableValidationResult;
import gov.irs.sbse.os.ts.csp.alsentity.ale.repository.EntityRepository;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.DatabaseSnapshotService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.MaterializedViewService;

import lombok.extern.slf4j.Slf4j;

import org.springframework.batch.core.JobExecution;

import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.stream.Collectors;

/**
 * Utility class for running batch jobs with appropriate snapshot restoration
 */
@Slf4j
public class JobUtil {
    
    private final Map<String, EntityRepository> entityRepos;
    private final DatabaseSnapshotService dbSnapshotService;
    private final MaterializedViewService materializedViewService;
    
    private String jobCode;
    private List<String> tables;
    private String priorSnapshotDate;
    private String prefix;
    
    private JobUtil(Map<String, EntityRepository> entityRepos, 
                   DatabaseSnapshotService dbSnapshotService, 
                   MaterializedViewService materializedViewService) {
        this.entityRepos = entityRepos;
        this.dbSnapshotService = dbSnapshotService;
        this.materializedViewService = materializedViewService;
    }
    
    /**
     * Builder method to create a JobUtil instance
     */
    public static JobUtil builder(Map<String, EntityRepository> entityRepos,
                           DatabaseSnapshotService dbSnapshotService,
                           MaterializedViewService materializedViewService) {
        return new JobUtil(entityRepos, dbSnapshotService, materializedViewService);
    }
    
    /**
     * Set the job code
     */
    public JobUtil forJob(String jobCode) {
        this.jobCode = jobCode;
        return this;
    }
    
    /**
     * Set the tables to restore
     */
    public JobUtil forTables(List<String> tables) {
        this.tables = tables;
        return this;
    }
    
    /**
     * Set the prior snapshot date
     */
    public JobUtil withPriorSnapshotDate(String priorSnapshotDate) {
        this.priorSnapshotDate = priorSnapshotDate;
        return this;
    }
    
    /**
     * Set the prefix (DAILY or WEEKLY)
     */
    public JobUtil forPrefix(String prefix) {
        this.prefix = prefix;
        return this;
    }
    
    /**
     * Execute the job with proper setup and cleanup
     * 
     * @param jobRunner The job to execute
     * @return JobExecution result
     * @throws Exception if execution fails
     */
    public <T> T execute(Callable<T> jobRunner) throws Exception {
        if (tables == null || tables.isEmpty()) {
            throw new IllegalStateException("No tables provided for job code: " + jobCode);
        }
        
        List<String> uniqueTables = tables.stream().distinct().collect(Collectors.toList());
        
        // Validate and restore prior-day snapshot tables
        EntityRepository destRepo = entityRepos.get(Constants.DEST_REPO_KEY);
        for (String table : uniqueTables) {
            if (table.startsWith("DIAL.")) {
                table = table.substring("DIAL.".length());
            }
            String priorSnapshotTableName = String.format("%s_%s_%s_%s", table, prefix, Constants.PRE_SNAPSHOT, priorSnapshotDate);
            String checkSQL = "SELECT COUNT(*) FROM ALL_TABLES WHERE TABLE_NAME='" + priorSnapshotTableName.toUpperCase() + "'";
            Integer snapshotCount = destRepo.queryForObject(checkSQL, Integer.class);
            if (snapshotCount == null || snapshotCount == 0) {
                throw new Exception("Required prior-day snapshot table " + priorSnapshotTableName + " does not exist.");
            }
        }
        
        // Restore prior snapshots
        for (String table : uniqueTables) {
            // Skip restore these tables due to they are not existed
            if ("ICSZIP5".equalsIgnoreCase(table) || "TINSUMMARY".equalsIgnoreCase(table) || table.startsWith("DIAL.")) {
                continue;
            }
            
            String snapshotTable = String.format("%s_%s_%s_%s", table, prefix, Constants.PRE_SNAPSHOT, priorSnapshotDate);
            
            boolean restored = dbSnapshotService.restoreSnapshotByDate(Constants.DEST_REPO_KEY, table, priorSnapshotDate, snapshotTable);
            if (!restored) {
                throw new Exception("Prior snapshot restoration failed for table " + table);
            }
        }
        
        // Execute the job
        T jobExecution = jobRunner.call();
        log.info("Job executed successfully for job code {}", jobCode);
        
        return jobExecution;
    }
}
