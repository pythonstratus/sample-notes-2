package com.abc.ics.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.Map;

/**
 * Configuration properties for ICS Zip Processing application
 * Maps to 'ics-zip' prefix in application.yml
 */
@Configuration
@ConfigurationProperties(prefix = "ics-zip")
@Data
@Validated
public class IcsZipConfigProperties {

    @NotNull
    private FileConfig file;

    @NotNull
    private LogConfig log;

    @NotNull
    private SqlConfig sql;

    @NotNull
    private ProcessingConfig processing;

    @NotNull
    private EmailConfig email;

    @Data
    public static class FileConfig {
        @NotEmpty
        private String inputDirectory;
        
        @NotEmpty
        private String inputFilePattern;
        
        @NotEmpty
        private String workingFileName;
        
        @NotEmpty
        private String archiveDirectory;
    }

    @Data
    public static class LogConfig {
        @NotEmpty
        private String directory;
        
        @NotEmpty
        private String mainLogFile;
        
        @NotEmpty
        private String errorLogFile;
        
        @NotEmpty
        private String deleteLogFile;
    }

    @Data
    public static class SqlConfig {
        @NotEmpty
        private String scriptDirectory;
        
        @NotEmpty
        private String crzipsScriptName;
    }

    @Data
    public static class ProcessingConfig {
        @NotEmpty
        private List<Integer> areas;
        
        @NotNull
        private Integer batchSize;
        
        @NotNull
        private Integer chunkSize;
    }

    @Data
    public static class EmailConfig {
        @NotEmpty
        private String from;
        
        @NotEmpty
        private String subjectPrefix;
        
        @NotNull
        private Boolean enabled;
        
        private Map<String, List<String>> recipients;
    }
}
