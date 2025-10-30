package com.abc.ics.model;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.Singular;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Response model for job status queries
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class JobStatusResponse {
    
    private Long executionId;
    private String jobName;
    private String status;
    private String exitCode;
    private String exitMessage;
    private String message;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private Long durationSeconds;
    private Boolean running;
    
    @Singular
    private Map<String, String> stepStatuses;
}
