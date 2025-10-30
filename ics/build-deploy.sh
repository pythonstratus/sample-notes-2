#!/bin/bash

# ============================================================================
# ICS Zip Processor - Build and Deployment Script
# ============================================================================
# This script helps with building, testing, and deploying the application
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="ics-zip-processor"
REGISTRY="your-registry"  # Update this
NAMESPACE="your-namespace"  # Update this for OpenShift

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Build Functions
# ============================================================================

clean_build() {
    print_header "Cleaning Previous Build"
    mvn clean
    print_info "Clean completed"
}

build_application() {
    print_header "Building Application"
    mvn clean package -DskipTests
    
    if [ -f "target/${APP_NAME}.jar" ]; then
        print_info "Build successful: target/${APP_NAME}.jar"
    else
        print_error "Build failed - JAR not found"
        exit 1
    fi
}

run_tests() {
    print_header "Running Tests"
    mvn test
    print_info "Tests completed"
}

build_docker_image() {
    print_header "Building Docker Image"
    
    local version=${1:-latest}
    local image_name="${REGISTRY}/${APP_NAME}:${version}"
    
    print_info "Building image: ${image_name}"
    docker build -t ${image_name} .
    
    print_info "Tagging as latest"
    docker tag ${image_name} ${REGISTRY}/${APP_NAME}:latest
    
    print_info "Docker image built successfully"
}

push_docker_image() {
    print_header "Pushing Docker Image to Registry"
    
    local version=${1:-latest}
    local image_name="${REGISTRY}/${APP_NAME}:${version}"
    
    print_info "Pushing: ${image_name}"
    docker push ${image_name}
    
    if [ "${version}" != "latest" ]; then
        print_info "Pushing: ${REGISTRY}/${APP_NAME}:latest"
        docker push ${REGISTRY}/${APP_NAME}:latest
    fi
    
    print_info "Docker image pushed successfully"
}

# ============================================================================
# Deployment Functions
# ============================================================================

deploy_to_openshift() {
    print_header "Deploying to OpenShift"
    
    print_info "Creating/updating secrets and configmaps"
    oc apply -f openshift-secrets-configmap.yaml -n ${NAMESPACE}
    
    print_info "Deploying application"
    oc apply -f openshift-deployment.yaml -n ${NAMESPACE}
    
    print_info "Waiting for deployment to complete..."
    oc rollout status deployment/${APP_NAME} -n ${NAMESPACE}
    
    print_info "Deployment completed successfully"
    
    # Get the route
    local route=$(oc get route ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.host}')
    print_info "Application URL: https://${route}"
}

check_deployment() {
    print_header "Checking Deployment Status"
    
    print_info "Pod status:"
    oc get pods -l app=${APP_NAME} -n ${NAMESPACE}
    
    print_info "Service status:"
    oc get svc ${APP_NAME} -n ${NAMESPACE}
    
    print_info "Route:"
    oc get route ${APP_NAME} -n ${NAMESPACE}
    
    # Test health endpoint
    local route=$(oc get route ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.host}')
    print_info "Testing health endpoint..."
    curl -s https://${route}/ics-zip-processor/actuator/health | jq '.' || echo "Health check endpoint not yet available"
}

view_logs() {
    print_header "Viewing Application Logs"
    oc logs -f deployment/${APP_NAME} -n ${NAMESPACE}
}

# ============================================================================
# Utility Functions
# ============================================================================

run_locally() {
    print_header "Running Application Locally"
    
    if [ ! -f "target/${APP_NAME}.jar" ]; then
        print_warning "JAR not found, building first..."
        build_application
    fi
    
    print_info "Starting application..."
    java -jar target/${APP_NAME}.jar --spring.profiles.active=dev
}

trigger_job() {
    print_header "Triggering ICS Zip Processing Job"
    
    local route=${1:-localhost:8080}
    local url="http://${route}/ics-zip-processor/api/ics-zip/trigger"
    
    print_info "Triggering job at: ${url}"
    
    response=$(curl -s -X POST ${url})
    echo ${response} | jq '.'
    
    execution_id=$(echo ${response} | jq -r '.executionId')
    
    if [ "${execution_id}" != "null" ]; then
        print_info "Job triggered with execution ID: ${execution_id}"
        print_info "Check status: ${url}/status/${execution_id}"
    fi
}

check_job_status() {
    print_header "Checking Job Status"
    
    local route=${1:-localhost:8080}
    local execution_id=${2}
    
    if [ -z "${execution_id}" ]; then
        # Get latest
        local url="http://${route}/ics-zip-processor/api/ics-zip/status/latest"
    else
        local url="http://${route}/ics-zip-processor/api/ics-zip/status/${execution_id}"
    fi
    
    print_info "Checking status at: ${url}"
    curl -s ${url} | jq '.'
}

# ============================================================================
# Main Menu
# ============================================================================

show_menu() {
    echo ""
    print_header "ICS Zip Processor - Build & Deployment Tool"
    echo ""
    echo "Build Commands:"
    echo "  1. Build Application (Maven)"
    echo "  2. Run Tests"
    echo "  3. Build Docker Image"
    echo "  4. Push Docker Image"
    echo ""
    echo "Deployment Commands:"
    echo "  5. Deploy to OpenShift"
    echo "  6. Check Deployment Status"
    echo "  7. View Logs"
    echo ""
    echo "Local Development:"
    echo "  8. Run Locally"
    echo "  9. Trigger Job (Local)"
    echo " 10. Check Job Status (Local)"
    echo ""
    echo "Complete Workflows:"
    echo " 11. Full Build (Clean + Build + Test + Docker)"
    echo " 12. Full Deploy (Build + Push + Deploy)"
    echo ""
    echo "  q. Quit"
    echo ""
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1) build_application ;;
                2) run_tests ;;
                3) 
                    read -p "Enter version (default: latest): " version
                    build_docker_image ${version:-latest}
                    ;;
                4) 
                    read -p "Enter version (default: latest): " version
                    push_docker_image ${version:-latest}
                    ;;
                5) deploy_to_openshift ;;
                6) check_deployment ;;
                7) view_logs ;;
                8) run_locally ;;
                9) trigger_job "localhost:8080" ;;
                10) 
                    read -p "Enter execution ID (or leave empty for latest): " exec_id
                    check_job_status "localhost:8080" ${exec_id}
                    ;;
                11)
                    clean_build
                    build_application
                    run_tests
                    read -p "Enter version (default: latest): " version
                    build_docker_image ${version:-latest}
                    ;;
                12)
                    build_application
                    read -p "Enter version (default: latest): " version
                    build_docker_image ${version:-latest}
                    push_docker_image ${version:-latest}
                    deploy_to_openshift
                    ;;
                q|Q) 
                    print_info "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option"
                    ;;
            esac
            
            echo ""
            read -p "Press Enter to continue..."
        done
    else
        # Command-line mode
        case $1 in
            build) build_application ;;
            test) run_tests ;;
            docker) build_docker_image ${2:-latest} ;;
            push) push_docker_image ${2:-latest} ;;
            deploy) deploy_to_openshift ;;
            status) check_deployment ;;
            logs) view_logs ;;
            run) run_locally ;;
            trigger) trigger_job ${2:-localhost:8080} ;;
            check) check_job_status ${2:-localhost:8080} ${3} ;;
            *)
                echo "Usage: $0 [command] [options]"
                echo "Commands: build, test, docker, push, deploy, status, logs, run, trigger, check"
                echo "Or run without arguments for interactive mode"
                exit 1
                ;;
        esac
    fi
}

# Run main
main "$@"
