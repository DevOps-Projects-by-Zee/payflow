#!/bin/bash
# Test script for bastion host connectivity and EKS access
# Usage: ./test-bastion.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get bastion IP from Terraform output or AWS
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASTION_KEY="${PROJECT_ROOT}/payflow-bastion.pem"

echo -e "${BLUE}=== Bastion Host Test ===${NC}"
echo ""

# Step 1: Get bastion IP
echo -e "${YELLOW}Step 1: Getting bastion host IP...${NC}"
BASTION_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=payflow-bastion" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text 2>/dev/null || echo "")

if [ -z "${BASTION_IP}" ] || [ "${BASTION_IP}" == "None" ]; then
  echo -e "${RED}✗ Could not find running bastion host${NC}"
  echo -e "${YELLOW}Checking instance status...${NC}"
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=payflow-bastion" \
    --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]' \
    --output table
  exit 1
fi

echo -e "${GREEN}✓ Bastion IP: ${BASTION_IP}${NC}"
echo ""

# Step 2: Check key file
echo -e "${YELLOW}Step 2: Checking SSH key...${NC}"
if [ ! -f "${BASTION_KEY}" ]; then
  echo -e "${RED}✗ SSH key not found: ${BASTION_KEY}${NC}"
  exit 1
fi

chmod 400 "${BASTION_KEY}" 2>/dev/null || true
echo -e "${GREEN}✓ SSH key found${NC}"
echo ""

# Step 3: Update security group with current IP
echo -e "${YELLOW}Step 3: Updating security group...${NC}"
MY_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s https://api.ipify.org)
BASTION_SG=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=payflow-bastion" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

# Check if rule already exists
EXISTING_RULE=$(aws ec2 describe-security-groups \
  --group-ids ${BASTION_SG} \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges[?CidrIp==\`${MY_IP}/32\`].CidrIp" \
  --output text)

if [ -z "${EXISTING_RULE}" ]; then
  echo -e "${YELLOW}   Adding SSH access from ${MY_IP}/32...${NC}"
  aws ec2 authorize-security-group-ingress \
    --group-id ${BASTION_SG} \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32 \
    --region us-east-1 >/dev/null 2>&1 || echo -e "${YELLOW}   Rule might already exist${NC}"
else
  echo -e "${GREEN}✓ SSH access already configured${NC}"
fi
echo ""

# Step 4: Test SSH connection
echo -e "${YELLOW}Step 4: Testing SSH connection...${NC}"
if ssh -i "${BASTION_KEY}" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=10 \
  -o BatchMode=yes \
  ec2-user@${BASTION_IP} "echo 'SSH connection successful!'" 2>/dev/null; then
  echo -e "${GREEN}✓ SSH connection working${NC}"
else
  echo -e "${RED}✗ SSH connection failed${NC}"
  echo -e "${YELLOW}   Try manually: ssh -i ${BASTION_KEY} ec2-user@${BASTION_IP}${NC}"
  exit 1
fi
echo ""

# Step 5: Test AWS CLI on bastion
echo -e "${YELLOW}Step 5: Testing AWS CLI on bastion...${NC}"
AWS_VERSION=$(ssh -i "${BASTION_KEY}" \
  -o StrictHostKeyChecking=no \
  ec2-user@${BASTION_IP} "aws --version" 2>/dev/null)
echo -e "${GREEN}✓ ${AWS_VERSION}${NC}"
echo ""

# Step 6: Configure kubectl
echo -e "${YELLOW}Step 6: Configuring kubectl for EKS...${NC}"
ssh -i "${BASTION_KEY}" \
  -o StrictHostKeyChecking=no \
  ec2-user@${BASTION_IP} \
  "aws eks update-kubeconfig --region us-east-1 --name payflow-hub-eks >/dev/null 2>&1 && echo 'kubectl configured'"
echo ""

# Step 7: Test kubectl access
echo -e "${YELLOW}Step 7: Testing kubectl access to EKS cluster...${NC}"
NODES=$(ssh -i "${BASTION_KEY}" \
  -o StrictHostKeyChecking=no \
  ec2-user@${BASTION_IP} \
  "kubectl get nodes --no-headers 2>&1")

if echo "${NODES}" | grep -q "Ready"; then
  echo -e "${GREEN}✓ EKS cluster accessible${NC}"
  echo "${NODES}" | while read line; do
    echo "  ${line}"
  done
else
  echo -e "${RED}✗ Could not access EKS cluster${NC}"
  echo "${NODES}"
  exit 1
fi
echo ""

# Step 8: Test cluster info
echo -e "${YELLOW}Step 8: Getting cluster information...${NC}"
CLUSTER_INFO=$(ssh -i "${BASTION_KEY}" \
  -o StrictHostKeyChecking=no \
  ec2-user@${BASTION_IP} \
  "kubectl cluster-info 2>&1 | head -3")
echo "${CLUSTER_INFO}"
echo ""

# Success summary
echo -e "${GREEN}=== Bastion Test Complete ===${NC}"
echo ""
echo -e "${GREEN}✓ SSH Access: Working${NC}"
echo -e "${GREEN}✓ AWS CLI: Installed${NC}"
echo -e "${GREEN}✓ kubectl: Configured${NC}"
echo -e "${GREEN}✓ EKS Access: Working${NC}"
echo ""
echo -e "${BLUE}You can now SSH to the bastion:${NC}"
echo -e "${YELLOW}  ssh -i ${BASTION_KEY} ec2-user@${BASTION_IP}${NC}"
echo ""
echo -e "${BLUE}From the bastion, you can manage your EKS cluster:${NC}"
echo -e "${YELLOW}  kubectl get nodes${NC}"
echo -e "${YELLOW}  kubectl get pods -A${NC}"
echo ""

