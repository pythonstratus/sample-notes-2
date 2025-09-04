# ETL Working Session - Complete Summary & Technical Approach
**September 3, 2025**

## Executive Summary

### Meeting Logistics Update
- **Schedule Change**: Moving from daily to weekly meetings
- **Communication**: Primary interaction through Teams and email
- **Response Expectations**: Prompt responses required for Diane and Sam's questions

### Current System Status

#### Daily/Weekly Runs
- No known issues reported
- Ranjitha confirmed stable operations

#### Sequencing Resolution
- Previous sequencing concerns addressed during sprint review with Sarah
- Sarah confirmed sequencing replication unnecessary for new systems
- Sharon will share sprint review recording for Diane and Sam's reference

---

## Technical Architecture Analysis & Implementation Strategy

### Current State Assessment

#### Existing System Bottlenecks
**Performance Issues:**
- In-memory processing of 15+ million records creating memory pressure
- Java-based sorting operations consuming excessive resources
- Sequential file processing with unnecessary intermediate file generation
- Network overhead from multiple database write operations
- Tomcat container-based execution preventing proper job termination

**Legacy System Constraints:**
- 40-year-old system with limited documentation
- Com Risk process involving file segmentation before database insertion
- Complex sequencing requirements across TDI/TDA file processing
- Memory-intensive loader operations reading records byte-by-byte

#### Job Scheduling Current Implementation
- **Concurrency & Synchronization**: Ganga confirmed implementation of Sam's suggested step-by-step sequencing
- **Process Flow**: Six-step sequential execution with proper wait conditions between steps
- **File Processing Challenge**: Exploring separate TDI/TDA file processing to eliminate combo file creation step
  - Memory consumption concerns noted by Santosh for this approach

### Database-Centric Processing Architecture

#### Core Migration Strategy: Frontend-to-Backend Processing
**Philosophy:** Move data-intensive operations from Java application layer to database layer for improved performance and reduced network overhead.

##### Current vs Proposed Data Flow
**Current Process:**
```
Java → Read Files → Sort in Memory → Generate Q/XQ CFF Files → Write to DB
```

**Proposed Process:**
```
Java → Stream to Staging Table → DB Triggers → Process & Distribute → Target Tables
```

##### Implementation Benefits
- **Direct Database Writing**: Replace Q files and XQ CFF file generation with direct database writes
- **Backend Processing**: Implement triggers and stored procedures to handle data distribution after job completion
- **Architecture Improvement**: Reduce network overhead and improve server performance
- **Sequence Optimization**: Use database auto-increment capabilities instead of Oracle sequence number queries

#### Sorting Strategy Redesign

**Current Implementation Issues:**
- In-memory Java sorting operations on large datasets
- Multiple sorting phases: name sorting, name splitting, period sorting, TDAPI sorting
- Ganga's question: "What is the purpose of the sorting? From the database side we can sort it."

**Proposed Database-Level Approach:**
- **Database-level sorting** using optimized indexes and ORDER BY clauses
- **Conditional Implementation**: Retain in-memory sorting only if calculations depend on specific row positioning
- **Investigation Required**: Determine if sorting is purely organizational or affects downstream calculations

**Technical Decision Framework:**
```
IF calculations use row_number() directly after sorting THEN
    Keep in-memory sorting (calculations depend on order)
ELSE 
    Migrate to database ORDER BY clauses with proper indexing
```

### Com Risk Process Architectural Review

#### Current Workflow Analysis
**Existing Process Questions Raised:**
- Why segment combo risk into separate files (tin summary, dial int, dial mod) instead of direct parsing?
- Is tin adjacency requirement (keeping taxpayer records together) actually necessary?
- Can we eliminate the file chopping approach entirely?

**Current Workflow:**
1. Build core dial reference on-the-fly
2. Generate combo risk file with correlation data
3. Segment combo risk into separate files
4. Process individual files into respective database tables

#### Proposed Streamlined Architecture
**New Workflow:**
```
Source Data → Single Staging Table → Backend Logic → Direct Table Distribution
```

**Implementation Strategy:**
- **Single Table Approach**: Dump all data into staging table, use backend triggers for processing
- **G Graph Logic Migration**: Move C mode and C E N T processing logic (G graph = 70) to backend
- **Elimination of Intermediate Files**: Direct database processing without file generation

**Benefits:**
- Eliminate file I/O operations
- Reduce processing steps from 4+ to 2
- Enable parallel processing of different data segments
- Simplify error handling and recovery

### Spring Batch Framework Enhancement

#### Current Implementation Assessment
**Limitations Identified:**
- Limited use of Spring Batch reader/writer pattern
- Processing concentrated in single step execution: "The current code wasn't really using the reader and writer, it was more like one step"
- Missing proper batch job segmentation

