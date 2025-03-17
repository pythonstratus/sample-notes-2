# Entity Service Deployment Guide for OpenShift

This guide outlines the steps to deploy the Entity Service (for Daily and Weekly E file loading to Oracle Database) to an OpenShift container, including Splunk and SMTP integration. This guide incorporates the decisions and considerations from the March 17, 2025 planning meeting.

## Current Status
- Coding and testing are complete on entity services as the base project
- Dev pipeline is active (since mid-last week)
- Entity ConfigMap already exists in OpenShift
- Data source resources for ALS need to be created

## Table of Contents
- [Current Status](#current-status)
- [Architecture Overview](#architecture-overview)
- [Deployment Options](#deployment-options)
- [Pre-Deployment Preparation](#pre-deployment-preparation)
- [Deployment Steps](#deployment-steps)
- [Splunk Integration](#splunk-integration)
- [SMTP Configuration](#smtp-configuration)
- [Load Job Scheduling](#load-job-scheduling)
- [Resource Considerations](#resource-considerations)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Verification and Testing](#verification-and-testing)
- [CI/CD Configuration](#cicd-configuration)
- [Security Considerations](#security-considerations)
- [Responsibilities Matrix](#responsibilities-matrix)

## Architecture Overview

The Entity Service is a Spring Boot application that processes E files and loads them into an Oracle Database on a scheduled basis (daily and weekly). The application will be deployed to OpenShift and requires the following integrations:

- Oracle Database connectivity for data loading
- Splunk for centralized logging
- SMTP for email notifications
- Spring Batch for job processing
- File watcher for file pickup

## Deployment Options

Two options have been considered for running the jobs:

1. **Option 1: Integrated with Entity Service**
   - Deploy as part of the existing Entity Service application
   - Leverage existing infrastructure and CI/CD pipeline
   - Easier to maintain as a single application

2. **Option 2: Standalone Job**
   - Run as a separate bootable job in OpenShift
   - No hostname, routing, or HTTPS configuration needed
   - Uses OpenShift's native job functionality
   - Requires coordination with CI/CD to create another Spring Boot application

**Decision**: Initial implementation will be integrated with the Entity Service (Option 1) for testing. Resources will be increased to handle the processing load. The standalone job approach can be considered after performance testing.

## Pre-Deployment Preparation

1. **Containerize Your Application**
   - Create a Dockerfile for your Entity Service
   - Include all dependencies for Oracle connectivity (Oracle client libraries)
   - Set up environment variables for database connection strings
   - Configure logging for both Daily and Weekly loads

2. **Prepare Configuration Files**
   - Create OpenShift deployment YAML files
   - Prepare ConfigMaps for environment-specific configurations
   - Create Secrets for database credentials

## Deployment Steps

### 1. Login to OpenShift

```bash
oc login <openshift-api-url> --token=<your-auth-token>
# Or using username/password
oc login <openshift-api-url> -u <username> -p <password>
```

### 2. Create a New Project (if needed)

```bash
oc new-project entity-service
```

### 3. Create Secrets for Database Credentials

```bash
oc create secret generic oracle-credentials \
  --from-literal=username=<db-username> \
  --from-literal=password=<db-password> \
  --from-literal=connection-string=<oracle-connection-string>
```

### 4. Create ConfigMaps for Application Configuration

```bash
oc create configmap entity-service-config \
  --from-file=config/application.properties \
  --from-file=config/logback.xml
```

### 5. Create Persistent Volume Claims (if needed)

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: entity-service-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```

### 6. Deploy the Application

Create a deployment.yaml file:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: entity-service
  labels:
    app: entity-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: entity-service
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: entity-service
    spec:
      containers:
      - name: entity-service
        image: <your-registry>/entity-service:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        volumeMounts:
        - name: data-volume
          mountPath: /app/data
        - name: config-volume
          mountPath: /app/config
        - name: splunk-config-volume
          mountPath: /app/config/splunk
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: oracle-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: oracle-credentials
              key: password
        - name: DB_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: oracle-credentials
              key: connection-string
        - name: JAVA_OPTS
          value: "-Xms256m -Xmx512m"
        - name: DAILY_LOAD_CRON
          value: "0 1 * * *"
        - name: WEEKLY_LOAD_CRON
          value: "0 2 * * 0"
        # Splunk config
        - name: SPLUNK_HOST
          valueFrom:
            secretKeyRef:
              name: splunk-credentials
              key: splunk-host
        - name: SPLUNK_PORT
          valueFrom:
            secretKeyRef:
              name: splunk-credentials
              key: splunk-port
        - name: SPLUNK_TOKEN
          valueFrom:
            secretKeyRef:
              name: splunk-credentials
              key: splunk-token
        - name: SPLUNK_INDEX
          valueFrom:
            secretKeyRef:
              name: splunk-credentials
              key: splunk-index
        - name: ENABLE_SPLUNK_LOGGING
          value: "true"
        # SMTP config
        - name: SMTP_HOST
          valueFrom:
            secretKeyRef:
              name: smtp-credentials
              key: smtp-host
        - name: SMTP_PORT
          valueFrom:
            secretKeyRef:
              name: smtp-credentials
              key: smtp-port
        - name: SMTP_USERNAME
          valueFrom:
            secretKeyRef:
              name: smtp-credentials
              key: smtp-username
        - name: SMTP_PASSWORD
          valueFrom:
            secretKeyRef:
              name: smtp-credentials
              key: smtp-password
        - name: SMTP_FROM_ADDRESS
          valueFrom:
            secretKeyRef:
              name: smtp-credentials
              key: smtp-from-address
        - name: SMTP_TO_ADDRESSES
          valueFrom:
            secretKeyRef:
              name: smtp-credentials
              key: smtp-to-addresses
        - name: ENABLE_EMAIL_NOTIFICATIONS
          value: "true"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: entity-service-data
      - name: config-volume
        configMap:
          name: entity-service-config
      - name: splunk-config-volume
        configMap:
          name: splunk-config
```

Apply the deployment:

```bash
oc apply -f deployment.yaml
```

### 7. Create a Service

```bash
oc create service clusterip entity-service --tcp=8080:8080
```

### 8. Create a Route for External Access

```bash
oc create route edge entity-service --service=entity-service --port=8080
```

## Splunk Integration

> **Note**: Splunk is already set up for Phase 1. For Phase 2, access is granted via a portal provided by Jordan. Create a ticket for Splunk integration and work with Joyce (Splunk admin) for configuration.

### 1. Create Splunk Connection Secrets

```bash
oc create secret generic splunk-credentials \
  --from-literal=splunk-host=<splunk-hostname> \
  --from-literal=splunk-port=<splunk-port> \
  --from-literal=splunk-token=<splunk-hec-token> \
  --from-literal=splunk-index=<splunk-index-name>
```

### 2. Update ConfigMap for Splunk Configuration

```bash
oc create configmap splunk-config \
  --from-file=config/splunk-logging.properties
```

### 3. Splunk Forwarder Setup

The Splunk forwarder will read log files automatically if they're in the correct format. Joyce (Splunk admin) handles integration by using the hostname where the application is deployed.

```yaml
# Add this container to your pod template for Splunk forwarder integration
containers:
- name: splunk-forwarder
  image: splunk/universalforwarder:latest
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "400m"
  volumeMounts:
  - name: splunk-forwarder-config
    mountPath: /opt/splunkforwarder/etc/system/local
  - name: data-volume
    mountPath: /logs
    readOnly: true
  env:
  - name: SPLUNK_START_ARGS
    value: "--accept-license"
  - name: SPLUNK_DEPLOYMENT_SERVER
    valueFrom:
      secretKeyRef:
        name: splunk-credentials
        key: splunk-host

volumes:
- name: splunk-forwarder-config
  configMap:
    name: splunk-forwarder-config
```

### 4. Create a LoggingConfiguration for Splunk

```bash
oc apply -f - <<EOF
apiVersion: "logging.openshift.io/v1"
kind: ClusterLogForwarder
metadata:
  name: instance
  namespace: openshift-logging
spec:
  outputs:
  - name: splunk-entity-service
    type: splunk
    url: https://<splunk-host>:<splunk-port>
    secret:
      name: splunk-credentials
  pipelines:
  - name: entity-service-logs
    inputRefs:
    - application
    outputRefs:
    - splunk-entity-service
    labels:
      app: entity-service
EOF
```

### 5. Log Configuration Notes

- No Log4J vulnerability is being used
- Add log statements to integrate with Splunk
- Developers need a Splunk pair sequence for log review
- Log push frequency to the Splunk server can be configured

## SMTP Configuration

> **Note**: SMTP forwarder is sufficient to send emails outside the Iris network. Confirm with Yusuf if this functionality is available out of the box. SFTP is already configured in the code.

### 1. Create SMTP Connection Secrets

```bash
oc create secret generic smtp-credentials \
  --from-literal=smtp-host=<smtp-hostname> \
  --from-literal=smtp-port=<smtp-port> \
  --from-literal=smtp-username=<smtp-username> \
  --from-literal=smtp-password=<smtp-password> \
  --from-literal=smtp-from-address=<smtp-from-email> \
  --from-literal=smtp-to-addresses=<comma-separated-recipient-emails>
```

### 2. Update Application ConfigMap for SMTP settings

```bash
oc patch configmap entity-service-config --patch '{
  "data": {
    "mail.properties": "mail.smtp.auth=true\nmail.smtp.starttls.enable=true\nmail.smtp.timeout=5000\nmail.smtp.connectiontimeout=5000\nmail.debug=false\nmail.transport.protocol=smtp"
  }
}'
```

### 3. Configure Email Notifications for Job Status

```bash
oc apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: entity-service-notify-template
  annotations:
    notifications.openshift.io/smtp-template: |
      Subject: Entity Service Job {{.Name}} - {{.Status}}
      Body: |
        Job Details:
        - Name: {{.Name}}
        - Namespace: {{.Namespace}}
        - Status: {{.Status}}
        - Start Time: {{.StartTime}}
        - Completion Time: {{.CompletionTime}}
        
        {{if eq .Status "Failed"}}
        Error Message: {{.ErrorMessage}}
        
        Please check the logs for more details.
        {{else}}
        Job completed successfully.
        
        Summary:
        - Files Processed: {{.ProcessedFiles}}
        - Records Loaded: {{.LoadedRecords}}
        {{end}}
EOF
```

### 4. Spring Configuration for SMTP

Configure Spring Email properties in the application:

```yaml
spring:
  mail:
    host: ${SMTP_HOST}
    port: ${SMTP_PORT}
    username: ${SMTP_USERNAME}
    password: ${SMTP_PASSWORD}
    properties:
      mail:
        smtp:
          auth: true
          starttls:
            enable: true
```

### 5. Testing SMTP

After deployment, perform a router test to verify email functionality:

```bash
# Test email functionality
oc exec deploy/entity-service -- curl -X POST http://localhost:8080/api/test/email \
  -H "Content-Type: application/json" \
  -d '{"subject":"Test Email","body":"Testing SMTP integration"}'
```

## Resource Considerations

> **Note**: Resource requests or increases are not an issue. Resources can be adjusted as needed since multiple applications are running on the same container. Past core dump issues occurred when checking file sizes, so increase resources accordingly.

### 1. Configure Horizontal Pod Autoscaling

```bash
oc autoscale deployment/entity-service --min=2 --max=5 --cpu-percent=80
```

### 2. Set Up Network Policies

```bash
oc apply -f - <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: entity-service-network-policy
spec:
  podSelector:
    matchLabels:
      app: entity-service
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: api-gateway
EOF
```

### 3. Configure Resource Quotas

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: entity-service-quota
spec:
  hard:
    pods: "10"
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "6"
    limits.memory: "12Gi"
EOF
```

### 4. Increase Resources for Processing Jobs

For the Entity Service processing E files, increase CPU and memory resources:

```yaml
resources:
  requests:
    memory: "1Gi"    # Increased from 512Mi
    cpu: "1000m"     # Increased from 500m
  limits:
    memory: "2Gi"    # Increased from 1Gi
    cpu: "2000m"     # Increased from 1000m
```

## Load Job Scheduling

> **Note**: The Entity Service uses Spring Batch for job processing and a file watcher to pick up files. There is an existing merge job running as a cron job every night at 2:30 AM that can be used as a reference.

### 1. Configure CronJobs for Data Loading

For Daily Load:
```bash
oc apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: entity-service-daily-load
spec:
  schedule: "0 1 * * *"  # 1:00 AM daily
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: entity-service-daily-job
            image: <your-registry>/entity-service:latest
            command: ["java", "-jar", "/app/entity-service.jar", "--job=daily-load"]
            env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: password
            - name: DB_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: connection-string
            # SMTP env vars for notifications
            - name: SMTP_HOST
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-host
            - name: SMTP_PORT
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-port
            - name: SMTP_USERNAME
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-username
            - name: SMTP_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-password
            - name: SMTP_FROM_ADDRESS
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-from-address
            - name: SMTP_TO_ADDRESSES
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-to-addresses
            - name: NOTIFY_ON_COMPLETION
              value: "true"
            - name: NOTIFY_ON_FAILURE
              value: "true"
          restartPolicy: OnFailure
EOF
```

For Weekly Load:
```bash
oc apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: entity-service-weekly-load
spec:
  schedule: "0 2 * * 0"  # 2:00 AM on Sundays
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: entity-service-weekly-job
            image: <your-registry>/entity-service:latest
            command: ["java", "-jar", "/app/entity-service.jar", "--job=weekly-load"]
            env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: password
            - name: DB_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: oracle-credentials
                  key: connection-string
            # SMTP env vars for notifications
            - name: SMTP_HOST
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-host
            - name: SMTP_PORT
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-port
            - name: SMTP_USERNAME
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-username
            - name: SMTP_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-password
            - name: SMTP_FROM_ADDRESS
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-from-address
            - name: SMTP_TO_ADDRESSES
              valueFrom:
                secretKeyRef:
                  name: smtp-credentials
                  key: smtp-to-addresses
            - name: NOTIFY_ON_COMPLETION
              value: "true"
            - name: NOTIFY_ON_FAILURE
              value: "true"
          restartPolicy: OnFailure
EOF
```

## Monitoring and Maintenance

### 1. Set Up Monitoring

```bash
# Apply Prometheus ServiceMonitor
oc apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: entity-service-monitor
spec:
  selector:
    matchLabels:
      app: entity-service
  endpoints:
  - port: 8080
    path: /metrics
    interval: 30s
EOF
```

### 2. Configure Logging

```bash
# Ensure logs go to OpenShift logging stack
oc set env deployment/entity-service LOGGING_TYPE=json
```

## Verification and Testing

### 1. Verify Deployment
```bash
# Check all resources
oc get all -l app=entity-service

# View logs
oc logs deploy/entity-service

# Check CronJobs
oc get cronjobs
```

### 2. Test Endpoints
```bash
# Get the route URL
export ROUTE_URL=$(oc get route entity-service -o jsonpath='{.spec.host}')

# Test the health endpoint
curl https://$ROUTE_URL/health
```

### 3. Test Splunk Integration

```bash
# Generate test logs
oc exec deploy/entity-service -- curl -X POST http://localhost:8080/api/test/log \
  -H "Content-Type: application/json" \
  -d '{"level":"INFO","message":"Testing Splunk integration"}'

# Verify logs are appearing in Splunk
# Use Splunk query: index=<your-index> sourcetype=entity-service
```

### 4. Test Email Notification

```bash
# Test email functionality
oc exec deploy/entity-service -- curl -X POST http://localhost:8080/api/test/email \
  -H "Content-Type: application/json" \
  -d '{"subject":"Test Email","body":"Testing SMTP integration"}'
```

### 5. File Processing Test

To test the complete end-to-end flow, create the exact same folder structure on OpenShift and place test files there:

```bash
# Create persistent storage with folder structure matching local development
oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: entity-service-file-storage
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
EOF

# Mount this storage to the Entity Service pod
# Update deployment.yaml to include:
volumeMounts:
- name: file-storage
  mountPath: /app/file-input

volumes:
- name: file-storage
  persistentVolumeClaim:
    claimName: entity-service-file-storage

# Copy test files to the persistent storage
oc cp ./test-files/E5-daily.dat $(oc get pod -l app=entity-service -o name | head -1):/app/file-input/
```

## CI/CD Configuration

### 1. Pipeline Configuration
- Dev pipeline is active (since mid-last week)
- Deployments are watched due to potential CD issues
- CI/CD is set up to deploy by branch, not a specific branch

### 2. Security Scans
- Two security flags are currently disabled: scan security and quail action vulnerability
- These will be enabled soon, but might reveal issues that need fixing
- Previously, enabling these flags resulted in 400 issues in Phase 1

### 3. Notification Configuration
- Santosh has names of people in NCI CD configure
- Additional email IDs can be added to notify people if a build or deployment fails

## Responsibilities Matrix

| Task | Responsible Team/Person | Notes |
|------|------------------------|-------|
| Deploying the code | Job team | Code is already deployed in entity service |
| OpenShift segment deployment | Job team | Team needs to be confident with OpenShift deployment |
| Splunk integration | Team with Joyce | Create a ticket for Splunk integration |
| SMTP configuration | Yusuf | To provide feedback on SMTP configuration |
| Monitoring deployments | TBD | Need to designate responsible persons |
| Feedback on deployment issues | Santosh | Add more email IDs for notifications |
| Code quality checks | Santosh and Islam | Ensure developers check in code that builds |

This deployment guide covers all necessary steps for deploying your Entity Service to OpenShift with complete Splunk and SMTP integration. Adjust resource settings, scheduling, and configuration based on your specific requirements.

## TSD Diagram

![Openshift-TSD-Daily-Weekly-2025-03-17-134058](https://github.com/user-attachments/assets/ed89cae5-feb4-4171-a9f3-0ed3668e3544)
