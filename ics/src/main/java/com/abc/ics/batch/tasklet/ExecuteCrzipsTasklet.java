package com.abc.ics.batch.tasklet;

import com.abc.ics.service.DatabaseService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.tasklet.Tasklet;
import org.springframework.batch.repeat.RepeatStatus;

/**
 * Tasklet for executing the crzips SQL procedure
 * Equivalent to PART 3 of ent_zip.csh (lines 261-274)
 * 
 * This procedure transforms data from oldzips to icszips table
 */
@Slf4j
@RequiredArgsConstructor
public class ExecuteCrzipsTasklet implements Tasklet {

    private final DatabaseService databaseService;

    @Override
    public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext) throws Exception {
        log.info("========== Starting Execute Crzips Step ==========");
        log.info("========== PART 3: Drop icszips, re-create icszips and load constraint-acceptable data from oldzips table ==========");
        
        // Execute the crzips SQL script
        databaseService.executeCrzipsScript();
        
        log.info("crzips procedure execution completed successfully");
        
        return RepeatStatus.FINISHED;
    }
}
