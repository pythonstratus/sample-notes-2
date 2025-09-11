# DIAL Hybrid Architecture Technical Proposal
**For Samuel Review Meeting - September 11, 2025**

## Executive Summary

This document presents our refined hybrid architecture approach for the DIAL system migration, incorporating Samuel's previous feedback about Spring Batch limitations for SQL-heavy workloads. The proposed solution leverages Spring Boot for orchestration while maintaining database-centric processing through stored procedures.

## Core Architecture Principles

### 1. Database-First Processing
- **Preserve existing SQL optimizations** through stored procedure implementation
- **Eliminate object-relational impedance mismatch** by avoiding unnecessary Java object transformations
- **Maintain set-based operations** for optimal database performance

### 2. Minimal Spring Batch Integration
- **Limited ItemReader usage** for file ingestion only
- **Direct JDBC operations** for data manipulation
- **Spring Boot orchestration** for job scheduling and monitoring

## Technical Implementation Strategy

### File Processing Pipeline

**Schema-Driven Flat File Processing:**
```
XML Schema Definition → ItemReader → Staging Tables → Stored Procedures
```

**Key Components:**

1. **Universal Flat File Reader**
   - XML schema-driven field parsing (position, length, type)
   - Dynamic map object creation (key-value pairs)
   - Configurable for any flat file format
   - No hardcoded field mappings

2. **Staging Table Architecture**
   - JDBC ItemWriter loads parsed data directly to staging tables
   - Minimal memory footprint with configurable chunk sizes
   - Multi-resource processing for concurrent file handling

3. **Stored Procedure Execution**
   - Parallel execution leveraging Oracle capabilities
   - Table-specific procedures for data transformation
   - Transaction control and rollback handling at database level

### Configuration Management Implementation

**File Structure Automation:**
- **Input Processing:** `/eftu/entity/incoming` with automated TDI/TDA file recognition
- **Organized Output:** `/entity/dial/current_extracts/[number]/DIALDIR/` structure
- **Backup Management:** Timestamped archives in `/entity/dial/previous_extracts`
- **Weekly Automation:** Scheduled execution with conflict resolution

### Memory and Performance Optimization

**Configurable Parameters (YAML):**
- Chunk size optimization
- Memory allocation settings
- Parallel container execution (5-6 containers)
- Resource management for large file volumes

**Performance Benefits:**
- Multi-resource ItemReader for concurrent processing
- Incremental vs. batch loading options
- Memory-dependent scaling (10-100+ files)
- Spring Batch listeners for monitoring and error handling

## Stored Procedure Migration Strategy

### Priority Conversion Targets

1. **CRENT (Create Entity)** - Primary conversion candidate
2. **CR Model** - Credit risk modeling procedures
3. **CNET** - Network calculation procedures
4. **TIN Summary** - Summary generation procedures

### Implementation Approach

**Schema Alignment:**
- Database table names match XML schema definitions
- Stored procedures use schema names for field references
- Type conversion logic (string → integer/float) implemented in SQL

**Data Transformation Logic:**
- Character-based calculations with hyphen detection
- Mathematical operations (divide by 100, multiply by -1)
- Conditional processing based on field patterns

**Transaction Control:**
- Database-native transaction management
- Rollback capabilities for failed operations
- Incremental and one-time load support

## Development Roadmap

### Phase 1: Foundation (Week 1)
- Complete schema-driven ItemReader implementation
- Establish staging table architecture
- Implement first stored procedure (CRENT)

### Phase 2: Core Procedures (Week 2-3)
- Convert remaining critical stored procedures
- Implement parallel execution framework
- Add comprehensive error handling and logging

### Phase 3: Integration & Testing (Week 4)
- ECP environment deployment
- Performance benchmarking
- Spring Actuator monitoring implementation

### Phase 4: Production Readiness (Week 5)
- Security integration
- Audit trail implementation
- Documentation and knowledge transfer

## Technical Advantages

### Database Optimization Preservation
- **Query optimizer utilization** maintained
- **Index efficiency** preserved
- **Database-specific features** leveraged

### Spring Boot Benefits
- **Job orchestration** and scheduling
- **Application monitoring** via Spring Actuator
- **Configuration management** through profiles
- **Dependency injection** for service components

### Operational Excellence
- **Minimal code footprint** (~200 lines core logic)
- **Universal flat file processing** capability
- **Configurable without code changes**
- **Scalable container deployment**

## Risk Mitigation

### Data Integrity
- Staging table validation before procedure execution
- Transaction rollback on processing failures
- Comprehensive audit logging

### Performance Monitoring
- Spring Boot health checks
- Database procedure execution metrics
- Memory utilization tracking
- Processing time optimization

### Maintenance Considerations
- Schema-driven approach reduces code maintenance
- Stored procedure versioning and deployment
- Configuration externalization for environment differences

## Next Steps

1. **Technical Deep-Dive Session** - Review specific legacy stored procedures
2. **Proof of Concept** - Implement CRENT stored procedure conversion
3. **Performance Benchmarking** - Compare hybrid approach vs. pure Spring Batch
4. **Architecture Validation** - Confirm alignment with ECP requirements

This hybrid architecture leverages the strengths of both modern Spring Boot capabilities and proven database processing efficiency, ensuring optimal performance while meeting enterprise compliance requirements.
