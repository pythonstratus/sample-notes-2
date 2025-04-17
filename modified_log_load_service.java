package com.abc.sbse.os.ts.csp.alsentity.ale.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.abc.sbse.os.ts.csp.alsentity.ale.model.LogLoad;
import com.abc.sbse.os.ts.csp.alsentity.ale.repository.LogLoadRepository;

/**
 * Service for handling LogLoad operations
 */
@Service
public class LogLoadService {
    
    private final LogLoadRepository logLoadRepository;
    
    @Autowired
    public LogLoadService(LogLoadRepository logLoadRepository) {
        this.logLoadRepository = logLoadRepository;
    }
    
    public LocalDate getMaxExtrDtByLoadname(String loadname) {
        return logLoadRepository.findMaxExtrDtByLoadname(loadname);
    }
    
    public String getHoliday(String today) {
        return logLoadRepository.findHoliday(today);
    }
    
    public void processHoliday(String holiday) {
        logLoadRepository.processHoliday(holiday);
    }
    
    public void prepareLogload(String today) {
        logLoadRepository.prepareLogload(today);
    }
    
    public String getPrevE3() {
        return logLoadRepository.getPrevE3();
    }
    
    /**
     * Save a log entry to the LOGLOAD table using the existing insertLogLoad method
     * 
     * @param jobCode LOADNAME - The job code (e.g., E5, E3, etc.)
     * @param extractDate EXTRDT - The extract date
     * @param recordCount NUMREC - Number of records processed
     */
    public void saveLogLoad(String jobCode, String extractDate, int recordCount) {
        try {
            // Create a new LogLoad object
            LogLoad logLoad = new LogLoad();
            logLoad.setLoadName(jobCode);
            logLoad.setExtractDate(extractDate);
            
            // Format current date as MMddyyyy for LOADDT
            LocalDate currentDate = LocalDate.now();
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MMddyyyy");
            String loadDate = currentDate.format(formatter);
            logLoad.setLoadDate(loadDate);
            
            // Get current username for UNIX field
            String username = System.getProperty("user.name");
            if (username == null || username.isEmpty()) {
                username = "SYSTEM";
            }
            logLoad.setUnixUsrId(username);
            
            // Set record count
            logLoad.setRecordCount(recordCount);
            
            // Use the existing insertLogLoad method
            logLoadRepository.insertLogLoad(logLoad);
            
        } catch (Exception e) {
            // Log the error but don't rethrow to prevent job execution from failing
            System.err.println("Error saving log entry: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
