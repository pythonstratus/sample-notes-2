package com.abc.sbse.os.ts.csp.alsentity.ale.config;

import javax.sql.DataSource;

import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.item.database.BeanPropertyItemSqlParameterSourceProvider;
import org.springframework.batch.item.database.JdbcBatchItemWriter;
import org.springframework.batch.item.file.FlatFileItemReader;
import org.springframework.batch.item.file.LineMapper;
import org.springframework.batch.item.file.mapping.DefaultLineMapper;
import org.springframework.batch.item.file.transform.FixedLengthTokenizer;
import org.springframework.batch.item.file.transform.Range;
import org.springframework.batch.repeat.RepeatStatus;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.FileSystemResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;

import com.abc.sbse.os.ts.csp.alsentity.ale.data.E9Record;
import com.abc.sbse.os.ts.csp.alsentity.ale.listener.JobCompletionNotificationListener;
import com.abc.sbse.os.ts.csp.alsentity.ale.mapper.E9RecordFieldSetMapper;

/**
 * Configuration for loading E9 data files into database
 * Implements the logic from the loadE9.ctl file
 */
@Configuration
@EnableBatchProcessing
public class E9LoadConfiguration {

    @Autowired
    public DataSource dataSource;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Value("${E9:./data/E9.dat}")
    private String E9_FILE_PATH;

    /**
     * Creates a reader for E9 data files
     * Configures according to the CTL file specifications
     */
    @Bean
    public FlatFileItemReader<E9Record> E9Reader() {
        FlatFileItemReader<E9Record> reader = new FlatFileItemReader<>();
        reader.setResource(new FileSystemResource(E9_FILE_PATH));
        reader.setLineMapper(E9LineMapper());
        reader.setStrict(false); // Allow for recovery on parsing errors
        return reader;
    }

    /**
     * Creates a line mapper for E9 data
     */
    @Bean
    public LineMapper<E9Record> E9LineMapper() {
        DefaultLineMapper<E9Record> lineMapper = new DefaultLineMapper<>();
        lineMapper.setLineTokenizer(E9FixedLengthTokenizer());
        lineMapper.setFieldSetMapper(E9FieldSetMapper());
        return lineMapper;
    }

    /**
     * Configures the fixed length tokenizer according to the CTL file
     */
    @Bean
    public FixedLengthTokenizer E9FixedLengthTokenizer() {
        FixedLengthTokenizer tokenizer = new FixedLengthTokenizer();
        tokenizer.setStrict(false); // Allow for flexibility in line length
        
        // Define field names as specified in CTL file
        tokenizer.setNames(
            "OUTPUTCD", "ENTEXTRACTDT", "RPTENDINGDT", "TIN", "FILESOURCECD", 
            "TINTYPE", "ASGMNTNUM", "TXPVRNUMTRLCD", "TXPVRMCTRLCD", "ENTCASECD", 
            "ENTSUBCASECD", "CYCTOUCHCNT", "TOUCHCNT", "LATESTTOUCHDT", "INPUTHRS", 
            "TOTALCASEHRS", "CASEIDCD", "INVITENSTATECD", "INVITEMCLSDT", "INVITEMTYPECD", 
            "INVITEMCTRLID", "NDSUBCASECD", "RCPTEXT", "CASESTATUS", "CASEROCLOSEDDT", 
            "CASEHOSTCLSDT", "ENTMODDISPCD", "ENTMODCLSNGCD", "INITCONTCTDT", "INITCONTCTDUDT"
        );

        // Set column ranges exactly as defined in CTL file
        tokenizer.setColumns(
            new Range(1, 2),      // OUTPUTCD
            new Range(3, 10),     // ENTEXTRACTDT
            new Range(11, 18),    // RPTENDINGDT
            new Range(19, 27),    // TIN
            new Range(28, 28),    // FILESOURCECD
            new Range(29, 29),    // TINTYPE
            new Range(30, 37),    // ASGMNTNUM
            new Range(38, 72),    // TXPVRNUMTRLCD
            new Range(73, 76),    // TXPVRMCTRLCD
            new Range(77, 79),    // ENTCASECD
            new Range(80, 82),    // ENTSUBCASECD
            new Range(83, 84),    // CYCTOUCHCNT
            new Range(85, 88),    // TOUCHCNT
            new Range(89, 96),    // LATESTTOUCHDT
            new Range(97, 102),   // INPUTHRS
            new Range(103, 108),  // TOTALCASEHRS
            new Range(109, 109),  // CASEIDCD
            new Range(110, 110),  // INVITENSTATECD
            new Range(111, 118),  // INVITEMCLSDT
            new Range(119, 119),  // INVITEMTYPECD
            new Range(120, 127),  // INVITEMCTRLID
            new Range(128, 130),  // NDSUBCASECD
            new Range(131, 133),  // RCPTEXT
            new Range(134, 134),  // CASESTATUS
            new Range(135, 142),  // CASEROCLOSEDDT
            new Range(143, 150),  // CASEHOSTCLSDT
            new Range(151, 152),  // ENTMODDISPCD
            new Range(153, 155),  // ENTMODCLSNGCD
            new Range(156, 163),  // INITCONTCTDT
            new Range(164, 171)   // INITCONTCTDUDT
        );
        
        return tokenizer;
    }

