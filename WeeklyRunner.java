
import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.jdbc.core.JdbcTemplate;

import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * Runner class for weekly jobs
 */
@Component
@Slf4j
public class WeeklyRunner {
    
    @Autowired(required = false)
    private String injectedPriorSnapshotDate;
    
    private static final String DEFAULT_PRIOR_SNAPSHOT_DATE = "03302025"; // Default value
    
    // Method to get the appropriate prior snapshot date
    private String getPriorSnapshotDate() {
        return (injectedPriorSnapshotDate != null) ? injectedPriorSnapshotDate : DEFAULT_PRIOR_SNAPSHOT_DATE;
    }
    
    @Autowired
    private Map<String, EntityRepository> entityRepos;
    
    @Autowired
    private BatchRunJobService batchRunJobService;
    
    @Autowired
    private DatabaseSnapshotService dbSnapshotService;
    
    @Autowired
    private MaterializedViewService materializedViewService;
    
    @Autowired
    private EntMonthService entMonthService;
    
    @Autowired
    private LogLoadService logLoadService;
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    /**
     * Run S1 job
     */
    public void runS1Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("S1");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("S1")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runS1Job();
                    return null;
                });
            System.out.println("Job launch for job code S1 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code S1: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E1 job
     */
    public void runE1Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("E1");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E1")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE1Job();
                    return null;
                });
            System.out.println("Job launch for job code E1 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E1: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E2 job
     */
    public void runE2Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("E2");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E2")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE2Job();
                    return null;
                });
            System.out.println("Job launch for job code E2 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E2: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E4 job
     */
    public void runE4Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("E4");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E4")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE4Job();
                    return null;
                });
            System.out.println("Job launch for job code E4 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E4: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E3 job
     */
    public void runE3Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("E3");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E3")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE3Job(false);
                    return null;
                });
            System.out.println("Job launch for job code E3 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E3: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run EA job
     */
    public void runEAJob() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("EA");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("EA")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runEAJob();
                    return null;
                });
            System.out.println("Job launch for job code EA completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code EA: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E9 job
     */
    public void runE9Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("E9");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E9")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE9Job();
                    return null;
                });
            System.out.println("Job launch for job code E9 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E9: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E6 job
     */
    public void runE6Job() {
        String jobCode = "E6";
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get(jobCode);
        try {
            String today = DateUtil.getCurrentDateMonthDayYear();
            String rpymnth = DateUtil.getReportMonth(today);
            String eowstartdt = entMonthService.findStartDateByRptMonth(rpymnth);
            String eowenddt = entMonthService.findEndDateByRptMonth(rpymnth);
            
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob(jobCode)
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE6Job();
                    batchRunJobService.runMArchivJob(eowstartdt, eowenddt, rpymnth);
                    batchRunJobService.runArchiveImgJob(eowstartdt, eowenddt, rpymnth);
                    batchRunJobService.runCasesdpJob(eowstartdt, eowenddt, rpymnth);
                    return null;
                });
            System.out.println("Job launch for job code E6 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E6: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run NOSEG5 job
     */
    public void runNOSEG5Job() {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get("NOSEG5");
        try {
            JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("NOSEG5")
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runNosegJob();
                    batchRunJobService.runNosegOpenJob();
                    return null;
                });
            System.out.println("Job launch for job code NOSEG5 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code NOSEG5: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run all weekly jobs
     */
    public void runAllWeeklyJobs() {
        for (String jobCode : Constants.WEEKLY_JOB_CODES) {
            List<String> tables = Constants.WEEKLY_JOB_TABLES.get(jobCode);
            try {
                System.out.println("Starting execution of weekly job: " + jobCode);
                
                JobUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                    .forJob(jobCode)
                    .forTables(tables)
                    .forPrefix(Constants.WEEKLY)
                    .withPriorSnapshotDate(getPriorSnapshotDate())
                    .execute(() -> {
                        runJobByCode(jobCode);
                        return null;
                    });
                
                System.out.println("Job launch for job code " + jobCode + " completed successfully");
            } catch (Exception e) {
                System.out.println("Failed to execute job code " + jobCode + ": " + e.getMessage());
                e.printStackTrace();
            }
        }
    }
    
    /**
     * Helper method to run the job based on job code
     */
    private void runJobByCode(String jobCode) throws Exception {
        switch (jobCode) {
            case "S1":
                batchRunJobService.runS1Job();
                break;
            case "E1":
                batchRunJobService.runE1Job();
                break;
            case "E2":
                batchRunJobService.runE2Job();
                break;
            case "E4":
                batchRunJobService.runE4Job();
                break;
            case "E3":
                batchRunJobService.runE3Job(false);
                break;
            case "EA":
                batchRunJobService.runEAJob();
                break;
            case "E9":
                batchRunJobService.runE9Job();
                break;
            case "E6":
                String today = DateUtil.getCurrentDateMonthDayYear();
                String rpymnth = DateUtil.getReportMonth(today);
                String eowstartdt = entMonthService.findStartDateByRptMonth(rpymnth);
                String eowenddt = entMonthService.findEndDateByRptMonth(rpymnth);
                batchRunJobService.runE6Job();
                batchRunJobService.runMArchivJob(eowstartdt, eowenddt, rpymnth);
                batchRunJobService.runArchiveImgJob(eowstartdt, eowenddt, rpymnth);
                batchRunJobService.runCasesdpJob(eowstartdt, eowenddt, rpymnth);
                break;
            case "NOSEG5":
                batchRunJobService.runNosegJob();
                batchRunJobService.runNosegOpenJob();
                break;
            default:
                throw new IllegalArgumentException("Unknown job code: " + jobCode);
        }
    }
    
    /**
     * Helper method to insert a log record for job execution
     */
    private void insertLogLoadRecord(String jobCode, String extractDate, int recordCount) {
        try {
            // Create a properly formatted date for Oracle
            // Oracle expects dates in a specific format, typically 'YYYY-MM-DD'
            // If extractDate is already in 'MMddyyyy' format, convert it to Oracle's expected format
            java.sql.Date sqlExtractDate;
            try {
                SimpleDateFormat inputFormat = new SimpleDateFormat("MMddyyyy");
                SimpleDateFormat oracleFormat = new SimpleDateFormat("yyyy-MM-dd");
                Date parsedDate = inputFormat.parse(extractDate);
                String formattedExtractDate = oracleFormat.format(parsedDate);
                sqlExtractDate = java.sql.Date.valueOf(formattedExtractDate);
            } catch (Exception e) {
                // If parsing fails, use current date as fallback
                sqlExtractDate = new java.sql.Date(System.currentTimeMillis());
                System.out.println("Failed to parse extract date: " + extractDate + ", using current date");
            }
            
            // Current date in SQL format
            java.sql.Date sqlLoadDate = new java.sql.Date(System.currentTimeMillis());
            
            // Get username
            String username = System.getProperty("user.name");
            if (username == null || username.isEmpty()) {
                username = "SYSTEM";
            }
            
            // SQL to insert a new record using proper date format for Oracle
            String sql = "INSERT INTO LOGLOAD (LOADNAME, EXTRTDT, LOADDT, UNIX, NUMREC) VALUES (?, ?, ?, ?, ?)";
            
            // Execute insert with properly formatted dates
            jdbcTemplate.update(sql,
                    jobCode,
                    sqlExtractDate,  // Use SQL Date object
                    sqlLoadDate,     // Use SQL Date object
                    username,
                    recordCount);
            
            System.out.println("Successfully inserted LOGLOAD record for job " + jobCode + " with count " + recordCount);
        } catch (Exception e) {
            System.out.println("Error inserting LOGLOAD record for job " + jobCode + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
}
