// =============================================================================
// FILE: pom.xml
// =============================================================================
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>oracle-soda-demo</artifactId>
    <version>1.0.0</version>
    <name>Oracle SODA Demo</name>
    <description>Oracle SODA Spring Boot Demo Application</description>

    <properties>
        <java.version>11</java.version>
        <oracle.version>23.3.0.23.09</oracle.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-jdbc</artifactId>
        </dependency>

        <dependency>
            <groupId>com.oracle.database.jdbc</groupId>
            <artifactId>ojdbc11</artifactId>
            <version>${oracle.version}</version>
        </dependency>
        
        <dependency>
            <groupId>com.oracle.database.soda</groupId>
            <artifactId>orajsoda</artifactId>
            <version>${oracle.version}</version>
        </dependency>

        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>

// =============================================================================
// FILE: src/main/resources/application.properties
// =============================================================================
# Server Configuration
server.port=8080
server.servlet.context-path=/

# Oracle Database Configuration
spring.datasource.url=jdbc:oracle:thin:@localhost:1521:XE
spring.datasource.username=your_username
spring.datasource.password=your_password
spring.datasource.driver-class-name=oracle.jdbc.OracleDriver

# Connection Pool Settings
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=2
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000

# Logging Configuration
logging.level.com.example.sodademo=DEBUG
logging.level.oracle.soda=INFO
logging.pattern.console=%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n

// =============================================================================
// FILE: src/main/java/com/example/sodademo/SodaDemoApplication.java
// =============================================================================
package com.example.sodademo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SodaDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(SodaDemoApplication.class, args);
    }
}

// =============================================================================
// FILE: src/main/java/com/example/sodademo/config/SodaConfig.java
// =============================================================================
package com.example.sodademo.config;

import oracle.soda.OracleDatabase;
import oracle.soda.rdbms.OracleRDBMSClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

@Configuration
public class SodaConfig {

    @Autowired
    private DataSource dataSource;

    @Bean
    public OracleDatabase oracleDatabase() throws SQLException {
        Connection connection = dataSource.getConnection();
        OracleRDBMSClient client = new OracleRDBMSClient();
        return client.getDatabase(connection);
    }
}

// =============================================================================
// FILE: src/main/java/com/example/sodademo/model/DocumentModel.java
// =============================================================================
package com.example.sodademo.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class DocumentModel {
    @JsonProperty("id")
    private String id;
    
    @JsonProperty("name")
    private String name;
    
    @JsonProperty("email")
    private String email;
    
    @JsonProperty("department")
    private String department;
    
    @JsonProperty("salary")
    private Double salary;
    
    @JsonProperty("hire_date")
    private String hireDate;

    // Constructors
    public DocumentModel() {}

    public DocumentModel(String id, String name, String email, String department, Double salary, String hireDate) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.department = department;
        this.salary = salary;
        this.hireDate = hireDate;
    }

    // Getters and Setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public Double getSalary() { return salary; }
    public void setSalary(Double salary) { this.salary = salary; }

    public String getHireDate() { return hireDate; }
    public void setHireDate(String hireDate) { this.hireDate = hireDate; }

    @Override
    public String toString() {
        return "DocumentModel{" +
                "id='" + id + '\'' +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", department='" + department + '\'' +
                ", salary=" + salary +
                ", hireDate='" + hireDate + '\'' +
                '}';
    }
}

// =============================================================================
// FILE: src/main/java/com/example/sodademo/service/SodaService.java
// =============================================================================
package com.example.sodademo.service;

