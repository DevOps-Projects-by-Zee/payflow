#!/bin/bash
# ============================================
# Deploy to Environment (Smart Detection)
# ============================================
# Purpose: Automatically detect and deploy to correct environment
# Usage: ./scripts/terraform/deploy-to-env.sh [local|aws|azure]
#
# What it does:
# 1. Detects environment (or uses provided)
# 2. Updates manifests for that environment
# 3. Builds/pushes images if needed
# 4. Deploys to Kubernetes
#
# This is the ONE command you run for any deployment!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Auto-detect environment
detect_environment() {
  # Check if kubectl context points to MicroK8s
  if kubectl config current-context 2>/dev/null | grep -q "microk8s\|local"; then
    echo "local"
    return
  fi
  
  # Check if kubectl context points to EKS
  if kubectl config current-context 2>/dev/null | grep -q "eks\|aws"; then
    echo "aws"
    return
  fi
  
  # Check if kubectl context points to AKS
  if kubectl config current-context 2>/dev/null | grep -q "aks\|azure"; then
    echo "azure"
    return
  fi
  
  # Check AWS credentials
  if aws sts get-caller-identity &>/dev/null; then
    log_warning "AWS credentials found, but kubectl context not set to EKS"
    log_warning "Assuming AWS deployment"
    echo "aws"
    return
  fi
  
  # Default to local
  log_warning "Could not detect environment, defaulting to local"
  echo "local"
}

ENVIRONMENT="${1:-$(detect_environment)}"

log_info "Detected environment: ${ENVIRONMENT}"

# Deploy based on environment
case "${ENVIRONMENT}" in
  local)
    log_info "Deploying to Local (MicroK8s)..."
    
    # Build images locally
    log_info "Building Docker images..."
    for service in api-gateway auth-service wallet-service transaction-service notification-service frontend; do
      docker build -t payflow/${service}:latest services/${service}
    done
    
    # Load into MicroK8s
    log_info "Loading images into MicroK8s..."
    for service in api-gateway auth-service wallet-service transaction-service notification-service frontend; do
      docker save payflow/${service}:latest | multipass exec microk8s-vm -- docker load 2>/dev/null || \
      docker tag payflow/${service}:latest localhost:32000/payflow/${service}:latest && \
      docker push localhost:32000/payflow/${service}:latest 2>/dev/null || true
    done
    
    # Deploy using local overlay
    log_info "Deploying to Kubernetes..."
    kubectl apply -k k8s/overlays/local
    
    log_success "Deployed to Local (MicroK8s)"
    ;;
    
  aws)
    log_info "Deploying to AWS (EKS)..."
    
    # Check if Terraform is deployed
    if [ ! -f "${PROJECT_ROOT}/terraform/environments/hub/.terraform/terraform.tfstate" ]; then
      log_error "Terraform infrastructure not deployed!"
      log_error "Please deploy infrastructure first:"
      log_error "  cd terraform/environments/hub"
      log_error "  terraform apply"
      exit 1
    fi
    
    # Update manifests with Terraform outputs
    log_info "Updating manifests with Terraform outputs..."
    "${SCRIPT_DIR}/update-k8s-for-aws.sh" hub
    
    # Build and push to ECR
    log_info "Building and pushing images to ECR..."
    "${SCRIPT_DIR}/build-push-ecr.sh" || {
      log_error "Failed to build/push images. Please check ECR access."
      exit 1
    }
    
    # Deploy using AWS overlay
    log_info "Deploying to EKS..."
    kubectl apply -k k8s/overlays/aws
    
    log_success "Deployed to AWS (EKS)"
    ;;
    
  azure)
    log_info "Deploying to Azure (AKS)..."
    
    # Update manifests for Azure
    log_info "Updating manifests for Azure..."
    "${SCRIPT_DIR}/update-k8s-for-azure.sh" || {
      log_warning "Azure update script not found, using base manifests"
    }
    
    # Build and push to ACR
    log_info "Building and pushing images to ACR..."
    "${SCRIPT_DIR}/build-push-acr.sh" || {
      log_error "Failed to build/push images. Please check ACR access."
      exit 1
    }
    
    # Deploy using Azure overlay
    log_info "Deploying to AKS..."
    kubectl apply -k k8s/overlays/azure 2>/dev/null || {
      log_warning "Azure overlay not found, using base manifests"
      kubectl apply -k k8s/base
    }
    
    log_success "Deployed to Azure (AKS)"
    ;;
    
  *)
    log_error "Unknown environment: ${ENVIRONMENT}"
    log_error "Valid options: local, aws, azure"
    exit 1
    ;;
esac

log_success "Deployment complete!"

