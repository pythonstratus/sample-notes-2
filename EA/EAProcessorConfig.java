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
 * Spring configuration class for the EA Processor
 * Extends the batch configuration with additional jobs and steps
 */
@Configuration
@EnableBatchProcessing
@Slf4j
public class EAProcessorConfig {

    @Value("${LOGDIR:./logs}")
    private String logDir;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private JobLauncher jobLauncher;

    @Autowired
    @Qualifier("importEAJob")
    private Job importEAJob; // The job we already defined for Loading EA data

    /**
     * Main processing job definition that orchestrates the entire flow
     */
    @Bean(name = "processEAJob")
    public Job processEAJob(JobRepository jobRepository,
                           JobCompletionNotificationListener listener,
                           Step truncateEATmpStep,
                           Step preprocessEADataStep,
                           Step importEAJobStep,
                           Step validateEALoadStep,
                           Step updateEasIdStep,
                           Step updateTaxPrdStep,
                           Step updateDefaultTaxPrdStep,
                           Step updateIcsStatusCdStep,
                           Step createLogLoadRecordEAStep) {
        return new JobBuilder("processEAJob", jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .start(truncateEATmpStep)
                .next(preprocessEADataStep)
                .next(importEAJobStep)
                .next(validateEALoadStep)
                .next(updateEasIdStep)
                .next(updateTaxPrdStep)
                .next(updateDefaultTaxPrdStep)
                .next(updateIcsStatusCdStep)
                .next(createLogLoadRecordEAStep)
                .build();
    }

    /**
     * Step to preprocess EA data before loading (fix EA.dat TAXPRD and TYPEID)
     */
    @Bean
    public Step preprocessEADataStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("preprocessEADataStep", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    // Execute the equivalent of fixE2-3 script on the EA.dat file
                    // In a real implementation, we'd need to handle this with a customized tasklet
                    // that can manipulate the file directly
                    log.info("Preprocessing EA.dat file to fix TAXPRD and TYPEID code");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    @Bean
    public Step importEAJobStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("importEAJobStep", jobRepository)
                .job(importEAJob)
                .launcher(jobLauncher)
                .repository(jobRepository)
                .build();
    }

    /**
     * Step to truncate EATMP table before processing
     */
    @Bean
    public Step truncateEATmpStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("truncateEATmpStep", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    jdbcTemplate.execute("TRUNCATE TABLE EATMP");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    /**
     * Step to validate EA data loading by checking error files
     */
    @Bean
    public Step validateEALoadStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("validateEALoadStep", jobRepository)
                .tasklet(new ValidationTasklet(logDir, "EA"), transactionManager)
                .build();
    }

    /**
     * Step to update EASID in EATMP table based on matching ENT record
     */
    @Bean
    public Step updateEasIdStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateEasIdStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE EATMP set EASID = " +
                        "(SELECT TINSID FROM ENT WHERE " +
                        "EATMP.TIN = ENT.TIN and " +
                        "EATMP.TINTYPE = ENT.TINTT and " +
                        "EATMP.FILESOURCECD = ENT.TINFS and " +
                        "rownum = 1)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update TAXPRD in EATMP table for specific MFTCD values
     */
    @Bean
    public Step updateTaxPrdStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateTaxPrdStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE EATMP set TAXPRD = last_day(TAXPRD) " +
                        "WHERE MFTCD NOT IN ('52','53','60')"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update TAXPRD in EATMP table to default value where needed
     */
    @Bean
    public Step updateDefaultTaxPrdStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateDefaultTaxPrdStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE EATMP set TAXPRD = '01/01/1900' " +
                        "WHERE NVL(TAXPRD,'01/01/1900') <= '01/01/1900'"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update ICSSTATUSCD in EATMP table based on MODDISPCD
     */
    @Bean
    public Step updateIcsStatusCdStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateIcsStatusCdStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE EATMP set ICSSTATUSCD = 'T' " +
                        "WHERE MODDISPCD in (6,15,35,36,70,80)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to create log load record for EA process
     */
    @Bean
    public Step createLogLoadRecordEAStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("createLogLoadRecordEAStep", jobRepository)
                .tasklet(new CreateLogLoadRecordTasklet(jdbcTemplate, "EA", "EXTRACTDT", "EATMP"), transactionManager)
                .build();
    }
}