import oracle.soda.OracleCollection;
import oracle.soda.OracleDatabase;
import oracle.soda.OracleDocument;
import oracle.soda.OracleException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class SodaService {

    private static final Logger logger = LoggerFactory.getLogger(SodaService.class);

    @Autowired
    private OracleDatabase oracleDatabase;

    private static final String COLLECTION_NAME = "employees";

    // Get or create collection
    private OracleCollection getCollection() throws OracleException {
        logger.debug("Getting or creating collection: {}", COLLECTION_NAME);
        OracleCollection collection = oracleDatabase.openCollection(COLLECTION_NAME);
        if (collection == null) {
            logger.info("Collection {} does not exist, creating it", COLLECTION_NAME);
            collection = oracleDatabase.admin().createCollection(COLLECTION_NAME);
        }
        return collection;
    }

    // Retrieve all documents
    public List<String> getAllDocuments() throws OracleException {
        logger.debug("Retrieving all documents from collection: {}", COLLECTION_NAME);
        OracleCollection collection = getCollection();
        List<String> documents = new ArrayList<>();
        
        for (OracleDocument doc : collection.find().getDocuments()) {
            documents.add(doc.getContentAsString());
        }
        
        logger.info("Retrieved {} documents", documents.size());
        return documents;
    }

    // Retrieve document by key
    public String getDocumentByKey(String key) throws OracleException {
        logger.debug("Retrieving document by key: {}", key);
        OracleCollection collection = getCollection();
        OracleDocument doc = collection.findOne(key);
        
        if (doc != null) {
            logger.info("Document found for key: {}", key);
            return doc.getContentAsString();
        }
        logger.warn("Document not found for key: {}", key);
        return null;
    }

    // Retrieve documents with filter
    public List<String> getDocumentsByFilter(String filterSpec) throws OracleException {
        logger.debug("Retrieving documents with filter: {}", filterSpec);
        OracleCollection collection = getCollection();
        List<String> documents = new ArrayList<>();
        
        for (OracleDocument doc : collection.find().filter(filterSpec).getDocuments()) {
            documents.add(doc.getContentAsString());
        }
        
        logger.info("Retrieved {} documents with filter", documents.size());
        return documents;
    }

    // Retrieve documents by department
    public List<String> getDocumentsByDepartment(String department) throws OracleException {
        String filterSpec = "{\"department\": \"" + department + "\"}";
        logger.debug("Retrieving documents by department: {}", department);
        return getDocumentsByFilter(filterSpec);
    }

    // Retrieve documents with salary greater than specified amount
    public List<String> getDocumentsBySalaryGreaterThan(double salary) throws OracleException {
        String filterSpec = "{\"salary\": {\"$gt\": " + salary + "}}";
        logger.debug("Retrieving documents with salary greater than: {}", salary);
        return getDocumentsByFilter(filterSpec);
    }

    // Get document count
    public long getDocumentCount() throws OracleException {
        logger.debug("Getting document count for collection: {}", COLLECTION_NAME);
        OracleCollection collection = getCollection();
        long count = collection.find().count();
        logger.info("Document count: {}", count);
        return count;
    }

    // Get documents with pagination
    public List<String> getDocumentsWithPagination(int skip, int limit) throws OracleException {
        logger.debug("Retrieving documents with pagination - skip: {}, limit: {}", skip, limit);
        OracleCollection collection = getCollection();
        List<String> documents = new ArrayList<>();
        
        for (OracleDocument doc : collection.find().skip(skip).limit(limit).getDocuments()) {
            documents.add(doc.getContentAsString());
        }
        
        logger.info("Retrieved {} documents with pagination", documents.size());
        return documents;
    }
}

// =============================================================================
// FILE: src/main/java/com/example/sodademo/controller/SodaController.java
// =============================================================================
package com.example.sodademo.controller;

import com.example.sodademo.service.SodaService;
import oracle.soda.OracleException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/documents")
@CrossOrigin(origins = "*")
public class SodaController {

    private static final Logger logger = LoggerFactory.getLogger(SodaController.class);

    @Autowired
    private SodaService sodaService;

