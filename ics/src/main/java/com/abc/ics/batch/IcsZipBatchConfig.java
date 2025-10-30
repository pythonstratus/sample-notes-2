package com.abc.ics.batch;

import com.abc.ics.batch.tasklet.*;
import com.abc.ics.config.IcsZipConfigProperties;
import com.abc.ics.service.DatabaseService;
import com.abc.ics.service.EmailService;
import com.abc.ics.service.FileService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * Spring Batch configuration for ICS Zip Processing Job
 * 
 * This configuration defines the batch job structure that replicates
 * the shell script workflow:
 * 1. File Validation
 * 2. Area Processing (for each of 8 areas)
 * 3. Execute crzips procedure
 * 4. Send notifications
 */
@Configuration
@Slf4j
@RequiredArgsConstructor
public class IcsZipBatchConfig {

    private final JobRepository jobRepository;
    private final PlatformTransactionManager transactionManager;
    private final FileService fileService;
    private final DatabaseService databaseService;
    private final EmailService emailService;
    private final IcsZipConfigProperties config;

    /**
     * Main ICS Zip Processing Job
     * Equivalent to the entire ent_zip.csh script
     */
    @Bean
    public Job icsZipProcessingJob() {
        return new JobBuilder("icsZipProcessingJob", jobRepository)
                .incrementer(new RunIdIncrementer())
                .start(fileValidationStep())
                .next(areaProcessingStep())
                .next(executeCrzipsStep())
                .next(notificationStep())
                .build();
    }

    /**
     * Step 1: File Validation
     * - Check for input file
     * - Validate exactly one file exists
     * - Copy to working directory
     */
    @Bean
    public Step fileValidationStep() {
        return new StepBuilder("fileValidationStep", jobRepository)
                .tasklet(fileValidationTasklet(), transactionManager)
                .build();
    }

    @Bean
    public FileValidationTasklet fileValidationTasklet() {
        return new FileValidationTasklet(fileService, emailService, config);
    }

    /**
     * Step 2: Area Processing
     * - Process each of the 8 geographic areas
     * - Delete old data from oldzips
     * - Load new data via batch insert
     */
    @Bean
    public Step areaProcessingStep() {
        return new StepBuilder("areaProcessingStep", jobRepository)
                .tasklet(areaProcessingTasklet(), transactionManager)
                .build();
    }

    @Bean
    public AreaProcessingTasklet areaProcessingTasklet() {
        return new AreaProcessingTasklet(fileService, databaseService, config);
    }

    /**
     * Step 3: Execute crzips SQL Script
     * - Run the crzips.sql procedure
     * - Transform data from oldzips to icszips
     */
    @Bean
    public Step executeCrzipsStep() {
        return new StepBuilder("executeCrzipsStep", jobRepository)
                .tasklet(executeCrzipsTasklet(), transactionManager)
                .build();
    }

    @Bean
    public ExecuteCrzipsTasklet executeCrzipsTasklet() {
        return new ExecuteCrzipsTasklet(databaseService);
    }

    /**
     * Step 4: Send Notifications
     * - Check for errors
     * - Send email notifications based on results
     */
    @Bean
    public Step notificationStep() {
        return new StepBuilder("notificationStep", jobRepository)
                .tasklet(notificationTasklet(), transactionManager)
                .build();
    }

    @Bean
    public NotificationTasklet notificationTasklet() {
        return new NotificationTasklet(emailService, fileService, config);
    }
}
