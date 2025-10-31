Here's a draft email for Samuel:

---

**Subject: Questions on SBSE Table Population and CSED Date Calculation in Legacy Code

**To:** Samuel

**CC:** [Your team as needed]

Hi Samuel,

I'm reaching out regarding two issues I've identified while analyzing the legacy dial code that need clarification:

## 1. SBSE Table Population Issue

We've discovered that the SBSC/SVAC TDI table is not being populated correctly, causing downstream failures in our ETL process. 

**Current situation:**
- The code expects to find data in the SBSC table to seed updates for dial ENT
- SBSC table is currently empty in our environment, causing all updates to fail
- We found that 15,000 records were copied from Legacy to SBSC initially
- The program is supposed to update the seed number, but we need to understand the source

**Questions:**
- What process or application is responsible for initially populating SVAC TDI/SBSC in Legacy?
- Should these tables be synced weekly from Legacy? If so, what's the mechanism?
- Is this something that should be handled through Goldengate replication?

## 2. CSED Date Calculation Discrepancy (loaddial.pc)

I've identified a date calculation issue in the legacy ProC code (see attached screenshot from loaddial.pc).

**The problem:**
When `csed = 19000101` and `rectype == 5`, the code executes:
```sql
EXEC SQL SELECT
  TO_CHAR(ADD_MONTHS(TO_DATE(:dtassd,'YYYYMMDD'),120),'YYYYMMDD')
  INTO :csed
  FROM DUAL;
```

**Expected behavior:** If dtassd = 1969 date, adding 120 months (10 years) should result in 1979

**Actual behavior:** The calculation is producing 2035 instead

**Questions:**
- Is this a known issue in Legacy, or is the logic intentionally different than expected?
- Should we be interpreting the date format differently?
- Is there documentation on how CSED dates should be calculated for this scenario?

Please let me know if you need any additional context or if we should set up a call to walk through these issues together.

Thanks,
[Your name]

---

Would you like me to adjust the tone or add any additional details?
