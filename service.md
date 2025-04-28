# ENTITY-SERVICE-REVAMPED

## Running Integration Tests

### Running Daily Integration Test

1. Open Visual Studio Code and navigate to the `test/java/gov/irs/sbse/os/ts/csp/alsentity/ale/util/DailyIntegrationTest.java` file in the Explorer
2. Within this file, locate the test method you want to run (e.g., `testRestoreAndLaunchE5Job()`)
3. Click to place your cursor on the test method name
4. Right-click and select "Run Test" or click the "Run Test" link that appears above the method
5. Alternatively, you can click the "Run" icon that appears in the gutter (left margin) next to the test method
6. Monitor the Debug Console at the bottom of VS Code to see the progress and logged information

### Running Weekly Integration Test

1. Open Visual Studio Code and navigate to the `test/java/gov/irs/sbse/os/ts/csp/alsentity/ale/util/WeeklyIntegrationTest.java` file in the Explorer
2. Within this file, locate the test method you want to run
3. Click to place your cursor on the test method name
4. Right-click and select "Run Test" or click the "Run Test" link that appears above the method
5. Alternatively, you can click the "Run" icon that appears in the gutter (left margin) next to the test method
6. Monitor the Debug Console at the bottom of VS Code to see the progress and logged information

### Tips for Integration Test Runs

- The integration tests may take several minutes to complete depending on the size of the data being processed
- You can view detailed logs in the Debug Console to track progress
- If you see any errors during test execution, check the logs for specific error messages
- The tests are designed to set up necessary test data, run the integration process, and then verify results

## Project Overview
This Java-based application - entity service for the IRS (Internal Revenue Service) that handles various data processing tasks, including daily and weekly file processing, data loading, and integration services.

## Project Structure

