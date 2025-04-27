spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,springfox.documentation.swagger2.configuration.Swagger2DocumentationConfiguration

@Bean
public CommandLineRunner commandLineRunner(
        DailyRunner dailyRunner,
        WeeklyRunner weeklyRunner,
        ApplicationArguments args) {
    
    return runner -> {
        // Store the date from command line, if present
        String dateParam = null;
        if (args.getOptionNames().contains("priorSnapshotDate")) {
            List<String> values = args.getOptionValues("priorSnapshotDate");
            if (values != null && !values.isEmpty()) {
                dateParam = values.get(0);
                log.warn("Using prior snapshot date from command line: " + dateParam);
            }
        }
        
        if (args.getOptionNames().contains("runMode")) {
            String runMode = args.getOptionValues("runMode").get(0);
            
            // Pass the date directly to the methods
            switch (runMode.toLowerCase()) {
                case "daily":
                    log.warn("Running daily integration jobs...");
                    dailyRunner.runAllDailyJobs(dateParam);  // Pass date directly
                    break;
                case "weekly":
                    log.warn("Running weekly integration jobs...");
                    weeklyRunner.runAllWeeklyJobs(dateParam);  // Pass date directly
                    break;
                case "e5":
                    log.warn("Running E5 job only...");
                    dailyRunner.runE5Job(dateParam);  // Pass date directly
                    break;
                default:
                    log.warn("Unknown run mode: " + runMode);
                    log.warn("Available modes: daily, weekly, e5");
            }
        } else {
            log.warn("No run mode specified. Please use --runMode=daily or --runMode=weekly");
        }
    };
}
