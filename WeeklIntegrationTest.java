@Test
// @Disabled
public void testRestoreAndLaunchAllWeeklyJobsSequentially() {
    // Start with an empty completable future as our starting point
    CompletableFuture<Void> previous = CompletableFuture.completedFuture(null);
    
    for (String jobCode : Constants.WEEKLY_JOB_CODES) {
        List<String> tables = Constants.WEEKLY_JOB_TABLES.get(jobCode);
        final String currentJobCode = jobCode;
        
        // Chain each job to the previous one to ensure sequential execution
        previous = previous.thenCompose(ignored -> {
            return CompletableFuture.runAsync(() -> {
                try {
                    IntegrationTestUtil.builder(entityRepos, dbSnapshotService, materializedViewService)
                        .forJob(currentJobCode)
                        .forTables(tables)
                        .forPrefix(Constants.WEEKLY)
                        .withPriorSnapshotDate(priorSnapshotDate)
                        .execute();
                    
                    switch (currentJobCode) {
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
                            // No return null here since this is a CompletableFuture
                            break;
                        case "NOSEG5":
                            batchRunJobService.runNosegJob();
                            batchRunJobService.runNosegOpenJob();
                            break;
                        default:
                            throw new IllegalArgumentException("Unknown job code: " + currentJobCode);
                    }
                } catch (Exception e) {
                    throw new CompletionException("Job launch for job code " + currentJobCode + 
                                                " failed: " + e.getMessage(), e);
                }
            });
        });
    }
    
    // Wait for all jobs to complete and handle any exceptions
    try {
        previous.join();
    } catch (CompletionException e) {
        fail("Job execution failed: " + e.getCause().getMessage());
    }
}
