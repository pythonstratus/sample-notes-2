package com.dial.api.controllers;

import com.dial.services.acquisition.ComboFileGenerator;
import com.dial.services.acquisition.DatabasePointerManager;
import com.dial.services.acquisition.ExportService;
import com.dial.services.acquisition.TableStatisticsService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobInstance;
import org.springframework.batch.core.JobParameters;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.explore.JobExplorer;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.batch.core.launch.NoSuchJobExecutionException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * REST controller for Data Acquisition operations.
 * Provides endpoints to trigger and monitor Stage 1 DIAL operations.
 */
@RestController
@RequestMapping("/api/acquisition")
public class DataAcquisitionController {
    private static final Logger logger = LoggerFactory.getLogger(DataAcquisitionController.class);
    
    private final JobLauncher jobLauncher;
    private final JobExplorer jobExplorer;
    private final Job dataAcquisitionJob;
    private final TableStatisticsService tableStatisticsService;
    private final DatabasePointerManager databasePointerManager;
    private final ExportService exportService;
    private final ComboFileGenerator comboFileGenerator;
    
    @Value("${dial.job.enabled.statistics:true}")
    private boolean enableStatisticsStep;
    
    @Value("${dial.job.enabled.pointer:true}")
    private boolean enablePointerStep;
    
    @Value("${dial.job.enabled.export:true}")
    private boolean enableExportStep;
    
    @Value("${dial.job.enabled.combo:true}")
    private boolean enableComboStep;
    
    @Value("${dial.job.max-history:10}")
    private int maxJobHistory;
    
    @Autowired
    public DataAcquisitionController(
            JobLauncher jobLauncher,
            JobExplorer jobExplorer,
            @Qualifier("dataAcquisitionJob") Job dataAcquisitionJob,
            TableStatisticsService tableStatisticsService,
            DatabasePointerManager databasePointerManager,
            ExportService exportService,
            ComboFileGenerator comboFileGenerator) {
        
        this.jobLauncher = jobLauncher;
        this.jobExplorer = jobExplorer;
        this.dataAcquisitionJob = dataAcquisitionJob;
        this.tableStatisticsService = tableStatisticsService;
        this.databasePointerManager = databasePointerManager;
        this.exportService = exportService;
        this.comboFileGenerator = comboFileGenerator;
    }
    
