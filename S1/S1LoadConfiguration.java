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

import com.abc.sbse.os.ts.csp.alsentity.ale.data.S1Record;
import com.abc.sbse.os.ts.csp.alsentity.ale.listener.JobCompletionNotificationListener;
import com.abc.sbse.os.ts.csp.alsentity.ale.mapper.S1RecordFieldSetMapper;

/**
 * Configuration for loading S1 data files into database
 * Implements the logic from the loadS1.ctl file
 */
@Configuration
@EnableBatchProcessing
public class S1LoadConfiguration {

    @Autowired
    public DataSource dataSource;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Value("${S1:./data/S1.dat}")
    private String S1_FILE_PATH;

    /**
     * Creates a reader for S1 data files
     * Configures according to the CTL file specifications
     */
    @Bean
    public FlatFileItemReader<S1Record> S1Reader() {
        FlatFileItemReader<S1Record> reader = new FlatFileItemReader<>();
        reader.setResource(new FileSystemResource(S1_FILE_PATH));
        reader.setLineMapper(S1LineMapper());
        reader.setStrict(false); // Allow for recovery on parsing errors
        return reader;
    }

    /**
     * Creates a line mapper for S1 data
     */
    @Bean
    public LineMapper<S1Record> S1LineMapper() {
        DefaultLineMapper<S1Record> lineMapper = new DefaultLineMapper<>();
        lineMapper.setLineTokenizer(S1FixedLengthTokenizer());
        lineMapper.setFieldSetMapper(S1FieldSetMapper());
        return lineMapper;
    }

    /**
     * Configures the fixed length tokenizer according to the CTL file
     */
    @Bean
    public FixedLengthTokenizer S1FixedLengthTokenizer() {
        FixedLengthTokenizer tokenizer = new FixedLengthTokenizer();
        tokenizer.setStrict(false); // Allow for flexibility in line length
        
        // Define field names as specified in CTL file
        tokenizer.setNames(
            "OUTPUTCD", "AREA", "TYPE", "CODE", "CDNAME",
            "EXTRDT", "TIMEDEF", "ACTIVE", "MGR", "CLERK",
            "PROF", "PARA", "DISP", "CTRSDEF"
        );

        // Set column ranges exactly as defined in CTL file
        tokenizer.setColumns(
            new Range(1, 2),    // OUTPUTCD
            new Range(3, 6),    // AREA
            new Range(7, 7),    // TYPE
            new Range(8, 10),   // CODE
            new Range(11, 45),  // CDNAME
            new Range(46, 53),  // EXTRDT
            new Range(54, 54),  // TIMEDEF
            new Range(55, 55),  // ACTIVE
            new Range(56, 56),  // MGR
            new Range(57, 57),  // CLERK
            new Range(58, 58),  // PROF
            new Range(59, 59),  // PARA
            new Range(60, 60),  // DISP
            new Range(61, 61)   // CTRSDEF
        );
        
        return tokenizer;
    }

    /**
     * Creates field set mapper for S1 records
     */
    @Bean
    public S1RecordFieldSetMapper S1FieldSetMapper() {
        return new S1RecordFieldSetMapper();
    }

    /**
     * Configures the database writer for S1 records
     */
    @Bean
    public JdbcBatchItemWriter<S1Record> S1Writer() {
        JdbcBatchItemWriter<S1Record> writer = new JdbcBatchItemWriter<>();
        writer.setItemSqlParameterSourceProvider(new BeanPropertyItemSqlParameterSourceProvider<>());
        writer.setDataSource(dataSource);
        
        // SQL insert statement with all fields from the S1 record
        writer.setSql("INSERT INTO S1TMP (" +
                "OUTPUTCD, AREA, TYPE, CODE, CDNAME, EXTRDT, " +
                "TIMEDEF, ACTIVE, MGR, CLERK, PROF, PARA, DISP, CTRSDEF" +
                ") VALUES (" +
                ":outputCd, :area, :type, :code, :cdName, :extractDt, " +
                ":timeDef, :active, :mgr, :clerk, :prof, :para, :disp, :ctrsDef" +
                ")");
        
        return writer;
    }

    /**
     * Step to clear S1TMP table before loading
     */
    @Bean(name = "clearS1Step")
    public Step clearS1Step(JobRepository jobRepository, PlatformTransactionManager transactionManager) {
        return new StepBuilder("clearS1Step", jobRepository)
                .tasklet((contribution, chunkContext) -> {
                    jdbcTemplate.execute("TRUNCATE TABLE S1TMP");
                    return RepeatStatus.FINISHED;
                }, transactionManager).build();
    }

    /**
     * Step to load S1 data file into table
     */
    @Bean(name = "loadS1FileToTableStep")
    public Step loadS1FileToTableStep(JobRepository jobRepository, PlatformTransactionManager transactionManager,
                                    FlatFileItemReader<S1Record> S1Reader, 
                                    JdbcBatchItemWriter<S1Record> S1Writer) {
        return new StepBuilder("loadS1FileToTableStep", jobRepository)
                .<S1Record, S1Record>chunk(5000, transactionManager)
                .reader(S1Reader)
                .writer(S1Writer)
                .build();
    }

    /**
     * Job to import S1 data
     */
    @Bean(name = "importS1Job")
    public Job importS1Job(JobRepository jobRepository, JobCompletionNotificationListener listener,
                         Step clearS1Step, Step loadS1FileToTableStep) {
        return new JobBuilder("importS1Job", jobRepository)
                .incrementer(new RunIdIncrementer())
                .listener(listener)
                .start(clearS1Step)
                .next(loadS1FileToTableStep)
                .build();
    }
}