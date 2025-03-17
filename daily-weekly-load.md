# Entity Service Deployment Guide for OpenShift

This guide outlines the steps to deploy the Entity Service (for Daily and Weekly E file loading to Oracle Database) to an OpenShift container, including Splunk and SMTP integration.

## Table of Contents
- [Pre-Deployment Preparation](#pre-deployment-preparation)
- [Deployment Steps](#deployment-steps)
- [Splunk Integration](#splunk-integration)
- [SMTP Configuration](#smtp-configuration)
- [Load Job Scheduling](#load-job-scheduling)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Verification and Testing](#verification-and-testing)

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

### 3. Configure Splunk Forwarder Sidecar (Optional for direct integration)

```yaml
# Add this container to your pod template if you need a dedicated Splunk forwarder
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

## SMTP Configuration

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

## Post-Deployment Configuration

### 1. Configure Horizontal Pod Autoscaling (optional)

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

## Load Job Scheduling

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

## TSD:

![Openshift-TSD-Daily-Weekly-2025-03-17-132335](https://github.com/user-attachments/assets/aac4509f-47da-4f92-8ce6-8d31a37616e5)


