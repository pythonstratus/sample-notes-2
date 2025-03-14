package com.abc.sbse.os.ts.csp.alsentity.ale.mapper;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

import org.springframework.batch.item.file.mapping.FieldSetMapper;
import org.springframework.batch.item.file.transform.FieldSet;
import org.springframework.validation.BindException;

import com.abc.sbse.os.ts.csp.alsentity.ale.data.EARecord;

import lombok.extern.slf4j.Slf4j;

/**
 * Maps data from the fixed-length file to EARecord objects
 * Handles data type conversions and default values according to load file CTL
 */
@Slf4j
public class EARecordFieldSetMapper implements FieldSetMapper<EARecord> {

    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final String DEFAULT_DATE = "19000101";

    @Override
    public EARecord mapFieldSet(FieldSet fieldSet) throws BindException {
        EARecord record = new EARecord();
        
        try {
            // Map String fields directly
            record.setOutputCd(fieldSet.readString("OUTPUTCD"));
            record.setInvItemCtrlId(fieldSet.readString("INVITEMCTRLID"));
            record.setAsgmntNum(fieldSet.readString("ASGMNTNUM"));
            record.setModTypeInd(fieldSet.readString("MODTYPEIND"));
            record.setIcsClosingCd(fieldSet.readString("ICSCLOSINGCD"));
            record.setTdiCloseCd(fieldSet.readString("TDICLOSECD"));
            record.setClosingTranScd(fieldSet.readString("CLOSINGTRANSCD"));
            record.setModDispCd(fieldSet.readString("MODDISPCD"));
            record.setIcsStatusCd(fieldSet.readString("ICSSTATUSCD"));
            
            // Map BigDecimal fields with null handling
            mapBigDecimalField(fieldSet, "TIN", record::setTin);
            mapBigDecimalField(fieldSet, "FILESOURCECD", record::setFileSourceCd);
            mapBigDecimalField(fieldSet, "TINTYPE", record::setTinType);
            
            // Special handling for MFTCD as per CTL file
            String mftCdStr = fieldSet.readString("MFTCD");
            if (mftCdStr != null && !mftCdStr.trim().isEmpty()) {
                // Apply NVL logic from the CTL file for MFTCD
                if ("0".equals(mftCdStr.trim())) {
                    record.setMftCd(null);
                } else {
                    record.setMftCd(new BigDecimal(mftCdStr.trim()));
                }
            }
            
            // Map date fields with specialized handling for TAXPRD
            mapDateField(fieldSet, "EXTRACTDT", record::setExtractDt, true);
            
            // Special handling for TAXPRD as per CTL file
            String taxPrdStr = fieldSet.readString("TAXPRD");
            if (taxPrdStr != null && !taxPrdStr.trim().isEmpty()) {
                try {
                    // Apply REPLACE logic from CTL for month and year parts
                    String yearPart = taxPrdStr.substring(0, 4);
                    String monthPart = taxPrdStr.substring(4, 6);
                    String dayPart = taxPrdStr.substring(6);
                    
                    // Replace as per CTL file
                    if (yearPart.equals("0000")) yearPart = "1900";
                    if (monthPart.equals("00")) monthPart = "01";
                    
                    String formattedDate = yearPart + monthPart + dayPart;
                    record.setTaxPrd(LocalDate.parse(formattedDate, DATE_FORMAT));
                } catch (Exception e) {
                    log.warn("Error parsing TAXPRD: {}", e.getMessage());
                }
            }
            
            // Map other date fields with default date replacement
            mapDateField(fieldSet, "TAXMODASSNDT", record::setTaxModAssnDt, true);
            mapDateField(fieldSet, "ROCLOSEDDT", record::setRoClosedDt, true);
            
            // Action-related fields - will be set later in processing
            record.setStatus("O"); // Default status, will be updated based on ACTIONCD
            
        } catch (Exception e) {
            log.error("Error mapping field set to EARecord: {}", e.getMessage(), e);
            throw new BindException(record, "EARecord");
        }
        
        return record;
    }
    
    /**
     * Maps a date field with option to replace zeros with default date
     */
    private void mapDateField(FieldSet fieldSet, String fieldName, java.util.function.Consumer<LocalDate> setter, 
                             boolean replaceZeros) {
        try {
            String dateStr = fieldSet.readString(fieldName);
            if (dateStr != null && !dateStr.trim().isEmpty()) {
                // Handle zero dates according to CTL file REPLACE directive
                if (replaceZeros && dateStr.equals("00000000")) {
                    dateStr = DEFAULT_DATE;
                }
                
                LocalDate date = LocalDate.parse(dateStr, DATE_FORMAT);
                setter.accept(date);
            }
        } catch (DateTimeParseException e) {
            log.warn("Invalid date format for field {}: {}", fieldName, e.getMessage());
        }
    }
    
    /**
     * Maps a BigDecimal field with null handling
     */
    private void mapBigDecimalField(FieldSet fieldSet, String fieldName, java.util.function.Consumer<BigDecimal> setter) {
        try {
            String valueStr = fieldSet.readString(fieldName);
            if (valueStr != null && !valueStr.trim().isEmpty()) {
                BigDecimal value = new BigDecimal(valueStr.trim());
                setter.accept(value);
            }
        } catch (NumberFormatException e) {
            log.warn("Invalid number format for field {}: {}", fieldName, e.getMessage());
        }
    }
}