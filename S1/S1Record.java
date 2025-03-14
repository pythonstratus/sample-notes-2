package com.abc.sbse.os.ts.csp.alsentity.ale.data;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Data model for S1 records based on the CTL file definition
 */
@Data
public class S1Record {
    // From CTL file positions 1-2
    private String outputCd;
    
    // From CTL file positions 3-6
    private BigDecimal area;
    
    // From CTL file position 7, with REPLACE logic
    private String type;
    
    // From CTL file positions 8-10
    private String code;
    
    // From CTL file positions 11-45
    private String cdName;
    
    // From CTL file positions 46-53
    private LocalDate extractDt;
    
    // From CTL file position 54
    private String timeDef;
    
    // From CTL file position 55, with NVL logic
    private String active;
    
    // From CTL file position 56, with NVL logic
    private String mgr;
    
    // From CTL file position 57, with NVL logic
    private String clerk;
    
    // From CTL file position 58, with NVL logic
    private String prof;
    
    // From CTL file position 59, with NVL logic
    private String para;
    
    // From CTL file position 60, with NVL logic
    private String disp;
    
    // From CTL file position 61
    private BigDecimal ctrsDef;
}