    /**
     * Run the complete data acquisition job (all steps of Stage 1)
     * 
     * @param params Optional parameter map to customize the job execution
     * @return Response with job execution details
     */
    @PostMapping("/run")
    public ResponseEntity<Map<String, Object>> runDataAcquisitionJob(
            @RequestParam(required = false) Map<String, String> params) {
        
        logger.info("Received request to run data acquisition job with params: {}", params);
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            // Start with base job parameters
            JobParametersBuilder jobParamsBuilder = new JobParametersBuilder()
                    .addDate("run.date", new Date())
                    .addString("run.id", UUID.randomUUID().toString());
            
            // Add any custom parameters passed in the request
            if (params != null) {
                for (Map.Entry<String, String> entry : params.entrySet()) {
                    jobParamsBuilder.addString(entry.getKey(), entry.getValue());
                }
            }
            
            // Run the job
            JobExecution jobExecution = jobLauncher.run(dataAcquisitionJob, jobParamsBuilder.toJobParameters());
            
            response.put("status", "Job started successfully");
            response.put("jobExecutionId", jobExecution.getId());
            response.put("jobName", jobExecution.getJobInstance().getJobName());
            response.put("startTime", jobExecution.getStartTime());
            response.put("timestamp", new Date());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error starting data acquisition job", e);
            
            response.put("status", "Error starting job");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Run a specific step or steps of the data acquisition process
     *
     * @param steps List of steps to run (statistics, pointers, export, combo)
     * @return Response with execution details
     */
    @PostMapping("/run/steps")
    public ResponseEntity<Map<String, Object>> runSelectedSteps(
            @RequestParam List<String> steps) {
        
        logger.info("Received request to run selected steps: {}", steps);
        
        Map<String, Object> response = new HashMap<>();
        Map<String, Object> results = new HashMap<>();
        boolean allSuccessful = true;
        
        // Validate step names
        List<String> validSteps = new ArrayList<>();
        List<String> invalidSteps = new ArrayList<>();
        
        for (String step : steps) {
            if (Arrays.asList("statistics", "pointers", "export", "combo").contains(step.toLowerCase())) {
                validSteps.add(step.toLowerCase());
            } else {
                invalidSteps.add(step);
            }
        }
        
        if (!invalidSteps.isEmpty()) {
            response.put("status", "Invalid steps requested");
            response.put("invalid_steps", invalidSteps);
            response.put("valid_steps", Arrays.asList("statistics", "pointers", "export", "combo"));
            return ResponseEntity.badRequest().body(response);
        }
        
        // Execute each requested step
        for (String step : validSteps) {
            try {
                boolean stepSuccess = executeStep(step);
                results.put(step, stepSuccess ? "success" : "failure");
                allSuccessful = allSuccessful && stepSuccess;
            } catch (Exception e) {
                logger.error("Error executing step: {}", step, e);
                results.put(step, "error: " + e.getMessage());
                allSuccessful = false;
            }
        }
        
        response.put("status", allSuccessful ? "All steps completed successfully" : "Some steps failed");
        response.put("results", results);
        response.put("timestamp", new Date());
        
        return ResponseEntity.status(allSuccessful ? HttpStatus.OK : HttpStatus.PARTIAL_CONTENT).body(response);
    }
    
    /**
     * Execute a specific step
     * 
     * @param step The step name to execute
     * @return true if the step executed successfully, false otherwise
     */
    private boolean executeStep(String step) {
        switch (step) {
            case "statistics":
                if (!enableStatisticsStep) {
                    logger.warn("Statistics step is disabled in configuration");
                    return false;
                }
                tableStatisticsService.updateTableStatistics();
                return true;
                
            case "pointers":
                if (!enablePointerStep) {
                    logger.warn("Pointer step is disabled in configuration");
                    return false;
                }
                databasePointerManager.updateDatabasePointers();
                return true;
                
            case "export":
                if (!enableExportStep) {
                    logger.warn("Export step is disabled in configuration");
                    return false;
                }
                return exportService.executeExport(null);
                
            case "combo":
                if (!enableComboStep) {
                    logger.warn("Combo file step is disabled in configuration");
                    return false;
                }
                // Assuming ComboFileGenerator has a method similar to the others
                comboFileGenerator.generateComboFiles();
                return true;
                
            default:
                throw new IllegalArgumentException("Unknown step: " + step);
        }
    }
    
    /**
     * Run just the table statistics gathering step
     */
    @PostMapping("/statistics")
    public ResponseEntity<Map<String, Object>> updateTableStatistics() {
        logger.info("Received request to update table statistics");
        
        if (!enableStatisticsStep) {
            Map<String, Object> response = new HashMap<>();
            response.put("status", "Statistics step is disabled in configuration");
            response.put("timestamp", new Date());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(response);
        }
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            tableStatisticsService.updateTableStatistics();
            
            response.put("status", "Table statistics updated successfully");
            response.put("timestamp", new Date());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error updating table statistics", e);
            
            response.put("status", "Error updating table statistics");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Run just the database pointer update step
     * 
     * @param schema Optional schema name to update
     */
    @PostMapping("/pointers")
    public ResponseEntity<Map<String, Object>> updateDatabasePointers(
            @RequestParam(required = false) String schema) {
        
        logger.info("Received request to update database pointers for schema: {}", 
                  schema != null ? schema : "all schemas");
        
        if (!enablePointerStep) {
            Map<String, Object> response = new HashMap<>();
            response.put("status", "Pointer step is disabled in configuration");
            response.put("timestamp", new Date());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(response);
        }
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            int updatedCount;
            if (schema != null) {
                updatedCount = databasePointerManager.updateDatabasePointers(schema);
            } else {
                updatedCount = databasePointerManager.updateDatabasePointers();
            }
            
            response.put("status", "Database pointers updated successfully");
            response.put("updatedCount", updatedCount);
            response.put("timestamp", new Date());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error updating database pointers", e);
            
            response.put("status", "Error updating database pointers");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Validate database pointers
     */
    @GetMapping("/pointers/validate")
    public ResponseEntity<Map<String, Object>> validateDatabasePointers() {
        logger.info("Received request to validate database pointers");
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            List<String> invalidSynonyms = databasePointerManager.validateDatabasePointers();
            
            boolean allValid = invalidSynonyms.isEmpty();
            
            response.put("status", allValid ? "All pointers are valid" : "Some pointers are invalid");
            response.put("valid", allValid);
            
            if (!allValid) {
                response.put("invalidCount", invalidSynonyms.size());
                response.put("invalidSynonyms", invalidSynonyms);
            }
            
            response.put("timestamp", new Date());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error validating database pointers", e);
            
            response.put("status", "Error validating database pointers");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Run just the export step
     * 
     * @param exportFile Optional specific export file to generate
     */
    @PostMapping("/export")
    public ResponseEntity<Map<String, Object>> executeExport(
            @RequestParam(required = false) String exportFile) {
        
        logger.info("Received request to execute export for file: {}", 
                   exportFile != null ? exportFile : "all files");
        
        if (!enableExportStep) {
            Map<String, Object> response = new HashMap<>();
            response.put("status", "Export step is disabled in configuration");
            response.put("timestamp", new Date());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(response);
        }
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            boolean success = exportService.executeExport(exportFile);
            
            if (success) {
                response.put("status", "Export executed successfully");
                response.put("exportFile", exportFile != null ? exportFile : "all configured files");
            } else {
                response.put("status", "Export failed");
                response.put("exportFile", exportFile != null ? exportFile : "all configured files");
            }
            
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(success ? HttpStatus.OK : HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        } catch (Exception e) {
            logger.error("Error executing export", e);
            
            response.put("status", "Error executing export");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Get status of a specific job execution
     * 
     * @param executionId The job execution ID to query
     */
    @GetMapping("/status/{executionId}")
    public ResponseEntity<Map<String, Object>> getJobExecutionStatus(@PathVariable Long executionId) {
        logger.info("Received request for job execution status: {}", executionId);
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            JobExecution jobExecution = jobExplorer.getJobExecution(executionId);
            
            if (jobExecution == null) {
                throw new NoSuchJobExecutionException("No job execution found with ID: " + executionId);
            }
            
            response.put("jobExecutionId", jobExecution.getId());
            response.put("jobName", jobExecution.getJobInstance().getJobName());
            response.put("status", jobExecution.getStatus().toString());
            response.put("startTime", jobExecution.getStartTime());
            response.put("endTime", jobExecution.getEndTime());
            response.put("exitCode", jobExecution.getExitStatus().getExitCode());
            response.put("exitDescription", jobExecution.getExitStatus().getExitDescription());
            
            // Include step execution details
            List<Map<String, Object>> stepExecutions = new ArrayList<>();
            for (org.springframework.batch.core.StepExecution stepExecution : jobExecution.getStepExecutions()) {
                Map<String, Object> stepInfo = new HashMap<>();
                stepInfo.put("stepName", stepExecution.getStepName());
                stepInfo.put("status", stepExecution.getStatus().toString());
                stepInfo.put("readCount", stepExecution.getReadCount());
                stepInfo.put("writeCount", stepExecution.getWriteCount());
                stepInfo.put("filterCount", stepExecution.getFilterCount());
                stepInfo.put("commitCount", stepExecution.getCommitCount());
                stepInfo.put("rollbackCount", stepExecution.getRollbackCount());
                stepInfo.put("startTime", stepExecution.getStartTime());
                stepInfo.put("endTime", stepExecution.getEndTime());
                
                stepExecutions.add(stepInfo);
            }
            
            response.put("stepExecutions", stepExecutions);
            response.put("timestamp", new Date());
            
            return ResponseEntity.ok(response);
        } catch (NoSuchJobExecutionException e) {
            logger.warn("Job execution not found: {}", executionId);
            
            response.put("status", "Job execution not found");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
        } catch (Exception e) {
            logger.error("Error retrieving job execution status", e);
            
            response.put("status", "Error retrieving job status");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Get job history for recent executions
     * 
     * @param from Optional start date filter
     * @param to Optional end date filter
     * @param limit Optional limit for number of results (default from properties)
     */
    @GetMapping("/history")
    public ResponseEntity<Map<String, Object>> getJobHistory(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to,
            @RequestParam(required = false) Integer limit) {
        
        logger.info("Received request for job history from {} to {} with limit {}", from, to, limit);
        
        Map<String, Object> response = new HashMap<>();
        int resultLimit = limit != null ? limit : maxJobHistory;
        
        try {
            List<JobInstance> jobInstances = 
                jobExplorer.findJobInstancesByJobName("dataAcquisitionJob", 0, resultLimit);
            
            List<Map<String, Object>> jobExecutions = new ArrayList<>();
            
            for (JobInstance jobInstance : jobInstances) {
                List<JobExecution> executions = jobExplorer.getJobExecutions(jobInstance);
                
                for (JobExecution execution : executions) {
                    // Apply date filters if provided
                    if (from != null && execution.getStartTime() != null) {
                        Date startDate = execution.getStartTime();
                        if (startDate.toInstant().isBefore(from.toInstant(java.time.ZoneOffset.UTC))) {
                            continue;
                        }
                    }
                    
                    if (to != null && execution.getStartTime() != null) {
                        Date startDate = execution.getStartTime();
                        if (startDate.toInstant().isAfter(to.toInstant(java.time.ZoneOffset.UTC))) {
                            continue;
                        }
                    }
                    
                    Map<String, Object> executionInfo = new HashMap<>();
                    executionInfo.put("jobExecutionId", execution.getId());
                    executionInfo.put("jobInstanceId", jobInstance.getId());
                    executionInfo.put("jobName", jobInstance.getJobName());
                    executionInfo.put("status", execution.getStatus().toString());
                    executionInfo.put("startTime", execution.getStartTime());
                    executionInfo.put("endTime", execution.getEndTime());
                    executionInfo.put("exitCode", execution.getExitStatus().getExitCode());
                    
                    // Add step status summary
                    Map<String, String> stepStatuses = execution.getStepExecutions().stream()
                        .collect(Collectors.toMap(
                            se -> se.getStepName(),
                            se -> se.getStatus().toString()
                        ));
                    
                    executionInfo.put("steps", stepStatuses);
                    jobExecutions.add(executionInfo);
                }
            }
            
            // Sort by start time, most recent first
            jobExecutions.sort((e1, e2) -> {
                Date d1 = (Date)e1.get("startTime");
                Date d2 = (Date)e2.get("startTime");
                if (d1 == null) return 1;
                if (d2 == null) return -1;
                return d2.compareTo(d1);
            });
            
            // Apply limit after sorting
            if (jobExecutions.size() > resultLimit) {
                jobExecutions = jobExecutions.subList(0, resultLimit);
            }
            
            response.put("status", "Job history query successful");
            response.put("count", jobExecutions.size());
            response.put("limit", resultLimit);
            response.put("jobs", jobExecutions);
            response.put("timestamp", new Date());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error retrieving job history", e);
            
            response.put("status", "Error retrieving job history");
            response.put("error", e.getMessage());
            response.put("timestamp", new Date());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    /**
     * Get current configuration status for data acquisition jobs
     */
    @GetMapping("/config")
    public ResponseEntity<Map<String, Object>> getConfiguration() {
        logger.info("Received request for job configuration");
        
        Map<String, Object> response = new HashMap<>();
        Map<String, Object> config = new HashMap<>();
        
        config.put("statistics.enabled", enableStatisticsStep);
        config.put("pointer.enabled", enablePointerStep);
        config.put("export.enabled", enableExportStep);
        config.put("combo.enabled", enableComboStep);
        
        response.put("status", "Configuration query successful");
        response.put("configuration", config);
        response.put("timestamp", new Date());
        
        return ResponseEntity.ok(response);
    }
}