@Test
@Disabled
public void testRestoreAndLaunchAllDailyJobs() {
    // Daily job codes: E5, E3, E8, E7, E8
    List<String> jobCodes = Arrays.asList("E5", "E3", "E8", "E7", "E8");
    
    for (String jobCode : jobCodes) {
        List<String> tables = Constants.DAILY_JOB_TABLES.get(jobCode);
        assertDoesNotThrow(() -> {
            try {
                // Create a single integration tester and execute each job sequentially
                IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializeViewService)
                    .forJob(jobCode)
                    .forTables(tables)
                    .forPrefix(Constants.DAILY)
                    .withPreforSnapshotDate(priorSnapshotDate)
                    .execute(() -> {
                        try {
                            // Execute the job and wait for completion
                            switch (jobCode) {
                                case "E5":
                                    CompletableFuture<Void> e5Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE5Job();
                                        } catch (Exception e) {
                                            System.err.println("Error executing E5 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E5 job execution failed", e);
                                        }
                                    });
                                    e5Future.join(); // Wait for completion
                                    break;
                                case "E3":
                                    CompletableFuture<Void> e3Future = CompletableFuture.runAsync(() -> {
                                        try {
                                            batchRunJobService.runE3Job();
                                        } catch (Exception e) {
                                            System.err.println("Error executing E3 job: " + e.getMessage());
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
                                        } catch (Exception e) {
                                            System.err.println("Error executing E8 job: " + e.getMessage());
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
                                        } catch (Exception e) {
                                            System.err.println("Error executing E7 job: " + e.getMessage());
                                            e.printStackTrace();
                                            throw new RuntimeException("E7 job execution failed", e);
                                        }
                                    });
                                    e7Future.join(); // Wait for completion
                                    break;
                                default:
                                    throw new IllegalArgumentException("Unknown job code: " + jobCode);
                            }
                            return null;
                        } catch (Exception e) {
                            System.err.println("Error in job execution for job code " + jobCode + ": " + e.getMessage());
                            e.printStackTrace();
                            throw e; // Re-throw to be caught by the outer try-catch
                        }
                    });
                
                System.out.println("Job launch for daily job code " + jobCode + " completed successfully");
            } catch (Exception e) {
                System.err.println("Failed to execute job code " + jobCode + ": " + e.getMessage());
                e.printStackTrace();
                throw e; // Re-throw to be caught by assertDoesNotThrow
            }
        }, "Job launch for daily job code " + jobCode + " should not throw an exception");
    }
}
