entity-service-recent/
├── .vscode/
├── src/
│   ├── main/
│   │   └── java/gov/irs/sbse/os/ts/csp/alsentity/ale/
│   │       ├── batch/
│   │       │   └── listeners/
│   │       │       ├── BaseListener.java
│   │       │       ├── BatchChunkListener.java
│   │       │       ├── BatchRetryListener.java
│   │       │       ├── BatchStopListener.java
│   │       │       ├── BatchStepListener.java
│   │       │       ├── JobLevelExecutionListener.java
│   │       │       ├── ProcessListener.java
│   │       │       ├── ReadListener.java
│   │       │       └── WriteListener.java
│   │       │   ├── BatchConfig.java
│   │       │   ├── BatchRetryPolicy.java
│   │       │   ├── ChunkedBufferedReader.java
│   │       │   ├── LineContainer.java
│   │       │   ├── ManualJDBCBatchItemWriter.java
│   │       │   ├── MetaDataUtilizingProcessor.java
│   │       │   └── RecordPreparedStatementSetter.java
│   │       ├── component/
│   │       │   ├── AsyncTableMigrator.java
│   │       │   └── ProgressBar.java
│   │       ├── config/
│   │       │   ├── AdditionalportConfig.java
│   │       │   ├── DataSourceConfig.java
│   │       │   ├── MailSenderConfig.java
│   │       │   ├── ReadOnlyDataSource.java
│   │       │   ├── ReadOnlyJdbcTemplate.java
│   │       │   └── WebConfig.java
│   │       ├── control/
│   │       │   ├── FieldMetaDataExtractor.java
│   │       │   ├── Replacement.java
│   │       │   └── ReplacementExtractor.java
│   │       ├── controller/
│   │       │   ├── LogLoadController.java
│   │       │   ├── SnapshotController.java
│   │       │   └── StatusController.java
│   │       ├── dom/
│   │       │   ├── EntityRecord.java
│   │       │   └── FieldData.java
│   │       ├── exception/
│   │       │   ├── EntityException.java
│   │       │   ├── EntityGlobalExceptionHandler.java
│   │       │   ├── PermanentException.java
│   │       │   └── TransientException.java
│   │       ├── model/
│   │       │   ├── ColumnInfo.java
│   │       │   ├── E1Tmp.java
│   │       │   ├── E3Tmp.java
│   │       │   ├── E5Tmp.java
│   │       │   ├── Ent.java
│   │       │   ├── EnTmp.java
│   │       │   ├── EnTmp2.java
│   │       │   ├── GenericRow.java
│   │       │   ├── JobStatus.java
│   │       │   ├── JustinsSuperObject.java
│   │       │   ├── LogLoad.java
│   │       │   ├── TableInfo.java
│   │       │   └── TableValidationResult.java
│   │       ├── populate/
│   │       │   ├── FieldDataExtractor.java
│   │       │   ├── FieldValue.java
│   │       │   ├── RecordSkipper.java
│   │       │   ├── SkipData.java
│   │       │   └── SkipInformation.java
│   │       ├── repository/
│   │       │   ├── implementation/
│   │       │   │   ├── AbstractEntityRepository.java
│   │       │   │   ├── AbsEntityRepositoryImpl.java
│   │       │   │   └── EntityRepositoryImpl.java
│   │       │   ├── EntityRepository.java
│   │       │   ├── EntRepository.java
│   │       │   ├── JobStatusRepository.java
│   │       │   └── LogLoadRepository.java
│   │       ├── routes/
│   │       │   ├── DailyFileProcessor.java
│   │       │   ├── DailyFileWatcher.java
│   │       │   ├── FileExceptionProcessor.java
│   │       │   ├── MonthlyFileProcessor.java
│   │       │   ├── MonthlyFileWatcher.java
│   │       │   ├── WeeklyFileProcessor.java
│   │       │   └── WeeklyFileWatcher.java
│   │       ├── security/
│   │       │   ├── AIsUserDto.java
│   │       │   └── AuthenticationFilter.java
│   │       ├── service/
│   │       │   ├── BatchJobService.java
│   │       │   ├── DatabaseSnapshotService.java
│   │       │   ├── EmailService.java
│   │       │   ├── EnTmpService.java
│   │       │   └── MaterializedViewService.java
│   │       ├── sql/
│   │       │   ├── SQLExecutor.java
│   │       │   ├── SQLExtractor.java
│   │       │   └── SQLQueryExtractor.java
│   │       └── util/
│   │           ├── CtlUtils.java
│   │           ├── DateUtil.java
│   │           ├── DBUtil.java
│   │           ├── FileUtil.java
│   │           ├── LoggingUtil.java
│   │           ├── SQLUtil.java
│   │           ├── StringUtil.java
│   │           ├── TimeUtil.java
│   │           ├── App.java
│   │           └── Constants.java
│   ├── resources/
│   │   ├── application-aqt.properties
│   │   ├── application-dev.properties
│   │   ├── application-embedded.properties
│   │   ├── application-local.properties
│   │   ├── c.proc[1-9EABC]
│   │   ├── E6.dat
│   │   ├── init.sql
│   │   ├── load[1-9EABS].ctl
│   │   ├── logback.xml
│   │   ├── logging.properties
│   │   ├── proc[1-9EABS].sql
│   │   ├── schema-all.sql.bak
│   │   ├── schema-all.sql.hsqldb
│   │   └── tableData.json
│   └── test/
│       └── java/gov/irs/sbse/os/ts/csp/alsentity/ale/
│           ├── control/
│           │   └── FieldMetaDataExtractorTests.java
│           ├── populate/
│           │   └── FieldDataExtractorTests.java
│           ├── repository/
│           │   ├── EntityRepositoryIntegrationTest.java
│           │   └── TableStatisticsTest.java
│           ├── service/
│           │   ├── DatabaseSnapshotServiceTest.java
│           │   ├── EmailServiceTest.java
│           │   └── MaterializedViewServiceIntegrationTest.java
│           ├── sql/
│           │   ├── SQLExtractorTests.java
│           │   └── SQLQueryExtractorTests.java
│           └── util/
│               ├── DateUtilTests.java
│               ├── FileUtilTests.java
│               ├── SQLUtilTests.java
│               ├── StringUtilTests.java
│               ├── DailyIntegrationTest.java
│               ├── JobExecutionIntegrationTest.java
│               ├── MonthlyIntegrationTest.java
│               ├── SchemaLogger.java
│               ├── ShowImpactedTablesTest.java
│               └── WeeklyIntegrationTest.java
├── .gitignore
├── dependencies.txt
├── pom.xml
├── README.JOE.MD
└── README.MD
