package gov.irs.sbse.os.ts.csp.alsentity.ale.util;

import gov.irs.sbse.os.ts.csp.alsentity.ale.Constants;
import gov.irs.sbse.os.ts.csp.alsentity.ale.model.TableValidationResult;
import gov.irs.sbse.os.ts.csp.alsentity.ale.repository.EntityRepository;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.BatchRunJobService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.DatabaseSnapshotService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.LogLoadService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.MaterializedViewService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.IntegrationTestUtil;
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

@Component
@Slf4j
public class DailyRunner {
    
    @Autowired(required = false)
    private String injectedPriorSnapshotDate;
    
    private static final String DEFAULT_PRIOR_SNAPSHOT_DATE = "04052025"; // Default value
    
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
    private LogLoadService logLoadService;
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    /**
     * Run E5 job 
     */
    public void runE5Job() {
        List<String> tables = Constants.DAILY_JOB_TABLES.get("E5");
        try {
            IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E5")
                .forTables(tables)
                .forPrefix(Constants.DAILY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE5Job();
                    return null;
                });
            System.out.println("Job launch for job code E5 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E5: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E3 job
     */
    public void runE3Job() {
        List<String> tables = Constants.DAILY_JOB_TABLES.get("E3");
        try {
            IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E3")
                .forTables(tables)
                .forPrefix(Constants.DAILY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE3Job(true);
                    return null;
                });
            System.out.println("Job launch for job code E3 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E3: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E8 job
     */
    public void runE8Job() {
        List<String> tables = Constants.DAILY_JOB_TABLES.get("E8");
        try {
            IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E8")
                .forTables(tables)
                .forPrefix(Constants.DAILY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE8Job();
                    return null;
                });
            System.out.println("Job launch for job code E8 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E8: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E7 job
     */
    public void runE7Job() {
        List<String> tables = Constants.DAILY_JOB_TABLES.get("E7");
        try {
            IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E7")
                .forTables(tables)
                .forPrefix(Constants.DAILY)
                .withPriorSnapshotDate(getPriorSnapshotDate())
                .execute(() -> {
                    batchRunJobService.runE7Job();
                    return null;
                });
            System.out.println("Job launch for job code E7 completed successfully");
        } catch (Exception e) {
            System.out.println("Error in job execution for job code E7: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Run E9 job
     */
    public void runE9Job() {
        List<String> tables = Constants.DAILY_JOB_TABLES.get("E9");
        try {
            IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob("E9")
                .forTables(tables)
                .forPrefix(Constants.DAILY)
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
     * Run all daily jobs
     */
    public void runAllDailyJobs() {
        // Daily job codes: E5, E3, E8, E7, E9
        List<String> jobCodes = Arrays.asList("E5", "E3", "E8", "E7", "E9");
        
        for (String jobCode : jobCodes) {
            List<String> tables = Constants.DAILY_JOB_TABLES.get(jobCode);
            try {
                // Create a single integration tester and execute each job sequentially
                IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                    .forJob(jobCode)
                    .forTables(tables)
                    .forPrefix(Constants.DAILY)
                    .withPriorSnapshotDate(getPriorSnapshotDate())
                    .execute(() -> {
                        try {
                            // Execute the job and wait for completion
                            switch (jobCode) {
                                case "E5":
                                    CompletableFuture<Void> e5Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE5Job();
                                            Thread.sleep(100);
                                            Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM ENTMGR", Integer.class);
                                            insertLogLoadRecord(jobCode, getPriorSnapshotDate(), recordCount != null ? recordCount : 0);
                                        } catch (Exception e) {
                                            System.out.println("Error executing E5 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E5 job execution failed", e);
                                        }
                                    });
                                    e5Future.join(); // Wait for completion
                                    break;
                                case "E3":
                                    CompletableFuture<Void> e3Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE3Job(true);
                                            Thread.sleep(100);
                                            Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM ENTACT", Integer.class);
                                            insertLogLoadRecord(jobCode, getPriorSnapshotDate(), recordCount != null ? recordCount : 0);
                                        } catch (Exception e) {
                                            System.out.println("Error executing E3 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E3 job execution failed", e);
                                        }
                                    });
                                    e3Future.join(); // Wait for completion
                                    break;
                                case "E8":
                                    CompletableFuture<Void> e8Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE8Job();
                                            Thread.sleep(100);
                                            Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM TIMENTM", Integer.class);
                                            insertLogLoadRecord(jobCode, getPriorSnapshotDate(), recordCount != null ? recordCount : 0);
                                        } catch (Exception e) {
                                            System.out.println("Error executing E8 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E8 job execution failed", e);
                                        }
                                    });
                                    e8Future.join(); // Wait for completion
                                    break;
                                case "E7":
                                    CompletableFuture<Void> e7Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE7Job();
                                            Thread.sleep(100);
                                            Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM TIMENTIN", Integer.class);
                                            insertLogLoadRecord(jobCode, getPriorSnapshotDate(), recordCount != null ? recordCount : 0);
                                        } catch (Exception e) {
                                            System.out.println("Error executing E7 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E7 job execution failed", e);
                                        }
                                    });
                                    e7Future.join(); // Wait for completion
                                    break;
                                case "E9":
                                    CompletableFuture<Void> e9Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE9Job();
                                            Thread.sleep(100);
                                            Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM entmod", Integer.class);
                                            insertLogLoadRecord(jobCode, getPriorSnapshotDate(), recordCount != null ? recordCount : 0);
                                        } catch (Exception e) {
                                            System.out.println("Error executing E9 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E9 job execution failed", e);
                                        }
                                    });
                                    e9Future.join(); // Wait for completion
                                    break;
                                default:
                                    throw new IllegalArgumentException("Unknown job code: " + jobCode);
                            }
                            return null;
                        } catch (Exception e) {
                            System.out.println("Error in job execution for job code " + jobCode + ": " + e.getMessage());
                            e.printStackTrace();
                            throw e; // Re-throw to be caught by the outer try-catch
                        }
                    });
                System.out.println("Job launch for daily job code " + jobCode + " completed successfully");
            } catch (Exception e) {
                System.out.println("Failed to execute job code " + jobCode + ": " + e.getMessage());
                e.printStackTrace();
            }
        }
    }
    
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
