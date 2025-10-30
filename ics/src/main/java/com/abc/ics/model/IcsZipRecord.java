package com.abc.ics.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Domain model representing an ICS Zip code assignment record
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IcsZipRecord {
    
    /**
     * Area code (didocd) - one of: 21, 22, 23, 24, 25, 26, 27, 35
     */
    private String areaCode;
    
    /**
     * Zip code
     */
    private String zipCode;
    
    /**
     * Raw line from the file for bad record tracking
     */
    private String rawLine;
    
    /**
     * Line number in the file
     */
    private Long lineNumber;
    
    /**
     * Additional fields can be added based on actual data structure
     * This is a placeholder - adjust based on your actual icszip.dat structure
     */
    private String additionalData;
}
