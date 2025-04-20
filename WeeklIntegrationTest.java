// App.java
package gov.irs.sbse.os.ts.csp.alsentity.ale;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;

@SpringBootApplication
@EnableScheduling
public class App {
    
    // Default prior snapshot date if not provided via command line
    private static String priorSnapshotDate = null;
    
    public static void main(String[] args) {
        ConfigurableApplicationContext context = SpringApplication.run(App.class, args);
        
        // Process command line arguments
        ApplicationArguments appArgs = context.getBean(ApplicationArguments.class);
        if (appArgs.getOptionNames().contains("priorSnapshotDate")) {
            priorSnapshotDate = appArgs.getOptionValues("priorSnapshotDate").get(0);
            System.out.println("Using prior snapshot date: " + priorSnapshotDate);
        } else {
            System.out.println("No prior snapshot date provided. Using defaults from test classes.");
        }
    }
    
    @Bean
    public String priorSnapshotDate() {
        return priorSnapshotDate;
    }
}

// Daily Integration test
// In DailyIntegrationTest.java
@Autowired(required = false)
private String injectedPriorSnapshotDate;

private static final String DEFAULT_PRIOR_SNAPSHOT_DATE = "04052025"; // Default value

// Method to get the appropriate prior snapshot date
private String getPriorSnapshotDate() {
    return (injectedPriorSnapshotDate != null) ? injectedPriorSnapshotDate : DEFAULT_PRIOR_SNAPSHOT_DATE;
}

// Then replace all occurrences of priorSnapshotDate with getPriorSnapshotDate()
// For example, in your test methods:
// .withPriorSnapshotDate(getPriorSnapshotDate())

// Weekly Integration Test
// In WeeklyIntegrationTest.java
@Autowired(required = false)
private String injectedPriorSnapshotDate;

private static final String DEFAULT_PRIOR_SNAPSHOT_DATE = "03302025"; // Default value

// Method to get the appropriate prior snapshot date
private String getPriorSnapshotDate() {
    return (injectedPriorSnapshotDate != null) ? injectedPriorSnapshotDate : DEFAULT_PRIOR_SNAPSHOT_DATE;
}

// Then replace all occurrences of priorSnapshotDate with getPriorSnapshotDate()
// For example, in your test methods:
// .withPriorSnapshotDate(getPriorSnapshotDate())

// pom.xml

<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <configuration>
        <mainClass>gov.irs.sbse.os.ts.csp.alsentity.ale.App</mainClass>
        <layout>JAR</layout>
    </configuration>
    <executions>
        <execution>
            <goals>
                <goal>repackage</goal>
            </goals>
        </execution>
    </executions>
</plugin>


// App.java again

@Bean
public CommandLineRunner commandLineRunner(
        DailyIntegrationTest dailyIntegrationTest,
        WeeklyIntegrationTest weeklyIntegrationTest,
        ApplicationArguments args) {
    
    return runner -> {
        if (args.getOptionNames().contains("runMode")) {
            String runMode = args.getOptionValues("runMode").get(0);
            
            switch (runMode.toLowerCase()) {
                case "daily":
                    System.out.println("Running daily integration jobs...");
                    dailyIntegrationTest.testRestoreAndLaunchAllDailyJobs();
                    break;
                case "weekly":
                    System.out.println("Running weekly integration jobs...");
                    weeklyIntegrationTest.testRestoreAndLaunchAllWeeklyJobs();
                    break;
                case "e5":
                    System.out.println("Running E5 job only...");
                    dailyIntegrationTest.testRestoreAndLaunchE5Job();
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

// MVN Clean

Build and run instructions

Build your application with Maven:

mvn clean package

Run your application with command-line arguments:

java -jar target/entity-service-1.0.jar --runMode=daily --priorSnapshotDate=04052025
Or for weekly jobs:
java -jar target/entity-service-1.0.jar --runMode=weekly --priorSnapshotDate=03302025
Or for a specific job (E5 for example):
java -jar target/entity-service-1.0.jar --runMode=e5 --priorSnapshotDate=04052025
