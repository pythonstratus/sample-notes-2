package com.abc.ics.service;

import com.abc.ics.config.IcsZipConfigProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.env.Environment;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * Service for sending email notifications
 * Equivalent to mailx commands in the shell script
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender mailSender;
    private final IcsZipConfigProperties config;
    private final Environment environment;
    private final FileService fileService;

    /**
     * Sends email notification
     * Equivalent to: mailx -s "subject" email@abc.com < $ERRFILE
     * 
     * @param subject Email subject
     * @param body Email body
     */
    public void sendEmail(String subject, String body) {
        if (!config.getEmail().getEnabled()) {
            log.info("Email notifications are disabled. Would have sent: {}", subject);
            return;
        }

        try {
            List<String> recipients = getRecipients();
            
            if (recipients == null || recipients.isEmpty()) {
                log.warn("No email recipients configured for current profile");
                return;
            }

            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(config.getEmail().getFrom());
            message.setTo(recipients.toArray(new String[0]));
            message.setSubject(config.getEmail().getSubjectPrefix() + " " + subject);
            message.setText(body);

            mailSender.send(message);
            
            log.info("Email sent successfully to {} recipients: {}", recipients.size(), subject);
            
        } catch (Exception e) {
            log.error("Failed to send email: {}", subject, e);
            // Don't throw exception - email failure shouldn't stop the process
        }
    }

    /**
     * Sends email with error file content
     * 
     * @param subject Email subject
     * @param errorFilePath Path to error file
     */
    public void sendEmailWithErrorFile(String subject, Path errorFilePath) {
        try {
            String body = Files.readString(errorFilePath);
            sendEmail(subject, body);
        } catch (IOException e) {
            log.error("Failed to read error file for email", e);
            sendEmail(subject, "Error occurred but could not read error file.");
        }
    }

    /**
     * Sends file copy error notification
     * Equivalent to shell script email when file copy fails
     */
    public void sendFileCopyErrorNotification() {
        String subject = "ent_zip.csh:PROBLEM COPYING TO icszip.dat";
        String body = String.format("Error occurred while copying icszip file at %s\n\n" +
                "Please check the error log for details.",
                fileService.getCurrentDateTime());
        
        sendEmail(subject, body);
    }

    /**
     * Sends multiple files error notification
     * Equivalent to shell script email when more than one file is found
     * 
     * @param fileCount Number of files found
     */
    public void sendMultipleFilesErrorNotification(int fileCount) {
        String subject = "ent_zip.csh:more than one icszip";
        String body = String.format("ERROR: %s more than one icszip.YYYYMMDD.dat\n\n" +
                "Found %d files when expecting exactly one.\n" +
                "Please investigate and remove duplicate files.",
                fileService.getCurrentDateTime(), fileCount);
        
        sendEmail(subject, body);
    }

    /**
     * Sends file not transferred notification
     * Equivalent to shell script email when no file is found
     */
    public void sendFileNotTransferredNotification() {
        String subject = "ent_zip.csh:icszip not transferred";
        String body = String.format("ERROR: %s icszip.YYYYMMDD.dat not transferred.\n\n" +
                "No input file was found for processing.\n" +
                "Please check the file transfer process.",
                fileService.getCurrentDateTime());
        
        sendEmail(subject, body);
    }

    /**
     * Sends job completion status notification
     * 
     * @param success Whether job completed successfully
     * @param errorLogPath Path to error log
     */
    public void sendJobStatusNotification(boolean success, Path errorLogPath) {
        String subject = success ? "ent_zip.csh status" : "ent_zip.csh:icszip not transferred";
        
        if (errorLogPath != null && Files.exists(errorLogPath)) {
            try {
                long fileSize = Files.size(errorLogPath);
                if (fileSize > 0) {
                    // Error file has content, send it
                    sendEmailWithErrorFile(subject, errorLogPath);
                    return;
                }
            } catch (IOException e) {
                log.warn("Could not check error log file size", e);
            }
        }
        
        if (!success) {
            String body = String.format("ICS Zip processing completed with errors at %s\n\n" +
                    "Please check the application logs for details.",
                    fileService.getCurrentDateTime());
            sendEmail(subject, body);
        } else {
            log.info("Job completed successfully. No error notifications to send.");
        }
    }

    /**
     * Gets the list of email recipients based on active profile
     * Maps to environment-specific email logic in shell script
     * 
     * @return List of email recipients
     */
    private List<String> getRecipients() {
        // Get active profile (dev, test, prod)
        String[] activeProfiles = environment.getActiveProfiles();
        String profile = activeProfiles.length > 0 ? activeProfiles[0] : "default";
        
        log.debug("Getting email recipients for profile: {}", profile);
        
        return config.getEmail().getRecipients().get("default");
    }

    /**
     * Gets system hostname for environment detection
     * Equivalent to: set SYSTEM = `/usr/bin/uname -n`
     * 
     * Note: In containerized environments, this returns container hostname
     * Use Spring profiles instead for environment detection
     * 
     * @return System hostname
     */
    public String getSystemHostname() {
        try {
            return java.net.InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            log.warn("Could not get system hostname", e);
            return "unknown";
        }
    }
}
