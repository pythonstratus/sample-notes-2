package com.abc.sbse.os.ts.csp.alsentity.ale.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

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
     * Save a log entry to the LOGLOAD table
     * 
     * @param jobCode LOADNAME - The job code (e.g., E5, E3, etc.)
     * @param extractDate EXTRDT - The extract date
     * @param recordCount NUMREC - Number of records processed
     */
    public void saveLogLoad(String jobCode, String extractDate, int recordCount) {
        // Format current date as MMddyyyy for LOADDT
        LocalDate currentDate = LocalDate.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MMddyyyy");
        String loadDate = currentDate.format(formatter);
        
        // Get current username for UNIX field
        String username = System.getProperty("user.name");
        if (username == null || username.isEmpty()) {
            username = "SYSTEM";
        }
        
        // Use the repository to save the log
        logLoadRepository.saveLogEntry(jobCode, extractDate, loadDate, username, recordCount);
    }
}
