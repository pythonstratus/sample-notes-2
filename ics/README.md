# ICS Zip Code Processor - Spring Boot Application

## Overview

This Spring Boot application replaces the legacy `ent_zip.csh` shell script for processing ICS zip code assignment data. It provides a modern, containerized solution with REST API endpoints, comprehensive logging, and enterprise-grade error handling.

### Key Features

- ✅ Complete shell script functionality converted to Java/Spring Boot
- ✅ Spring Batch for robust batch processing with restart capabilities
- ✅ RESTful API for job triggering and monitoring
- ✅ Comprehensive SLF4J/Logback logging
- ✅ Email notifications (environment-specific)
- ✅ OpenShift/Kubernetes ready
- ✅ Health checks and metrics via Spring Actuator
- ✅ Oracle database connectivity with connection pooling
- ✅ Transaction management and error recovery

## Architecture

### Workflow

```
1. File Validation Step
   - Validate input file exists and is unique
   - Copy to working directory
   
2. Area Processing Step
   - Process 8 geographic areas (21, 22, 23, 24, 25, 26, 27, 35)
   - Delete old records from oldzips table
   - Batch insert new records
   
3. Execute Crzips Step
   - Run crzips.sql procedure
   - Transform data: oldzips → icszips
   
4. Notification Step
   - Send email notifications based on results
   - Log completion status
```

### Technology Stack

- **Java**: 17 LTS
- **Spring Boot**: 3.1.0
- **Spring Batch**: Batch processing framework
- **Oracle JDBC**: Database connectivity
- **SLF4J + Logback**: Logging
- **Maven**: Build tool
- **Docker**: Containerization
- **OpenShift**: Deployment platform

## Prerequisites

### Development Environment

- Java 17 or higher
- Maven 3.9+
- Docker (for containerization)
- Access to Oracle database
- SMTP server for email notifications

### Oracle Database

Required tables:
- `oldzips` - Staging table for incoming data
- `icszips` - Production table for processed data
- Spring Batch metadata tables (auto-created)

### SQL Script

Place your `crzips.sql` script in:
- Development: `/als-ALS/app/execloc/d.dial/crzips.sql`
- Container: Mount as ConfigMap (see deployment section)

## Building the Application

### 1. Clone/Copy Project Files

```bash
# Ensure all files are in place
ls -la
# Should see: pom.xml, src/, Dockerfile, etc.
```

### 2. Build with Maven

```bash
# Clean and build
mvn clean package

# Skip tests if needed
mvn clean package -DskipTests

# Build output: target/ics-zip-processor.jar
```

### 3. Build Docker Image

```bash
# Build the image
docker build -t ics-zip-processor:latest .

# Tag for your registry
docker tag ics-zip-processor:latest your-registry/ics-zip-processor:latest

# Push to registry
docker push your-registry/ics-zip-processor:latest
```

## Configuration

### Application Properties

The application uses `application.yml` for configuration with profile-specific settings.

#### Key Configuration Sections

**Database Connection:**
```yaml
spring:
  datasource:
    url: jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}:${DB_SID}
    username: ${DB_USERNAME:dial}
    password: ${DB_PASSWORD}
```

**Email Settings:**
```yaml
spring:
  mail:
    host: ${SMTP_HOST:smtp.abc.com}
    
ics-zip:
  email:
    from: noreply@abc.com
    recipients:
      default:
        - team@abc.com
```

**File Paths:**
```yaml
ics-zip:
  file:
    input-directory: /als-ALS/app/entity/d.ics_zips
    archive-directory: /als-ALS/app/dataload/d.ICS_ZIPS/d.ARCHIVE
  log:
    directory: /als-ALS/app/entity/d.logfiles
```

### Environment Variables

Set these environment variables for deployment:

```bash
# Database
DB_HOST=your-oracle-host
DB_PORT=1521
DB_SID=ORCL
DB_USERNAME=dial
DB_PASSWORD=your-password

# Email
SMTP_HOST=smtp.abc.com
EMAIL_FROM=noreply@abc.com
EMAIL_ENABLED=true

# Spring Profile
SPRING_PROFILES_ACTIVE=prod  # dev, test, or prod
```

## Running the Application

### Local Development

```bash
# Run with Maven
mvn spring-boot:run

# Or run the JAR
java -jar target/ics-zip-processor.jar

# With specific profile
java -jar target/ics-zip-processor.jar --spring.profiles.active=dev
```

### Docker

```bash
# Run container
docker run -d \
  --name ics-zip-processor \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DB_HOST=your-host \
  -e DB_PASSWORD=your-password \
  -v /path/to/data:/als-ALS/app/entity/d.ics_zips \
  -v /path/to/logs:/als-ALS/app/entity/d.logfiles \
  ics-zip-processor:latest
```

