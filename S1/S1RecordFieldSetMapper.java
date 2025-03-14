package com.abc.sbse.os.ts.csp.alsentity.ale.mapper;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

import org.springframework.batch.item.file.mapping.FieldSetMapper;
import org.springframework.batch.item.file.transform.FieldSet;
import org.springframework.validation.BindException;

import com.abc.sbse.os.ts.csp.alsentity.ale.data.S1Record;

import lombok.extern.slf4j.Slf4j;

/**
 * Maps data from the fixed-length file to S1Record objects
 * Handles data type conversions and default values according to load file CTL
 */
@Slf4j
public class S1RecordFieldSetMapper implements FieldSetMapper<S1Record> {

    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");

    @Override
    public S1Record mapFieldSet(FieldSet fieldSet) throws BindException {
        S1Record record = new S1Record();
        
        try {
            // Map String fields directly
            record.setOutputCd(fieldSet.readString("OUTPUTCD"));
            record.setCode(fieldSet.readString("CODE"));
            record.setCdName(fieldSet.readString("CDNAME"));
            
            // Map BigDecimal fields
            mapBigDecimalField(fieldSet, "AREA", record::setArea);
            mapBigDecimalField(fieldSet, "CTRSDEF", record::setCtrsDef);
            
            // Special handling for TYPE with REPLACE logic as per CTL file
            String typeStr = fieldSet.readString("TYPE");
            if (typeStr != null && !typeStr.trim().isEmpty()) {
                if (typeStr.equals("1")) {
                    record.setType("C");
                } else if (typeStr.equals("2")) {
                    record.setType("S");
                } else {
                    record.setType(typeStr);
                }
            }
            
            // Map EXTRACTDT field
            mapDateField(fieldSet, "EXTRDT", record::setExtractDt);
            
            // Map TIMEDEF field
            record.setTimeDef(fieldSet.readString("TIMEDEF"));
            
            // Map fields with NVL logic
            mapNvlField(fieldSet, "ACTIVE", record::setActive, "Y");
            mapNvlField(fieldSet, "MGR", record::setMgr, "F");
            mapNvlField(fieldSet, "CLERK", record::setClerk, "F");
            mapNvlField(fieldSet, "PROF", record::setProf, "T");
            mapNvlField(fieldSet, "PARA", record::setPara, "T");
            mapNvlField(fieldSet, "DISP", record::setDisp, "N");
            
        } catch (Exception e) {
            log.error("Error mapping field set to S1Record: {}", e.getMessage(), e);
            throw new BindException(record, "S1Record");
        }
        
        return record;
    }
    
    /**
     * Maps a date field
     */
    private void mapDateField(FieldSet fieldSet, String fieldName, java.util.function.Consumer<LocalDate> setter) {
        try {
            String dateStr = fieldSet.readString(fieldName);
            if (dateStr != null && !dateStr.trim().isEmpty()) {
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
    
    /**
     * Maps a field with NVL logic - if null, uses default value
     */
    private void mapNvlField(FieldSet fieldSet, String fieldName, java.util.function.Consumer<String> setter, 
                           String defaultValue) {
        String value = fieldSet.readString(fieldName);
        if (value == null || value.trim().isEmpty()) {
            setter.accept(defaultValue);
        } else {
            setter.accept(value);
        }
    }
}