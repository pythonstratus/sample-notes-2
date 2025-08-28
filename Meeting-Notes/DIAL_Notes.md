# Database Connection DIAL Meeting Summary

## Core Issue
- **Primary Problem**: Entity dev is connecting to dial (production/testing) instead of dial dev, causing environment mismatches
- **Root Cause**: Synonyms are dropped and recreated during testing, switching connection targets inappropriately
- **Current State**: "entity dev to dial" instead of proper "dev to dev" connection

## Technical Details

### Database Environment Structure
- **dial**: Original database, exact replica of old system, used for production-like testing
- **dial dev**: Latest version development database where developers can freely modify data
- **entity dev**: Development entity database that should connect to dial dev

### Synonym Management Process
1. **Pre-test**: Database backed up with "2" suffix (e.g., Table2)
2. **During test**: Synonyms created to connect to "2" tables for 3-hour application runs
3. **Post-test**: "2" tables deleted, synonyms recreated to original tables
4. **Issue**: Synonyms refresh deletes existing ones and points to wrong database

### ETL Dependencies
- **dial tables**: Regularly refreshed from golden gate replica for ETLs
- **dial dev tables**: Used by entity dev via synonyms from RPT and ALS rpt
- **Conflict**: Same synonym names pointing to different databases

## Immediate Solutions

### Temporary Fix
- Comment out synonym deletion/recreation code
- Create synonyms in entity dev pointing to dial (not dial dev)
- Prevent automatic synonym management during testing

### Environment Segregation
- **Kamal & Ravi**: Use dial for CR testing (won't affect entity jobs)
- **Ganga**: Use dial dev for tier testing
- **Rationale**: dial dev data gets truncated when dial application runs

## Long-term Strategy

### Production Alignment
- **Development**: dial dev ↔ dial dev connections
- **Testing**: dial test ↔ dial test connections  
- **Production**: dial ↔ dial connections (no "dev" suffix)

### Code Requirements
- Replace all "dial" references with "dial dev" before production deployment
- Change table owners from dial dev to dial when moving to production/testing environments

## Outstanding Concerns

### Synchronization Issues
- **Ganga's concern**: Changing everything to dial could cause table deletion issues during testing
- **Infrastructure gap**: dial lacks automated daily/weekly cron jobs like production
- **Dependency**: Need S3 to local directory (ECP) copy job implementation

### Coordination Requirements
- Keep Sam informed for process synchronization
- No backend configuration changes needed per Ravi
- Post-change testing required despite code remaining unchanged

## Action Items
- Document discussion outcomes
- Ganga: Complete ICS assign work (1-2 hour timeline)
- Kamal: Proceed with testing
- Update required scripts
- Implement temporary synonym solution
