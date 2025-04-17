package gov.irs.sbse.os.ts.csp.alsentity.ale.service;

import gov.irs.sbse.os.ts.csp.alsentity.ale.model.LogLoad;
import gov.irs.sbse.os.ts.csp.alsentity.ale.repository.LogLoadRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.logging.Logger;

/**
 * Service for handling operations related to the LOGLOAD table
 */
@Service
public class LogLoadService {

    private static final Logger log = Logger.getLogger(LogLoadService.class.getName());

    @Autowired
    private LogLoadRepository logLoadRepository;

    /**
     * Save a log entry to the LOGLOAD table
     * 
     * @param jobCode LOADNAME - The job code (e.g., E5, E3, etc.)
     * @param extractDate EXTRDT - The extract date
     * @param recordCount NUMREC - Number of records processed
     */
    public void saveLogLoad(String jobCode, String extractDate, int recordCount) {
        try {
            LogLoad logLoad = new LogLoad();
            logLoad.setLoadName(jobCode);
            logLoad.setExtrDt(extractDate);
            
            // Current date formatted as MMddyyyy for LOADDT
            LocalDate currentDate = LocalDate.now();
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MMddyyyy");
            String loadDate = currentDate.format(formatter);
            logLoad.setLoadDt(loadDate);
            
            // Get current username for UNIX field
            String username = System.getProperty("user.name");
            if (username == null || username.isEmpty()) {
                username = "SYSTEM";
            }
            logLoad.setUnix(username);
            
            // Set record count
            logLoad.setNumRec(recordCount);
            
            // Save to database
            logLoadRepository.save(logLoad);
            log.info("Successfully logged job " + jobCode + " with " + recordCount + " records");
        } catch (Exception e) {
            log.severe("Error saving to LOGLOAD table: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
