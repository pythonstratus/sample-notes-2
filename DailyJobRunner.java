package com.abc.sbse.os.ts.csp.alsentity.ale.util;

import com.abc.sbse.os.ts.csp.alsentity.ale.Constants;
import com.abc.sbse.os.ts.csp.alsentity.ale.service.BatchRunJobService;
import com.abc.sbse.os.ts.csp.alsentity.ale.service.DatabaseSnapshotService;
import com.abc.sbse.os.ts.csp.alsentity.ale.service.LogLoadService;
import com.abc.sbse.os.ts.csp.alsentity.ale.service.MaterializedViewService;
import com.abc.sbse.os.ts.csp.alsentity.ale.repository.EntityRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.logging.Logger;

/**
 * Runner for daily batch jobs
 * This class leverages existing functionality but packages it as an executable JAR
 */
@SpringBootApplication
@ComponentScan(basePackages = "com.abc.sbse.os.ts.csp.alsentity.ale")
public class DailyJobRunner implements CommandLineRunner {

    private static final Logger log = Logger.getLogger(DailyJobRunner.class.getName());
    
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
    
    // Default prior snapshot date
    private String priorSnapshotDate = "03282023";

    public static void main(String[] args) {
        SpringApplication.run(DailyJobRunner.class, args);
    }

    @Override
    public void run(String... args) throws Exception {
        if (args.length > 0) {
            priorSnapshotDate = args[0];
            log.info("Using provided prior snapshot date: " + priorSnapshotDate);
        } else {
            log.info("Using default prior snapshot date: " + priorSnapshotDate);
        }
        
        runDailyJobs();
    }
    
    /**
     * Run all daily jobs in sequence and log job information to LOGLOAD table
     */
    private void runDailyJobs() {
        // Daily job codes: E5, E3, E8, E7, EB
        List<String> jobCodes = Arrays.asList("E5", "E3", "E8", "E7", "EB");
        
        for (String jobCode : jobCodes) {
            List<String> tables = Constants.DAILY_JOB_TABLES.get(jobCode);
            log.info("Processing job: " + jobCode);
            
            try {
                JobExecutionUtil.builder(entityRepos, dbSnapshotService, materializedViewService, jdbcTemplate)
                    .forJob(jobCode)
                    .forTables(tables)
                    .forPrefix(Constants.DAILY)
                    .withPriorSnapshotDate(priorSnapshotDate)
                    .execute(() -> {
                        try {
                            // Execute the job and wait for completion
                            switch (jobCode) {
                                case "E5":
                                    CompletableFuture<Void> e5Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E5 job...");
                                            int recordCount = batchRunJobService.runE5Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E5 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E5 job execution failed", e);
                                        }
                                    });
                                    e5Future.join(); // Wait for completion
                                    break;
                                case "E3":
                                    CompletableFuture<Void> e3Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E3 job...");
                                            int recordCount = batchRunJobService.runE3Job(true);
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
                                case "E8":
                                    CompletableFuture<Void> e8Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E8 job...");
                                            int recordCount = batchRunJobService.runE8Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E8 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E8 job execution failed", e);
                                        }
                                    });
                                    e8Future.join(); // Wait for completion
                                    break;
                                case "E7":
                                    CompletableFuture<Void> e7Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing E7 job...");
                                            int recordCount = batchRunJobService.runE7Job();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing E7 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E7 job execution failed", e);
                                        }
                                    });
                                    e7Future.join(); // Wait for completion
                                    break;
                                case "EB":
                                    CompletableFuture<Void> ebFuture = CompletableFuture.runAsync(() -> {
                                        try {
                                            log.info("Executing EB job...");
                                            int recordCount = batchRunJobService.runEBJob();
                                            // Log job execution to LOGLOAD table
                                            logLoadService.saveLogLoad(jobCode, priorSnapshotDate, recordCount);
                                        } catch (Exception e) {
                                            log.severe("Error executing EB job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("EB job execution failed", e);
                                        }
                                    });
                                    ebFuture.join(); // Wait for completion
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
                log.severe("Failed to execute job code " + jobCode + ": " + e.getMessage());
                e.printStackTrace();
            }
        }
        
        log.info("All daily jobs completed");
    }
}
