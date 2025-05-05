-- Modified SQL with explicit date handling
SELECT 
  p.BADGE AS badge,
  p.SEID AS seid,
  NVL(p.ROID, 0) AS roid,
  p.NAME AS name,
  p.TITLE AS title,
  p.TOUR AS tour,
  NVL(p.GRADE, 0) AS grade,
  SUBSTR(NVL(EMPTYE(p.TYPE, p.POSTYPE, p.ELEVEL), 'UNKNOWN'), 1, 8) AS empType,
  NVL(ADJPERCENT, 0) AS adjpercent,
  p.ADJREASON
  -- ... other columns ...
FROM entemp p
LEFT JOIN (
  SELECT roid, COUNT(*) AS cases
  FROM trantrail
  -- If there's a date column here that's causing issues, add explicit formatting
  -- For example, if there's a date column like "created_date":
  -- WHERE status = 'O' AND TO_CHAR(created_date, 'YYYY-MM-DD') >= '2023-01-01'
  WHERE status = 'O'
  GROUP BY roid
) tt ON p.roid = tt.roid
LEFT JOIN targetlvl t1 ON t1.grade = p.grade
WHERE p.eactive IN ('Y', 'A')
-- If you have any date conditions, modify them with explicit TO_DATE conversions
-- For example:
-- AND p.hire_date >= TO_DATE('2023-01-01', 'YYYY-MM-DD')
