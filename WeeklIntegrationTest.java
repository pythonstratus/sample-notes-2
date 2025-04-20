@Test
// @Disabled
public void testRestoreAndLaunchAllWeeklyJobsSequentially() {
    // Start with an empty completable future
    CompletableFuture<Void> jobChain = CompletableFuture.completedFuture(null);
    
    for (String jobCode : Constants.WEEKLY_JOB_CODES) {
        // Create a new stage in the chain for each job
        final String currentJobCode = jobCode;
        
        jobChain = jobChain.thenCompose(ignored -> {
            return CompletableFuture.runAsync(() -> {
                List<String> tables = Constants.WEEKLY_JOB_TABLES.get(currentJobCode);
                
                try {
                    // Setup the job environment
                    IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                        .forJob(currentJobCode)
                        .forTables(tables)
                        .forPrefix(Constants.WEEKLY)
                        .withPriorSnapshotDate(priorSnapshotDate)
                        .execute();
                    
                    // Run the specific job
                    executeJobByCode(currentJobCode);
                } catch (Exception e) {
                    throw new CompletionException("Job launch for job code " + currentJobCode + " failed", e);
                }
            });
        });
    }
    
    // Wait for all jobs to complete
    try {
        jobChain.join();
    } catch (CompletionException e) {
        fail("Job execution failed: " + e.getMessage());
    }
}

// Helper method to run jobs with exception handling
private void executeJobByCode(String jobCode) throws Exception {
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
            String RPTMNTH = DateUtil.getReportMonth(today);
            String EOMSTARTDT = entMonthService.findStartDateByRptmonth(RPTMNTH);
            String EOMENDDT = entMonthService.findEndDateByRptmonth(RPTMNTH);
            batchRunJobService.runE6Job();
            batchRunJobService.runMRArchInvJob(EOMSTARTDT, EOMENDDT, RPTMNTH);
            batchRunJobService.runArchiveInvJob(EOMSTARTDT, EOMENDDT, RPTMNTH);
            batchRunJobService.runCasedapJob(EOMSTARTDT, EOMENDDT, RPTMNTH);
            break;
        case "NOSEG5":
            batchRunJobService.runNosegJob();
            batchRunJobService.runNosegOpenJob();
            break;
        default:
            throw new IllegalArgumentException("Unknown job code: " + jobCode);
    }
}
