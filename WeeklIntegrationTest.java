package org.springframework.batch.test.context;

import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Disabled;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.JobExecution;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest(classes = App.class)
@ActiveProfiles("test-local")
@SIf4J
public class WeeklyIntegrationTest {

    private static final String priorSnapshotDate = "03302025"; // Prior snapshot date for validation

    @SuppressWarnings("SpringJavaInjectionPointsAutowiringInspection")
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
     * Test for weekly job code S1.
     */
    @Test
    //@Disabled
    public void testRestoreAndLaunchAllWeeklyJobs() {
        for (String jobCode : Constants.WEEKLY_JOB_CODES) {
            List<String> tables = Constants.WEEKLY_JOB_TABLES.get(jobCode);
            final String currentJobCode = jobCode;
            
            assertDoesNotThrow(() -> {
                // Create a single integration tester and execute each job sequentially
                IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                .forJob(currentJobCode)
                .forTables(tables)
                .forPrefix(Constants.WEEKLY)
                .withPriorSnapshotDate(priorSnapshotDate)
                .execute(() -> {
                    switch (currentJobCode) {
                        case "S1":
                            CompletableFuture<Void> s1Future = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runS1Job();
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM S1TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing S1 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"S1 job execution failed", e);
                                }
                            });
                            s1Future.join(); // wait for completion
                            break;
                            
                        case "E1":
                            CompletableFuture<Void> e1Future = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runE1Job();
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM E1TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing E1 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"E1 job execution failed", e);
                                }
                            });
                            e1Future.join(); // wait for completion
                            break;
                            
                        case "E2":
                            CompletableFuture<Void> e2Future = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runE2Job();
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM E2TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing E2 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"E2 job execution failed", e);
                                }
                            });
                            e2Future.join(); // wait for completion
                            break;
                            
                        case "E4":
                            CompletableFuture<Void> e4Future = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runE4Job();
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM E4TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing E4 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"E4 job execution failed", e);
                                }
                            });
                            e4Future.join(); // wait for completion
                            break;
                            
                        case "E3":
                            CompletableFuture<Void> e3Future = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runE3Job(isDaily:false);
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM E3TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing E3 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"E3 job execution failed", e);
                                }
                            });
                            e3Future.join(); // wait for completion
                            break;
                            
                        case "EA":
                            CompletableFuture<Void> eaFuture = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runEAJob();
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM EATABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing EA job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"EA job execution failed", e);
                                }
                            });
                            eaFuture.join(); // wait for completion
                            break;
                            
                        case "E9":
                            CompletableFuture<Void> e9Future = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runE9Job();
                                    Thread.sleep(millis:100);
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM E9TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing E9 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"E9 job execution failed", e);
                                }
                            });
                            e9Future.join(); // wait for completion
                            break;
                            
                        case "E6":
                            CompletableFuture<Void> e6Future = CompletableFuture.runAsync(() -> {
                                try {
                                    String today = DateUtil.getCurrentReportingMonthYear();
                                    String RPRTMTH = DateUtil.getReportingMonth(today);
                                    String CONSTARTDT = entMonthService.findStartDateByReportingMonth(RPRTMTH);
                                    String EOREMDT = entMonthService.findEndDateByReportingMonth(RPRTMTH);
                                    
                                    batchRunJobService.runE6Job();
                                    Thread.sleep(millis:100);
                                    batchRunJobService.runMonthlyJob(CONSTARTDT, EOREMDT, RPRTMTH);
                                    Thread.sleep(millis:100);
                                    batchRunJobService.runCascadingJob(CONSTARTDT, EOREMDT, RPRTMTH);
                                    Thread.sleep(millis:100);
                                    
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM E6TABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing E6 job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"E6 job execution failed", e);
                                }
                            });
                            e6Future.join(); // wait for completion
                            break;
                            
                        case "MOSES":
                            CompletableFuture<Void> mosesFuture = CompletableFuture.runAsync(() -> {
                                try {
                                    batchRunJobService.runMosesJob();
                                    Thread.sleep(millis:100);
                                    batchRunJobService.runMosesOpenJob();
                                    Thread.sleep(millis:100);
                                    
                                    Integer recordCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM MOSESTABLE", Integer.class);
                                    insertLogLoadRecord(currentJobCode, priorSnapshotDate, recordCount != null ? recordCount : 0);
                                } catch (Exception e) {
                                    log.warn("Error executing MOSES job: " + e.getMessage());
                                    e.printStackTrace();
                                    throw new RuntimeException(message:"MOSES job execution failed", e);
                                }
                            });
                            mosesFuture.join(); // wait for completion
                            break;
                            
                        default:
                            throw new IllegalArgumentException("Unknown job code: " + currentJobCode);
                    }
                    return null;
                });
            });
        }
    }
    
    /**
     * Insert a record into the log load table
     * 
     * @param jobCode The job code
     * @param snapshotDate The snapshot date
     * @param recordCount The record count
     */
    private void insertLogLoadRecord(String jobCode, String snapshotDate, int recordCount) {
        try {
            logLoadService.insertLogLoadRecord(jobCode, snapshotDate, recordCount);
        } catch (Exception e) {
            log.warn("Error in job execution for job code " + jobCode + ": " + e.getMessage());
            e.printStackTrace();
            throw e; // Re-throw to be caught by the outer try-catch
        }
    }
}