#### Proposed Spring Batch Redesign

##### Job Architecture Transformation
**Current:** Single job with sequential steps in flow
**Proposed:** Domain-based job separation with proper reader/processor/writer implementation

```
ETL_Master_Job
├── Data_Ingestion_Job
│   ├── TDI_Reader → TDI_Processor → Database_Writer
│   └── TDA_Reader → TDA_Processor → Database_Writer
├── Transformation_Job
│   ├── Sorting_Processor
│   └── Validation_Processor
└── Distribution_Job
    ├── Tin_Summary_Writer
    ├── Dial_Mod_Writer
    └── Dial_Int_Writer
```

##### Container Strategy Migration
**Current Issue:** Tomcat container preventing proper job termination
**Solution:** Standalone Spring Boot application deployment

**Implementation Options:**
- **Standalone Application**: Run as cron job outside web container
- **Spring Boot Configuration**: WebApplicationType.NONE for non-web execution
- **Job Termination**: Proper shutdown handling for batch processes

**Technical Implementation:**
```java
@SpringBootApplication
@EnableBatchProcessing
public class ETLApplication {
    // Standalone execution mode
    SpringApplication.setWebApplicationType(WebApplicationType.NONE);
}
```

##### Stored Procedure Integration
- **Performance Boost**: Stored procedures created to offload Java processing to Oracle
- **Functions Delivery**: Functions and stored procedures to be sent to Samuel
- **Reader/Writer Optimization**: Performance improvement through proper Spring Batch component implementation

### Performance Optimization Strategies

#### Memory Management Solutions
**Problem:** Container memory duplication across parallel jobs - "Loading and processing 15 million records in memory on a server is expensive"
**Solution:** Centralized database processing with minimal Java memory footprint

**Implementation Approach:**
- Stream processing instead of batch loading entire datasets
- Database connection pooling optimization
- JVM heap size tuning specific to streaming operations
- Move from "reading each record byte by byte" to more efficient bulk operations

#### Parallel Processing Architecture

##### Area-Based Parallelization Strategy
**Concept:** Process service center areas (A11, A12, etc.) in parallel
**Business Consultation Required**: Confirm approach compatibility with DAO operations across service centers

**Technical Implementation:**
```
Area_11_Job ┐
Area_12_Job ├── Parallel Execution
Area_13_Job ┘
    ↓
Synchronization_Point
    ↓
Final_Aggregation_Job
```

**Considerations:**
- Ensure no cross-area data dependencies
- Implement proper synchronization for shared resources
- Include Steve (Area 11 technical lead) in solution discussions

##### TDI/TDA Data Processing
**Current Requirement:** "Data for TDIs and TDAs must be together, such as A11 and A12, which are combined into a combo raw"
**Proposed Approach:** Parallel processing with proper data coordination
**Action Item:** Ganga to discuss parallel process coordination requirements

### Advanced Technology Integration

#### Spark Integration Evaluation
**Santos' Technical Proposal:** 
- Directed Acyclic Graph (DAG) approach for efficient processing in confined memory space
- Container-based deployment without Hadoop dependency
- Spark streaming to speed up jobs without changing current system architecture

**Benefits Analysis:**
- Distributed processing capabilities for large datasets
- Advanced memory management for 15+ million record processing
- Streaming processing support
- Minimal system architecture changes required

**Risk Assessment & Concerns:**
- **Previous Classification**: Sam noted Spark marked as high-risk and isolated to RAS
- **Server Isolation**: Concerns about data access patterns and container deployment
- **Team Decision**: "Okay with not using it if it's problematic"

**Technical Decision Approach:**
- Develop proof-of-concept for performance comparison
- Assess containerization compatibility with existing infrastructure
- Evaluate maintenance overhead and team expertise requirements

### Implementation Roadmap

#### Phase 1: Database Migration Foundation (2-3 weeks)
**Immediate Actions:**
1. **CTRS eom**: Implementation to begin immediately
2. **Stored Procedures**: Deploy functions and stored procedures to Oracle
3. **Staging Tables**: Design and implement database staging schema
4. **Performance Baseline**: Establish current system metrics

**Deliverables:**
- Database triggers for automatic data distribution
- Stored procedures for core data processing logic
- Performance baseline documentation

#### Phase 2: Spring Batch Redesign (3-4 weeks)
**Key Tasks:**
- **Reader/Writer Separation**: "Will split those out. Currently doing everything under one task"
- **Domain Organization**: "Treat them like a domain approach rather than these steps here"
- **Container Migration**: Move from Tomcat to standalone execution
- **Job Segmentation**: Split end-to-end process into separate batch jobs

