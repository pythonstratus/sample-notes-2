Brief Summary
A database issue was identified where the ASET review indicator (asedind) field contains spaces instead of NULL values in queue records, causing ORA-01722 "invalid number" errors when queries try to convert these spaces to numbers. The issue affects module management functionality - it works fine for open cases but fails for queue cases. The root cause is that during data import via SQL loader, spaces in flat files are treated as spaces rather than NULLs in the database.
Action Items for Diaconia Java Code Team

Data Validation Handling: Plan for and accommodate space characters where NULL values should exist when pulling data from the legacy database during migration/modernization
Comparison Logic: Implement correct comparison logic that accounts for the difference between:

Spaces (current incorrect state in legacy DB)
NULL values (correct target state)
Zero values (valid business value meaning "no trust fund assessed")


Testing Preparation: Be aware this issue will affect data validation testing - the Java code needs to handle the legacy data correctly while outputting proper NULL values
Multiple Column Impact: Note that this isn't just the ASET indicator - there are at least 3 different columns with the same space-instead-of-NULL issue that need similar handling

Decision: Legacy system will NOT be fixed (too many testing implications). Diaconia team should handle the data transformation during modernization to convert spaces to proper NULL values while maintaining business logic that differentiates between NULL (field doesn't apply) and 0 (field applies but no assessment made).
