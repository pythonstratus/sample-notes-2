package com.abc.ics.batch.tasklet;

import com.abc.ics.config.IcsZipConfigProperties;
import com.abc.ics.service.DatabaseService;
import com.abc.ics.service.FileService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * Tasklet for processing each geographic area
 * Equivalent to PART 2 of ent_zip.csh (lines 146-240)
 * 
 * This tasklet processes all 8 areas sequentially:
 * - Extract area records from main file
 * - Delete old records from oldzips
 * - Load new records into oldzips
 */
@Slf4j
@RequiredArgsConstructor
public class AreaProcessingTasklet implements Tasklet {

    private final FileService fileService;
    private final DatabaseService databaseService;
    private final IcsZipConfigProperties config;

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        log.info("========== Starting Area Processing Step ==========");
        log.info("========== {} ========== PART 2: Load latest zip code assignment files to oldzips table =====",
                fileService.getCurrentDateTime());
        
        // Get working file from previous step
        String workingFilePath = (String) chunkContext.getStepContext()
                .getStepExecution()
                .getJobExecution()
                .getExecutionContext()
                .get("workingFile");
        
        if (workingFilePath == null) {
            throw new IllegalStateException("Working file not found in execution context");
        }
        
        Path workingFile = Paths.get(workingFilePath);
        
        // Test database connection
        databaseService.testConnection();
        
        // Process each area
        List<Integer> areas = config.getProcessing().getAreas();
        log.info("Processing {} geographic areas: {}", areas.size(), areas);
        
        int totalRecordsProcessed = 0;
        
        for (Integer area : areas) {
            try {
                log.info("========== Processing Area {} ==========", area);
                
                // Check if area data exists in the main file
                Path areaFile = fileService.extractAreaRecords(workingFile, area);
                
                if (fileService.fileExistsAndNotEmpty(areaFile)) {
                    // Delete old records for this area
                    int deletedCount = databaseService.deleteOldZipsForArea(area);
                    
                    // Load new records
                    int insertedCount = databaseService.loadDataToOldZips(areaFile, area);
                    totalRecordsProcessed += insertedCount;
                    
                    log.info("========== {} ========== AREA {} COMPLETE =====",
                            fileService.getCurrentDateTime(), area);
                } else {
                    log.warn("========== {} ========== AREA {} MISSING =====",
                            fileService.getCurrentDateTime(), area);
                }
                
            } catch (Exception e) {
                log.error("Error processing area {}", area, e);
                // Continue with next area instead of failing entire job
                // This mimics the shell script behavior
                log.warn("Continuing with next area despite error in area {}", area);
            }
        }
        
        log.info("========== {} ========== LOAD TO OLDZIPS FINISH =====",
                fileService.getCurrentDateTime());
        log.info("Total records processed across all areas: {}", totalRecordsProcessed);
        
        // Store total count for reporting
        chunkContext.getStepContext()
                .getStepExecution()
                .getJobExecution()
                .getExecutionContext()
                .put("totalRecordsProcessed", totalRecordsProcessed);
        
        return RepeatStatus.FINISHED;
    }
}