    // Health check endpoint
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Oracle SODA API");
        return ResponseEntity.ok(response);
    }

    // Get all documents
    @GetMapping
    public ResponseEntity<?> getAllDocuments() {
        try {
            logger.info("Request received to get all documents");
            List<String> documents = sodaService.getAllDocuments();
            
            Map<String, Object> response = new HashMap<>();
            response.put("documents", documents);
            response.put("count", documents.size());
            
            return ResponseEntity.ok(response);
        } catch (OracleException e) {
            logger.error("Error retrieving all documents", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error retrieving documents", e.getMessage()));
        }
    }

    // Get document by key
    @GetMapping("/{key}")
    public ResponseEntity<?> getDocumentByKey(@PathVariable String key) {
        try {
            logger.info("Request received to get document by key: {}", key);
            String document = sodaService.getDocumentByKey(key);
            
            if (document != null) {
                return ResponseEntity.ok(document);
            } else {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(createErrorResponse("Document not found", "No document found with key: " + key));
            }
        } catch (OracleException e) {
            logger.error("Error retrieving document by key: {}", key, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error retrieving document", e.getMessage()));
        }
    }

    // Get documents by department
    @GetMapping("/department/{department}")
    public ResponseEntity<?> getDocumentsByDepartment(@PathVariable String department) {
        try {
            logger.info("Request received to get documents by department: {}", department);
            List<String> documents = sodaService.getDocumentsByDepartment(department);
            
            Map<String, Object> response = new HashMap<>();
            response.put("documents", documents);
            response.put("department", department);
            response.put("count", documents.size());
            
            return ResponseEntity.ok(response);
        } catch (OracleException e) {
            logger.error("Error retrieving documents by department: {}", department, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error retrieving documents by department", e.getMessage()));
        }
    }

    // Get documents by salary greater than
    @GetMapping("/salary/gt/{salary}")
    public ResponseEntity<?> getDocumentsBySalary(@PathVariable double salary) {
        try {
            logger.info("Request received to get documents with salary > {}", salary);
            List<String> documents = sodaService.getDocumentsBySalaryGreaterThan(salary);
            
            Map<String, Object> response = new HashMap<>();
            response.put("documents", documents);
            response.put("filter_salary_gt", salary);
            response.put("count", documents.size());
            
            return ResponseEntity.ok(response);
        } catch (OracleException e) {
            logger.error("Error retrieving documents by salary > {}", salary, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error retrieving documents by salary", e.getMessage()));
        }
    }

    // Get documents with custom filter
    @PostMapping("/filter")
    public ResponseEntity<?> getDocumentsByFilter(@RequestBody Map<String, String> request) {
        try {
            String filterSpec = request.get("filter");
            if (filterSpec == null || filterSpec.trim().isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(createErrorResponse("Invalid request", "Filter specification is required"));
            }
            
            logger.info("Request received with custom filter: {}", filterSpec);
            List<String> documents = sodaService.getDocumentsByFilter(filterSpec);
            
            Map<String, Object> response = new HashMap<>();
            response.put("documents", documents);
            response.put("filter", filterSpec);
            response.put("count", documents.size());
            
            return ResponseEntity.ok(response);
        } catch (OracleException e) {
            logger.error("Error retrieving documents with custom filter", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error retrieving documents with filter", e.getMessage()));
        }
    }

    // Get document count
    @GetMapping("/count")
    public ResponseEntity<?> getDocumentCount() {
        try {
            logger.info("Request received to get document count");
            long count = sodaService.getDocumentCount();
            
            Map<String, Object> response = new HashMap<>();
            response.put("count", count);
            response.put("collection", "employees");
            
            return ResponseEntity.ok(response);
        } catch (OracleException e) {
            logger.error("Error getting document count", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error getting document count", e.getMessage()));
        }
    }

    // Get documents with pagination
    @GetMapping("/page")
    public ResponseEntity<?> getDocumentsWithPagination(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "10") int limit) {
        
        // Validate parameters
        if (skip < 0 || limit <= 0 || limit > 100) {
            return ResponseEntity.badRequest()
                    .body(createErrorResponse("Invalid parameters", 
                          "Skip must be >= 0, limit must be > 0 and <= 100"));
        }
        
        try {
            logger.info("Request received for pagination - skip: {}, limit: {}", skip, limit);
            List<String> documents = sodaService.getDocumentsWithPagination(skip, limit);
            
            Map<String, Object> response = new HashMap<>();
            response.put("documents", documents);
            response.put("pagination", Map.of(
                "skip", skip,
                "limit", limit,
                "returned", documents.size()
            ));
            
            return ResponseEntity.ok(response);
        } catch (OracleException e) {
            logger.error("Error retrieving documents with pagination", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(createErrorResponse("Error retrieving paginated documents", e.getMessage()));
        }
    }

    // Helper method to create error response
    private Map<String, Object> createErrorResponse(String error, String message) {
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("error", error);
        errorResponse.put("message", message);
        errorResponse.put("timestamp", System.currentTimeMillis());
        return errorResponse;
    }
}

// =============================================================================
// FILE: src/main/java/com/example/sodademo/exception/SodaExceptionHandler.java
// =============================================================================
package com.example.sodademo.exception;

import oracle.soda.OracleException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.context.request.WebRequest;

import java.util.HashMap;
import java.util.Map;

@ControllerAdvice
public class SodaExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(SodaExceptionHandler.class);

    @ExceptionHandler(OracleException.class)
    public ResponseEntity<Map<String, Object>> handleOracleException(
            OracleException ex, WebRequest request) {
        
        logger.error("Oracle SODA Exception occurred", ex);
        
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("error", "Database Operation Failed");
        errorResponse.put("message", ex.getMessage());
        errorResponse.put("timestamp", System.currentTimeMillis());
        errorResponse.put("path", request.getDescription(false));
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(
            Exception ex, WebRequest request) {
        
        logger.error("Unexpected exception occurred", ex);
        
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("error", "Internal Server Error");
        errorResponse.put("message", "An unexpected error occurred");
        errorResponse.put("timestamp", System.currentTimeMillis());
        errorResponse.put("path", request.getDescription(false));
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
}

// =============================================================================
// FILE: .gitignore
// =============================================================================
# Compiled class file
*.class

# Log file
*.log

# BlueJ files
*.ctxt

# Mobile Tools for Java (J2ME)
.mtj.tmp/

# Package Files #
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar

# virtual machine crash logs
hs_err_pid*

# Maven
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties
dependency-reduced-pom.xml
buildNumber.properties
.mvn/timing.properties
.mvn/wrapper/maven-wrapper.jar

# IDE
.idea/
*.iws
*.iml
*.ipr
.vscode/
.classpath
.project
.settings/

# Spring Boot
application-local.properties
application-dev.properties

# OS
.DS_Store
Thumbs.db
