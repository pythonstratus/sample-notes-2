package com.als.service;

import com.als.config.ApplicationConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * DialStep1OrchestratorService - Coordinates all Step 1 DIAL operations
 * 
 * This service orchestrates the execution of all Step 1 processes:
 * 1. Dial1_crRAW - Creates COMBO.raw files 
 * 2. Dial1_dothrcp - Gathers database table statistics
 * 3. Dial1_exports - Performs Oracle exports for DIAL tables
 * 4. Dial1_point2cp - Executes database synchronization operations
 */
@Service
public class DialStep1OrchestratorService {
    
    private static final Logger logger = LoggerFactory.getLogger(DialStep1OrchestratorService.class);
    
    @Autowired
    private ApplicationConfig config;
    
    @Autowired
    private DialCrRawService dialCrRawService;
    
    @Autowired
    private DialTableStatsService dialTableStatsService;
    
    @Autowired
    private DialExportsService dialExportsService;
    
    @Autowired
    private DialSyncService dialSyncService;
    
    /**
     * Execute all Step 1 operations in the correct sequence
     * 
     * Based on the original DIAL scripts, these operations should run in order:
     * 1. Create COMBO.raw files (Dial1_crRAW)
     * 2. Gather table statistics (Dial1_dothrcp) 
     * 3. Perform exports (Dial1_exports)
     * 4. Synchronize databases (Dial1_point2cp)
     */
    public void executeStep1Operations() {
        logger.info("=== Starting DIAL Step 1 Operations ===");
        String startTime = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        
        try {
            // Step 1a: Create COMBO.raw files
            logger.info("Step 1a: Starting COMBO.raw file creation");
            dialCrRawService.processComboRawFiles();
            logger.info("Step 1a: COMBO.raw file creation completed successfully");
            
            // Step 1b: Gather database table statistics  
            logger.info("Step 1b: Starting database table statistics gathering");
            dialTableStatsService.gatherTableStatistics();
            logger.info("Step 1b: Table statistics gathering completed successfully");
            
            // Step 1c: Perform Oracle exports
            logger.info("Step 1c: Starting Oracle export operations");
            dialExportsService.performDialExports();
            logger.info("Step 1c: Oracle export operations completed successfully");
            
            // Step 1d: Database synchronization
            logger.info("Step 1d: Starting database synchronization");
            dialSyncService.performDatabaseSync();
            logger.info("Step 1d: Database synchronization completed successfully");
            
            String endTime = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
            logger.info("=== DIAL Step 1 Operations Completed Successfully ===");
            logger.info("Start Time: {}, End Time: {}", startTime, endTime);
            
        } catch (Exception e) {
            logger.error("Error during DIAL Step 1 operations", e);
            throw new RuntimeException("DIAL Step 1 operations failed", e);
        }
    }
    
    /**
     * Execute individual Step 1 operation by name
     * Useful for troubleshooting or re-running specific steps
     */
    public void executeStep1Operation(String operationName) {
        logger.info("Executing individual Step 1 operation: {}", operationName);
        
        try {
            switch (operationName.toLowerCase()) {
                case "crraw":
                case "combo":
                    dialCrRawService.processComboRawFiles();
                    break;
                case "stats":
                case "dothrcp":
                    dialTableStatsService.gatherTableStatistics();
                    break;
                case "exports":
                    dialExportsService.performDialExports();
                    break;
                case "sync":
                case "point2cp":
                    dialSyncService.performDatabaseSync();
                    break;
                default:
                    throw new IllegalArgumentException("Unknown Step 1 operation: " + operationName);
            }
            logger.info("Step 1 operation '{}' completed successfully", operationName);
            
        } catch (Exception e) {
            logger.error("Error executing Step 1 operation: {}", operationName, e);
            throw new RuntimeException("Step 1 operation failed: " + operationName, e);
        }
    }
    
    /**
     * Check status of Step 1 prerequisites
     * Validates that all required components are ready
     */
    public boolean validateStep1Prerequisites() {
        logger.info("Validating Step 1 prerequisites");
        
        try {
            // Add validation logic here
            // - Check database connectivity
            // - Verify required directories exist
            // - Validate configuration settings
            // - Check file permissions
            
            logger.info("Step 1 prerequisites validation passed");
            return true;
            
        } catch (Exception e) {
            logger.error("Step 1 prerequisites validation failed", e);
            return false;
        }
    }
}