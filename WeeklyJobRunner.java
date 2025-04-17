package gov.irs.sbse.os.ts.csp.alsentity.ale.util;

import gov.irs.sbse.os.ts.csp.alsentity.ale.Constants;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.BatchRunJobService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.DatabaseSnapshotService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.LogLoadService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.service.MaterializedViewService;
import gov.irs.sbse.os.ts.csp.alsentity.ale.repository.EntityRepository;
import gov.irs.sbse.os.ts.csp.alsentity.ale.integrationTestUtil;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.logging.Logger;

/**
 * Runner for weekly batch jobs
 * This class leverages existing functionality but packages it as an executable JAR
 */
@SpringBootApplication
@ComponentScan(basePackages = "gov.irs.sbse.os.ts.csp.alsentity.ale")
public class WeeklyJobRunner implements CommandLineRunner {

    private static final Logger log = Logger.getLogger(WeeklyJobRunner.class.getName());
    
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
    
    // Default prior snapshot date
    private String priorSnapshotDate = "03282023";

    public static void main(String[] args) {
        SpringApplication.run(WeeklyJobRunner.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        if (args.length > 0) {
            priorSnapshotDate = args[0];
            log.info("Using provided prior snapshot date: " + priorSnapshotDate);
        } else {
            log.info("Using default prior snapshot date: " + priorSnapshotDate);
        }
        
        runWeeklyJobs();
    }
    
    /**
     * Run all weekly jobs in sequence and log job information to LOGLOAD table
     */
    private void runWeeklyJobs() {
        // Weekly job codes: S1, E1, E2, E3, E4, EA, and E9
        List<String> jobCodes = Arrays.asList("S1", "E1", "E2", "E3", "E4", "EA", "E9");
        
        for (String jobCode : jobCodes) {
            List<String> tables = Constants.WEEKLY_JOB_TABLES.get(jobCode);
            log.info("Processing job: " + jobCode);
            
            try {
                integrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                    .forJob(jobCode)
                    .forTables(tables)
                    .forPrefix(Constants.WEEKLY)
                    .withPriorSnapshotDate(priorSnapshotDate)
                    .execute(() -> {
                        try {
                            // Execute the job and wait for completion
                            switch (jobCode) {
                                case "S1":
                                    CompletableFuture<Void> s1Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing S1 job...");
                                            int recordCount = batchRunJobService.runS1Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing S1 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("S1 job execution failed", e);
                                        }
                                    });
                                    s1Future.join(); // Wait for completion
                                    break;
                                case "E1":
                                    CompletableFuture<Void> e1Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E1 job...");
                                            int recordCount = batchRunJobService.runE1Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E1 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E1 job execution failed", e);
                                        }
                                    });
                                    e1Future.join(); // Wait for completion
                                    break;
                                case "E2":
                                    CompletableFuture<Void> e2Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E2 job...");
                                            int recordCount = batchRunJobService.runE2Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E2 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E2 job execution failed", e);
                                        }
                                    });
                                    e2Future.join(); // Wait for completion
                                    break;
                                case "E3":
                                    CompletableFuture<Void> e3Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E3 job for weekly run...");
                                            int recordCount = batchRunJobService.runE3Job(false);
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E3 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E3 job execution failed", e);
                                        }
                                    });
                                    e3Future.join(); // Wait for completion
                                    break;
                                case "E4":
                                    CompletableFuture<Void> e4Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E4 job...");
                                            int recordCount = batchRunJobService.runE4Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E4 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E4 job execution failed", e);
                                        }
                                    });
                                    e4Future.join(); // Wait for completion
                                    break;
                                case "EA":
                                    CompletableFuture<Void> eaFuture = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing EA job...");
                                            int recordCount = batchRunJobService.runEAJob();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing EA job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("EA job execution failed", e);
                                        }
                                    });
                                    eaFuture.join(); // Wait for completion
                                    break;
                                case "E9":
                                    CompletableFuture<Void> e9Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E9 job...");
                                            int recordCount = batchRunJobService.runE9Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E9 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E9 job execution failed", e);
                                        }
                                    });
                                    e9Future.join(); // Wait for completion
                                    break;
                                default:
                                    throw new IllegalArgumentException("Unknown job code: " + jobCode);
                            }
                            
                            log.info("Job " + jobCode + " completed successfully");
                            return null;
                        } catch (Exception e) {
                            log.severe("Error in job execution for job code " + jobCode + ": " + e.getMessage());
                            e.printStackTrace();
                            throw e; // Re-throw to be caught by the outer try-catch
                        }
                    });
            } catch (Exception e) {
                log.severe("Failed to execute job " + jobCode + ": " + e.getMessage());
                e.printStackTrace();
            }
        }
        
        log.info("All weekly jobs completed");
    }
}
