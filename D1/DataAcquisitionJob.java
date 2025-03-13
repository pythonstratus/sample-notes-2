package com.dial.batch.config;

import com.dial.services.acquisition.ComboFileGenerator;
import com.dial.services.acquisition.DatabasePointerManager;
import com.dial.services.acquisition.ExportService;
import com.dial.services.acquisition.TableStatisticsService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.batch.core.configuration.annotation.JobBuilderFactory;
import org.springframework.batch.core.configuration.annotation.StepBuilderFactory;
import org.springframework.batch.core.job.builder.FlowBuilder;
import org.springframework.batch.core.job.flow.Flow;
import org.springframework.batch.core.job.flow.support.SimpleFlow;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.core.listener.JobExecutionListenerSupport;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.SimpleAsyncTaskExecutor;
import org.springframework.core.task.TaskExecutor;

/**
 * Spring Batch configuration for the Data Acquisition job (Stage 1).
 * Implements the functionality of Dial1 scripts in a Spring Batch context.
 */
@Configuration
@EnableBatchProcessing
public class DataAcquisitionJob {
    private static final Logger logger = LoggerFactory.getLogger(DataAcquisitionJob.class);
    
    private final JobBuilderFactory jobBuilderFactory;
    private final StepBuilderFactory stepBuilderFactory;
    
    @Value("${dial.job.enabled.statistics:true}")
    private boolean enableStatisticsStep;
    
    @Value("${dial.job.enabled.pointer:true}")
    private boolean enablePointerStep;
    
    @Value("${dial.job.enabled.export:true}")
    private boolean enableExportStep;
    
    @Value("${dial.job.enabled.combo:true}")
    private boolean enableComboStep;
    
    @Value("${dial.job.parallel.execution:false}")
    private boolean parallelExecution;
    
    @Value("${dial.job.max-threads:4}")
    private int maxThreads;
    
    @Value("${dial.job.retry-limit:3}")
    private int retryLimit;
    
    @Autowired
    public DataAcquisitionJob(JobBuilderFactory jobBuilderFactory, StepBuilderFactory stepBuilderFactory) {
        this.jobBuilderFactory = jobBuilderFactory;
        this.stepBuilderFactory = stepBuilderFactory;
    }
    
    /**
     * Creates the main data acquisition job
     */
    @Bean
    public Job dataAcquisitionJob(
            Step tableStatisticsStep,
            Step databasePointerStep,
            Step exportStep,
            Step comboFileGenerationStep,
            JobCompletionNotificationListener jobCompletionListener) {
        
        logger.info("Configuring data acquisition job with steps enabled: " +
                   "Statistics={}, Pointer={}, Export={}, Combo={}",
                   enableStatisticsStep, enablePointerStep, enableExportStep, enableComboStep);
        
        if (parallelExecution) {
            logger.info("Configuring with parallel execution using {} threads", maxThreads);
            return configureParallelJob(
                tableStatisticsStep, 
                databasePointerStep, 
                exportStep, 
                comboFileGenerationStep,
                jobCompletionListener
            );
        } else {
            logger.info("Configuring with sequential execution");
            return configureSequentialJob(
                tableStatisticsStep, 
                databasePointerStep, 
                exportStep, 
                comboFileGenerationStep,
                jobCompletionListener
            );
        }
    }
    
    /**
     * Configures a sequential job where steps run one after another
     */
    private Job configureSequentialJob(
            Step tableStatisticsStep,
            Step databasePointerStep,
            Step exportStep,
            Step comboFileGenerationStep,
            JobCompletionNotificationListener jobCompletionListener) {
        
        // Start with a job builder
        var jobBuilder = jobBuilderFactory.get("dataAcquisitionJob")
                .incrementer(new RunIdIncrementer())
                .listener(jobCompletionListener);
        
        // Add enabled steps in sequence
        var flowBuilder = jobBuilder.start(new SimpleFlow("emptyFlow"));
        
        if (enableStatisticsStep) {
            flowBuilder = flowBuilder.next(tableStatisticsStep);
        }
        
        if (enablePointerStep) {
            flowBuilder = flowBuilder.next(databasePointerStep);
        }
        
        if (enableExportStep) {
            flowBuilder = flowBuilder.next(exportStep);
        }
        
        if (enableComboStep) {
            flowBuilder = flowBuilder.next(comboFileGenerationStep);
        }
        
        return flowBuilder.build().build();
    }
    