    /**
     * Creates field set mapper for E9 records
     */
    @Bean
    public E9RecordFieldSetMapper E9FieldSetMapper() {
        return new E9RecordFieldSetMapper();
    }

    /**
     * Configures the database writer for E9 records
     */
    @Bean
    public JdbcBatchItemWriter<E9Record> E9Writer() {
        JdbcBatchItemWriter<E9Record> writer = new JdbcBatchItemWriter<>();
        writer.setItemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>());
        writer.setDataSource(dataSource);
        
        // SQL insert statement with all fields from the E9 record
        writer.setSql("INSERT INTO E9TMP (" +
                "OUTPUTCD, TIN, FILESOURCECD, TINTYPE, ASGMNTNUM, TXPVRNUMTRLCD, TXPVRMCTRLCD, " +
                "ENTCASECD, ENTSUBCASECD, CYCTOUCHCNT, TOUCHCNT, INPUTHRS, TOTALCASEHRS, " +
                "CASEIDCD, INVITENSTATECD, INVITEMTYPECD, INVITEMCTRLID, NDSUBCASECD, RCPTEXT, " +
                "CASESTATUS, ENTMODDISPCD, ENTMODCLSNGCD, ENTEXTRACTDT, RPTENDINGDT, LATESTTOUCHDT, " +
                "INVITEMCLSDT, CASEROCLOSEDDT, CASEHOSTCLSDT, INITCONTCTDT, INITCONTCTDUDT" +
                ") VALUES (" +
                ":outputCd, :tin, :fileSourceCd, :tinType, :asgmntNum, :txpVrNumTrlCd, :txpVrMCtrlCd, " +
                ":entCaseCd, :entSubCaseCd, :cycTouchCnt, :touchCnt, :inputHrs, :totalCaseHrs, " +
                ":caseIdCd, :invItenStateCd, :invItemTypeCd, :invItemCtrlId, :ndSubCaseCd, :rcpText, " +
                ":caseStatus, :entModDispCd, :entModClsngCd, :entExtractDt, :rptEndingDt, :latestTouchDt, " +
                ":invItemClsDt, :caseRoClosedDt, :caseHostClsDt, :initContCtDt, :initContCtDuDt" +
                ")");
        
        return writer;
    }

    /**
     * Step to clear E9TMP table before loading
     */
    @Bean(name = "clearE9Step")
    public Step clearE9Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("clearE9Step", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    jdbcTemplate.execute("TRUNCATE TABLE E9TMP");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    /**
     * Step to load E9 data file into table
     */
    @Bean(name = "loadE9FileToTableStep")
    public Step loadE9FileToTableStep(JobRepository jobRepository, PlatformTransactionManager transactionManager,
                                     FlatFileItemReader<E9Record> E9Reader, 
                                     JdbcBatchItemWriter<E9Record> E9Writer) {
        return new StepBuilder("loadE9FileToTableStep", jobRepository)
                .<E9Record, E9Record>chunk(5000, transactionManager)
                .reader(E9Reader)
                .writer(E9Writer)
                .build();
    }

    /**
     * Job to import E9 data
     */
    @Bean(name = "importE9Job")
    public Job importE9Job(JobRepository jobRepository, JobCompletionNotificationListener listener,
                         Step clearE9Step, Step loadE9FileToTableStep) {
        return new JobBuilder("importE9Job", jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .start(clearE9Step)
                .next(loadE9FileToTableStep)
                .build();
    }
}