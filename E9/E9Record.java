package com.abc.sbse.os.ts.csp.alsentity.ale.data;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Data model for E9 records based on the CTL file definition
 */
@Data
public class E9Record {
    // From CTL file positions 1-2
    private String outputCd;
    
    // From CTL file positions 3-10, with REPLACE for zeros
    private LocalDate entExtractDt;
    
    // From CTL file positions 11-18, with REPLACE for zeros
    private LocalDate rptEndingDt;
    
    // From CTL file positions 19-27
    private BigDecimal tin;
    
    // From CTL file position 28
    private BigDecimal fileSourceCd;
    
    // From CTL file position 29
    private BigDecimal tinType;
    
    // From CTL file positions 30-37
    private BigDecimal asgmntNum;
    
    // From CTL file positions 38-72
    private String txpVrNumTrlCd;
    
    // From CTL file positions 73-76
    private String txpVrMCtrlCd;
    
    // From CTL file positions 77-79
    private String entCaseCd;
    
    // From CTL file positions 80-82
    private String entSubCaseCd;
    
    // From CTL file positions 83-84
    private BigDecimal cycTouchCnt;
    
    // From CTL file positions 85-88
    private BigDecimal touchCnt;
    
    // From CTL file positions 89-96, with REPLACE for zeros
    private LocalDate latestTouchDt;
    
    // From CTL file positions 97-102
    private BigDecimal inputHrs;
    
    // From CTL file positions 103-108
    private BigDecimal totalCaseHrs;
    
    // From CTL file position 109
    private String caseIdCd;
    
    // From CTL file position 110
    private String invItenStateCd;
    
    // From CTL file positions 111-118, with REPLACE for zeros
    private LocalDate invItemClsDt;
    
    // From CTL file position 119
    private String invItemTypeCd;
    
    // From CTL file positions 120-127
    private String invItemCtrlId;
    
    // From CTL file positions 128-130
    private String ndSubCaseCd;
    
    // From CTL file position 131-133
    private String rcpText;
    
    // From CTL file position 134
    private String caseStatus;
    
    // From CTL file positions 135-142, with REPLACE for zeros
    private LocalDate caseRoClosedDt;
    
    // From CTL file positions 143-150, with REPLACE for zeros
    private LocalDate caseHostClsDt;
    
    // From CTL file positions 151-152
    private String entModDispCd;
    
    // From CTL file positions 153-155
    private String entModClsngCd;
    
    // From CTL file positions 156-163, with REPLACE for zeros
    private LocalDate initContCtDt;
    
    // From CTL file positions 164-171, with REPLACE for zeros
    private LocalDate initContCtDuDt;
    
    // Additional fields used in processing but not directly from the input file
    private String caseSid;  // Used in SQL updates
    private LocalDate roAsgmnDt;  // Calculated from rptEndingDt
    private BigDecimal mftCd;     // Default set to null, updated later
    private LocalDate taxPrd;     // Default set to null, updated later
    private String modTypeInd;    // Set based on transaction type
    private String lienDetermCd;  // Set during processing
    private LocalDate lienDetermDt; // Set during processing
    private LocalDate extractDt;  // Set from entExtractDt
}