**Deliverables:**
- Proper Spring Batch reader/processor/writer implementation
- Domain-based job architecture
- Standalone application deployment capability

#### Phase 3: Performance Optimization (2-3 weeks)
**Focus Areas:**
- **Parallel Processing**: Implement area-based parallel execution
- **Memory Optimization**: Reduce in-memory processing footprint  
- **Database Performance**: Optimize queries and indexing strategy
- **Testing Integration**: Work with Ranjitha on test case adaptation

**Deliverables:**
- Parallel processing framework
- Memory usage optimization
- Comprehensive performance testing results

#### Phase 4: Advanced Features & Quality Assurance (4-6 weeks)
**Optional Enhancements:**
- Spark integration proof-of-concept (pending risk assessment)
- Advanced error handling and recovery mechanisms
- Monitoring and alerting system implementation

**Quality Assurance Framework:**
- **Code Reviews**: Increase frequency with GitHub-based assignments
- **Testing Strategy**: Ranjitha's complete test suite execution
- **Documentation**: Comprehensive system documentation for 40-year-old legacy system

---

## Apache Spark Integration - Future Enhancement Suggestion

### Overview
This section outlines Apache Spark as a potential future enhancement to the ETL system, separate from the core implementation phases. This suggestion should be evaluated after successful completion of the database-centric architecture migration.

### Technical Proposal Details
**Santos' Spark Initiative:**
- **White Paper Development**: Comprehensive documentation on Spark implementation approach
- **DAG Processing**: Directed Acyclic Graph approach for efficient processing in confined memory space
- **Container Deployment**: Container-based Spark deployment without Hadoop dependency
- **Streaming Integration**: Spark streaming to accelerate job processing without major system architecture changes

### Potential Benefits Analysis
**Performance Advantages:**
- **Distributed Processing**: Handle large datasets (15+ million records) across multiple nodes
- **Advanced Memory Management**: Intelligent memory allocation and garbage collection optimization
- **Streaming Capabilities**: Real-time processing support for future requirements
- **Fault Tolerance**: Built-in recovery mechanisms for failed processing tasks

**Integration Benefits:**
- **Minimal Architecture Changes**: Can work alongside existing Spring Batch framework
- **Independent Deployment**: Container-based approach allows isolated testing and deployment
- **Scalability**: Horizontal scaling capabilities for growing data volumes

### Risk Assessment & Concerns

#### Technical Risks
- **Previous Classification**: Sam noted Spark marked as high-risk technology and isolated to RAS environment
- **Server Isolation Requirements**: Data security and access pattern restrictions
- **Integration Complexity**: Additional complexity layer on top of existing system redesign
- **Team Expertise Gap**: Learning curve and maintenance overhead for development team

#### Operational Risks
- **Image Updates**: Islam's concern about potential points of failure with Spark image updates
- **Container Management**: Additional container orchestration and monitoring requirements
- **Network Overhead**: Data movement between Spark cluster and database systems
- **Resource Competition**: Potential resource conflicts with existing ETL processes

### Implementation Approach (If Approved)

#### Phase 1: Proof of Concept (3-4 weeks)
**Objectives:**
- Validate Spark performance against current database-centric approach
- Test container deployment within existing infrastructure constraints
- Assess integration complexity with Spring Batch framework

**Deliverables:**
- Performance benchmark comparison
- Container deployment documentation
- Integration architecture proposal
- Risk mitigation strategy

#### Phase 2: Pilot Implementation (4-6 weeks)
**Scope:**
- Implement Spark processing for single area (A11 or A12) as test case
- Develop monitoring and alerting for Spark jobs
- Create rollback procedures and failure handling
- Document operational procedures

**Success Criteria:**
- Performance improvement over database-only approach
- Stable operation within RAS isolation requirements
- Successful integration with existing monitoring systems

### Decision Framework

#### Prerequisites for Spark Evaluation
1. **Core Implementation Complete**: Database-centric architecture fully deployed and stable
2. **Performance Baseline Established**: Clear metrics from Phase 3 performance optimization
3. **Team Readiness**: Development team comfortable with new architecture
4. **Stakeholder Approval**: Business validation for additional technology complexity

#### Go/No-Go Criteria
**Proceed with Spark IF:**
- Database-centric approach shows limitations with largest datasets
- Team demonstrates readiness for additional complexity
- RAS isolation concerns can be adequately addressed
- Clear performance benefits demonstrated in proof of concept

**Alternative Approach IF:**
- Database-centric solution meets all performance requirements
- Team prefers to maintain simpler architecture
- RAS security concerns cannot be resolved
- Maintenance overhead deemed too high

### Business Considerations

#### Cost-Benefit Analysis
**Additional Costs:**
- Development time for Spark integration (7-10 weeks total)
- Additional infrastructure and licensing requirements
- Team training and expertise development
- Ongoing maintenance and monitoring overhead

