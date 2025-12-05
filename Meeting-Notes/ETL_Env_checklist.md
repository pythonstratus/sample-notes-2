

## ETL Environment Promotion Checklist

### Phase 1: Pre-Migration Readiness (Before Any Promotion)

**Code & Configuration Baseline**
- Confirm all Java ETL code is merged to a stable branch (feature-complete for the target environment)
- Verify the Java sequential processing logic (your fix for the order-dependent calculations) is fully tested in Dev
- Document all environment-specific properties that need parameterization:
  - Database connection strings (DIAL vs DIAL_DEV vs DIAL_TEST schemas)
  - S3 bucket endpoints and credentials
  - Logging levels and Splunk endpoints
  - AppDynamics agent configuration

**Synonym & Schema Strategy**
- Map out synonym ownership changes per environment (you mentioned synonyms pointing to different databases caused conflicts)
- Create a matrix: which tables need `_DEV` suffix removed when promoting to higher environments
- Script the synonym recreation process to be idempotent and environment-aware

**Data Validation Baseline**
- Run your minus queries between legacy and modernized output in Dev
- Document the current match rate (you mentioned 99.92%) and any known discrepancy patterns
- Establish acceptance criteria for each environment (e.g., Test requires 99.9%, Pre-Prod requires 100%)

---

### Phase 2: Test Environment Promotion

**Infrastructure Setup**
- Verify ECP namespace for Test exists with sufficient resource quota
- Confirm S3 bucket access — is Islam's bucket request approved? Can Test namespace download from the configured bucket?
- Set up Splunk connectivity (you noted it wasn't sending notifications in some environments)
- Determine AppDynamics availability (noted as not set up in test)

**Database Configuration**
- Verify DIAL_TEST schema exists and has production-like structure
- Configure synonyms in Test to point to DIAL_TEST tables (not DIAL_DEV)
- Confirm Golden Gate replication is NOT active in Test (use static test data)

**Deployment Checklist**
```
□ Build Docker image from release branch, tag as test-{version}
□ Push to enterprise registry (harbor)
□ Update Kubernetes manifests with Test-specific ConfigMaps/Secrets
□ Deploy CronJobs: ICS Daily, ICS Weekly, DIAL, SIA
□ Verify PVC mounts for responses folder (/inbound location)
□ Run manual job execution to validate deployment
```

**Validation**
- Execute ETLs with sanitized production copy data
- Run minus queries against expected output
- Verify Splunk logs are flowing
- Document any Test-specific discrepancies

---

### Phase 3: Pre-Prod / UAT Environment

**Business User Coordination**
- Schedule UAT window with Sam, Diane, and business stakeholders
- Prepare test cases that cover the edge cases you identified (the ~11,000 order-dependent records)
- Create rollback plan

**Infrastructure**
- Pre-Prod schema should mirror production structure exactly
- Consider using production data copy (with appropriate approvals for PII handling)
- Enable AppDynamics monitoring
- Configure production-like S3 bucket integration

**Deployment**
```
□ Tag release candidate from tested branch
□ Build and push docker image with preprod-{version} tag
□ Deploy using Blue-Green strategy (maintain rollback capability)
□ Execute full ETL cycle with production-volume data
□ Performance validation: confirm 2-5 minute processing time holds at scale
```

**Sign-Off Checklist**
- Business users validate output against legacy system
- 100% data match achieved or discrepancies formally accepted
- Performance benchmarks documented
- Rick/leadership approval obtained

---

### Phase 4: Production Deployment

**Change Management**
- Submit change request through formal approval process
- Schedule maintenance window
- Notify downstream consumers of potential data refresh timing changes

**Pre-Deployment**
```
□ Final code freeze on release branch
□ Database backup of production tables
□ Verify Golden Gate replication is stable
□ Confirm S3 bucket (ALS bucket → Entity namespace) access
□ Pre-stage rollback artifacts
```

**Deployment Execution**
```
□ Deploy using canary or blue-green strategy
□ Execute health checks immediately post-deploy
□ Run first scheduled ETL cycle under monitoring
□ Compare output against legacy system one final time
□ Monitor Splunk/AppDynamics for 24 hours
```

**Post-Deployment**
- Document any production-specific configuration
- Update runbooks for operations team
- Schedule legacy system decommission timeline

---

### Cross-Cutting Concerns for All Environments

| Concern | Dev | Test | Pre-Prod | Prod |
|---------|-----|------|----------|------|
| Database Schema | DIAL_DEV | DIAL_TEST | DIAL_PREPROD | DIAL |
| S3 Bucket | ALS bucket (dev) | ALS bucket (test) | Entity bucket | Entity bucket |
| Golden Gate | Active | Off | Off | Active |
| Splunk | Optional | Required | Required | Required |
| AppDynamics | Off | Off | Required | Required |
| Data | Synthetic | Sanitized copy | Prod mirror | Live |

---

### Key Risks to Track

1. **Namespace separation timing** — Jobs can't run in parallel between ALS and Entity namespaces during transition
2. **Bucket configuration delays** — Islam's bucket request took 6 weeks last time
3. **Synonym recreation conflicts** — The issue where synonyms point to wrong database after refresh
4. **Order-dependent calculation validation** — Ensure Java sequential logic matches legacy in every environment

