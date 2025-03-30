// File: pom.xml
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
        <node.version>v16.17.0</node.version>
        <npm.version>8.15.0</npm.version>
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
            
            <!-- Frontend Maven Plugin -->
            <plugin>
                <groupId>com.github.eirslett</groupId>
                <artifactId>frontend-maven-plugin</artifactId>
                <version>1.12.1</version>
                <configuration>
                    <workingDirectory>${frontend.src.dir}</workingDirectory>
                    <installDirectory>${project.build.directory}</installDirectory>
                </configuration>
                <executions>
                    <!-- Install Node and NPM -->
                    <execution>
                        <id>install-node-and-npm</id>
                        <goals>
                            <goal>install-node-and-npm</goal>
                        </goals>
                        <configuration>
                            <nodeVersion>${node.version}</nodeVersion>
                            <npmVersion>${npm.version}</npmVersion>
                        </configuration>
                    </execution>
                    
                    <!-- Install dependencies -->
                    <execution>
                        <id>npm-install</id>
                        <goals>
                            <goal>npm</goal>
                        </goals>
                        <configuration>
                            <arguments>install</arguments>
                        </configuration>
                    </execution>
                    
                    <!-- Build frontend -->
                    <execution>
                        <id>npm-build</id>
                        <goals>
                            <goal>npm</goal>
                        </goals>
                        <configuration>
                            <arguments>run build</arguments>
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

2. Build and run the backend
   ```bash
   mvn spring-boot:run
   ```

3. In a separate terminal, build and run the frontend
   ```bash
   cd src/main/webapp
   npm install
   npm start
   ```

4. Access the application at http://localhost:3000

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




test-runner/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── testrunner/
│   │   │           ├── TestRunnerApplication.java
│   │   │           ├── config/
│   │   │           │   └── WebSocketConfig.java
│   │   │           ├── controller/
│   │   │           │   └── TestController.java
│   │   │           ├── model/
│   │   │           │   ├── TestJob.java
│   │   │           │   └── TestUpdate.java
│   │   │           └── service/
│   │   │               └── TestExecutionService.java
│   │   ├── resources/
│   │   │   └── application.properties
│   │   └── webapp/
│   │       ├── public/
│   │       │   └── index.html
│   │       ├── src/
│   │       │   ├── App.js
│   │       │   ├── App.css
│   │       │   ├── index.js
│   │       │   └── components/
│   │       │       └── TestPanel.js
│   │       └── package.json
├── pom.xml
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
└── README.md
