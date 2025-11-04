#!/bin/bash
# ============================================
# Update Azure Key Vault Secret Sync Configuration
# ============================================
# Purpose: Automatically populate placeholder values in azure-keyvault-secrets.yaml
# Usage: ./scripts/local/update-azure-secrets-config.sh
#
# Prerequisites:
# 1. Terraform must be initialized and have outputs available
# 2. Run from project root directory
# 3. Ensure terraform is in PATH

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Updating Azure Key Vault Secret Sync Configuration${NC}"
echo ""

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Error: terraform not found in PATH${NC}"
    exit 1
fi

# Change to terraform directory
TERRAFORM_DIR="azure-infra/terraform/envs/prod"
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}✗ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if terraform is initialized
if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠ Warning: Terraform not initialized. Run 'terraform init' first.${NC}"
    exit 1
fi

# Get outputs
echo -e "${YELLOW}📋 Fetching Terraform outputs...${NC}"

KEY_VAULT_URL=$(terraform output -raw key_vault_url 2>/dev/null || echo "")
KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
CLIENT_ID=$(terraform output -raw workload_identity_primary_client_id 2>/dev/null || echo "")

# Validate outputs
if [ -z "$KEY_VAULT_URL" ]; then
    echo -e "${RED}✗ Error: Could not get key_vault_url from Terraform outputs${NC}"
    echo "   Make sure you've run 'terraform apply' and outputs are available"
    exit 1
fi

if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}✗ Error: Could not get workload_identity_primary_client_id from Terraform outputs${NC}"
    echo "   Make sure you've run 'terraform apply' and outputs are available"
    exit 1
fi

# Extract Key Vault name from URL if not provided
if [ -z "$KEY_VAULT_NAME" ]; then
    KEY_VAULT_NAME=$(echo "$KEY_VAULT_URL" | sed -e 's|https://||' -e 's|\.vault\.azure\.net||')
fi

echo -e "${GREEN}✓ Key Vault URL: $KEY_VAULT_URL${NC}"
echo -e "${GREEN}✓ Key Vault Name: $KEY_VAULT_NAME${NC}"
echo -e "${GREEN}✓ Managed Identity Client ID: $CLIENT_ID${NC}"
echo ""

# Update azure-keyvault-secrets.yaml
SECRETS_FILE="../../../../k8s/external-secrets/azure-keyvault-secrets.yaml"

if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}✗ Error: Secret file not found: $SECRETS_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}📝 Updating $SECRETS_FILE...${NC}"

# Create backup
cp "$SECRETS_FILE" "${SECRETS_FILE}.backup"
echo -e "${GREEN}✓ Backup created: ${SECRETS_FILE}.backup${NC}"

# Update Key Vault URL
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|vaultUrl:.*|vaultUrl: \"$KEY_VAULT_URL\"|g" "$SECRETS_FILE"
    sed -i '' "s|REPLACE_WITH_MANAGED_IDENTITY_CLIENT_ID|$CLIENT_ID|g" "$SECRETS_FILE"
else
    # Linux
    sed -i "s|vaultUrl:.*|vaultUrl: \"$KEY_VAULT_URL\"|g" "$SECRETS_FILE"
    sed -i "s|REPLACE_WITH_MANAGED_IDENTITY_CLIENT_ID|$CLIENT_ID|g" "$SECRETS_FILE"
fi

echo -e "${GREEN}✓ Updated Key Vault URL${NC}"
echo -e "${GREEN}✓ Updated Managed Identity Client ID${NC}"
echo ""

# Verify changes
echo -e "${YELLOW}🔍 Verifying changes...${NC}"
if grep -q "$KEY_VAULT_URL" "$SECRETS_FILE" && grep -q "$CLIENT_ID" "$SECRETS_FILE"; then
    echo -e "${GREEN}✓ Verification successful!${NC}"
else
    echo -e "${RED}✗ Error: Verification failed. Please check the file manually.${NC}"
    echo "   Restore from backup: cp ${SECRETS_FILE}.backup $SECRETS_FILE"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Configuration updated successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the changes: diff $SECRETS_FILE ${SECRETS_FILE}.backup"
echo "2. Apply the configuration: kubectl apply -f $SECRETS_FILE"
echo "3. Verify External Secrets are syncing: kubectl get externalsecrets -n payflow"
echo "4. Check Kubernetes secrets: kubectl get secrets db-secrets -n payflow -o yaml"

