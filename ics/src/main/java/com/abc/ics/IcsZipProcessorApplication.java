package com.abc.ics;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * Main Spring Boot Application for ICS Zip Code Processing
 * 
 * This application processes ICS zip code assignment data from mainframe files
 * and loads them into Oracle database tables (oldzips -> icszips).
 * 
 * Original shell script: ent_zip.csh
 * 
 * @author Generated from ent_zip.csh shell script
 * @version 1.0.0
 */
@SpringBootApplication
@EnableAsync
public class IcsZipProcessorApplication {

    public static void main(String[] args) {
        SpringApplication.run(IcsZipProcessorApplication.class, args);
    }
}
