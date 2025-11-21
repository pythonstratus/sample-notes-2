SELECT 
    TIN,
    RECTYPE,
    NAMELINE,
    TAXPRD,
    
    -- Show the composite sort key
    NAMELINE || 
    CASE 
        WHEN RECTYPE = 5 THEN '1'
        WHEN RECTYPE = 0 THEN '2'
        ELSE '3'
    END AS COMPOSITE_KEY,
    
    ROW_NUMBER() OVER (
        ORDER BY
            TIN,
            NAMELINE || 
            CASE 
                WHEN RECTYPE = 5 THEN '1'
                WHEN RECTYPE = 0 THEN '2'
                ELSE '3'
            END,
            TAXPRD DESC NULLS LAST,
            ROWID
    ) AS PROCESSING_SEQUENCE

FROM DIAL_STAGING
WHERE TIN IN (1488893, 1506400)
ORDER BY PROCESSING_SEQUENCE;
```

**Expected results:**
```
TIN      | RECTYPE | NAMELINE                  | TAXPRD | COMPOSITE_KEY              | PROC_SEQ
---------|---------|---------------------------|--------|----------------------------|----------
1488893  | 5       | ROBERT W CURRIER          | 201812 | ROBERT W CURRIER1          | 1
1488893  | 0       | ROBERT W & EDITH J CURRIER| 201712 | ROBERT W & EDITH J CURRIER2| 2
1506400  | 5       | NOLANDO BRICE             | 202112 | NOLANDO BRICE1             | 3
1506400  | 0       | NOLANDO BRICE             | 202312 | NOLANDO BRICE2             | 4
1506400  | 5       | NOLANDO N BRICE           | 201512 | NOLANDO N BRICE1           | 5




SELECT 
    TIN,
    RECTYPE,
    NAMELINE,
    TAXPRD,
    FILESOURCECD,
    TINTYPE,
    ASSIGNMENTAO,
    ASSIGNMENTTO,
    MODTYPEIND,
    ROWID
FROM DIAL_STAGING
WHERE TIN IN (1488893, 1506400)
ORDER BY TIN, RECTYPE, TAXPRD DESC;
