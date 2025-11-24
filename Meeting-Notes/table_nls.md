

**Subject:** RE: Table Definition Discrepancies - DIALDEV vs Legacy M7 DIAL

Hi [Name],

Thanks for the detailed analysis and for documenting the 5-table comparison. Let me address each of your questions directly.


**Q1: Why are there differences in table structure between DIALDEV, DIAL_LEGACY_REPLICA, and M7 DIAL?**

The NVARCHAR2 datatype selection was an intentional architectural decision for two reasons:

*Exadata Optimization:*
The legacy M7 systems used fixed-width CHAR to support predictable memory allocation and pointer arithmetic in C-based processing. On Exadata, NVARCHAR2 performs better—Smart Scan and Hybrid Columnar Compression (HCC) are optimized for variable-length datatypes, and storage indexes handle them efficiently. Fixed-width CHAR with space-padding creates unnecessary I/O and storage overhead in this architecture.

*Java Modernization Alignment:*
Our Java ETL layer uses UTF-16 internally for all string handling—which maps directly to NVARCHAR2 (AL16UTF16). This eliminates character set conversion overhead between the application and database layers. JDBC's setNString() binds natively to NVARCHAR2, avoiding implicit conversions that CHAR would require and reducing potential data integrity issues during high-volume processing.


**Q2: What would it take to correct these discrepancies and match the Legacy table structures?**

Reverting to CHAR is possible but not recommended. It would require:

- Schema migration scripts across all affected environments
- Java application code updates (switching from setNString() to setString())
- Full regression testing of ETL processes
- Re-validation against production data

This effort would provide no performance or functional benefit on Exadata—in fact, it would reduce efficiency.

**My recommendation:** Keep the NVARCHAR2 structure in place. For the ORA-12704 validation issue, I'll create comparison views with TO_CHAR() casting so your MINUS queries work cleanly against the legacy replica tables. I can have these ready by [date]. This gives us a clean validation path without the overhead of schema changes.


**Q3: Why only certain columns? (Diane's question)**

The NVARCHAR2 conversion was specifically applied to the legacy CHAR(1) flag/indicator columns (CSED_REV, NOACT, ASED, ASED_REV, OVERAGE, LIEN, BACK_WTH, CAF, NEWMOD, ACCEL, NAICS, BODCD, BODCLCD, SPECIAL_PROJ_IND). These fields flow through string handling in the Java layer and benefit from native UTF-16 alignment. Numeric and date columns retained their original datatypes since they don't pass through string processing.

If we want full consistency across all character columns, I can review the schema and standardize—just let me know if that's preferred.


Let me know if you'd like to discuss further or if you have any concerns with this approach.

**References:**
- [Oracle Globalization Support Guide - Character Set Selection](https://docs.oracle.com/en/database/oracle/oracle-database/19/nlspg/choosing-character-set.html)
- [Oracle Exadata Smart Scan Overview](https://docs.oracle.com/en/engineered-systems/exadata-database-machine/)
- [Oracle JDBC Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/jjdbc/)

Note: This datatype change was on our radar to communicate to the team—we had planned to share this documentation once we completed the current DIAL process stabilization. Appreciate you raising it now so we can align early.
These architectural decisions were informed by our team's hands-on experience working across both the M7 legacy environment and the Exadata platform, ensuring we leverage the strengths of each system appropriately during this modernization effort.

Santosh

---

This format directly addresses each question while maintaining technical credibility and a clear recommendation. Anything you'd like me to adjust?
