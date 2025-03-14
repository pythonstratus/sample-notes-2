package com.abc.sbse.os.ts.csp.alsentity.ale.config;

import org.slf4j.Logger;
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
import org.springframework.batch.core.step.job.DefaultJobParametersExtractor;
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
import com.abc.sbse.os.ts.csp.alsentity.ale.util.SqlExecutionUtil;

import lombok.extern.slf4j.Slf4j;

/**
 * Spring configuration class for the E9 Processor
 * Extends the batch configuration with additional jobs and steps
 */
@Configuration
@EnableBatchProcessing
@Slf4j
public class E9ProcessorConfig {

    @Value("${LOGDIR:./logs}")
    private String logDir;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private JobLauncher jobLauncher;

    @Autowired
    private SqlExecutionUtil sqlExecutionUtil;

    @Autowired
    @Qualifier("importE9Job")
    private Job importE9Job; // The job we already defined for Loading E9 data

    /**
     * Main processing job definition that orchestrates the entire flow
     */
    @Bean(name = "processE9Job")
    public Job processE9Job(JobRepository jobRepository,
                           JobCompletionNotificationListener listener,
                           Step truncateE9TmpStep,
                           Step importE9JobStep,
                           Step validateE9LoadStep,
                           Step updateCasesIdStep,
                           Step mergeIntoTranTrailStep,
                           Step mergeIntoEntStep,
                           Step updateHinfIndStep,
                           Step truncateCnte2Step,
                           Step insertIntoCnte2Step,
                           Step truncateCnte4Step,
                           Step insertIntoCnte4Step,
                           Step updateTranTrailCountsStep,
                           Step updateTranTrailSegindStep,
                           Step truncateSegmodsStep,
                           Step createLogLoadRecordE9Step) {
        return new JobBuilder("processE9Job", jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .start(truncateE9TmpStep)
                .next(importE9JobStep)
                .next(validateE9LoadStep)
                .next(updateCasesIdStep)
                .next(mergeIntoTranTrailStep) 
                .next(mergeIntoEntStep)
                .next(updateHinfIndStep)
                .next(truncateCnte2Step)
                .next(insertIntoCnte2Step)
                .next(truncateCnte4Step)
                .next(insertIntoCnte4Step)
                .next(updateTranTrailCountsStep)
                .next(updateTranTrailSegindStep)
                .next(truncateSegmodsStep)
                .next(createLogLoadRecordE9Step)
                .build();
    }

    @Bean
    public Step importE9JobStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("importE9JobStep", jobRepository)
                .job(importE9Job)
                .launcher(jobLauncher)
                .repository(jobRepository)
                .parametersExtractor(new DefaultJobParametersExtractor())
                .build();
    }

    /**
     * Step to truncate E9TMP table before processing
     */
    @Bean
    public Step truncateE9TmpStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("truncateE9TmpStep", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    jdbcTemplate.execute("TRUNCATE TABLE E9TMP");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    /**
     * Step to validate E9 data loading by checking error files
     */
    @Bean
    public Step validateE9LoadStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("validateE9LoadStep", jobRepository)
                .tasklet(new ValidationTasklet(logDir, "E9"), transactionManager)
                .build();
    }

