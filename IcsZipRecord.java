package com.abc.ics.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Model class representing an ICS Zip Code record
 * Maps to the OLDZIPS database table structure
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IcsZipRecord {

    /**
     * Zip code (5 digits)
     * Database: DIZIPCD - NUMBER(5)
     * File position: Field 2 (e.g., "00501")
     */
    private Integer dizipcd;

    /**
     * Area/DO code (2 digits)
     * Database: DIDOCD - NUMBER(2)
     * File position: Field 1 (e.g., "21")
     * Valid values: 21-27, 35
     */
    private Integer didocd;

    /**
     * GS Level (2 digits)
     * Database: GSLVL - NUMBER(2)
     * File position: Field 3 (e.g., "11", "12", "13")
     */
    private Integer gslvl;

    /**
     * Employee ID (8 digits)
     * Database: ROEMPID - NUMBER(8)
     * File position: Field 4 (e.g., "21061614")
     */
    private Integer roempid;

    /**
     * Alpha beginning character
     * Database: ALPHABEG - CHAR(1)
     * File position: Field 5 (e.g., "A", "N")
     */
    private String alphabeg;

    /**
     * Alpha ending character
     * Database: ALPHAEND - CHAR(1)
     * File position: Field 6 (e.g., "Z", "M")
     */
    private String alphaend;

    /**
     * BOD code (2 characters)
     * Database: BODCD - VARCHAR2(2)
     * File position: Field 7 (e.g., "XX")
     */
    private String bodcd;

    /**
     * BOD class code (3 characters)
     * Database: BODCLCD - VARCHAR2(3)
     * File position: Field 8 (e.g., "XXX")
     */
    private String bodclcd;

    /**
     * ACSO indicator (1 digit)
     * Database: ACSOIND - NUMBER(1)
     * File position: Field 9 (e.g., "0")
     */
    private Integer acsoind;

    /**
     * Returns a string representation of the record for logging
     */
    @Override
    public String toString() {
        return String.format("IcsZipRecord[didocd=%d, dizipcd=%05d, gslvl=%d, roempid=%d, " +
                "alphabeg=%s, alphaend=%s, bodcd=%s, bodclcd=%s, acsoind=%d]",
                didocd, dizipcd, gslvl, roempid, alphabeg, alphaend, bodcd, bodclcd, acsoind);
    }

    /**
     * Validates if the record has all required fields populated
     * 
     * @return true if all required fields are present
     */
    public boolean isValid() {
        return dizipcd != null && dizipcd > 0 &&
               didocd != null && didocd > 0 &&
               gslvl != null && gslvl > 0 &&
               roempid != null && roempid > 0 &&
               alphabeg != null && !alphabeg.trim().isEmpty() &&
               alphaend != null && !alphaend.trim().isEmpty() &&
               bodcd != null && !bodcd.trim().isEmpty() &&
               bodclcd != null && !bodclcd.trim().isEmpty() &&
               acsoind != null;
    }

    /**
     * Creates a record from pipe-delimited string
     * Format: didocd|dizipcd|gslvl|roempid|alphabeg|alphaend|bodcd|bodclcd|acsoind|
     * Example: 21|00501|11|21061614|A|Z|XX|XXX|0|
     * 
     * @param line Pipe-delimited line
     * @return IcsZipRecord or null if parsing fails
     */
    public static IcsZipRecord fromPipeDelimitedString(String line) {
        if (line == null || line.trim().isEmpty()) {
            return null;
        }

        try {
            String[] fields = line.split("\\|", -1);
            
            if (fields.length < 9) {
                return null;
            }

            return IcsZipRecord.builder()
                    .didocd(Integer.parseInt(fields[0].trim()))
                    .dizipcd(Integer.parseInt(fields[1].trim()))
                    .gslvl(Integer.parseInt(fields[2].trim()))
                    .roempid(Integer.parseInt(fields[3].trim()))
                    .alphabeg(fields[4].trim())
                    .alphaend(fields[5].trim())
                    .bodcd(fields[6].trim())
                    .bodclcd(fields[7].trim())
                    .acsoind(Integer.parseInt(fields[8].trim()))
                    .build();
                    
        } catch (NumberFormatException | ArrayIndexOutOfBoundsException e) {
            return null;
        }
    }

    /**
     * Converts record to pipe-delimited string
     * 
     * @return Pipe-delimited string representation
     */
    public String toPipeDelimitedString() {
        return String.format("%d|%05d|%02d|%08d|%s|%s|%s|%s|%d|",
                didocd, dizipcd, gslvl, roempid, alphabeg, alphaend, bodcd, bodclcd, acsoind);
    }
}
