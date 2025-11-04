#!/bin/bash
# ============================================
# Update External Secrets ARNs from Terraform
# ============================================
# Purpose: Replace placeholder ARNs in External Secrets manifests with actual values
# Usage: ./scripts/terraform/update-external-secrets-arns.sh <environment>
#
# This script:
# 1. Reads Terraform outputs from specified environment
# 2. Updates External Secrets manifests with actual secret ARNs
# 3. Updates Service Account IRSA annotations with IAM role ARN

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment name required${NC}"
  echo "Usage: $0 <environment>"
  echo "Example: $0 production"
  exit 1
fi

ENVIRONMENT=$1
ENV_DIR="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"
EXTERNAL_SECRETS_FILE="${PROJECT_ROOT}/k8s/external-secrets/external-secrets.yaml"
SERVICE_ACCOUNTS_FILE="${PROJECT_ROOT}/k8s/external-secrets/service-accounts.yaml"

if [ ! -d "${ENV_DIR}" ]; then
  echo -e "${RED}Error: Environment directory not found: ${ENV_DIR}${NC}"
  exit 1
fi

cd "${ENV_DIR}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Updating External Secrets ARNs${NC}"
echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
  echo -e "${YELLOW}Initializing Terraform...${NC}"
  terraform init -backend-config=backend-config.hcl
fi

# Get secret ARNs from Terraform outputs
echo -e "${YELLOW}Getting secret ARNs from Terraform...${NC}"

POSTGRES_ARN=$(terraform output -raw postgres_secret_arn 2>/dev/null || echo "")
REDIS_ARN=$(terraform output -raw redis_secret_arn 2>/dev/null || echo "")
JWT_ARN=$(terraform output -raw jwt_secret_arn 2>/dev/null || echo "")
RABBITMQ_ARN=$(terraform output -raw rabbitmq_secret_arn 2>/dev/null || echo "")
SECRETS_POLICY_ARN=$(terraform output -raw secrets_access_policy_arn 2>/dev/null || echo "")

if [ -z "${POSTGRES_ARN}" ] || [ -z "${REDIS_ARN}" ] || [ -z "${JWT_ARN}" ] || [ -z "${RABBITMQ_ARN}" ]; then
  echo -e "${RED}Error: Could not get all secret ARNs from Terraform outputs${NC}"
  echo "Make sure Terraform has been applied and outputs are available"
  echo ""
  echo "Try running:"
  echo "  cd ${ENV_DIR}"
  echo "  terraform apply"
  exit 1
fi

echo -e "${GREEN}✓ Secret ARNs retrieved${NC}"
echo "  PostgreSQL: ${POSTGRES_ARN}"
echo "  Redis: ${REDIS_ARN}"
echo "  JWT: ${JWT_ARN}"
echo "  RabbitMQ: ${RABBITMQ_ARN}"
echo ""

# Update External Secrets file
if [ -f "${EXTERNAL_SECRETS_FILE}" ]; then
  echo -e "${YELLOW}Updating External Secrets manifest...${NC}"
  
  # Create backup
  cp "${EXTERNAL_SECRETS_FILE}" "${EXTERNAL_SECRETS_FILE}.bak"
  
  # Replace ARNs
  sed -i.bak "s|REPLACE_WITH_POSTGRES_SECRET_ARN|${POSTGRES_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  sed -i.bak "s|REPLACE_WITH_REDIS_SECRET_ARN|${REDIS_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  sed -i.bak "s|REPLACE_WITH_JWT_SECRET_ARN|${JWT_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  sed -i.bak "s|REPLACE_WITH_RABBITMQ_SECRET_ARN|${RABBITMQ_ARN}|g" "${EXTERNAL_SECRETS_FILE}"
  
  # Remove backup files
  rm -f "${EXTERNAL_SECRETS_FILE}.bak"
  
  echo -e "${GREEN}✓ External Secrets manifest updated${NC}"
else
  echo -e "${YELLOW}⚠ External Secrets file not found: ${EXTERNAL_SECRETS_FILE}${NC}"
fi

# Update Service Accounts file (IRSA role ARN)
# Note: We need to create IAM role for External Secrets Operator
# This is a placeholder - you'll need to create the IAM role separately
if [ -f "${SERVICE_ACCOUNTS_FILE}" ]; then
  echo -e "${YELLOW}Note: Service Account IRSA role ARN needs to be set manually${NC}"
  echo "  The IAM role should be created with the policy ARN: ${SECRETS_POLICY_ARN}"
  echo "  Update ${SERVICE_ACCOUNTS_FILE} with the IAM role ARN"
  echo ""
  echo "  Example IAM role creation:"
  echo "    aws iam create-role --role-name payflow-${ENVIRONMENT}-eso-role \\"
  echo "      --assume-role-policy-document file://trust-policy.json"
  echo "    aws iam attach-role-policy --role-name payflow-${ENVIRONMENT}-eso-role \\"
  echo "      --policy-arn ${SECRETS_POLICY_ARN}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Update Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Create IAM role for External Secrets Operator:"
echo "   - Use OIDC provider from EKS cluster"
echo "   - Attach policy: ${SECRETS_POLICY_ARN}"
echo ""
echo "2. Update Service Account annotations:"
echo "   - Edit ${SERVICE_ACCOUNTS_FILE}"
echo "   - Replace REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN with actual IAM role ARN"
echo ""
echo "3. Apply External Secrets:"
echo "   kubectl apply -f ${EXTERNAL_SECRETS_FILE}"
echo ""
echo "4. Verify secrets are synced:"
echo "   kubectl get externalsecrets -n payflow"
echo "   kubectl get secret db-secrets -n payflow"
echo ""

