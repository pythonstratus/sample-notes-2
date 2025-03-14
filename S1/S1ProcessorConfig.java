package com.abc.sbse.os.ts.csp.alsentity.ale.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;

import com.abc.sbse.os.ts.csp.alsentity.ale.batch.commontasklet.CreateLogLoadRecordTasklet;
import com.abc.sbse.os.ts.csp.alsentity.ale.batch.commontasklet.SqlRunnerTasklet;
import com.abc.sbse.os.ts.csp.alsentity.ale.batch.commontasklet.ValidationTasklet;
import com.abc.sbse.os.ts.csp.alsentity.ale.listener.JobCompletionNotificationListener;

import lombok.extern.slf4j.Slf4j;

/**
 * Spring configuration class for the S1 Processor
 * Extends the batch configuration with additional jobs and steps
 */
@Configuration
@EnableBatchProcessing
@Slf4j
public class S1ProcessorConfig {

    @Value("${LOGDIR:./logs}")
    private String logDir;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private JobLauncher jobLauncher;

    @Autowired
    @Qualifier("importS1Job")
    private Job importS1Job; // The job we already defined for Loading S1 data

    /**
     * Main processing job definition that orchestrates the entire flow
     */
    @Bean(name = "processS1Job")
    public Job processS1Job(JobRepository jobRepository,
                           JobCompletionNotificationListener listener,
                           Step truncateS1TmpStep,
                           Step importS1JobStep,
                           Step validateS1LoadStep,
                           Step deleteFromEntcodeStep,
                           Step updateTimeDefStep,
                           Step updateDefaultTimeDefStep,
                           Step updateCtrsDefStep,
                           Step updateDefaultCtrsDefStep,
                           Step mergeIntoEntcodeStep,
                           Step createLogLoadRecordS1Step) {
        return new JobBuilder("processS1Job", jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .start(truncateS1TmpStep)
                .next(importS1JobStep)
                .next(validateS1LoadStep)
                .next(deleteFromEntcodeStep)
                .next(updateTimeDefStep)
                .next(updateDefaultTimeDefStep)
                .next(updateCtrsDefStep)
                .next(updateDefaultCtrsDefStep)
                .next(mergeIntoEntcodeStep)
                .next(createLogLoadRecordS1Step)
                .build();
    }

    @Bean
    public Step importS1JobStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("importS1JobStep", jobRepository)
                .job(importS1Job)
                .launcher(jobLauncher)
                .repository(jobRepository)
                .build();
    }

    /**
     * Step to truncate S1TMP table before processing
     */
    @Bean
    public Step truncateS1TmpStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("truncateS1TmpStep", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    jdbcTemplate.execute("TRUNCATE TABLE S1TMP");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    /**
     * Step to validate S1 data loading by checking error files
     */
    @Bean
    public Step validateS1LoadStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("validateS1LoadStep", jobRepository)
                .tasklet(new ValidationTasklet(logDir, "S1"), transactionManager)
                .build();
    }

    /**
     * Step to delete from ENTCODE table where AREA = '0001'
     */
    @Bean
    public Step deleteFromEntcodeStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("deleteFromEntcodeStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "DELETE FROM ENTCODE WHERE AREA = '0001'"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update TIMEDEF in S1TMP table for special code ranges
     */
    @Bean
    public Step updateTimeDefStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateTimeDefStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE S1TMP set TIMEDEF = 'D' WHERE TIMEDEF IS NULL " +
                        "and code between '301' and '308' and Type = 'S'"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update default TIMEDEF in S1TMP table
     */
    @Bean
    public Step updateDefaultTimeDefStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateDefaultTimeDefStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE S1TMP set TIMEDEF = 'T' WHERE TIMEDEF is null"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update CTRSDEF in S1TMP table for special code ranges
     */
    @Bean
    public Step updateCtrsDefStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateCtrsDefStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE S1TMP set CTRSDEF = 3 WHERE TIMEDEF IS NULL " +
                        "and code between '301' and '308' and Type = 'S'"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update default CTRSDEF in S1TMP table
     */
    @Bean
    public Step updateDefaultCtrsDefStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateDefaultCtrsDefStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE S1TMP set CTRSDEF = '1' WHERE CTRSDEF is null"
                ), transactionManager)
                .build();
    }

    /**
     * Step to merge S1TMP data into ENTCODE table
     */
    @Bean
    public Step mergeIntoEntcodeStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("mergeIntoEntcodeStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "MERGE INTO ENTCODE a " +
                        "USING (SELECT * FROM S1TMP) b " +
                        "ON (a.CODE = b.CODE and a.TYPE = b.TYPE and a.AREA = b.AREA) " +
                        "WHEN MATCHED THEN " +
                        "  UPDATE SET a.CDNAME=b.CDNAME, a.EXTRDT=b.EXTRDT " +
                        "WHEN NOT MATCHED THEN " +
                        "  INSERT (AREA, TYPE, CODE, CDNAME, EXTRDT, TIMEDEF, ACTIVE, MGR, " +
                        "         CLERK, PROF, PARA, DISP, CTRSDEF ) " +
                        "  VALUES ( b.AREA, b.TYPE, b.CODE, b.CDNAME, b.EXTRDT, b.TIMEDEF, " +
                        "          b.ACTIVE, b.MGR, b.CLERK, b.PROF, b.PARA, b.DISP, b.CTRSDEF)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to create log load record for S1 process
     */
    @Bean
    public Step createLogLoadRecordS1Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("createLogLoadRecordS1Step", jobRepository)
                .tasklet(new CreateLogLoadRecordTasklet(jdbcTemplate, "S1", "EXTRDT", "S1TMP"), transactionManager)
                .build();
    }
}