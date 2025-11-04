#!/bin/bash
# ============================================
# Update Kubernetes Manifests for AWS Deployment
# ============================================
# Purpose: Automatically update K8s manifests with Terraform outputs
# Usage: ./scripts/terraform/update-k8s-for-aws.sh [hub|production]
#
# What it does:
# 1. Reads Terraform outputs (ECR URLs, IAM roles, secret ARNs)
# 2. Updates K8s manifests with actual values
# 3. Changes imagePullPolicy from Never to IfNotPresent
# 4. Updates image URLs to ECR format
#
# Prerequisites:
# - Terraform infrastructure must be deployed first
# - Run from project root: ./scripts/terraform/update-k8s-for-aws.sh hub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENVIRONMENT="${1:-hub}"  # Default to hub

# Services to update
SERVICES=(
  "api-gateway"
  "auth-service"
  "wallet-service"
  "transaction-service"
  "notification-service"
  "frontend"
)

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

# Check if Terraform is deployed
check_terraform() {
  log_info "Checking Terraform deployment..."
  
  TERRAFORM_DIR="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"
  
  if [ ! -d "${TERRAFORM_DIR}" ]; then
    log_error "Terraform directory not found: ${TERRAFORM_DIR}"
    exit 1
  fi
  
  cd "${TERRAFORM_DIR}"
  
  # Check if terraform state exists
  if ! terraform output ecr_repository_urls &>/dev/null; then
    log_error "Terraform outputs not found. Please deploy infrastructure first:"
    log_error "  cd terraform/environments/${ENVIRONMENT}"
    log_error "  terraform apply"
    exit 1
  fi
  
  log_success "Terraform infrastructure found"
}

# Get Terraform outputs
get_terraform_outputs() {
  log_info "Getting Terraform outputs..."
  
  cd "${TERRAFORM_DIR}"
  
  # Get AWS account ID and region
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
  AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
  
  # Get ECR repository URLs
  log_info "Fetching ECR repository URLs..."
  ECR_URLS=$(terraform output -json ecr_repository_urls 2>/dev/null)
  
  if [ -z "$ECR_URLS" ] || [ "$ECR_URLS" = "null" ]; then
    log_error "ECR repository URLs not found in Terraform outputs"
    exit 1
  fi
  
  # Get IAM role ARN for service accounts (if exists)
  SECRETS_ROLE_ARN=$(terraform output -raw secrets_access_role_arn 2>/dev/null || echo "")
  
  # Get secret ARNs (if in production)
  if [ "$ENVIRONMENT" = "production" ]; then
    POSTGRES_SECRET_ARN=$(terraform output -raw postgres_secret_arn 2>/dev/null || echo "")
    JWT_SECRET_ARN=$(terraform output -raw jwt_secret_arn 2>/dev/null || echo "")
    REDIS_SECRET_ARN=$(terraform output -raw redis_secret_arn 2>/dev/null || echo "")
    RABBITMQ_SECRET_ARN=$(terraform output -raw rabbitmq_secret_arn 2>/dev/null || echo "")
  fi
  
  log_success "Terraform outputs retrieved"
}

# Update AWS overlay kustomization.yaml with ECR URLs
update_aws_overlay() {
  log_info "Updating AWS overlay with ECR URLs..."
  
  OVERLAY_FILE="${PROJECT_ROOT}/k8s/overlays/aws/kustomization.yaml"
  
  if [ ! -f "${OVERLAY_FILE}" ]; then
    log_error "AWS overlay not found: ${OVERLAY_FILE}"
    return 1
  fi
  
  for service in "${SERVICES[@]}"; do
    log_info "Updating ${service} ECR URL..."
    
    # Get ECR URL for this service
    ECR_URL=$(echo "$ECR_URLS" | jq -r ".${service}" 2>/dev/null || echo "")
    
    if [ -z "$ECR_URL" ] || [ "$ECR_URL" = "null" ]; then
      # Fallback: construct ECR URL manually
      ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/payflow/${service}"
      log_warning "ECR URL not in outputs, using constructed: ${ECR_URL}"
    fi
    
    # Update newName in overlay kustomization.yaml
    # Pattern: newName: payflow/<service> -> newName: <ECR_URL>
    sed -i.bak "s|newName: payflow/${service}|newName: ${ECR_URL}|g" "${OVERLAY_FILE}"
    
    log_success "Updated ${service} to ${ECR_URL}"
  done
  
  # Remove backup file
  rm -f "${OVERLAY_FILE}.bak"
  
  log_success "AWS overlay updated with ECR URLs"
}

