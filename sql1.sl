UPDATE ENT 
SET PREDCD = (
    SELECT emis_predic_cd 
    FROM TINSUMMARY 
    WHERE emistin = tin 
    AND emistt = tint 
    AND emisfs = tinfs 
    AND ronum = 1
)
WHERE EXISTS (
    SELECT 1 
    FROM TINSUMMARY 
    WHERE emistin = tin 
    AND emistt = tint 
    AND emisfs = tinfs 
    AND ronum = 1
)
