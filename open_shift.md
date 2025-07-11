# OpenShift CLI (OC) User Guide

## Overview

The OpenShift CLI (oc) is the command-line interface for Red Hat OpenShift, a Kubernetes-based container platform. This tool allows you to interact with OpenShift clusters from the command line to develop, build, deploy, and run your applications.

## Installation and Setup

### Activate OpenShift CLI (OC)

Follow these steps to set up the OpenShift CLI on your Windows system:

#### Step 1: Create Directory Structure
Go to this path: `C:\Users\[YourSEID]\bin`

1. If the path exists, copy the `oc.exe` file to this location
2. If the path doesn't exist:
   - Create a new folder at `C:\Users\[YourSEID]\`
   - Rename the folder to "bin"

#### Step 2: Add to System PATH
Go to "Edit environment variables for your account"

1. Select "Path" 
2. Click on Edit button or double click the path
3. Click on New button and add this path: `C:\Users\[YourSEID]\bin`

#### Step 3: Install the Binary
Go to `C:\Users\[YourSEID]\bin` path and copy/paste the `oc.exe` file to this location.

### Verify Installation

Open a new command prompt and run:
```
C:\Users\[SEID]\bin>oc
```

You should see the OpenShift Client help information, confirming that the installation was successful.

## Authentication and Initial Setup

### Login to OpenShift Cluster

To authenticate with your OpenShift cluster, use the login command with your token:

```bash
oc login --token=sha256~qKZ1KQmQ4ioqn-yATzGlmSi7Lo1Jv9-7yPan2Qy-0YI --server=https://api.ecpdevtest.tcc.abc.com:6443
```

**Example Output:**
```
Logged into "https://api.ecpdevtest.tcc.abc.com:6443" as "[SEID]" using the token provided.
```

### View Available Projects

After logging in, you can see available projects:

```bash
oc project
```

**Example Output:**
```
You have access to the following projects and can switch between them with 'oc project <projectname>':

* devspaces-[SEID]
  sbse-als-aqt
  sbse-als-dev
```

### Switch Between Projects

To switch to a specific project:

```bash
oc project sbse-als-dev
```

**Example Output:**
```
Now using project "sbse-als-dev" on server "https://api.ecpdevtest.tcc.abc.com:6443".
```

## Common OpenShift CLI Commands

### Authentication and Connection
- `oc login` - Authenticate to an OpenShift cluster
- `oc whoami` - Show current user context
- `oc project` - Switch between or view current project/namespace

### Resource Management
- `oc get` - List resources (pods, services, deployments, etc.)
- `oc describe` - Show detailed information about resources
- `oc create` - Create resources from files or command line
- `oc apply` - Apply configuration changes
- `oc delete` - Remove resources

### Viewing Resources

#### List Pods
```bash
oc get pods
```

**Example Output:**
```
NAME                        READY   STATUS      RESTARTS   AGE
als-batch-29203650-gttrq    0/1     Completed   0          6h50m
als-service-5854c7f68-4kqzm 1/1     Running     0          30m
als-ui-5f698456d-kk78d      1/1     Running     0          18h
```

#### Execute Commands in Pods
```bash
oc exec entity-service-f5944ff66-gp66l -- ls -l /
```

**Example Output:**
```
total 12
lrwxrwxrwx. 1 root root     7 Jun 21 2021 bin -> usr/bin
dr-xr-xr-x. 2 root root     6 Jun 21 2021 boot
drwxr-xr-x. 3 root root    18 Apr 16 10:08 deployments
```

#### View Files in Pods
```bash
oc exec entity-service-f5944ff66-gp66l -- ls -l /eftu/entity/incoming
```

**Example Output:**
```
total 9933671
drwxrwsr-x. 2 1000940000 1000940000    2 Jun 10 22:13 0610
drwxrwsr-x. 2 1000940000 1000940000    1 Jun 17 22:48 0617
-rw-rw-r--. 1 1000940000 1000940000 2022592 Jun 17 03:05 Bkp_E3
-rw-rw-r--. 1 1000940000 1000940000     603 Jul 10 06:04 DlyLogLOAD.out
```

### Application Deployment
- `oc new-app` - Create new applications from source code, images, or templates
- `oc new-build` - Create build configurations
- `oc start-build` - Trigger builds

### OpenShift-Specific Features
- `oc new-project` - Create new projects (namespaces with additional OpenShift features)
- `oc expose` - Create routes to expose services externally
- `oc rollout` - Manage deployments and rollouts
- `oc adm` - Administrative commands

## File Transfer Operations

### Copy Files from Local to Pod

If you need to copy local files to a pod, use the `oc rsync` command:

```bash
oc rsync C:\Users\[SEID]\daily entity-service-f5944ff66-gp66l:/eftu/entity/incoming
```

**Note:** The `rsync` command requires additional setup on Windows. If you encounter the error "rsync command not found in path", you'll need to:

1. Download `cwRsync` for Windows
2. Add it to your system PATH
3. The command will then be able to sync files like `daily/sample.txt`

### Alternative File Transfer Methods

For simple file transfers, you can also use:
```bash
oc cp local-file pod-name:/remote-path
```

## Project Management

### Creating New Projects
```bash
oc new-project my-new-project
```

### Listing All Projects
```bash
oc get projects
```

### Getting Project Information
```bash
oc describe project project-name
```

## Troubleshooting

### Common Issues

1. **Authentication Problems**: Ensure your token is valid and the server URL is correct
2. **Path Issues**: Verify that the `oc.exe` file is in your system PATH
3. **Permission Errors**: Make sure you have appropriate permissions for the project you're trying to access
4. **Network Connectivity**: Ensure you can reach the OpenShift cluster server

### Useful Debugging Commands

```bash
# Check current context
oc whoami --show-context

# Check cluster info
oc cluster-info

# View events
oc get events

# Check resource usage
oc top pods
```

## Advanced Usage

### Working with YAML Files
```bash
# Apply configuration from file
oc apply -f my-config.yaml

# Export existing resource to YAML
oc get deployment my-app -o yaml > my-app.yaml
```

### Port Forwarding
```bash
# Forward local port to pod
oc port-forward pod-name 8080:8080
```

### Logs and Monitoring
```bash
# View pod logs
oc logs pod-name

# Follow logs in real-time
oc logs -f pod-name

# View logs from previous container instance
oc logs pod-name --previous
```

## Best Practices

1. **Always verify your current project** before executing commands
2. **Use specific resource names** to avoid accidental operations on wrong resources
3. **Regularly check your authentication status** with `oc whoami`
4. **Keep your CLI tool updated** to the latest version compatible with your cluster
5. **Use dry-run options** when testing commands: `oc apply --dry-run=client -f file.yaml`

## Getting Help

For more information about any command, use:
```bash
oc help
oc <command> --help
```

For example:
```bash
oc get --help
oc login --help
```

---

This guide provides the essential information needed to effectively use the OpenShift CLI tool. Remember that the oc tool is essentially a superset of kubectl with additional OpenShift-specific functionality, so many Kubernetes commands will also work with the oc tool.
