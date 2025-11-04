#!/bin/bash
# ============================================
# Auto-Replace ARNs Script
# ============================================
# Purpose: Automatically fetch ARNs from Terraform and replace placeholders
# Usage: ./scripts/replace-arns.sh [environment]
# Example: ./scripts/replace-arns.sh production

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ENVIRONMENT=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ARN Replacement Script${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to get Terraform output
get_terraform_output() {
    local output_name=$1
    local tf_dir="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"
    
    if [ ! -d "$tf_dir" ]; then
        echo -e "${RED}Error: Terraform directory not found: ${tf_dir}${NC}"
        return 1
    fi
    
    cd "$tf_dir"
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

# Function to get Terraform output (JSON)
get_terraform_output_json() {
    local output_name=$1
    local tf_dir="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"
    
    if [ ! -d "$tf_dir" ]; then
        echo -e "${RED}Error: Terraform directory not found: ${tf_dir}${NC}"
        return 1
    fi
    
    cd "$tf_dir"
    terraform output -json "$output_name" 2>/dev/null || echo "{}"
}

echo -e "${YELLOW}Step 1: Fetching ARNs from Terraform...${NC}"

# Try to get values from Terraform
ROLE_ARN=$(get_terraform_output "secrets_access_role_arn")
SECRETS_JSON=$(get_terraform_output_json "secrets_manager_arns")

# Extract secret ARNs from JSON
if [ "$SECRETS_JSON" != "{}" ] && [ -n "$SECRETS_JSON" ]; then
    POSTGRES_ARN=$(echo "$SECRETS_JSON" | grep -o '"postgres_secret"[^,]*' | cut -d'"' -f4 || echo "")
    REDIS_ARN=$(echo "$SECRETS_JSON" | grep -o '"redis_secret"[^,]*' | cut -d'"' -f4 || echo "")
    JWT_ARN=$(echo "$SECRETS_JSON" | grep -o '"jwt_secret"[^,]*' | cut -d'"' -f4 || echo "")
else
    POSTGRES_ARN=""
    REDIS_ARN=""
    JWT_ARN=""
fi

# If Terraform outputs failed, try AWS CLI
if [ -z "$ROLE_ARN" ]; then
    echo -e "${YELLOW}Terraform output failed, trying AWS CLI...${NC}"
    ROLE_ARN=$(aws iam list-roles --query 'Roles[?contains(RoleName, `payflow`) && contains(RoleName, `secrets`)].Arn' --output text 2>/dev/null | head -1 || echo "")
fi

if [ -z "$POSTGRES_ARN" ]; then
    POSTGRES_ARN=$(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `payflow`) && contains(Name, `postgres`)].ARN' --output text 2>/dev/null | head -1 || echo "")
fi

if [ -z "$REDIS_ARN" ]; then
    REDIS_ARN=$(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `payflow`) && contains(Name, `redis`)].ARN' --output text 2>/dev/null | head -1 || echo "")
fi

if [ -z "$JWT_ARN" ]; then
    JWT_ARN=$(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `payflow`) && contains(Name, `jwt`)].ARN' --output text 2>/dev/null | head -1 || echo "")
fi

# If still empty, prompt for manual input
if [ -z "$ROLE_ARN" ]; then
    echo -e "${YELLOW}Could not find IAM role ARN automatically.${NC}"
    echo -e "${BLUE}Please enter the Secrets Manager IAM role ARN:${NC}"
    read -p "Role ARN: " ROLE_ARN
fi

if [ -z "$POSTGRES_ARN" ]; then
    echo -e "${YELLOW}Could not find PostgreSQL secret ARN automatically.${NC}"
    echo -e "${BLUE}Please enter the PostgreSQL secret ARN:${NC}"
    read -p "PostgreSQL Secret ARN: " POSTGRES_ARN
fi

if [ -z "$REDIS_ARN" ]; then
    echo -e "${YELLOW}Could not find Redis secret ARN automatically.${NC}"
    echo -e "${BLUE}Please enter the Redis secret ARN:${NC}"
    read -p "Redis Secret ARN: " REDIS_ARN
fi

if [ -z "$JWT_ARN" ]; then
    echo -e "${YELLOW}Could not find JWT secret ARN automatically.${NC}"
    echo -e "${BLUE}Please enter the JWT secret ARN:${NC}"
    read -p "JWT Secret ARN: " JWT_ARN
fi

# Validate ARNs
if [[ ! "$ROLE_ARN" =~ ^arn:aws:iam:: ]]; then
    echo -e "${RED}Error: Invalid IAM role ARN format${NC}"
    exit 1