```
ENTITY-SERVICE/
├── src/
│   └── main/
│       └── java/
│           └── gov/irs/sbse/os/ts/csp/alsentity/ale/
│               ├── app/
│               │   └── App.java
│               ├── batch/
│               │   ├── archiveinv/
│               │   │   ├── CreateEomactsTasklet.java
│               │   │   ├── CreateEomtrailTasklet.java
│               │   │   └── PopulateEommodsTableTasklet.java
│               │   └── casedsp/
│               │       ├── ArchiveAreaDatFileTasklet.java
│               │       ├── GenerateAreaDatFileTasklet.java
│               │       ├── GenerateCasedspDatFileTasklet.java
│               │       ├── InitialEntactEomTableTasklet.java
│               │       ├── InitialEntmodEomTableTasklet.java
│               │       ├── InitialTrantrailEomTableTasklet.java
│               │       ├── RemoveOldDatAndBadFileTasklet.java
│               │       └── UpdateArchiveInvAndArchivecasedspTableTasklet.java
│               ├── commontasklet/
│               │   ├── CreateLogLoadRecordTasklet.java
│               │   ├── MkArchInvCommonTasklet.java
│               │   ├── SqlRunnerTasklet.java
│               │   └── ValidationTasklet.java
│               ├── component/
│               │   ├── AsyncTableMigrator.java
│               │   ├── ProgressBar.java
│               │   └── TableMetricsComponent.java
│               ├── config/
│               │   ├── AdditionalportConfig.java
│               │   ├── ArchiveInvProcessorConfig.java
│               │   ├── CasedspLoadConfiguration.java
│               │   ├── CasedspProcessorConfig.java
│               │   ├── CheckCountNosegProcessorConfig.java
│               │   ├── DataSourceConfig.java
│               │   ├── E1LoadConfiguration.java
│               │   ├── E1ProcessorConfig.java
│               │   ├── E2LoadConfiguration.java
│               │   └── ...more configuration files
│               ├── controller/
│               │   ├── DailyWeeklyIntegrationController.java
│               │   ├── LogLoadController.java
│               │   ├── SnapshotController.java
│               │   └── StatusController.java
│               ├── data/
│               │   ├── CasedspRecord.java
│               │   ├── E1Record.java
│               │   ├── E2Record.java
│               │   └── ...more record files
│               ├── e1/
│               │   ├── E1TabFixTasklet.java
│               │   ├── BasicDatParser.java
│               │   ├── DailyLoadCheck.java
│               │   └── WeeklyLoadCheck.java
│               ├── entityprocess/
│               │   ├── E1RecordProcessor.java
│               │   ├── E2RecordProcessor.java
│               │   └── E5RecordProcessor.java
│               ├── exception/
│               │   ├── EntityException.java
│               │   ├── EntityGlobalExceptionHandler.java
│               │   ├── PermanentException.java
│               │   └── TransientException.java
│               ├── listener/
│               │   └── JobCompletionNotificationListener.java
│               ├── mapper/
│               │   ├── E1RecordFieldSetMapper.java
│               │   ├── E2RecordFieldSetMapper.java
│               │   └── ...more field set mappers
│               ├── model/
│               │   ├── ColumnInfo.java
│               │   ├── E3Tmp.java
│               │   ├── E5Tmp.java
│               │   ├── EntJava
│               │   ├── EntTmp.java
│               │   ├── EntTmp2.java
│               │   ├── GenericRow.java
│               │   ├── JobStatus.java
│               │   ├── LogLoad.java
│               │   ├── TableInfo.java
│               │   └── TableValidationResult.java
│               ├── repository/
│               │   ├── implementation/
│               │   │   ├── AbstractEntityRepository.java
│               │   │   ├── AlsEntityRepositoryImpl.java
│               │   │   └── EntityRepositoryImpl.java
│               │   ├── EntityRepository.java
│               │   ├── EntMonthRepository.java
│               │   ├── EntRepository.java
│               │   ├── JobStatusRepository.java
│               │   └── LogLoadRepository.java
│               ├── routes/
│               │   ├── DailyFileProcessor.java
│               │   ├── DailyFileWatcher.java
│               │   ├── FileExceptionProcessor.java
│               │   ├── WeeklyFileProcessor.java
│               │   └── WeeklyFileWatcher.java
│               ├── scheduler/
│               │   └── LoadScheduler.java
│               ├── security/
│               │   ├── AlsUserDto.java
│               │   └── AuthenticationFilter.java
│               ├── service/
│               │   ├── BatchRunJobService.java
│               │   ├── DailyIntegrationService.java
│               │   ├── DatabaseSnapshotService.java
│               │   ├── EmailService.java
│               │   ├── EntMonthService.java
│               │   ├── EntTmpService.java
│               │   ├── JobContext.java
│               │   ├── LogLoadService.java
│               │   ├── MaterializedViewService.java
│               │   └── WeeklyIntegrationService.java
│               └── util/
│                   ├── CIIUtil.java
│                   ├── DailyRunner.java
│                   ├── DateUtil.java
│                   ├── DBUtil.java
│                   ├── FieldMappingUtil.java
│                   ├── FileContentProcess.java
│                   ├── FileProcess.java
│                   ├── FileUtil.java
│                   ├── IntegrationTestUtil.java
│                   ├── JobUtil.java
│                   ├── LoggingUtil.java
│                   ├── SqlExecutionUtil.java
│                   ├── SQLUtil.java
│                   ├── StringUtil.java
│                   ├── TimeUtil.java
│                   ├── WeeklyRunner.java
│                   ├── App.java
│                   └── Constants.java
├── resources/
│   ├── application-aqt.properties
│   ├── application-dev.properties
│   ├── application-embedded.properties
│   ├── application-local.properties
│   ├── logback-spring.xml
│   └── tableData.json
├── test/
│   └── java/
│       └── gov/irs/sbse/os/ts/csp/alsentity/ale/
│           ├── component/
│           │   └── TableStatisticsTest.java
│           ├── config/
│           │   ├── SqlFunctions.java
│           │   ├── TestE1Steps.java
│           │   ├── TestE2Steps.java
│           │   └── ...more test configurations
│           ├── repository/
│           │   ├── EntityRepositoryIntegrationTest.java
│           │   └── JobStatusRepositoryIntegrationTest.java
│           ├── service/
│           │   ├── DatabaseSnapshotServiceTest.java
│           │   ├── EmailServiceTest.java
│           │   └── MaterializedViewServiceIntegrationTest.java
│           └── util/
│               ├── FileUtilTests.java
│               ├── SQLUtilTests.java
│               ├── StringUtilTests.java
│               ├── DailyIntegrationTest.java
│               ├── EdIntegrationTest.java
│               ├── IntegrationTestUtil.java
│               └── WeeklyIntegrationTest.java
└── resources/
    └── db/
        ├── schema-h2.sql
        ├── application-test.properties
        ├── application-test-local.properties
        ├── logback-spring.xml
        ├── dependencies.txt
        ├── entity-service-batch.jar
        ├── entity-service-revamped.zip
        ├── pom.xml
        ├── README.JOE.MD
        └── README.MD
```

