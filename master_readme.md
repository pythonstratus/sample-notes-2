# Data Management Repository

A collection of SQL scripts and utilities for data warehouse management, ETL job scheduling, and data quality validation.

## Overview

This repository contains essential tools for managing data warehouse operations, including dimension table creation, data comparison utilities, and a comprehensive ETL job scheduling system.

## Repository Contents

### 1. Holiday and Date Dimension Management (`holiday_dates.md`)

**Purpose:** Manage calendar and holiday data for data warehouse operations.

**Key Components:**
- **`dim_date.sql`** - Creates and populates a comprehensive date dimension table
- Handles business calendars, holidays, and date calculations
- Essential for time-based reporting and ETL operations

**Use Cases:**
- Data warehouse date dimension creation
- Holiday calendar management
- Time-based data filtering and aggregation

### 2. Data Comparison and Validation (`compare_tables.md`)

**Purpose:** Comprehensive data quality and validation tools for comparing database tables and ensuring data integrity.

**Key Scripts:**
- **`compare_columns.sql`** - Compares column structures between tables
- **`compare_tables_excluder_columns.sql`** - Table comparison with selective column exclusion
- **`compare_tables_fn.sql`** - Function-based approach for automated table comparisons

**Use Cases:**
- Data migration validation
- ETL quality assurance
- Schema drift detection
- Database synchronization verification

### 3. ETL Job Scheduler & Management UI

**Purpose:** Complete Spring Boot application for scheduling, managing, and monitoring ETL jobs with a user-friendly web interface.

**Key Features:**
- **Job Scheduling:** Cron-based scheduling with flexible day/time configuration
- **Manual Execution:** On-demand job triggering for individual or grouped jobs
- **Real-time Monitoring:** Live status tracking and execution history
- **Secure Access:** OAuth2/OpenID Connect integration with OpenShift
- **Comprehensive Logging:** Detailed execution logs and error tracking

**Architecture:**
- Spring Boot 2.7.x with Java 11
- Oracle Database for persistence
- Bootstrap 5 responsive UI
- OpenShift container deployment
- RESTful API design

## Quick Start

### Date Dimension Setup
```sql
-- Execute the dim_date.sql script to create your date dimension
-- Customize holiday definitions as needed for your organization
```

### Data Validation
```sql
-- Use comparison scripts to validate data consistency
-- Example: Compare production vs staging tables
```

### ETL Scheduler Deployment
```bash
# Build and deploy the Spring Boot application
mvn clean package
# Deploy to OpenShift using provided YAML configurations
```

## Benefits

- **Standardized Date Management:** Consistent calendar and holiday handling across systems
- **Data Quality Assurance:** Automated validation tools to ensure data integrity
- **Centralized ETL Control:** Single interface for managing all ETL operations
- **Enterprise-Ready:** Production-ready tools with security and monitoring built-in
- **Scalable Architecture:** Container-based deployment with cloud-native design

## Technologies

- **Database:** Oracle Database, SQL
- **Backend:** Spring Boot, Spring Security, JPA/Hibernate
- **Frontend:** Thymeleaf, Bootstrap 5, JavaScript
- **Deployment:** Docker, OpenShift/Kubernetes
- **Security:** OAuth2/OpenID Connect

## Getting Started

1. **Set up Date Dimensions:** Start with `dim_date.sql` to establish your calendar foundation
2. **Implement Data Validation:** Use comparison scripts to ensure data quality
3. **Deploy ETL Scheduler:** Follow the deployment guide for centralized job management

## Documentation Structure

Each component includes detailed documentation with:
- Setup and configuration instructions
- Usage examples and best practices
- Troubleshooting guides
- API documentation (for the scheduler)

This repository provides a complete toolkit for enterprise data management, from foundational dimension tables to advanced ETL orchestration and monitoring capabilities.
