package com.abc.ics.model;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Response model for job execution requests
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class JobExecutionResponse {
    
    private Boolean success;
    private Long executionId;
    private String jobName;
    private String status;
    private String message;
    private LocalDateTime startTime;
}