fi

if [[ ! "$POSTGRES_ARN" =~ ^arn:aws:secretsmanager: ]]; then
    echo -e "${RED}Error: Invalid PostgreSQL secret ARN format${NC}"
    exit 1
fi

if [[ ! "$REDIS_ARN" =~ ^arn:aws:secretsmanager: ]]; then
    echo -e "${RED}Error: Invalid Redis secret ARN format${NC}"
    exit 1
fi

if [[ ! "$JWT_ARN" =~ ^arn:aws:secretsmanager: ]]; then
    echo -e "${RED}Error: Invalid JWT secret ARN format${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Found ARNs:${NC}"
echo -e "  Role ARN: ${ROLE_ARN}"
echo -e "  PostgreSQL Secret: ${POSTGRES_ARN}"
echo -e "  Redis Secret: ${REDIS_ARN}"
echo -e "  JWT Secret: ${JWT_ARN}"
echo ""

# Confirmation
read -p "Replace placeholders with these values? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 2: Replacing placeholders...${NC}"

cd "$PROJECT_ROOT"

# Replace in service-accounts.yaml
if [ -f "k8s/external-secrets/service-accounts.yaml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${ROLE_ARN}|g" k8s/external-secrets/service-accounts.yaml
    else
        # Linux
        sed -i "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${ROLE_ARN}|g" k8s/external-secrets/service-accounts.yaml
    fi
    echo -e "${GREEN}✓ Updated service-accounts.yaml${NC}"
else
    echo -e "${RED}✗ service-accounts.yaml not found${NC}"
fi

# Replace in external-secrets.yaml
if [ -f "k8s/external-secrets/external-secrets.yaml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|REPLACE_WITH_POSTGRES_SECRET_ARN|${POSTGRES_ARN}|g" k8s/external-secrets/external-secrets.yaml
        sed -i '' "s|REPLACE_WITH_REDIS_SECRET_ARN|${REDIS_ARN}|g" k8s/external-secrets/external-secrets.yaml
        sed -i '' "s|REPLACE_WITH_JWT_SECRET_ARN|${JWT_ARN}|g" k8s/external-secrets/external-secrets.yaml
    else
        # Linux
        sed -i "s|REPLACE_WITH_POSTGRES_SECRET_ARN|${POSTGRES_ARN}|g" k8s/external-secrets/external-secrets.yaml
        sed -i "s|REPLACE_WITH_REDIS_SECRET_ARN|${REDIS_ARN}|g" k8s/external-secrets/external-secrets.yaml
        sed -i "s|REPLACE_WITH_JWT_SECRET_ARN|${JWT_ARN}|g" k8s/external-secrets/external-secrets.yaml
    fi
    echo -e "${GREEN}✓ Updated external-secrets.yaml${NC}"
else
    echo -e "${RED}✗ external-secrets.yaml not found${NC}"
fi

# Replace in eso-install.yaml
if [ -f "k8s/external-secrets/eso-install.yaml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${ROLE_ARN}|g" k8s/external-secrets/eso-install.yaml
    else
        # Linux
        sed -i "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${ROLE_ARN}|g" k8s/external-secrets/eso-install.yaml
    fi
    echo -e "${GREEN}✓ Updated eso-install.yaml${NC}"
else
    echo -e "${RED}✗ eso-install.yaml not found${NC}"
fi

# Replace in transaction-timeout.yaml (service account)
if [ -f "k8s/jobs/transaction-timeout.yaml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${ROLE_ARN}|g" k8s/jobs/transaction-timeout.yaml
    else
        # Linux
        sed -i "s|REPLACE_WITH_SECRETS_ACCESS_ROLE_ARN|${ROLE_ARN}|g" k8s/jobs/transaction-timeout.yaml
    fi
    echo -e "${GREEN}✓ Updated transaction-timeout.yaml${NC}"
fi

echo ""
echo -e "${YELLOW}Step 3: Verifying replacements...${NC}"

# Check for remaining placeholders
REMAINING=$(grep -r "REPLACE_WITH" k8s/external-secrets/ k8s/jobs/transaction-timeout.yaml 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓ All placeholders replaced successfully!${NC}"
else
    echo -e "${RED}✗ Warning: ${REMAINING} placeholder(s) still remain${NC}"
    grep -r "REPLACE_WITH" k8s/external-secrets/ k8s/jobs/transaction-timeout.yaml 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ARN Replacement Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review the updated files"
echo -e "  2. Follow the deployment guide: docs/MANUAL_DEPLOYMENT_GUIDE.md"
echo ""

