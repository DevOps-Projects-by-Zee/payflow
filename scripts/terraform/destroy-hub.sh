#!/bin/bash
# ============================================
# Destroy PayFlow Hub Environment
# ============================================
# Purpose: Safely destroy Hub infrastructure
# Warning: This will DELETE all resources in the Hub environment!
#
# Safety Features:
# - Requires explicit environment name confirmation
# - Shows what will be destroyed before proceeding
# - Prevents accidental deletion
#
# Usage: scripts/terraform/destroy-hub.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HUB_DIR="${PROJECT_ROOT}/terraform/environments/hub"

echo -e "${RED}========================================${NC}"
echo -e "${RED}⚠️  DESTROY PayFlow Hub Environment ⚠️${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will DELETE all Hub infrastructure!${NC}"
echo ""
echo "This includes:"
echo "  - EKS cluster and all nodes"
echo "  - VPC, Subnets, NAT Gateway"
echo "  - Bastion host"
echo "  - ECR repositories"
echo "  - S3 backend bucket (if this is the last environment)"
echo "  - DynamoDB table (if this is the last environment)"
echo "  - All associated resources"
echo ""

# Safety check: Require explicit confirmation
read -p "Type 'destroy-hub' to confirm: " CONFIRM
if [ "${CONFIRM}" != "destroy-hub" ]; then
  echo -e "${RED}Destruction cancelled (confirmation did not match 'destroy-hub')${NC}"
  exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
  echo -e "${RED}Error: Terraform is not installed${NC}"
  exit 1
fi

# Check if backend config exists
if [ ! -f "${HUB_DIR}/backend-config.hcl" ]; then
  echo -e "${RED}Error: backend-config.hcl not found${NC}"
  exit 1
fi

cd "${HUB_DIR}"

# Check if Terraform is initialized
if [ ! -d "${HUB_DIR}/.terraform" ]; then
  echo -e "${YELLOW}Initializing Terraform...${NC}"
  terraform init -backend-config=backend-config.hcl
fi

echo ""
echo -e "${BLUE}Step 1: Planning destruction...${NC}"
terraform plan -destroy -out=destroy.tfplan
echo ""

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Review the destruction plan above!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
read -p "Proceed with destruction? (yes/no): " FINAL_CONFIRM
if [ "${FINAL_CONFIRM}" != "yes" ]; then
  echo -e "${GREEN}Destruction cancelled${NC}"
  rm -f destroy.tfplan
  exit 0
fi

echo ""
echo -e "${RED}Step 2: Destroying infrastructure...${NC}"
terraform apply destroy.tfplan

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Hub Environment Destroyed${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Note:${NC}"
echo "  - S3 backend bucket and DynamoDB table are NOT deleted"
echo "  - These are shared resources used by all environments"
echo "  - To delete backend infrastructure, run: scripts/terraform/destroy-backend.sh"
echo ""

# Cleanup plan file
rm -f destroy.tfplan

