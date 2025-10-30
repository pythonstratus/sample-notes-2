package com.abc.ics.controller;

import com.abc.ics.model.JobExecutionResponse;
import com.abc.ics.model.JobStatusResponse;
import com.abc.ics.service.JobManagementService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * REST Controller for ICS Zip Processing Job Management
 * 
 * Provides endpoints to:
 * - Trigger the job
 * - Check job status
 * - Get job history
 */
@RestController
@RequestMapping("/api/ics-zip")
@Slf4j
@RequiredArgsConstructor
public class IcsZipController {

    private final JobManagementService jobManagementService;

    /**
     * Trigger ICS Zip processing job
     * 
     * POST /api/ics-zip/trigger
     * 
     * @return Job execution details
     */
    @PostMapping("/trigger")
    public ResponseEntity<JobExecutionResponse> triggerJob() {
        log.info("Received request to trigger ICS Zip processing job");
        
        try {
            JobExecutionResponse response = jobManagementService.triggerJob();
            log.info("Job triggered successfully with execution ID: {}", response.getExecutionId());
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to trigger job", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(JobExecutionResponse.builder()
                            .success(false)
                            .message("Failed to trigger job: " + e.getMessage())
                            .build());
        }
    }

    /**
     * Get job execution status
     * 
     * GET /api/ics-zip/status/{executionId}
     * 
     * @param executionId Job execution ID
     * @return Job status details
     */
    @GetMapping("/status/{executionId}")
    public ResponseEntity<JobStatusResponse> getJobStatus(@PathVariable Long executionId) {
        log.info("Received request to check status for execution ID: {}", executionId);
        
        try {
            JobStatusResponse response = jobManagementService.getJobStatus(executionId);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to get job status", e);
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(JobStatusResponse.builder()
                            .executionId(executionId)
                            .status("NOT_FOUND")
                            .message("Job execution not found: " + e.getMessage())
                            .build());
        }
    }

    /**
     * Get latest job execution status
     * 
     * GET /api/ics-zip/status/latest
     * 
     * @return Latest job status details
     */
    @GetMapping("/status/latest")
    public ResponseEntity<JobStatusResponse> getLatestJobStatus() {
        log.info("Received request to check latest job status");
        
        try {
            JobStatusResponse response = jobManagementService.getLatestJobStatus();
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to get latest job status", e);
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(JobStatusResponse.builder()
                            .status("NOT_FOUND")
                            .message("No job executions found")
                            .build());
        }
    }

    /**
     * Health check endpoint
     * 
     * GET /api/ics-zip/health
     * 
     * @return Health status
     */
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("ICS Zip Processor is running");
    }
}
