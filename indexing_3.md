Excellent! Looking at your existing indexes, I can see some **CRITICAL GAPS** that are likely causing major performance issues:

## 🔴 **CRITICAL MISSING INDEX**

### **ENT table is missing a TINSID index!**
```sql
-- This is THE MOST IMPORTANT index you need to create
-- Your procedure does hundreds of updates like: UPDATE ent SET risk = X WHERE tinsid = Y
-- Without this index, each update does a FULL TABLE SCAN!

CREATE INDEX idx_ent_tinsid ON ent(tinsid);
```

## ✅ **Good News - What You Already Have:**

1. **ENT table has:**
   - PK_ENTX on TINSID (This is GREAT! Primary key serves as an index)
   - ENT_RISK_IX on RISK

2. **ENTMOD table has:**
   - ENTMOD_SID_IX on EMODSID (Good for your cursors)
   - ENTMOD_STATUS_IX on STATUS

3. **TRANTRAIL table has:**
   - TRANTRAIL_TINSID_IX on TINSID
   - TRANTRAIL_STATUS_IX on STATUS
   - TRANTRAIL_SEGIND_IX on SEGIND

## 🟡 **Additional Indexes Needed for Your Queries:**

### 1. **Composite Index for ENTMOD (for entcur2)**
```sql
-- Your entcur2 queries multiple columns together
CREATE INDEX idx_entmod_composite ON entmod(
    emodsid,
    status,
    type
);
```

### 2. **Composite Index for TRANTRAIL (for the subquery in entcur1)**
```sql
-- For better performance on the subquery
CREATE INDEX idx_trantrail_composite ON trantrail(
    status,
    segind,
    tinsid
);
```

### 3. **Function-Based Indexes (Optional but Helpful)**
```sql
-- Since you use decode(type,...) in WHERE clauses
CREATE INDEX idx_entmod_type_decode ON entmod(
    emodsid,
    DECODE(type,'2',1,'F',1,'G',1,'I',1,0)
);

-- Since you use decode(segind,...) in WHERE clauses
CREATE INDEX idx_trantrail_segind_decode ON trantrail(
    tinsid,
    DECODE(segind,'A',1,'I',1,'C',1,0)
);
```

## 📊 **Performance Impact Analysis:**

Since **PK_ENTX already exists on ENT.TINSID**, you're actually in better shape than I initially thought! A primary key automatically creates a unique index.

However, you still need:

### **Priority 1 - Must Have:**
```sql
-- Composite index for your main cursor query
CREATE INDEX idx_entmod_cursor ON entmod(emodsid, status, type);
```

### **Priority 2 - Significant Improvement:**
```sql
-- For the TRANTRAIL subquery performance
CREATE INDEX idx_trantrail_subquery ON trantrail(status, segind, tinsid);
```

### **Priority 3 - Nice to Have:**
```sql
-- If you query ENT by risk value
CREATE INDEX idx_ent_tinsid_risk ON ent(tinsid, risk);
```

## 🔍 **Verify Your Indexes Are Being Used:**

```sql
-- After creating indexes, run this to ensure they're being used
ALTER SESSION SET SQL_TRACE = TRUE;

-- Run your procedure
EXEC ENTITYDEV.riskcalc(area => 35);

-- Then check the trace file or use:
SELECT * FROM v$sql_plan 
WHERE sql_id IN (
    SELECT sql_id FROM v$sql 
    WHERE sql_text LIKE '%UPDATE ent SET risk%'
);
```

## 💡 **Summary:**

The good news is you already have the most critical index (PK_ENTX on TINSID). The missing composite indexes are what's likely slowing down your cursor queries. Create the Priority 1 and 2 indexes above for immediate performance gains!