    /**
     * Step to update CASESID in E9TMP table
     */
    @Bean
    public Step updateCasesIdStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateCasesIdStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE E9TMP set CASESID = " +
                        "(SELECT tinsid " +
                        "FROM ENT " +
                        "WHERE E9TMP.TIN = ENT.TIN and " +
                        "E9TMP.TINTYPE = ENT.TINTT and " +
                        "E9TMP.FILESOURCECD = ENT.TINFS and " +
                        "rownum = 1)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to merge data into TRANTRAIL table
     */
    @Bean
    public Step mergeIntoTranTrailStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("mergeIntoTranTrailStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "MERGE INTO TRANTRAIL " +
                        "USING (SELECT " +
                        "     CASESID, " +
                        "     ASGMNTNUM, " +
                        "     max(CYCTOUCHCNT) TOUCHCNT, " +
                        "     max(INPUTHRS) INPUTHRS, " +
                        "     ENTEXTRACTDT " +
                        "FROM E9TMP " +
                        "GROUP BY CASESID, ASGMNTNUM, ENTEXTRACTDT " +
                        ") " +
                        "on (TINSID = CASESID and " +
                        "    ROID = ASGMNTNUM and " +
                        "    TRANTRAIL.STATUS = 'O') " +
                        "WHEN MATCHED THEN " +
                        "UPDATE SET " +
                        "    EXTRDT = ENTEXTRACTDT, " +
                        "    TOUCH = TOUCHCNT, " +
                        "    HRS = INPUTHRS"
                ), transactionManager)
                .build();
    }

    /**
     * Step to merge data into ENT table
     */
    @Bean
    public Step mergeIntoEntStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("mergeIntoEntStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "MERGE INTO ENT " +
                        "using (SELECT " +
                        "    CASESID, " +
                        "    TIN TMPTIN, " +
                        "    FILESOURCECD, " +
                        "    TINTYPE, " +
                        "    ENTEXTRACTDT, " +
                        "    max(TOUCHCNT) TOUCHCNT, " +
                        "    max(TOTALCASEHRS) CASEHRS, " +
                        "    CASEIDCD, " +
                        "    ENTCASECD, " +
                        "    ENTSUBCASECD, " +
                        "    max(INVITENSTATECD) " +
                        "FROM E9TMP " +
                        "GROUP BY " +
                        "    CASESID, " +
                        "    TIN, " +
                        "    FILESOURCECD, " +
                        "    TINTYPE, " +
                        "    ENTEXTRACTDT, " +
                        "    CASEIDCD, " +
                        "    ENTCASECD, " +
                        "    ENTSUBCASECD " +
                        ") " +
                        "on (ENT.TIN = TMPTIN and " +
                        "    TINFS = FILESOURCECD and " +
                        "    TINTT = TINTYPE) " +
                        "WHEN MATCHED THEN " +
                        "UPDATE SET " +
                        "    EXTRDT = ENTEXTRACTDT, " +
                        "    TOTTOUCH = TOUCHCNT, " +
                        "    TOTHRS = CASEHRS, " +
                        "    CASEIID = CASEIDCD, " +
                        "    CASECODE = ENTCASECD, " +
                        "    SUBCODE = ENTSUBCASECD"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update HINFIND in the ENT table
     */
    @Bean
    public Step updateHinfIndStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateHinfIndStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "update als.ENT set HINFIND = 0; " +
                        "update als.ENT set HINFIND = 1 " +
                        "where exists(select 1 from trantrail where " +
                        "    ent.tinsid = trantrail.tinsid " +
                        "    and segind in ('C','I') " +
                        "    and org = 'CF' and status = 'O') " +
                        "and tinfs = 1 " +
                        "and risk between 99 and 100 " +
                        "and exists (select 1 from entmod " +
                        "    where tinsid = emodsid " +
                        "    and status = 'O' " +
                        "    and type in ('F','G','T') " +
                        "    and selcode between 30 and 39)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to truncate CNTE2 table
     */
    @Bean
    public Step truncateCnte2Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("truncateCnte2Step", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate, "TRUNCATE table CNTE2"), transactionManager)
                .build();
    }

    /**
     * Step to insert data into CNTE2 table
     */
    @Bean
    public Step insertIntoCnte2Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("insertIntoCnte2Step", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "INSERT into CNTE2 " +
                        "(SELECT emodsid, roid, " +
                        "sum(case when decode(TYPE,'A',1,'B',1,'C',1,'D',1,'E',1,0) = 1 " +
                        "    then 1 else 0 end), " +
                        "sum(case when decode(TYPE,'F',1,'G',1,'I',1,0) = 1 " +
                        "    then 1 else 0 end) " +
                        "FROM ENTMOD WHERE status = 'O' " +
                        "GROUP BY emodsid, roid); " +
                        "CREATE INDEX CNTE2_IX on CNTE2 (SID)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to truncate CNTE4 table
     */
    @Bean
    public Step truncateCnte4Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("truncateCnte4Step", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate, "TRUNCATE table CNTE4"), transactionManager)
                .build();
    }

    /**
     * Step to insert data into CNTE4 table
     */
    @Bean
    public Step insertIntoCnte4Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("insertIntoCnte4Step", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "INSERT into CNTE4 " +
                        "(SELECT emodsid, roid, " +
                        "sum(case when decode(TYPE,'O',1,'N',1,0) = 1 " +
                        "    then 1 else 0 end) , " +
                        "sum(case when decode(TYPE,'T',1,0) = 1 " +
                        "    then 1 else 0 end) , " +
                        "sum(case when decode(TYPE,'V',1,0) = 1 " +
                        "    then 1 else 0 end) , " +
                        "sum(case when decode(TYPE,'R',1,'X',1,'Z',1,0) = 1 " +
                        "    then 1 else 0 end) " +
                        "FROM ENTMOD " +
                        "WHERE status = 'O' " +
                        "GROUP BY emodsid, roid); " +
                        "CREATE INDEX CNTE4_IX on CNTE4 (SID)"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update count values in TRANTRAIL table
     */
    @Bean
    public Step updateTranTrailCountsStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateTranTrailCountsStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE TRANTRAIL set " +
                        "tdacnt = nvl((SELECT tdacnt FROM CNTE2 " +
                        "    WHERE tinsid = sid and TRANTRAIL.roid = CNTE2.roid),0), " +
                        "tdicnt = nvl((SELECT tdicnt FROM CNTE2 " +
                        "    WHERE tinsid = sid and TRANTRAIL.roid = CNTE2.roid),0), " +
                        "oicnt = nvl((SELECT oicnt FROM CNTE4 " +
                        "    WHERE tinsid = sid and TRANTRAIL.roid = CNTE4.roid),0), " +
                        "ftdcnt = nvl((SELECT ftdcnt FROM CNTE4 " +
                        "    WHERE tinsid = sid and TRANTRAIL.roid = CNTE4.roid),0), " +
                        "oiccnt = nvl((SELECT oiccnt FROM CNTE4 " +
                        "    WHERE tinsid = sid and TRANTRAIL.roid = CNTE4.roid),0), " +
                        "nidrscnt = nvl((SELECT nidrscnt FROM CNTE4 " +
                        "    WHERE tinsid = sid and TRANTRAIL.roid = CNTE4.roid),0) " +
                        "WHERE status = 'O' " +
                        "and EXISTS (SELECT 1 FROM ENTMOD m " +
                        "    WHERE tinsid = emodsid " +
                        "    and TRANTRAIL.roid = m.roid " +
                        "    and m.status = 'O')"
                ), transactionManager)
                .build();
    }

    /**
     * Step to update SEGIND in TRANTRAIL table based on counts
     */
    @Bean
    public Step updateTranTrailSegindStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("updateTranTrailSegindStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate,
                        "UPDATE TRANTRAIL set " +
                        "segind = (case " +
                        "    when tdacnt > 0 and tdicnt > 0 then 'C' " +
                        "    when tdacnt > 0 and tdicnt = 0 then 'A' " +
                        "    when tdicnt > 0 and tdacnt = 0 then 'I' " +
                        "    when tdacnt = 0 and tdicnt = 0 and ftdcnt > 0 then 'F' " +
                        "    when tdacnt = 0 and tdicnt = 0 and ftdcnt = 0 and oicnt > 0 then 'O' " +
                        "    when tdacnt = 0 and tdicnt = 0 and ftdcnt = 0 and oicnt = 0 " +
                        "        and oiccnt+nidrscnt > 0 then 'P' else ' ' " +
                        "end) " +
                        "WHERE status = 'O'"
                ), transactionManager)
                .build();
    }

    /**
     * Step to truncate SEGMODS table
     */
    @Bean
    public Step truncateSegmodsStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("truncateSegmodsStep", jobRepository)
                .tasklet(new SqlRunnerTasklet(jdbcTemplate, "TRUNCATE table SEGMODS"), transactionManager)
                .build();
    }

    /**
     * Step to create log load record for E9 process
     */
    @Bean
    public Step createLogLoadRecordE9Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("createLogLoadRecordE9Step", jobRepository)
                .tasklet(new CreateLogLoadRecordTasklet(jdbcTemplate, "E9", "EXTRACTDT", "E9TMP"), transactionManager)
                .build();
    }
}