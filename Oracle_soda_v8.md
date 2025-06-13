# Oracle SODA Spring Boot API

A Spring Boot application for accessing and querying Oracle Database using Oracle SODA (Simple Oracle Document Access) framework. This application demonstrates how to build high-performance REST APIs for JSON document operations and can handle large-scale datasets efficiently (10+ million records).

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup and Installation](#setup-and-installation)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [API Endpoints](#api-endpoints)
- [SODA CRUD Operations](#soda-crud-operations)
- [Testing Examples](#testing-examples)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This application provides RESTful APIs using Oracle SODA framework, offering:

- **High Performance**: Optimized for large-scale document operations (10+ million records)
- **Flexible Querying**: Advanced filtering with JSON-based query specifications
- **Complete CRUD Operations**: Create, Read, Update, and Delete JSON documents
- **Pagination**: Efficient data retrieval with configurable page sizes
- **JSON Response**: Clean JSON output for easy integration
- **Generic Framework**: Adaptable for any document collection and use case

### Oracle SODA Benefits

- **NoSQL-style operations** on Oracle Database
- **JSON document storage** with relational database benefits
- **ACID transactions** and enterprise features
- **SQL and NoSQL hybrid** approach
- **Automatic indexing** and query optimization

### Sample Use Cases

This application can be used for various document-based operations:
- **Financial Records**: Entity modifications, transactions, balances
- **User Profiles**: Customer data, preferences, activity logs
- **Product Catalogs**: Inventory, specifications, pricing
- **Audit Logs**: System events, changes, compliance tracking
- **IoT Data**: Sensor readings, device status, telemetry
- **Content Management**: Articles, metadata, workflows

## 🔧 Prerequisites

- **Java 11** or higher
- **Maven 3.6+**
- **Oracle Database 12c R2+** with SODA enabled
- **Oracle JDBC Driver**
- Access to ENTMOD table

## 🚀 Setup and Installation

### 1. Clone and Build

```bash
# Navigate to your project directory
cd oracle-soda-entmod

# Build the project
mvn clean package

# This creates: target/oracle-soda-demo-1.0.0.jar
```

### 2. Prepare Configuration

Create `application.properties` file in the same directory as your JAR:

```properties
# Server Configuration
server.port=8080

# Oracle Database Configuration
spring.datasource.url=jdbc:oracle:thin:@your-host:1521/your-service-name
spring.datasource.username=your_username
spring.datasource.password=your_password
spring.datasource.driver-class-name=oracle.jdbc.OracleDriver

# Connection Pool Settings
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000

# Logging Configuration
logging.level.com.example.sodademo=INFO
logging.level.oracle.soda=WARN
```

## ⚙️ Configuration

### Database Connection Formats

**For Oracle XE:**
```properties
spring.datasource.url=jdbc:oracle:thin:@localhost:1521/XE
```

**For Oracle with SID:**
```properties
spring.datasource.url=jdbc:oracle:thin:@localhost:1521:ORCL
```

**For Oracle Cloud/Service Name:**
```properties
spring.datasource.url=jdbc:oracle:thin:@//your-host:1521/your_service_name
```

### Environment Variables (Alternative)

```bash
export SPRING_DATASOURCE_URL="jdbc:oracle:thin:@your-host:1521/your-service"
export SPRING_DATASOURCE_USERNAME="your_username"
export SPRING_DATASOURCE_PASSWORD="your_password"
```

## 🏃 Running the Application

### Method 1: With application.properties file

```bash
# Place application.properties in same directory as JAR
java -jar oracle-soda-demo-1.0.0.jar
```

### Method 2: With command line arguments

```bash
java -jar oracle-soda-demo-1.0.0.jar \
  --spring.datasource.url="jdbc:oracle:thin:@your-host:1521/your-service" \
  --spring.datasource.username="your_username" \
  --spring.datasource.password="your_password"
```

### Method 3: With config directory

```bash
# Create config directory structure
mkdir config
# Place application.properties in config/
java -jar oracle-soda-demo-1.0.0.jar
```

The application will start on `http://localhost:8080`

## 🔌 API Endpoints

| Method | Endpoint | Description | Parameters |
|--------|----------|-------------|------------|
| GET | `/api/entmod/health` | Health check | None |
| GET | `/api/entmod/ro/{roId}` | Get by identifier | `roId`, `page`, `size` |
| GET | `/api/entmod/period` | Get by period range | `start`, `end`, `page`, `size` |
| GET | `/api/entmod/status/{status}/type/{type}` | Get by status and type | `status`, `type`, `page`, `size` |
| GET | `/api/entmod/balance/above/{amount}` | Get by threshold value | `amount`, `page`, `size` |
| GET | `/api/entmod/overdue` | Get overdue records | `asOfDate`, `page`, `size` |
| POST | `/api/entmod/filter` | Custom filter query | JSON body with filter |
| GET | `/api/entmod/count` | Get document count | `filter` (optional) |

## 🔄 SODA CRUD Operations

### Create Documents
```bash
# Insert a new document
curl -X POST http://localhost:8080/api/documents/insert \
  -H "Content-Type: application/json" \
  -d '{
    "ROID": 12345,
    "BALANCE": 1000.50,
    "STATUS": "ACTIVE",
    "TYPE": "A",
    "PERIOD": "2024-01-01"
  }'
```

### Read Documents
```bash
# Get documents with pagination
curl "http://localhost:8080/api/entmod/ro/12345?page=0&size=10"

# Get with custom filter
curl -X POST http://localhost:8080/api/entmod/filter \
  -H "Content-Type: application/json" \
  -d '{"filter": "{\"STATUS\": \"ACTIVE\"}", "page": 0, "size": 20}'
```

### Update Documents
```bash
# Update existing document by key
curl -X PUT http://localhost:8080/api/documents/{documentKey} \
  -H "Content-Type: application/json" \
  -d '{
    "ROID": 12345,
    "BALANCE": 1500.75,
    "STATUS": "UPDATED"
  }'
```

### Delete Documents
```bash
# Delete document by key
curl -X DELETE http://localhost:8080/api/documents/{documentKey}

# Delete documents by filter
curl -X DELETE http://localhost:8080/api/documents/filter \
  -H "Content-Type: application/json" \
  -d '{"filter": "{\"STATUS\": \"INACTIVE\"}"}'
```

## 🧪 Testing Examples

### 1. Health Check

```bash
curl http://localhost:8080/api/entmod/health
```

**Expected Response:**
```json
{
  "status": "UP",
  "service": "Oracle SODA API",
  "timestamp": "1686123456789"
}
```

### 2. Basic Document Operations

#### Get Documents by Identifier
```bash
# Get first 10 records for ID 12345
curl "http://localhost:8080/api/entmod/ro/12345?page=0&size=10"

# Get records 21-30 for ID 67890
curl "http://localhost:8080/api/entmod/ro/67890?page=2&size=10"
```

**Expected Response:**
```json
{
  "data": [
    {
      "EMODSID": 1001,
      "ROID": 12345,
      "PERIOD": "2023-12-31",
      "BALANCE": 15000.50,
      "STATUS": "ACTIVE",
      "TYPE": "A"
    }
  ],
  "pagination": {
    "page": 0,
    "size": 10,
    "totalCount": 150,
    "returned": 10,
    "hasMore": true
  },
  "roId": 12345
}
```

### 3. Date Range Queries

```bash
# Get records for 2023
curl "http://localhost:8080/api/entmod/period?start=2023-01-01&end=2023-12-31&page=0&size=20"

# Get records for Q1 2024
curl "http://localhost:8080/api/entmod/period?start=2024-01-01&end=2024-03-31&page=0&size=50"
```

### 4. Status and Type Filtering

```bash
# Get active type A records
curl "http://localhost:8080/api/entmod/status/ACTIVE/type/A?page=0&size=25"

# Get closed type B records
curl "http://localhost:8080/api/entmod/status/CLOSED/type/B?page=0&size=15"
```

### 5. Threshold-Based Queries

```bash
# Get records with balance > $50,000
curl "http://localhost:8080/api/entmod/balance/above/50000?page=0&size=30"

# Get high-value records > $1,000,000
curl "http://localhost:8080/api/entmod/balance/above/1000000?page=0&size=10"
```

### 6. Time-Based Filtering

```bash
# Get records overdue as of today
curl "http://localhost:8080/api/entmod/overdue?page=0&size=20"

# Get records overdue as of specific date
curl "http://localhost:8080/api/entmod/overdue?asOfDate=2024-01-01&page=0&size=50"
```

### 7. Advanced Custom Filtering

```bash
# Complex filter: Active records with recent periods
curl -X POST http://localhost:8080/api/entmod/filter \
  -H "Content-Type: application/json" \
  -d '{
    "filter": "{\"$and\": [{\"ROID\": 12345}, {\"STATUS\": \"ACTIVE\"}, {\"PERIOD\": {\"$gte\": \"2023-01-01\"}}]}",
    "page": 0,
    "size": 25
  }'

# Filter by multiple identifiers
curl -X POST http://localhost:8080/api/entmod/filter \
  -H "Content-Type: application/json" \
  -d '{
    "filter": "{\"ROID\": {\"$in\": [12345, 67890, 11111]}}",
    "page": 0,
    "size": 100
  }'

# Filter by value range
curl -X POST http://localhost:8080/api/entmod/filter \
  -H "Content-Type: application/json" \
  -d '{
    "filter": "{\"BALANCE\": {\"$gte\": 10000, \"$lte\": 100000}}",
    "page": 0,
    "size": 50
  }'

# Text search with regex
curl -X POST http://localhost:8080/api/entmod/filter \
  -H "Content-Type: application/json" \
  -d '{
    "filter": "{\"STATUS\": {\"$regex\": \"ACT.*\"}}",
    "page": 0,
    "size": 30
  }'
```

### 8. Document Counting

```bash
# Total count
curl "http://localhost:8080/api/entmod/count"

# Count with filter
curl "http://localhost:8080/api/entmod/count?filter={\"STATUS\":\"ACTIVE\"}"
```

### 9. CRUD Operations Examples

#### Create Documents
```bash
# Insert a new document
curl -X POST http://localhost:8080/api/documents/insert \
  -H "Content-Type: application/json" \
  -d '{
    "ROID": 99999,
    "BALANCE": 2500.00,
    "STATUS": "NEW",
    "TYPE": "C",
    "PERIOD": "2024-06-01",
    "DUEDATE": "2024-07-01"
  }'
```

#### Update Documents
```bash
# Update document by key
curl -X PUT http://localhost:8080/api/documents/ABC123DEF456 \
  -H "Content-Type: application/json" \
  -d '{
    "BALANCE": 3000.00,
    "STATUS": "UPDATED"
  }'
```

#### Delete Documents
```bash
# Delete single document
curl -X DELETE http://localhost:8080/api/documents/ABC123DEF456

# Delete multiple documents by filter
curl -X DELETE http://localhost:8080/api/documents/filter \
  -H "Content-Type: application/json" \
  -d '{"filter": "{\"STATUS\": \"DELETED\"}"}'
```

## 📊 Performance Testing Examples

### Load Testing with Multiple Identifiers

```bash
# Test concurrent requests
for i in {12345..12355}; do
  curl "http://localhost:8080/api/entmod/ro/$i?page=0&size=100" &
done
wait
```

### Large Dataset Pagination

```bash
# Test pagination through large dataset
for page in {0..10}; do
  echo "Testing page $page"
  curl "http://localhost:8080/api/entmod/ro/12345?page=$page&size=500"
  sleep 1
done
```

### Performance Monitoring

```bash
# Monitor response times
time curl "http://localhost:8080/api/entmod/ro/12345?page=0&size=1000"

# Test with various page sizes
for size in 10 50 100 500 1000; do
  echo "Testing page size: $size"
  time curl "http://localhost:8080/api/entmod/ro/12345?page=0&size=$size" > /dev/null
done
```

## 🚀 Performance Optimization

### Database Indexes (Critical for Large Datasets)

Execute these SQL statements for optimal performance with large collections:

```sql
-- Essential indexes for common queries
CREATE INDEX IDX_COLLECTION_FIELD1 ON your_collection (JSON_VALUE(JSON_DOCUMENT, '$.FIELD1'));
CREATE INDEX IDX_COLLECTION_FIELD2 ON your_collection (JSON_VALUE(JSON_DOCUMENT, '$.FIELD2'));
CREATE INDEX IDX_COLLECTION_STATUS ON your_collection (JSON_VALUE(JSON_DOCUMENT, '$.STATUS'));
CREATE INDEX IDX_COLLECTION_DATE ON your_collection (JSON_VALUE(JSON_DOCUMENT, '$.DATE_FIELD'));
CREATE INDEX IDX_COLLECTION_AMOUNT ON your_collection (JSON_VALUE(JSON_DOCUMENT, '$.AMOUNT_FIELD'));

-- Composite indexes for common query patterns
CREATE INDEX IDX_COLLECTION_FIELD1_DATE ON your_collection (
    JSON_VALUE(JSON_DOCUMENT, '$.FIELD1'),
    JSON_VALUE(JSON_DOCUMENT, '$.DATE_FIELD')
);

CREATE INDEX IDX_COLLECTION_STATUS_TYPE ON your_collection (
    JSON_VALUE(JSON_DOCUMENT, '$.STATUS'),
    JSON_VALUE(JSON_DOCUMENT, '$.TYPE')
);

-- Enable JSON search index for text-based searches
CREATE SEARCH INDEX collection_search_idx ON your_collection (JSON_DOCUMENT) FOR JSON;
```

### Example ENTMOD-Specific Indexes

For ENTMOD table specifically, use these indexes:

```sql
-- ENTMOD specific indexes
CREATE INDEX IDX_ENTMOD_ROID ON entmod_collection (JSON_VALUE(JSON_DOCUMENT, '$.ROID'));
CREATE INDEX IDX_ENTMOD_PERIOD ON entmod_collection (JSON_VALUE(JSON_DOCUMENT, '$.PERIOD'));
CREATE INDEX IDX_ENTMOD_STATUS ON entmod_collection (JSON_VALUE(JSON_DOCUMENT, '$.STATUS'));
CREATE INDEX IDX_ENTMOD_BALANCE ON entmod_collection (JSON_VALUE(JSON_DOCUMENT, '$.BALANCE'));
CREATE INDEX IDX_ENTMOD_DUEDATE ON entmod_collection (JSON_VALUE(JSON_DOCUMENT, '$.DUEDATE'));
```

### Recommended Settings

**Application Properties for Production:**
```properties
# Optimized connection pool for high volume
spring.datasource.hikari.maximum-pool-size=50
spring.datasource.hikari.minimum-idle=20
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=300000
spring.datasource.hikari.max-lifetime=1200000

# JVM options for large datasets
# Add to startup: -Xms4g -Xmx16g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

## 🔍 Troubleshooting

### Common Issues

**1. Connection Refused**
```bash
# Check if Oracle is running
lsnrctl status

# Verify connection string format
# For XE: jdbc:oracle:thin:@localhost:1521/XE
# For SID: jdbc:oracle:thin:@localhost:1521:ORCL
```

**2. SODA Collection Not Found / DBMS_SODA_ADMIN Error**

This error occurs when your Oracle user doesn't have SODA privileges. Execute these commands as SYSDBA or privileged user:

```sql
-- Connect as SYSDBA
sqlplus / as sysdba

-- If using Pluggable Database (PDB), connect to it first
ALTER SESSION SET CONTAINER = your_pdb_name;

-- Grant SODA privileges to your user
GRANT SODA_APP TO your_username;
GRANT CREATE TABLE TO your_username;
GRANT CREATE VIEW TO your_username;
GRANT CREATE SEQUENCE TO your_username;
GRANT CREATE INDEX TO your_username;

-- Grant unlimited quota on tablespace
ALTER USER your_username QUOTA UNLIMITED ON USERS;

-- Additional privileges for SODA operations
GRANT EXECUTE ON DBMS_SODA TO your_username;
GRANT EXECUTE ON DBMS_SODA_ADMIN TO your_username;

-- If using Oracle 19c or later
GRANT DB_DEVELOPER_ROLE TO your_username;

-- Verify SODA is enabled
SELECT * FROM DBA_USERS WHERE USERNAME = 'YOUR_USERNAME';
```

**For Oracle Cloud / Autonomous Database:**
```sql
-- Connect as ADMIN user
-- Grant SODA privileges
GRANT SODA_APP TO your_username;
GRANT DWROLE TO your_username;
GRANT UNLIMITED TABLESPACE TO your_username;
```

**Verify SODA Setup:**
```sql
-- Login as your user and test
SELECT * FROM USER_SODA_COLLECTIONS;

-- Test SODA functionality
BEGIN
  DBMS_SODA.CREATE_COLLECTION('test_collection');
END;
/

-- Clean up test
BEGIN
  DBMS_SODA.DROP_COLLECTION('test_collection');
END;
/
```

**3. Slow Queries**
```bash
# Check if indexes exist
# Monitor query execution times
# Reduce page size if needed (recommended: 100-500)
```

**4. Out of Memory Errors**
```bash
# Increase JVM memory
java -Xms2g -Xmx8g -jar oracle-soda-demo-1.0.0.jar

# Reduce page size
curl "http://localhost:8080/api/entmod/ro/12345?page=0&size=100"
```

**5. Connection Leak Detection**
```properties
# Add to application.properties to monitor connections
spring.datasource.hikari.leak-detection-threshold=60000
logging.level.com.zaxxer.hikari.pool.ProxyLeakTask=DEBUG
```

### Debugging Tips

**Enable Debug Logging:**
```properties
logging.level.com.example.sodademo=DEBUG
logging.level.oracle.soda=DEBUG
```

**Test Database Connectivity:**
```bash
# Test basic connectivity
curl http://localhost:8080/api/entmod/health

# Test count (should return quickly)
curl http://localhost:8080/api/entmod/count
```

## 📚 Additional Resources

- [Oracle SODA Documentation](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/)
- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/)
- [Oracle Database Performance Tuning](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/)

## 🤝 Support

For issues related to:
- **Application bugs**: Check application logs
- **Database connectivity**: Verify Oracle connection and SODA setup
- **Performance**: Review indexing and query patterns
- **Configuration**: Validate application.properties settings

---

**Note**: This application demonstrates Oracle SODA framework capabilities for high-performance document operations. The framework is generic and can be adapted for various use cases including financial records, user profiles, product catalogs, audit logs, IoT data, and content management. Proper indexing and configuration are essential for optimal performance with large datasets.
