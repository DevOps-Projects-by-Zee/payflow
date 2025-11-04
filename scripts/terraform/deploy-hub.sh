#!/bin/bash
# ============================================
# Deploy PayFlow Hub Environment
# ============================================
# Purpose: Deploy Hub infrastructure (foundation for all environments)
# Manual Steps: Run commands step-by-step to understand what's happening
#
# Deployment Order:
# 1. Initialize backend (scripts/terraform/init-backend.sh)
# 2. Create AWS Key Pair for bastion
# 3. Configure backend-config.hcl
# 4. Initialize Terraform
# 5. Plan and apply

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

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PayFlow Hub Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed${NC}"
  echo "Install: https://aws.amazon.com/cli/"
  exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
  echo -e "${RED}Error: Terraform is not installed${NC}"
  echo "Install: https://www.terraform.io/downloads"
  exit 1
fi

# Check if backend is initialized
if [ ! -f "${HUB_DIR}/backend-config.hcl" ]; then
  echo -e "${RED}Error: backend-config.hcl not found${NC}"
  echo "Run: scripts/terraform/init-backend.sh first"
  exit 1
fi

# Check if backend-config.hcl has placeholder values
if grep -q "xxxxx" "${HUB_DIR}/backend-config.hcl"; then
  echo -e "${RED}Error: backend-config.hcl contains placeholder values${NC}"
  echo "Update backend-config.hcl with values from init-backend.sh output"
  exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "${HUB_DIR}/terraform.tfvars" ]; then
  echo -e "${YELLOW}Warning: terraform.tfvars not found${NC}"
  echo "Copy terraform.tfvars.example to terraform.tfvars and update values"
  echo ""
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

cd "${HUB_DIR}"

echo -e "${BLUE}Step 1: Initializing Terraform...${NC}"
terraform init -backend-config=backend-config.hcl
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

echo -e "${BLUE}Step 2: Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration valid${NC}"
echo ""

echo -e "${BLUE}Step 3: Planning Terraform changes...${NC}"
terraform plan -out=tfplan
echo -e "${GREEN}✓ Plan created${NC}"
echo ""

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Review the plan above carefully!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
read -p "Apply changes? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled"
  exit 0
fi

echo -e "${BLUE}Step 4: Applying Terraform changes...${NC}"
terraform apply tfplan
echo -e "${GREEN}✓ Hub environment deployed!${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Get bastion IP:"
echo "   terraform output bastion_public_ip"
echo ""
echo "2. SSH to bastion:"
echo "   ssh -i your-key.pem ec2-user@<bastion-ip>"
echo ""
echo "3. Configure kubectl:"
echo "   aws eks update-kubeconfig --region us-east-1 --name payflow-hub-eks"
echo ""
echo "4. Verify cluster:"
echo "   kubectl get nodes"
echo ""
echo "5. Deploy production:"
echo "   cd ../production"
echo "   terraform init -backend-config=backend-config.hcl"
echo "   terraform apply"
echo ""