    /**
     * Configures a parallel job where steps can run simultaneously
     */
    private Job configureParallelJob(
            Step tableStatisticsStep,
            Step databasePointerStep,
            Step exportStep,
            Step comboFileGenerationStep,
            JobCompletionNotificationListener jobCompletionListener) {
        
        // Create flows for enabled steps
        FlowBuilder<Flow> parallelFlowBuilder = new FlowBuilder<>("parallelFlow");
        Flow parallelFlow = null;
        
        // Build parallel flows for enabled steps
        if (enableStatisticsStep && enablePointerStep) {
            // Start with statistics and pointer in parallel
            Flow statsFlow = new FlowBuilder<Flow>("statisticsFlow")
                    .start(tableStatisticsStep)
                    .build();
            
            Flow pointerFlow = new FlowBuilder<Flow>("pointerFlow")
                    .start(databasePointerStep)
                    .build();
            
            parallelFlow = parallelFlowBuilder
                    .split(taskExecutor())
                    .add(statsFlow, pointerFlow)
                    .build();
            
        } else if (enableStatisticsStep) {
            parallelFlow = new FlowBuilder<Flow>("statisticsFlow")
                    .start(tableStatisticsStep)
                    .build();
        } else if (enablePointerStep) {
            parallelFlow = new FlowBuilder<Flow>("pointerFlow")
                    .start(databasePointerStep)
                    .build();
        }
        
        // If we have export and combo steps, add them sequentially after the parallel part
        Flow finalFlow = parallelFlow;
        
        if (enableExportStep) {
            FlowBuilder<Flow> exportFlowBuilder = new FlowBuilder<>("exportFlow");
            if (finalFlow != null) {
                finalFlow = exportFlowBuilder
                        .start(finalFlow)
                        .next(exportStep)
                        .build();
            } else {
                finalFlow = exportFlowBuilder
                        .start(exportStep)
                        .build();
            }
        }
        
        if (enableComboStep) {
            FlowBuilder<Flow> comboFlowBuilder = new FlowBuilder<>("comboFlow");
            if (finalFlow != null) {
                finalFlow = comboFlowBuilder
                        .start(finalFlow)
                        .next(comboFileGenerationStep)
                        .build();
            } else {
                finalFlow = comboFlowBuilder
                        .start(comboFileGenerationStep)
                        .build();
            }
        }
        
        // If no steps are enabled, create an empty flow
        if (finalFlow == null) {
            finalFlow = new FlowBuilder<Flow>("emptyFlow").build();
        }
        
        // Create the final job
        return jobBuilderFactory.get("dataAcquisitionParallelJob")
                .incrementer(new RunIdIncrementer())
                .listener(jobCompletionListener)
                .start(finalFlow)
                .end()
                .build();
    }
    
    /**
     * Creates a task executor for parallel step execution
     */
    @Bean
    public TaskExecutor taskExecutor() {
        SimpleAsyncTaskExecutor executor = new SimpleAsyncTaskExecutor("dial-job-");
        executor.setConcurrencyLimit(maxThreads);
        return executor;
    }
    
    /**
     * Step for table statistics collection
     */
    @Bean
    public Step tableStatisticsStep(TableStatisticsService tableStatisticsService) {
        return stepBuilderFactory.get("tableStatisticsStep")
                .tasklet(tableStatisticsService)
                .allowStartIfComplete(true)
                .startLimit(retryLimit)
                .build();
    }
    
    /**
     * Step for database pointer management
     */
    @Bean
    public Step databasePointerStep(DatabasePointerManager databasePointerManager) {
        return stepBuilderFactory.get("databasePointerStep")
                .tasklet(databasePointerManager)
                .allowStartIfComplete(true)
                .startLimit(retryLimit)
                .build();
    }
    
    /**
     * Step for database export
     */
    @Bean
    public Step exportStep(ExportService exportService) {
        return stepBuilderFactory.get("exportStep")
                .tasklet(exportService)
                .allowStartIfComplete(true)
                .startLimit(retryLimit)
                .build();
    }
    
    /**
     * Step for combo file generation
     */
    @Bean
    public Step comboFileGenerationStep(ComboFileGenerator comboFileGenerator) {
        return stepBuilderFactory.get("comboFileGenerationStep")
                .tasklet(comboFileGenerator)
                .allowStartIfComplete(true)
                .startLimit(retryLimit)
                .build();
    }
    
    /**
     * Listener for job completion notification
     */
    @Bean
    public JobCompletionNotificationListener jobCompletionListener() {
        return new JobCompletionNotificationListener();
    }
    
    /**
     * Job completion notification listener
     */
    public static class JobCompletionNotificationListener extends JobExecutionListenerSupport {
        
        private static final Logger logger = LoggerFactory.getLogger(JobCompletionNotificationListener.class);
        
        @Override
        public void beforeJob(org.springframework.batch.core.JobExecution jobExecution) {
            logger.info("Starting Data Acquisition Job: {}", jobExecution.getJobInstance().getJobName());
        }
        
        @Override
        public void afterJob(org.springframework.batch.core.JobExecution jobExecution) {
            logger.info("Data Acquisition Job completed with status: {}", jobExecution.getStatus());
            
            // Log performance metrics
            long duration = jobExecution.getEndTime().getTime() - jobExecution.getStartTime().getTime();
            logger.info("Job duration: {} ms", duration);
            
            // Log step details
            jobExecution.getStepExecutions().forEach(stepExecution -> 
                logger.info("Step {} completed with status: {}, read: {}, written: {}, filtered: {}",
                    stepExecution.getStepName(),
                    stepExecution.getStatus(),
                    stepExecution.getReadCount(),
                    stepExecution.getWriteCount(),
                    stepExecution.getFilterCount())
            );
        }
    }
}