# Update service accounts with IAM role ARNs
update_service_accounts() {
  if [ -z "$SECRETS_ROLE_ARN" ]; then
    log_warning "Secrets access role ARN not found, skipping service account updates"
    log_warning "You may need to update service-accounts.yaml manually"
    return
  fi
  
  log_info "Updating service accounts with IAM role ARN..."
  
  SERVICE_ACCOUNTS_FILE="${PROJECT_ROOT}/k8s/external-secrets/service-accounts.yaml"
  
  if [ ! -f "${SERVICE_ACCOUNTS_FILE}" ]; then
    log_warning "Service accounts file not found: ${SERVICE_ACCOUNTS_FILE}"
    return
  fi
    
  # Replace placeholder with actual role ARN
  sed -i.bak "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${SECRETS_ROLE_ARN}|g" "${SERVICE_ACCOUNTS_FILE}"
  rm -f "${SERVICE_ACCOUNTS_FILE}.bak"
  
  log_success "Service accounts updated"
}

# Update external secrets with secret ARNs (production only)
update_external_secrets() {
  if [ "$ENVIRONMENT" != "production" ]; then
    log_info "Skipping external secrets update (not production environment)"
    return
  fi
  
  EXTERNAL_SECRETS_FILE="${PROJECT_ROOT}/k8s/external-secrets/external-secrets.yaml"
  
  if [ ! -f "${EXTERNAL_SECRETS_FILE}" ]; then
    log_warning "External secrets file not found: ${EXTERNAL_SECRETS_FILE}"
    return
  fi
  
  log_info "Updating external secrets with secret ARNs..."
  
  # Update PostgreSQL secret ARN
  if [ -n "$POSTGRES_SECRET_ARN" ]; then
    sed -i.bak "s|REPLACE_WITH_POSTGRES_SECRET_ARN|${POSTGRES_SECRET_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  fi
  
  # Update JWT secret ARN
  if [ -n "$JWT_SECRET_ARN" ]; then
    sed -i.bak "s|REPLACE_WITH_JWT_SECRET_ARN|${JWT_SECRET_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  fi
  
  # Update Redis secret ARN
  if [ -n "$REDIS_SECRET_ARN" ]; then
    sed -i.bak "s|REPLACE_WITH_REDIS_SECRET_ARN|${REDIS_SECRET_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  fi
  
  # Update RabbitMQ secret ARN
  if [ -n "$RABBITMQ_SECRET_ARN" ]; then
    sed -i.bak "s|REPLACE_WITH_RABBITMQ_SECRET_ARN|${RABBITMQ_SECRET_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  fi
  
  rm -f "${EXTERNAL_SECRETS_FILE}.bak"
  
  log_success "External secrets updated"
}

# Main execution
main() {
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Update K8s Manifests for AWS${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  
  check_terraform
  get_terraform_outputs
  update_aws_overlay
  update_service_accounts
  update_external_secrets
  
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Update Complete!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo -e "${YELLOW}Next Steps:${NC}"
  echo "1. Review the updated overlay:"
  echo "   git diff k8s/overlays/aws/kustomization.yaml"
  echo ""
  echo "2. Build and push Docker images to ECR:"
  echo "   scripts/terraform/build-push-ecr.sh"
  echo ""
  echo "3. Deploy to EKS using AWS overlay:"
  echo "   kubectl apply -k k8s/overlays/aws"
}

main "$@"

