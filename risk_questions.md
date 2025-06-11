# Questions for Original Users/Stakeholders Regarding Risk Calculation Stored Procedure

## 1. **Business Rule Management**

### Current State Understanding
- We've identified hundreds of hardcoded business rules within the 1,300+ line stored procedure. How frequently are these business rules updated or modified?
- Who is responsible for requesting these rule changes? (Business analysts, risk management team, compliance, etc.)
- What is the typical approval process before a rule change is implemented in production?
- How often do rule changes need to be rolled back due to incorrect implementation or business impact?

### Change History
- Can you provide examples of recent rule changes that were implemented?
- What typically triggers a rule change? (Regulatory requirements, business strategy, risk threshold adjustments, etc.)
- Are there seasonal or cyclical patterns to when rules are updated?

## 2. **Development and Maintenance Process**

### Technical Implementation
- Who currently maintains and updates the stored procedure code? Is it a specific team or individual?
- What development/testing process is followed when changes are made?
- How are changes tested before production deployment?
- Is there a version control system tracking changes to these procedures?

### Documentation
- Is there documentation explaining what each rule does and why it exists?
- Are the hardcoded account numbers and thresholds documented anywhere outside the code?
- Do you maintain a change log of what was modified and why?

## 3. **Scope and Impact Analysis**

### Other Affected Procedures
- Does this pattern of hardcoded business rules exist in other stored procedures?
- Can you provide a list of stored procedures that undergo similar frequent updates?
- Are there other critical ETL procedures with similar complexity and maintenance requirements?
- Which procedures are most critical to daily operations?

### Dependencies
- Are there other systems or procedures that depend on the risk calculations from this procedure?
- If this procedure fails or produces incorrect results, what is the business impact?
- How quickly do issues need to be resolved when they occur?

## 4. **Performance and Operational History**

### Historical Performance
- When was this procedure originally developed?
- Has performance degraded over time, or has it always taken this long for certain areas?
- What changes in data volume have occurred since the original Pro*C implementation?
- Are there specific areas (like 22, 23) that have always been problematic?

### Operational Requirements
- What is the acceptable execution time for this procedure?
- Are there specific SLAs that must be met?
- During what time windows does this procedure typically run?
- Are there peak periods where performance is more critical?

## 5. **Future Planning**

### Strategic Direction
- Are there plans to modernize or redesign this risk calculation process?
- Would the business be open to moving these rules to a configuration table rather than hardcoded values?
- Are there upcoming regulatory or business changes that might require significant modifications?

### Rule Engine Consideration
- Would a rule engine approach where business users could modify rules through a UI be valuable?
- What concerns would you have about moving away from hardcoded rules?
- How important is it to maintain an audit trail of rule changes?

## 6. **Data Understanding**

### Business Logic
- Can you explain why certain areas (21, 22, 23) have significantly more data than others?
- What do these "areas" represent in business terms?
- Are there patterns to which accounts fall into which risk categories?

### Validation
- How do you currently validate that risk calculations are correct?
- Are there test cases or expected results for various scenarios?
- When rules are changed, how do you ensure they don't inadvertently affect other calculations?

## 7. **Compliance and Audit**

### Regulatory Requirements
- Are these risk calculations required for regulatory compliance?
- How often are they audited?
- What documentation is required for auditors regarding how risks are calculated?
- Are there specific regulations that drive the complexity of these rules?

## 8. **Alternative Solutions**

### Openness to Change
- If we could provide better performance while maintaining the same business logic, would you be open to architectural changes?
- What concerns would you have about moving some of this logic outside the database?
- Would you consider a phased approach where we optimize the highest-impact areas first?

### Critical Requirements
- What aspects of the current system absolutely cannot change?
- What would be the minimum testing/validation required for any changes?
- Who would need to sign off on any proposed modifications?

## 9. **Specific Technical Questions**

### About the Hardcoded Values
- The procedure contains lists of account codes (0019, 0020, etc.) - how often do these lists change?
- Are these account codes used in other procedures as well?
- Would centralizing these in a reference table cause any concerns?

### About the Risk Rankings
- What do the different risk values (99, 103, 105, 107, etc.) represent?
- How are these risk values used downstream?
- Would changing the risk calculation logic require changes in consuming systems?

## 10. **Lessons Learned**

### Historical Issues
- What problems have you encountered with this procedure in the past?
- Have there been any significant incidents related to incorrect risk calculations?
- What would you do differently if you were designing this system today?

These questions will help you understand not just the technical aspects but also the business context, maintenance burden, and potential paths forward for optimization while managing risk appropriately.