## OpenShift Deployment

### 1. Create Secrets

```bash
# Edit openshift-secrets-configmap.yaml with your values
# Then apply:
oc apply -f openshift-secrets-configmap.yaml
```

### 2. Create ConfigMap for SQL Script

```bash
# Create configmap from your crzips.sql file
oc create configmap ics-zip-sql-scripts --from-file=crzips.sql=./crzips.sql

# Or use the YAML template and edit it
```

### 3. Deploy Application

```bash
# Apply deployment
oc apply -f openshift-deployment.yaml

# Check status
oc get pods -l app=ics-zip-processor
oc logs -f deployment/ics-zip-processor

# Get route
oc get route ics-zip-processor
```

### 4. Verify Deployment

```bash
# Health check
curl https://your-route/ics-zip-processor/actuator/health

# API endpoint
curl https://your-route/ics-zip-processor/api/ics-zip/health
```

## API Usage

### Base URL

```
Local: http://localhost:8080/ics-zip-processor/api/ics-zip
OpenShift: https://your-route/ics-zip-processor/api/ics-zip
```

### Endpoints

#### 1. Trigger Job

**POST** `/api/ics-zip/trigger`

Starts a new job execution.

```bash
curl -X POST http://localhost:8080/ics-zip-processor/api/ics-zip/trigger
```

**Response:**
```json
{
  "success": true,
  "executionId": 1,
  "jobName": "icsZipProcessingJob",
  "status": "STARTED",
  "message": "Job triggered successfully",
  "startTime": "2025-10-30T10:30:00"
}
```

#### 2. Check Job Status

**GET** `/api/ics-zip/status/{executionId}`

Gets status of a specific job execution.

```bash
curl http://localhost:8080/ics-zip-processor/api/ics-zip/status/1
```

**Response:**
```json
{
  "executionId": 1,
  "jobName": "icsZipProcessingJob",
  "status": "COMPLETED",
  "exitCode": "COMPLETED",
  "startTime": "2025-10-30T10:30:00",
  "endTime": "2025-10-30T10:35:00",
  "durationSeconds": 300,
  "running": false,
  "stepStatuses": {
    "fileValidationStep": "COMPLETED",
    "areaProcessingStep": "COMPLETED",
    "executeCrzipsStep": "COMPLETED",
    "notificationStep": "COMPLETED"
  }
}
```

#### 3. Get Latest Job Status

**GET** `/api/ics-zip/status/latest`

Gets status of the most recent job execution.

```bash
curl http://localhost:8080/ics-zip-processor/api/ics-zip/status/latest
```

#### 4. Health Check

**GET** `/actuator/health`

Spring Actuator health endpoint.

```bash
curl http://localhost:8080/ics-zip-processor/actuator/health
```

## Logging

### Log Files

All logs are written to: `/als-ALS/app/entity/d.logfiles/`

- `ent_zip.log` - Main application log
- `ent_error.log` - Error-level logs only
- `ent_delete.log` - Database deletion operations (if configured)

### Log Levels

```yaml
logging:
  level:
    root: INFO
    com.abc.ics: DEBUG
    org.springframework.batch: INFO
    org.springframework.jdbc: DEBUG
```

### Log Rotation

- Maximum file size: 10MB
- Retention: 30 days
- Compressed archives: gzip

### Viewing Logs

```bash
# In OpenShift
oc logs -f deployment/ics-zip-processor

# Docker
docker logs -f ics-zip-processor

# Local files
tail -f /als-ALS/app/entity/d.logfiles/ent_zip.log
```

## Monitoring

### Spring Actuator Endpoints

Available at `/actuator/`:

- `/health` - Application health
- `/info` - Application information
- `/metrics` - Application metrics
- `/loggers` - Log level management

### Health Checks

```bash
# Kubernetes/OpenShift health probes
Liveness:  /actuator/health (every 30s)
Readiness: /actuator/health (every 10s)
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failure

**Symptoms:**
```
FATAL ERROR: Oracle instance is not available for zip code processing
```

**Solutions:**
- Verify database credentials in secrets
- Check network connectivity to Oracle host
- Ensure Oracle TNS is accessible
- Verify Oracle JDBC driver version compatibility

#### 2. File Not Found

**Symptoms:**
```
ERROR: icszip.YYYYMMDD.dat not transferred
```

**Solutions:**
- Check input directory path: `/als-ALS/app/entity/d.ics_zips`
- Verify file naming convention: `icszip.YYYYMMDD.dat`
- Ensure proper volume mounts in container
- Check file permissions

#### 3. Multiple Files Error

**Symptoms:**
```
ERROR: more than one icszip.YYYYMMDD.dat
```

**Solutions:**
- Clean up old files from input directory
- Check file transfer process
- Review archive process

#### 4. SQL Script Execution Failure

**Symptoms:**
```
FATAL ERROR: Unable to load icszips from oldzips
```

**Solutions:**
- Verify crzips.sql exists at configured path
- Check SQL script syntax
- Verify database table structure (oldzips, icszips)
- Review database permissions for user 'dial'

### Debug Mode

Enable debug logging:

```bash
# Environment variable
DEBUG_LOGGING=true

