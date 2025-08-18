Database Link: The Simple Solution
Why DB Link is Simpler
Single Source of Truth: Both systems call the same sequence on Legacy (ALS) via database link

No replication = No sync issues
No lag = No timing problems
No control tables = No complexity

Key Benefits
Eliminates Core Problem:

Same sequence source → Identical TIN_SID values guaranteed
Your minus queries will show zero mismatches (sequence-wise)

Solves Sam's ETL Concerns:

No replication lag to wait for
No pre-ETL synchronization needed
ETL jobs can run immediately without coordination

Minimal Implementation:

Create database link: ENTITYDEV → ALS
Change sequence calls: TINSIDCNT.NEXTVAL@als_link
Done.

Trade-offs
Dependency: ENTITYDEV depends on ALS network connectivity
Performance: Network call for each sequence (typically negligible)
Legacy Load: ALS handles sequence requests from both systems
Bottom Line
Instead of complex replication and synchronization to make two sequences match, use one sequence from both systems. Simple, reliable, and directly addresses your verification requirements.
The elegance: Turn a synchronization problem into a "no synchronization needed" solution.
