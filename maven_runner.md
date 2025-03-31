<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.10</version>
        <relativePath/>
    </parent>

    <groupId>com.testrunner</groupId>
    <artifactId>test-runner</artifactId>
    <version>1.0.0</version>
    <name>Test Runner</name>
    <description>Web interface for running Maven tests</description>

    <properties>
        <java.version>17</java.version>
        <frontend.src.dir>${project.basedir}/src/main/webapp</frontend.src.dir>
    </properties>

    <dependencies>
        <!-- Spring Boot -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-websocket</artifactId>
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
            
            <!-- Use existing npm and node for frontend build -->
            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>exec-maven-plugin</artifactId>
                <version>3.1.0</version>
                <executions>
                    <!-- Install dependencies -->
                    <execution>
                        <id>npm-install</id>
                        <phase>generate-resources</phase>
                        <goals>
                            <goal>exec</goal>
                        </goals>
                        <configuration>
                            <executable>npm</executable>
                            <arguments>
                                <argument>install</argument>
                            </arguments>
                            <workingDirectory>${frontend.src.dir}</workingDirectory>
                        </configuration>
                    </execution>
                    
                    <!-- Build frontend -->
                    <execution>
                        <id>npm-build</id>
                        <phase>generate-resources</phase>
                        <goals>
                            <goal>exec</goal>
                        </goals>
                        <configuration>
                            <executable>npm</executable>
                            <arguments>
                                <argument>run</argument>
                                <argument>build</argument>
                            </arguments>
                            <workingDirectory>${frontend.src.dir}</workingDirectory>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
            
            <!-- Copy frontend build to target -->
            <plugin>
                <artifactId>maven-resources-plugin</artifactId>
                <executions>
                    <execution>
                        <id>copy-resources</id>
                        <phase>prepare-package</phase>
                        <goals>
                            <goal>copy-resources</goal>
                        </goals>
                        <configuration>
                            <outputDirectory>${project.build.directory}/classes/static</outputDirectory>
                            <resources>
                                <resource>
                                    <directory>${frontend.src.dir}/build</directory>
                                    <filtering>false</filtering>
                                </resource>
                            </resources>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>

// File: README.md
# Test Runner Web Interface

A full-stack web application for running Maven tests with real-time feedback.

## Features

- Run daily, weekly, and monthly test jobs with a single click
- View real-time console output for each test job
- Monitor the status of multiple concurrent test jobs
- Modern, responsive UI with Bootstrap styling

## Tech Stack

- **Backend**: Java Spring Boot with WebSocket support
- **Frontend**: React.js with Bootstrap for styling
- **Communication**: WebSockets for real-time updates
- **Build**: Maven for the backend, npm for the frontend
- **Containerization**: Docker for easy deployment

## Prerequisites

- Java 17 or higher
- Maven 3.6 or higher
- Node.js 16 or higher and npm (for development)
- Docker and Docker Compose (for containerized deployment)

## Getting Started

### Development Setup

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/test-runner.git
   cd test-runner
   ```

2. Prepare the frontend dependencies (ensure you have Node.js and npm installed)
   ```bash
   cd src/main/webapp
   npm install
   ```

3. Return to the project root and build/run the application
   ```bash
   cd ../../../
   mvn spring-boot:run
   ```

4. For development mode with hot-reload on the frontend, you can also run:
   ```bash
   cd src/main/webapp
   npm start
   ```
   And access the dev server at http://localhost:3000

### Building for Production

1. Build the entire application with Maven
   ```bash
   mvn clean package
   ```

2. Run the packaged application
   ```bash
   java -jar target/test-runner-1.0.0.jar
   ```

3. Access the application at http://localhost:8080

### Using Docker

1. Build and run with Docker Compose
   ```bash
   docker-compose up --build
   ```

2. Access the application at http://localhost:8080

## Configuration

### Test Commands

Test commands are configured in the `application.properties` file. You can modify these properties to customize the commands:

```properties
# Test commands configuration
test.command.daily=mvn test -Dtest=DatabaseSnapshotServiceTest#testCreateSnapshotAndValidateForDailyTables
test.command.weekly=mvn test -Dtest=DatabaseSnapshotServiceTest#testCreateSnapshotAndValidateForWeeklyTables
test.command.monthly=mvn test -Dtest=DatabaseSnapshotServiceTest#testCreateSnapshotAndValidateForMonthlyTables
```

To add new test types, you'll need to:
1. Add the new command to `application.properties`
2. Update the `TestExecutionService.java` to handle the new command
3. Add the corresponding button in the React frontend

### Working Directory

If your Maven commands need to run in
