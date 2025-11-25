# DIAL Data Processing Technical Summary

## Core Problem
The team has achieved 99.92% data accuracy in the DIAL system migration but is struggling to reach the required 100% match due to **order-dependent calculations** that behave fundamentally differently between legacy C code and modern SQL operations.

## Technical Architecture

### Legacy System Flow
1. Reads TDI and TDS files (600 characters per record)
2. Loads into Oracle RAW table
3. Uses Oracle export tool to create `combo.raw` file, sorted by TIN number
4. **Sequential C code processing** through combo.raw
5. Calculates entity attributes during the single-pass sequential read

### Current Modern System Issues
- Using SQL set-based operations (ORDER BY, window functions)
- **Non-deterministic ordering** when records have identical sort keys
- Platform differences between legacy M7 and Exadata produce different tie-breaking behavior
- SQL partitioning selects different representative records than legacy code

## Critical Fields with Order Dependencies

### In TIN_SUMMARY table (4 problematic columns):
1. **ENT_TDI_XREF** - Cross-reference flag calculated based on record order
2. **ENT_TYPE** - Entity type (1, 2, or 3) determined by which record processes first
3. **LARGE_REPEAT** - Flag depending on ordered processing
4. **Aggregate values** - Running cumulative sums (e.g., 100 → 199 → 299 → 349)

### Core Issue Example:
For records with the same TIN:
- **If REC_TYPE=5 processes first**: ENT_TYPE=1, XREF=A
- **If REC_TYPE=0 processes first**: ENT_TYPE=2, XREF=I
- **If REC_TYPE=1 processes first**: ENT_TYPE=1, XREF=A
- Subsequent records get values based on what came before (3, C, etc.)

SQL sorting by name/tax_prd produces different ordering than legacy, causing approximately **11,000 out of 15 million records** to have mismatched values.

## Proposed Solution: Java-Based Sequential Processing

### New Approach:
```
1. Extract data from DIAL_STAGING table
2. Sort by TIN number (matching legacy RAW table export)
3. Load into Java application
4. Process records sequentially in exact legacy order
5. Calculate ENT_TYPE, ENT_TDI_XREF, aggregate values, flags in Java
6. Write calculated values to output file
7. Load file back into database tables
```

This approach gives **full control over record ordering and calculation sequence**, replicating the legacy C code's behavior exactly.

### Key Java Implementation Details:
- Read records in the exact order from combo.raw equivalent
- Maintain local variables for running calculations (like C code)
- Calculate all dependent fields in single sequential pass:
  - ENT_TDI_XREF
  - ENT_TYPE  
  - Aggregate running sums
  - Various flags (LARGE_REPEAT, etc.)
- Write enriched records back to file for database load

## Legacy Code Reference
The critical sorting/loading logic is in `dial_2_cr_data_1` or `dial_2_cr_data_2`:
- Loads TIN numbers into RAW table
- Exports with `ORDER BY tin` clause
- Creates combo.raw for sequential C processing
- C code iterates through file maintaining calculation state

## Deployment Infrastructure
- **Code repository**: GitHub with Actions pipeline
- **Runtime**: ECP (Enterprise Container Platform)
- **Batch execution**: On-demand job triggers via dial_con_job
- **Environments**: Dev, Test, Production

## Strategic Decision Points

### Proposed Simplification:
- **Remove ENT_TYPE from requirements** (if business approves)
- Focus on ENT_TDI_XREF calculation accuracy
- This eliminates one source of order-dependent complexity

### Testing Approach:
- Sam will work specifically on ENT_TDI_XREF calculation
- Create test views/procedures for targeted validation
- Run MINUS queries between legacy and modern TIN_SUMMARY
- Validate against specific problem records already identified

## Why This is Complex
**Fundamental paradigm mismatch:**
- Legacy: Procedural, stateful, single-pass sequential processing
- Modern: Declarative, stateless, set-based SQL operations

The legacy code has undocumented tie-breaking logic embedded in its sequential processing that cannot be replicated with standard SQL ORDER BY clauses. The only reliable solution is to recreate the sequential processing model.
