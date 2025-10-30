package com.abc.ics.batch.tasklet;

import com.abc.ics.config.IcsZipConfigProperties;
import com.abc.ics.exception.FileValidationException;
import com.abc.ics.service.EmailService;
import com.abc.ics.service.FileService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;

import java.nio.file.Path;

/**
 * Tasklet for validating input files
 * Equivalent to PART 1 of ent_zip.csh (lines 37-144)
 */
@Slf4j
@RequiredArgsConstructor
public class FileValidationTasklet implements Tasklet {

    private final FileService fileService;
    private final EmailService emailService;
    private final IcsZipConfigProperties config;

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        log.info("========== Starting File Validation Step ==========");
        
        try {
            // Backup previous log file
            fileService.backupLogFile();
            
            // Validate and get input file
            Path inputFile = fileService.validateAndGetInputFile();
            
            // Copy to working file
            Path workingFile = fileService.copyToWorkingFile(inputFile);
            
            // Store file paths in execution context for next steps
            chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .put("inputFile", inputFile.toString());
            
            chunkContext.getStepContext()
                    .getStepExecution()
                    .getJobExecution()
                    .getExecutionContext()
                    .put("workingFile", workingFile.toString());
            
            log.info("File validation completed successfully");
            log.info("Input file: {}", inputFile);
            log.info("Working file: {}", workingFile);
            
            return RepeatStatus.FINISHED;
            
        } catch (FileValidationException e) {
            log.error("File validation failed", e);
            
            // Send appropriate email notification based on error type
            if (e.getMessage().contains("Multiple input files")) {
                emailService.sendMultipleFilesErrorNotification(2); // Adjust count based on actual
            } else if (e.getMessage().contains("No input files")) {
                emailService.sendFileNotTransferredNotification();
            } else if (e.getMessage().contains("Error copying")) {
                emailService.sendFileCopyErrorNotification();
            }
            
            throw e;
        }
    }
}