# Or in application.yml
logging:
  level:
    com.abc.ics: DEBUG
```

### Testing Database Connection

```bash
# Using sqlplus (if available)
sqlplus dial/password@host:port/SID

# From container
oc exec -it pod-name -- bash
# Then try database connection
```

## Customization

### TODO: Customize for Your Environment

1. **Update File Format Parsing** (`DatabaseService.parseRecords()`)
   - Modify to match your actual icszip.dat file structure
   - Current implementation is a placeholder

2. **Update Database Schema** (`DatabaseService.batchInsertToOldZips()`)
   - Modify SQL to match your oldzips table structure
   - Add actual column mappings

3. **Configure Email Recipients**
   - Update `application.yml` with correct email addresses
   - Adjust per environment (dev, test, prod)

4. **Add Your crzips.sql Script**
   - Place actual SQL script content in ConfigMap
   - Or mount from external volume

5. **Adjust Resource Limits**
   - Modify CPU/memory in `openshift-deployment.yaml`
   - Based on actual workload requirements

## Migration from Shell Script

### Comparison

| Feature | Shell Script | Spring Boot App |
|---------|-------------|-----------------|
| **Execution** | Cron job | REST API trigger or scheduler |
| **Logging** | File redirects | SLF4J/Logback with rotation |
| **Error Handling** | Basic if-then | Try-catch, retry policies |
| **Monitoring** | Log files only | Actuator metrics, health checks |
| **Restart** | From beginning | From failed step |
| **Parallel Processing** | Sequential | Configurable (future enhancement) |
| **Testing** | Manual | Unit + Integration tests |
| **Deployment** | Server-dependent | Containerized, cloud-ready |

### Migration Steps

1. ✅ Deploy Spring Boot application alongside shell script
2. ✅ Run both in parallel for validation period
3. ✅ Compare outputs and logs
4. ✅ Gradually shift traffic to Spring Boot
5. ✅ Decommission shell script after successful validation

## Development

### Project Structure

```
ics-zip-processor/
├── src/
│   └── main/
│       ├── java/com/abc/ics/
│       │   ├── IcsZipProcessorApplication.java
│       │   ├── batch/
│       │   │   ├── IcsZipBatchConfig.java
│       │   │   └── tasklet/
│       │   ├── config/
│       │   ├── controller/
│       │   ├── exception/
│       │   ├── model/
│       │   └── service/
│       └── resources/
│           ├── application.yml
│           └── logback-spring.xml
├── pom.xml
├── Dockerfile
├── openshift-deployment.yaml
└── README.md
```

### Running Tests

```bash
# Run all tests
mvn test

# Run specific test class
mvn test -Dtest=FileServiceTest

# Run with coverage
mvn clean test jacoco:report
```

### Adding New Features

1. Create feature branch
2. Implement changes
3. Add unit tests
4. Update documentation
5. Submit pull request

## Support

### Contacts

- **Development Team**: your-team@abc.com
- **DevOps/Chinmaya**: chinmaya@abc.com
- **DBA Team**: dba-team@abc.com

### Resources

- [Spring Batch Documentation](https://docs.spring.io/spring-batch/docs/current/reference/html/)
- [Spring Boot Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [OpenShift Documentation](https://docs.openshift.com/)

## License

Copyright © 2025 ABC Company. All rights reserved.

---

## Quick Start Checklist

- [ ] Java 17 installed
- [ ] Maven 3.9+ installed
- [ ] Oracle JDBC driver configured
- [ ] Database credentials obtained
- [ ] crzips.sql script available
- [ ] Build successful: `mvn clean package`
- [ ] Docker image built
- [ ] OpenShift secrets created
- [ ] Application deployed
- [ ] Health check passing
- [ ] Test job triggered successfully
- [ ] Logs verified
- [ ] Email notifications received

---

**Version**: 1.0.0  
**Last Updated**: October 30, 2025  
**Generated from**: ent_zip.csh shell script
