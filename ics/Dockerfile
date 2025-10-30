# Multi-stage build for ICS Zip Processor

# Stage 1: Build the application
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom.xml and download dependencies (cached layer)
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime image
FROM eclipse-temurin:17-jre-alpine

# Install required system utilities
RUN apk add --no-cache \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# Create application user (OpenShift compatibility)
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser

# Create required directories with proper permissions
RUN mkdir -p /als-ALS/app/entity/d.logfiles && \
    mkdir -p /als-ALS/app/entity/d.ics_zips && \
    mkdir -p /als-ALS/app/dataload/d.ICS_ZIPS/d.ARCHIVE && \
    mkdir -p /als-ALS/app/execloc/d.dial && \
    chown -R appuser:appgroup /als-ALS

# Set working directory
WORKDIR /app

# Copy JAR from build stage
COPY --from=build /app/target/ics-zip-processor.jar app.jar

# Copy SQL scripts (if needed)
# COPY crzips.sql /als-ALS/app/execloc/d.dial/

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user (OpenShift requirement)
USER 1001

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ics-zip-processor/actuator/health || exit 1

# JVM Options for container
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
