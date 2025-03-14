package com.abc.sbse.os.ts.csp.alsentity.ale.mapper;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

import org.springframework.batch.item.file.mapping.FieldSetMapper;
import org.springframework.batch.item.file.transform.FieldSet;
import org.springframework.validation.BindException;

import com.abc.sbse.os.ts.csp.alsentity.ale.data.E9Record;

import lombok.extern.slf4j.Slf4j;

/**
 * Maps data from the fixed-length file to E9Record objects
 * Handles data type conversions and default values according to load file CTL
 */
@Slf4j
public class E9RecordFieldSetMapper implements FieldSetMapper<E9Record> {

    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final String DEFAULT_DATE = "19000101";

    @Override
    public E9Record mapFieldSet(FieldSet fieldSet) throws BindException {
        E9Record record = new E9Record();
        
        try {
            // Map String fields directly
            record.setOutputCd(fieldSet.readString("OUTPUTCD"));
            record.setTxpVrNumTrlCd(fieldSet.readString("TXPVRNUMTRLCD"));
            record.setTxpVrMCtrlCd(fieldSet.readString("TXPVRMCTRLCD"));
            record.setEntCaseCd(fieldSet.readString("ENTCASECD"));
            record.setEntSubCaseCd(fieldSet.readString("ENTSUBCASECD"));
            record.setCaseIdCd(fieldSet.readString("CASEIDCD"));
            record.setInvItenStateCd(fieldSet.readString("INVITENSTATECD"));
            record.setInvItemTypeCd(fieldSet.readString("INVITEMTYPECD"));
            record.setInvItemCtrlId(fieldSet.readString("INVITEMCTRLID"));
            record.setNdSubCaseCd(fieldSet.readString("NDSUBCASECD"));
            record.setRcpText(fieldSet.readString("RCPTEXT"));
            record.setCaseStatus(fieldSet.readString("CASESTATUS"));
            record.setEntModDispCd(fieldSet.readString("ENTMODDISPCD"));
            record.setEntModClsngCd(fieldSet.readString("ENTMODCLSNGCD"));
            
            // Map BigDecimal fields with null handling
            mapBigDecimalField(fieldSet, "TIN", record::setTin);
            mapBigDecimalField(fieldSet, "FILESOURCECD", record::setFileSourceCd);
            mapBigDecimalField(fieldSet, "TINTYPE", record::setTinType);
            mapBigDecimalField(fieldSet, "ASGMNTNUM", record::setAsgmntNum);
            mapBigDecimalField(fieldSet, "CYCTOUCHCNT", record::setCycTouchCnt);
            mapBigDecimalField(fieldSet, "TOUCHCNT", record::setTouchCnt);
            
            // Special handling for INPUTHRS and TOTALCASEHRS as specified in the CTL file
            String inputHrsStr = fieldSet.readString("INPUTHRS");
            if (inputHrsStr != null && !inputHrsStr.trim().isEmpty()) {
                try {
                    // Apply DECODE logic from the CTL file if needed
                    BigDecimal inputHrs = new BigDecimal(inputHrsStr);
                    record.setInputHrs(inputHrs);
                } catch (NumberFormatException e) {
                    log.warn("Invalid INPUTHRS value: {}", inputHrsStr);
                    record.setInputHrs(null);
                }
            }
            
            String totalCaseHrsStr = fieldSet.readString("TOTALCASEHRS");
            if (totalCaseHrsStr != null && !totalCaseHrsStr.trim().isEmpty()) {
                try {
                    // Apply DECODE logic from the CTL file if needed
                    BigDecimal totalCaseHrs = new BigDecimal(totalCaseHrsStr);
                    record.setTotalCaseHrs(totalCaseHrs);
                } catch (NumberFormatException e) {
                    log.warn("Invalid TOTALCASEHRS value: {}", totalCaseHrsStr);
                    record.setTotalCaseHrs(null);
                }
            }
            
            // Map date fields with default date replacement as specified in CTL file
            mapDateField(fieldSet, "ENTEXTRACTDT", record::setEntExtractDt, true);
            mapDateField(fieldSet, "RPTENDINGDT", record::setRptEndingDt, true);
            mapDateField(fieldSet, "LATESTTOUCHDT", record::setLatestTouchDt, true);
            mapDateField(fieldSet, "INVITEMCLSDT", record::setInvItemClsDt, true);
            mapDateField(fieldSet, "CASEROCLOSEDDT", record::setCaseRoClosedDt, true);
            mapDateField(fieldSet, "CASEHOSTCLSDT", record::setCaseHostClsDt, true);
            mapDateField(fieldSet, "INITCONTCTDT", record::setInitContCtDt, true);
            mapDateField(fieldSet, "INITCONTCTDUDT", record::setInitContCtDuDt, true);
            
            // Set extractDt from entExtractDt for consistency
            record.setExtractDt(record.getEntExtractDt());
            
            // Set roAsgmnDt from rptEndingDt as per business logic
            record.setRoAsgmnDt(record.getRptEndingDt());
            
        } catch (Exception e) {
            log.error("Error mapping field set to E9Record: {}", e.getMessage(), e);
            throw new BindException(record, "E9Record");
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