package com.abc.sbse.os.ts.csp.alsentity.ale.data;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Data model for EA records based on the CTL file definition
 */
@Data
public class EARecord {
    // From CTL file positions 1-2
    private String outputCd;
    
    // From CTL file positions 3-10, with REPLACE for zeros
    private LocalDate extractDt;
    
    // From CTL file positions 11-19
    private BigDecimal tin;
    
    // From CTL file position 20
    private BigDecimal fileSourceCd;
    
    // From CTL file position 21
    private BigDecimal tinType;
    
    // From CTL file positions 22-23
    private BigDecimal mftCd;
    
    // From CTL file positions 24-29, with REPLACE handling
    private LocalDate taxPrd;
    
    // From CTL file positions 30-37
    private String invItemCtrlId;
    
    // From CTL file positions 38-45
    private String asgmntNum;
    
    // From CTL file position 46
    private String modTypeInd;
    
    // From CTL file positions 47-54, with REPLACE for zeros
    private LocalDate taxModAssnDt;
    
    // From CTL file positions 55-62, with REPLACE for zeros
    private LocalDate roClosedDt;
    
    // From CTL file positions 63-65
    private String icsClosingCd;
    
    // From CTL file positions 66-68
    private String tdiCloseCd;
    
    // From CTL file positions 69-71
    private String closingTranScd;
    
    // From CTL file positions 72-73
    private String modDispCd;
    
    // From CTL file position 74
    private String icsStatusCd;
    
    // Additional fields used in processing but not directly from the input file
    private String caseSid;          // EASID - Used in SQL updates
    private String actionCd;         // Not directly in file but used for processing
    private LocalDate actionDt;      // Not directly in file but used for processing
    private String contactCd;        // Not directly in file but used for processing
    private LocalDate contactDt;     // Not directly in file but used for processing
    private String status;           // Set based on ACTIONCD
    private String comments;         // Not directly in file but potentially used
}