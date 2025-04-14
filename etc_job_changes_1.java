@Test
@Disabled
public void testRestoreAndLaunchAllDailyJobs() {
    // Daily job codes: E5, E3, E8, E7, E8
    List<String> jobCodes = Arrays.asList("E5", "E3", "E8", "E7", "E8");
    
    for (String jobCode : jobCodes) {
        List<String> tables = Constants.DAILY_JOB_TABLES.get(jobCode);
        assertDoesNotThrow(() -> {
            // Create a single integration tester and execute each job sequentially
            IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializeViewService)
                .forJob(jobCode)
                .forTables(tables)
                .forPrefix(Constants.DAILY)
                .withPreforSnapshotDate(priorSnapshotDate)
                .execute(() -> {
                    // Execute the job and wait for completion
                    switch (jobCode) {
                        case "E5":
                            CompletableFuture<Void> e5Future = CompletableFuture.runAsync(() -> batchRunJobService.runE5Job());
                            e5Future.join(); // Wait for completion
                            break;
                        case "E3":
                            CompletableFuture<Void> e3Future = CompletableFuture.runAsync(() -> batchRunJobService.runE3Job());
                            e3Future.join(); // Wait for completion
                            break;
                        case "E8":
                            CompletableFuture<Void> e8Future = CompletableFuture.runAsync(() -> batchRunJobService.runE8Job());
                            e8Future.join(); // Wait for completion
                            break;
                        case "E7":
                            CompletableFuture<Void> e7Future = CompletableFuture.runAsync(() -> batchRunJobService.runE7Job());
                            e7Future.join(); // Wait for completion
                            break;
                        default:
                            throw new IllegalArgumentException("Unknown job code: " + jobCode);
                    }
                    return null;
                });
            
            System.out.println("Job launch for daily job code " + jobCode + " completed successfully");
        }, "Job launch for daily job code " + jobCode + " should not throw an exception");
    }
}
