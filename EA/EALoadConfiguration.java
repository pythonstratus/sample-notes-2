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

import com.abc.sbse.os.ts.csp.alsentity.ale.data.EARecord;
import com.abc.sbse.os.ts.csp.alsentity.ale.listener.JobCompletionNotificationListener;
import com.abc.sbse.os.ts.csp.alsentity.ale.mapper.EARecordFieldSetMapper;

/**
 * Configuration for loading EA data files into database
 * Implements the logic from the loadEA.ctl file
 */
@Configuration
@EnableBatchProcessing
public class EALoadConfiguration {

    @Autowired
    public DataSource dataSource;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Value("${EA:./data/EA.dat}")
    private String EA_FILE_PATH;

    /**
     * Creates a reader for EA data files
     * Configures according to the CTL file specifications
     */
    @Bean
    public FlatFileItemReader<EARecord> EAReader() {
        FlatFileItemReader<EARecord> reader = new FlatFileItemReader<>();
        reader.setResource(new FileSystemResource(EA_FILE_PATH));
        reader.setLineMapper(EALineMapper());
        reader.setStrict(false); // Allow for recovery on parsing errors
        return reader;
    }

    /**
     * Creates a line mapper for EA data
     */
    @Bean
    public LineMapper<EARecord> EALineMapper() {
        DefaultLineMapper<EARecord> lineMapper = new DefaultLineMapper<>();
        lineMapper.setLineTokenizer(EAFixedLengthTokenizer());
        lineMapper.setFieldSetMapper(EAFieldSetMapper());
        return lineMapper;
    }

    /**
     * Configures the fixed length tokenizer according to the CTL file
     */
    @Bean
    public FixedLengthTokenizer EAFixedLengthTokenizer() {
        FixedLengthTokenizer tokenizer = new FixedLengthTokenizer();
        tokenizer.setStrict(false); // Allow for flexibility in line length
        
        // Define field names as specified in CTL file
        tokenizer.setNames(
            "OUTPUTCD", "EXTRACTDT", "TIN", "FILESOURCECD", "TINTYPE", 
            "MFTCD", "TAXPRD", "INVITEMCTRLID", "ASGMNTNUM", "MODTYPEIND",
            "TAXMODASSNDT", "ROCLOSEDDT", "ICSCLOSINGCD", "TDICLOSECD", 
            "CLOSINGTRANSCD", "MODDISPCD", "ICSSTATUSCD"
        );

        // Set column ranges exactly as defined in CTL file
        tokenizer.setColumns(
            new Range(1, 2),      // OUTPUTCD
            new Range(3, 10),     // EXTRACTDT
            new Range(11, 19),    // TIN
            new Range(20, 20),    // FILESOURCECD
            new Range(21, 21),    // TINTYPE
            new Range(22, 23),    // MFTCD
            new Range(24, 29),    // TAXPRD
            new Range(30, 37),    // INVITEMCTRLID
            new Range(38, 45),    // ASGMNTNUM
            new Range(46, 46),    // MODTYPEIND
            new Range(47, 54),    // TAXMODASSNDT
            new Range(55, 62),    // ROCLOSEDDT
            new Range(63, 65),    // ICSCLOSINGCD
            new Range(66, 68),    // TDICLOSECD
            new Range(69, 71),    // CLOSINGTRANSCD
            new Range(72, 73),    // MODDISPCD
            new Range(74, 74)     // ICSSTATUSCD
        );
        
        return tokenizer;
    }

    /**
     * Creates field set mapper for EA records
     */
    @Bean
    public EARecordFieldSetMapper EAFieldSetMapper() {
        return new EARecordFieldSetMapper();
    }

    /**
     * Configures the database writer for EA records
     */
    @Bean
    public JdbcBatchItemWriter<EARecord> EAWriter() {
        JdbcBatchItemWriter<EARecord> writer = new JdbcBatchItemWriter<>();
        writer.setItemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>());
        writer.setDataSource(dataSource);
        
        // SQL insert statement with all fields from the EA record
        writer.setSql("INSERT INTO EATMP (" +
                "OUTPUTCD, TIN, FILESOURCECD, TINTYPE, MFTCD, TAXPRD, " +
                "INVITEMCTRLID, ASGMNTNUM, MODTYPEIND, TAXMODASSNDT, ROCLOSEDDT, " +
                "ICSCLOSINGCD, TDICLOSECD, CLOSINGTRANSCD, MODDISPCD, ICSSTATUSCD, " +
                "EXTRACTDT, STATUS" +
                ") VALUES (" +
                ":outputCd, :tin, :fileSourceCd, :tinType, :mftCd, :taxPrd, " +
                ":invItemCtrlId, :asgmntNum, :modTypeInd, :taxModAssnDt, :roClosedDt, " +
                ":icsClosingCd, :tdiCloseCd, :closingTranScd, :modDispCd, :icsStatusCd, " +
                ":extractDt, :status" +
                ")");
        
        return writer;
    }

    /**
     * Step to clear EATMP table before loading
     */
    @Bean(name = "clearEAStep")
    public Step clearEAStep(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("clearEAStep", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    jdbcTemplate.execute("TRUNCATE TABLE EATMP");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    /**
     * Step to load EA data file into table
     */
    @Bean(name = "loadEAFileToTableStep")
    public Step loadEAFileToTableStep(JobRepository jobRepository, PlatformTransactionManager transactionManager,
                                    FlatFileItemReader<EARecord> EAReader, 
                                    JdbcBatchItemWriter<EARecord> EAWriter) {
        return new StepBuilder("loadEAFileToTableStep", jobRepository)
                .<EARecord, EARecord>chunk(5000, transactionManager)
                .reader(EAReader)
                .writer(EAWriter)
                .build();
    }

    /**
     * Job to import EA data
     */
    @Bean(name = "importEAJob")
    public Job importEAJob(JobRepository jobRepository, JobCompletionNotificationListener listener,
                         Step clearEAStep, Step loadEAFileToTableStep) {
        return new JobBuilder("importEAJob", jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .start(clearEAStep)
                .next(loadEAFileToTableStep)
                .build();
    }
}