## Key Components

### Batch Processing
The application implements the Spring Batch framework for handling data processing tasks:
- `batch/archiveinv`: Handles end-of-month (EOM) transaction processing
- `batch/casedsp`: Processes case disposition files and data

### Data Models
- `E1Record`, `E2Record`, etc.: Different entity record types for various IRS systems
- `CasedspRecord`: Case disposition records
- Various mapper classes that transform data between different formats

### File Processing
- `DailyFileProcessor` and `WeeklyFileProcessor`: Handle scheduled file processing jobs
- `DailyFileWatcher` and `WeeklyFileWatcher`: Monitor for new files to process

### Services
- `DailyIntegrationService` and `WeeklyIntegrationService`: Orchestrate daily and weekly data integration
- `DatabaseSnapshotService`: Creates database snapshots
- `LogLoadService`: Manages load logging
- `EmailService`: Handles notifications

### Controllers
- `DailyWeeklyIntegrationController`: API endpoints for integration processes
- `LogLoadController`: Endpoints for log management
- `SnapshotController`: Endpoints for database snapshot operations
- `StatusController`: Status monitoring endpoints

### Configuration
Numerous configuration classes for different components and processes:
- Data source configurations
- Processor configurations for different entity types (E1, E2, etc.)
- Load configurations

### Repository Layer
- Repository interfaces and implementations that abstract database operations
- Support for entity storage and retrieval

### Security
- `AuthenticationFilter`: Handles authentication
- `AlsUserDto`: User data transfer object

## Technical Overview

This application appears to be a Spring Boot-based service that:

1. Processes data files from various IRS systems
2. Loads and transforms data into structured formats
3. Handles both daily and weekly processing jobs
4. Provides REST APIs for monitoring and controlling the processes
5. Implements batch processing for efficient handling of large datasets
6. Includes comprehensive test coverage for components

The application follows a modular architecture with clear separation of concerns through controllers, services, repositories, and utility classes.

## Troubleshooting Integration Tests

### Common Issues

1. **Database Connection Errors**
   - Verify that the database settings in `application-test.properties` or `application-test-local.properties` are correct
   - Ensure the database server is running and accessible from your development environment

2. **File Path Issues**
   - Check that any file paths referenced in the tests exist in your local environment
   - Some tests may expect specific files to be present in certain directories

3. **Permission Problems**
   - Ensure your user account has proper permissions to read/write to the required directories
   - Database user permissions should allow for creating/dropping tables and executing stored procedures

4. **Test Data Issues**
   - Verify that test data exists and is properly formatted
   - Some tests may rely on `tableData.json` to be properly configured

### Getting Help

If you encounter issues running the integration tests:

1. Check the Debug Console for detailed error messages
2. Look at the test class implementation to understand what data and environment it expects
3. Contact the development team via the support channel if issues persist
