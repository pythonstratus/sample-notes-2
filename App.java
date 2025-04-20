@Bean
public CommandLineRunner commandLineRunner(
        DailyRunner dailyRunner,
        WeeklyRunner weeklyRunner,
        ApplicationArguments args) {
    
    return runner -> {
        if (args.getOptionNames().contains("runMode")) {
            String runMode = args.getOptionValues("runMode").get(0);
            
            switch (runMode.toLowerCase()) {
                case "daily":
                    System.out.println("Running daily integration jobs...");
                    dailyRunner.runAllDailyJobs();
                    break;
                case "weekly":
                    System.out.println("Running weekly integration jobs...");
                    weeklyRunner.runAllWeeklyJobs();
                    break;
                case "e5":
                    System.out.println("Running E5 job only...");
                    dailyRunner.runE5Job();
                    break;
                // Add more specific job cases as needed
                default:
                    System.out.println("Unknown run mode: " + runMode);
                    System.out.println("Available modes: daily, weekly, e5");
            }
        } else {
            System.out.println("No run mode specified. Please use --runMode=daily or --runMode=weekly");
        }
    };
}
