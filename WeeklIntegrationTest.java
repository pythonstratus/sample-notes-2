@Test
// @Disabled
public void testRestoreAndLaunchAllWeeklyJobsSequentially() {
    List<String> jobCodes = new ArrayList<>(Constants.WEEKLY_JOB_CODES);
    
    // Create individual CompletableFutures for each job
    CompletableFuture<Void> previousJob = CompletableFuture.completedFuture(null);
    
    for (String jobCode : jobCodes) {
        // Create a CompletableFuture for each job
        CompletableFuture<Void> currentJob = previousJob.thenRunAsync(() -> {
            List<String> tables = Constants.WEEKLY_JOB_TABLES.get(jobCode);
            
            try {
                // Set up and execute the job
                IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                    .forJob(jobCode)
                    .forTables(tables)
                    .forPrefix(Constants.WEEKLY)
                    .withPriorSnapshotDate(priorSnapshotDate)
                    .execute();
                
                runJobByCode(jobCode);
            } catch (Exception e) {
                throw new CompletionException("Job launch for job code " + jobCode + " failed", e);
            }
        });
        
        // Update previous job for next iteration
        previousJob = currentJob;
    }
    
    // Wait for the last job to complete
    try {
        previousJob.join();
    } catch (CompletionException e) {
        fail("Job execution failed: " + e.getMessage());
    }
}

// Helper method to run the job based on job code
private void runJobByCode(String jobCode) {
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
