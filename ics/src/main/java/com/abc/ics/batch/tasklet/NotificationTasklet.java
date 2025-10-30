package com.abc.ics.batch.tasklet;

import com.abc.ics.config.IcsZipConfigProperties;
import com.abc.ics.service.EmailService;
import com.abc.ics.service.FileService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;

import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Tasklet for sending final notifications
 * Equivalent to the final email section of ent_zip.csh (lines 282-310)
 */
@Slf4j
@RequiredArgsConstructor
public class NotificationTasklet implements Tasklet {

    private final EmailService emailService;
    private final FileService fileService;
    private final IcsZipConfigProperties config;

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        log.info("========== Starting Notification Step ==========");
        
        // Get job execution status
        boolean jobSuccessful = chunkContext.getStepContext()
                .getStepExecution()
                .getJobExecution()
                .getStatus()
                .isUnsuccessful() == false;
        
        // Check error log file
        Path errorLogPath = Paths.get(config.getLog().getDirectory(), 
                config.getLog().getErrorLogFile());
        
        // Send status notification if there are errors
        emailService.sendJobStatusNotification(jobSuccessful, errorLogPath);
        
        log.info("ent_zip.csh done");
        log.info("========== Job Completed ==========");
        
        return RepeatStatus.FINISHED;
    }
}
