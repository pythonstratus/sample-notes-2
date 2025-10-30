package com.abc.ics.service;

import com.abc.ics.model.JobExecutionResponse;
import com.abc.ics.model.JobStatusResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.*;
import org.springframework.batch.core.explore.JobExplorer;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.batch.core.repository.JobExecutionAlreadyRunningException;
import org.springframework.batch.core.repository.JobInstanceAlreadyCompleteException;
import org.springframework.batch.core.repository.JobRestartException;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.List;

/**
 * Service for managing Spring Batch jobs
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class JobManagementService {

    private final JobLauncher jobLauncher;
    private final Job icsZipProcessingJob;
    private final JobExplorer jobExplorer;

    /**
     * Triggers the ICS Zip processing job
     * 
     * @return Job execution response
     */
    public JobExecutionResponse triggerJob() {
        try {
            // Create job parameters with current timestamp to make each execution unique
            JobParameters jobParameters = new JobParametersBuilder()
                    .addDate("runDate", new Date())
                    .addString("triggeredBy", "REST_API")
                    .toJobParameters();

            log.info("Starting ICS Zip processing job with parameters: {}", jobParameters);
            
            JobExecution execution = jobLauncher.run(icsZipProcessingJob, jobParameters);
            
            return JobExecutionResponse.builder()
                    .success(true)
                    .executionId(execution.getId())
                    .jobName(execution.getJobInstance().getJobName())
                    .status(execution.getStatus().toString())
                    .message("Job triggered successfully")
                    .startTime(toLocalDateTime(execution.getStartTime()))
                    .build();
            
        } catch (JobExecutionAlreadyRunningException e) {
            log.warn("Job is already running", e);
            return JobExecutionResponse.builder()
                    .success(false)
                    .message("Job is already running")
                    .build();
                    
        } catch (JobRestartException e) {
            log.error("Job restart failed", e);
            return JobExecutionResponse.builder()
                    .success(false)
                    .message("Job restart failed: " + e.getMessage())
                    .build();
                    
        } catch (JobInstanceAlreadyCompleteException e) {
            log.warn("Job instance already complete", e);
            return JobExecutionResponse.builder()
                    .success(false)
                    .message("Job instance already complete")
                    .build();
                    
        } catch (JobParametersInvalidException e) {
            log.error("Invalid job parameters", e);
            return JobExecutionResponse.builder()
                    .success(false)
                    .message("Invalid job parameters: " + e.getMessage())
                    .build();
        }
    }

    /**
     * Gets job execution status
     * 
     * @param executionId Job execution ID
     * @return Job status response
     */
    public JobStatusResponse getJobStatus(Long executionId) {
        JobExecution execution = jobExplorer.getJobExecution(executionId);
        
        if (execution == null) {
            throw new IllegalArgumentException("Job execution not found: " + executionId);
        }
        
        return buildJobStatusResponse(execution);
    }

    /**
     * Gets latest job execution status
     * 
     * @return Latest job status response
     */
    public JobStatusResponse getLatestJobStatus() {
        List<String> jobNames = jobExplorer.getJobNames();
        
        if (jobNames.isEmpty()) {
            throw new IllegalStateException("No jobs found");
        }
        
        String jobName = "icsZipProcessingJob";
        List<JobInstance> jobInstances = jobExplorer.getJobInstances(jobName, 0, 1);
        
        if (jobInstances.isEmpty()) {
            throw new IllegalStateException("No job instances found for: " + jobName);
        }
        
        JobInstance latestInstance = jobInstances.get(0);
        List<JobExecution> executions = jobExplorer.getJobExecutions(latestInstance);
        
        if (executions.isEmpty()) {
            throw new IllegalStateException("No job executions found");
        }
        
        // Get the latest execution
        JobExecution latestExecution = executions.stream()
                .max((e1, e2) -> e1.getStartTime().compareTo(e2.getStartTime()))
                .orElseThrow(() -> new IllegalStateException("Could not find latest execution"));
        
        return buildJobStatusResponse(latestExecution);
    }

    /**
     * Builds job status response from job execution
     * 
     * @param execution Job execution
     * @return Job status response
     */
    private JobStatusResponse buildJobStatusResponse(JobExecution execution) {
        JobStatusResponse.JobStatusResponseBuilder builder = JobStatusResponse.builder()
                .executionId(execution.getId())
                .jobName(execution.getJobInstance().getJobName())
                .status(execution.getStatus().toString())
                .exitCode(execution.getExitStatus().getExitCode())
                .exitMessage(execution.getExitStatus().getExitDescription())
                .startTime(toLocalDateTime(execution.getStartTime()))
                .endTime(toLocalDateTime(execution.getEndTime()));
        
        // Add step information
        execution.getStepExecutions().forEach(stepExecution -> {
            builder.stepStatus(stepExecution.getStepName(), 
                    stepExecution.getStatus().toString());
        });
        
        // Calculate duration if job has completed
        if (execution.getEndTime() != null && execution.getStartTime() != null) {
            long durationMillis = execution.getEndTime().getTime() - execution.getStartTime().getTime();
            builder.durationSeconds(durationMillis / 1000);
        }
        
        // Check if job is still running
        builder.running(execution.isRunning());
        
        return builder.build();
    }

    /**
     * Converts Date to LocalDateTime
     * 
     * @param date Date to convert
     * @return LocalDateTime
     */
    private LocalDateTime toLocalDateTime(Date date) {
        if (date == null) {
            return null;
        }
        return date.toInstant()
                .atZone(ZoneId.systemDefault())
                .toLocalDateTime();
    }
}
