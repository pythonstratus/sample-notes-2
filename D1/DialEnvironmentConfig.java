package com.dial.core.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;

/**
 * Configuration class that replaces the DIAL.path shell script.
 * Loads environment variables and paths needed for DIAL application.
 */
@Configuration
public class DialEnvironmentConfig {
    private static final Logger logger = LoggerFactory.getLogger(DialEnvironmentConfig.class);

    @Value("${dial.als.base.dir:/als-ALS/app}")
    private String alsBaseDir;

    @Value("${dial.oracle.home:/opt/app/oracle/product/19.0.0/db_3}")
    private String oracleHome;

    @Value("${dial.oracle.sid:ALS}")
    private String oracleSid;

    @Value("${dial.oracle.term:xterm}")
    private String oracleTerm;

    @Value("${dial.path.backup.enabled:true}")
    private boolean backupEnabled;

    @Value("${dial.file.processing.areas:11,12,13,14,15,21,22,23,24,25,26,27,35}")
    private String processingAreasString;

    /**
     * Initialize environment configuration
     */
    @Bean
    public Map<String, String> dialEnvironment(Environment springEnv) {
        Map<String, String> env = new HashMap<>();
        
        // Set path variables
        String path = System.getenv("PATH");
        env.put("PATH", String.format("%s:%s/bin:%s/execlocd.common:%s/execlocd.dial:%s/openwinin/bin", 
            path, oracleHome, alsBaseDir, alsBaseDir, alsBaseDir));
        
        // Oracle config
        env.put("ORACLE_HOME", oracleHome);
        env.put("ORACLE_TERM", oracleTerm);
        env.put("ORACLE_SID", oracleSid);
        env.put("TNS_ADMIN", alsBaseDir + "/execlocd.common/TNSDIR");
        env.put("LD_LIBRARY_PATH", oracleHome + "/lib");
        env.put("LD_LIBRARY_PATH_64", oracleHome + "/lib");
        
        // DIAL specific directories
        env.put("TERMINFO", alsBaseDir + "/execlocd.common/TERMINFO");
        env.put("TERMCAP", alsBaseDir + "/execlocd.common/TERMINFO/alscap");
        env.put("LOCALPRT", "YES");
        env.put("VERSION", "ALS_9.0");
        env.put("EXECLOC", alsBaseDir + "/execlocd.dial");
        env.put("DIAL", alsBaseDir + "/execlocd.dial");
        env.put("LOADSTAGE", alsBaseDir + "/loadstage");
        env.put("EPC_DISABLED", "TRUE");
        env.put("ALSDIR", alsBaseDir + "/app");
        
        // Processing paths
        env.put("AREADIR", alsBaseDir + "/loadstage/AREADIR");
        env.put("CONSOLDIR", alsBaseDir + "/loadstage/CONSOLDIR");
        env.put("DIALRAW", alsBaseDir + "/rawfiles/DIAL.raw");
        env.put("EXP_DIR", alsBaseDir + "/rawfiles/EXP_DIR");
        env.put("RAW_DIR", alsBaseDir + "/rawfiles/NEWDIAL.raw");
        env.put("RAW_BKUP", alsBaseDir + "/rawfiles/OLDDIAL.raw");
        env.put("XFILES", alsBaseDir + "/rawfiles/XFILES_DIR");
        
        // Set up TDA and TDI file settings
        env.put("TCC_TDAS", "TDA.11 TDA.12 TDA.13 TDA.14 TDA.15 TDA.21 TDA.22 TDA.23 TDA.24 TDA.25 TDA.26 TDA.27 TDA.35");
        env.put("TCC_TDIS", "tdi.11 tdi.12 tdi.13 tdi.14 tdi.15 tdi.21 tdi.22 tdi.23 tdi.24 tdi.25 tdi.26 tdi.27 tdi.35");
        
        // Create directories if needed
        createRequiredDirectories(env);
        
        logger.info("DIAL environment initialized");
        return env;
    }
    
    /**
     * Creates all required directories if they don't exist
     */
    private void createRequiredDirectories(Map<String, String> env) {
        // Create directories for paths in environment that should exist
        String[] requiredDirs = {
            "AREADIR", "CONSOLDIR", "EXP_DIR", "RAW_DIR", "RAW_BKUP", "XFILES", "LOADSTAGE", "DIAL"
        };
        
        for (String dirKey : requiredDirs) {
            String dirPath = env.get(dirKey);
            if (dirPath != null) {
                File dir = new File(dirPath);
                if (!dir.exists()) {
                    logger.info("Creating directory: {}", dirPath);
                    if (!dir.mkdirs()) {
                        logger.warn("Failed to create directory: {}", dirPath);
                    }
                }
            }
        }
    }
    
    /**
     * Returns the database password path
     */
    @Bean
    public Path dialDatabasePasswordFile() {
        return Paths.get(alsBaseDir, "execlocd.common/DecipherIt", "dial");
    }
    
    /**
     * Returns the ALS database password path
     */
    @Bean
    public Path alsDatabasePasswordFile() {
        return Paths.get(alsBaseDir, "execlocd.common/DecipherIt", "als");
    }
    
    /**
     * Returns the processing areas as an array
     */
    @Bean
    public String[] processingAreas() {
        return processingAreasString.split(",");
    }
    
    /**
     * Indicates whether backup of files is enabled
     */
    @Bean
    public boolean isBackupEnabled() {
        return backupEnabled;
    }
}