**Potential Benefits:**
- Future-proofing for data growth beyond current 15M records
- Enhanced real-time processing capabilities
- Improved fault tolerance and recovery
- Advanced analytics and processing capabilities

#### Recommendation Timeline
**Suggested Evaluation Point**: After completion of Phase 3 (Performance Optimization)
- **Assessment Period**: 2-3 weeks to evaluate core system performance
- **Decision Deadline**: End of Phase 3 implementation
- **Implementation Start**: Only if approved after core system validation

### Alternative Suggestions

If Spark integration is deemed too complex or risky, consider these alternatives:

#### Database Optimization Focus
- **Advanced Indexing**: Implement specialized database indexes for large dataset processing
- **Partitioning Strategy**: Table partitioning for improved query performance
- **Connection Pooling**: Enhanced database connection management

#### Infrastructure Scaling
- **Vertical Scaling**: Increased memory and CPU resources for existing architecture
- **Database Clustering**: Multi-node database configuration for distributed processing
- **Caching Layer**: Redis or similar for frequently accessed data

---

#### Team Coordination Strategy
**Technical Leadership Integration:**
- **Steve (Area 11)**: Include most technical person in solution conversations
- **Cross-team Collaboration**: Enhanced coordination between development teams
- **Business Alignment**: Careful communication with stakeholders about system changes

#### Code Quality & Review Process
**GitHub Integration Improvements:**
- Mandatory code reviews for all changes with LE team assignments
- Email notifications to PMs for review status
- **Current Gap**: "This process hasn't been consistently followed for AL's or entity"

**Development Process:**
- Developers push code to Git with reviewer notifications
- Structured review assignments through GitHub
- Documentation requirements for new components

### Risk Management & Legacy System Protection

#### System Modification Caution
**40-Year System Considerations:**
- **Documentation Gap**: Undocumented legacy system requiring careful modification approach
- **Change Approval**: "Before removing steps, suggest it to the AV team for discussion"
- **Goal Clarification**: "Migrating steps from the front end to the back end is the aim, not removing them"
- **Business Alignment**: Focus on efficiency while maintaining CCD team alignment

#### Implementation Safety Measures
- **Feature Flags**: Gradual rollout capability for major changes
- **Parallel Processing**: Maintain existing capability during transition
- **Rollback Procedures**: Comprehensive recovery plans for each phase
- **Stakeholder Approval**: Business validation for each major architectural change

### Meeting Schedule & Follow-up

#### Revised Meeting Cadence
**New Schedule:** Twice weekly (Tuesdays and Thursdays)
- **Rationale**: Allow more development time between collaborative sessions
- **Flexibility**: Adjust frequency based on team progress and needs
- **Coordination**: Sharon to update calendar invitations

#### Action Items Summary

**Immediate Priority:**
1. **CTRS eom**: Speaker to begin implementation
2. **Comprehensive PR**: Paul's pull request ready for review
3. **Dial Processing**: Speaker collaboration with Ganga and Sia on dial-related work
4. **Sam Follow-up**: Speaker to respond on all discussed topics

**Research & Analysis:**
- **Sorting Purpose Investigation**: Determine specific business requirements for current sorting implementation
- **Performance Assessment**: Evaluate loader dial byte-by-byte processing impact
- **Spring Batch Redesign**: Provide timeline estimate for reader/writer task restructuring
- **Parallel Processing Feasibility**: Ganga to discuss coordination requirements as action item

**Quality & Documentation:**
- **Naming Conventions**: Implement domain-based task categorization with sensible names
- **Test Case Adaptation**: Ranjitha to assess compatibility with proposed changes
- **White Paper Decision**: Islam's question about Spark documentation detail level (bullet points vs comprehensive)

### Success Metrics & Performance Targets

#### Quantitative Goals
- **Processing Time**: 30-50% reduction in overall job execution time
- **Memory Usage**: 40-60% reduction in peak memory consumption (from current 15+ million record in-memory processing)
- **System Stability**: 99.9% job completion rate with proper termination
- **Resource Utilization**: Improved CPU and I/O efficiency through database-centric processing

#### Operational Improvements
- **Deployment Frequency**: Faster release cycles through improved Spring Batch testing
- **Error Recovery**: Reduced manual intervention through better job termination handling
- **System Monitoring**: Enhanced visibility into job performance and bottleneck identification
- **Maintenance Efficiency**: Simplified troubleshooting through improved logging and comprehensive documentation

---

**Next Steps**: Team to proceed with Phase 1 database migration foundation while maintaining system stability and business alignment. Regular progress updates through established communication channels with focus on performance metrics and stakeholder feedback integration.
