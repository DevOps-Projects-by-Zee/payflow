#!/bin/bash
# ============================================
# Destroy Terraform Backend Infrastructure
# ============================================
# Purpose: Delete S3 backend bucket and DynamoDB table
# Warning: This will DELETE Terraform state files!
# Only run this if you want to completely remove ALL infrastructure
#
# Usage: scripts/terraform/destroy-backend.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
PROJECT_NAME="payflow"
REGION="us-east-1"

echo -e "${RED}========================================${NC}"
echo -e "${RED}⚠️  DESTROY Terraform Backend ⚠️${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will DELETE Terraform state files!${NC}"
echo ""
echo "This includes:"
echo "  - S3 bucket with all Terraform state files"
echo "  - DynamoDB table for state locking"
echo "  - KMS key for state encryption"
echo "  - AWS Key Pair (payflow-bastion)"
echo "  - Local key file (payflow-bastion.pem)"
echo ""
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

# Safety check: Require explicit confirmation
read -p "Type 'destroy-backend' to confirm: " CONFIRM
if [ "${CONFIRM}" != "destroy-backend" ]; then
  echo -e "${RED}Destruction cancelled${NC}"
  exit 1
fi

# Get bucket name from backend-config.hcl
BACKEND_CONFIG="${PROJECT_ROOT}/terraform/environments/hub/backend-config.hcl"
if [ ! -f "${BACKEND_CONFIG}" ]; then
  echo -e "${RED}Error: backend-config.hcl not found${NC}"
  echo "Cannot determine bucket name"
  exit 1
fi

BUCKET_NAME=$(grep "^bucket" "${BACKEND_CONFIG}" | sed 's/.*= *"\(.*\)"/\1/' | tr -d ' ')
KMS_KEY_ARN=$(grep "^kms_key_id" "${BACKEND_CONFIG}" | sed 's|.*= *"\(.*\)"|\1|' | tr -d ' ')

if [ -z "${BUCKET_NAME}" ] || [ "${BUCKET_NAME}" = "payflow-terraform-state-xxxxx" ]; then
  echo -e "${RED}Error: Invalid bucket name in backend-config.hcl${NC}"
  echo "Backend may not be initialized"
  exit 1
fi

echo ""
echo -e "${YELLOW}Found Backend Resources:${NC}"
echo "  Bucket: ${BUCKET_NAME}"
echo "  KMS Key: ${KMS_KEY_ARN}"
echo ""

read -p "Proceed with backend destruction? (yes/no): " FINAL_CONFIRM
if [ "${FINAL_CONFIRM}" != "yes" ]; then
  echo -e "${GREEN}Destruction cancelled${NC}"
  exit 0
fi

# Step 1: Delete all objects in bucket (including versions)
echo -e "${BLUE}Step 1: Deleting all objects in S3 bucket...${NC}"
aws s3api delete-objects \
  --bucket "${BUCKET_NAME}" \
  --delete "$(aws s3api list-object-versions \
    --bucket "${BUCKET_NAME}" \
    --output json \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || echo "No objects to delete"

# Delete delete markers
aws s3api delete-objects \
  --bucket "${BUCKET_NAME}" \
  --delete "$(aws s3api list-object-versions \
    --bucket "${BUCKET_NAME}" \
    --output json \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || echo "No delete markers to delete"

echo -e "${GREEN}✓ S3 bucket objects deleted${NC}"

# Step 2: Delete S3 bucket
echo -e "${BLUE}Step 2: Deleting S3 bucket...${NC}"
aws s3 rb s3://${BUCKET_NAME} --region ${REGION} || {
  echo -e "${YELLOW}Warning: Failed to delete bucket (may have objects or versioning enabled)${NC}"
  echo "Try manually: aws s3 rb s3://${BUCKET_NAME} --force"
}
echo -e "${GREEN}✓ S3 bucket deleted${NC}"

# Step 3: Delete DynamoDB table
echo -e "${BLUE}Step 3: Deleting DynamoDB table...${NC}"
aws dynamodb delete-table \
  --table-name ${PROJECT_NAME}-terraform-locks \
  --region ${REGION} \
  --wait 2>/dev/null || echo -e "${YELLOW}Warning: DynamoDB table may not exist${NC}"
echo -e "${GREEN}✓ DynamoDB table deleted${NC}"

# Step 4: Schedule KMS key deletion (7 day window)
echo -e "${BLUE}Step 4: Scheduling KMS key deletion...${NC}"
KMS_KEY_ID=$(echo "${KMS_KEY_ARN}" | awk -F: '{print $NF}')
aws kms schedule-key-deletion \
  --key-id "${KMS_KEY_ID}" \
  --pending-window-in-days 7 \
  --region ${REGION} || echo -e "${YELLOW}Warning: KMS key may not exist or already scheduled${NC}"
echo -e "${GREEN}✓ KMS key deletion scheduled (7 day window)${NC}"

# Step 5: Delete AWS Key Pair
KEY_PAIR_NAME="${PROJECT_NAME}-bastion"
echo -e "${BLUE}Step 5: Deleting AWS Key Pair...${NC}"
if aws ec2 describe-key-pairs --key-names ${KEY_PAIR_NAME} --region ${REGION} &>/dev/null; then
  aws ec2 delete-key-pair --key-name ${KEY_PAIR_NAME} --region ${REGION}
  echo -e "${GREEN}✓ AWS Key Pair deleted${NC}"
else
  echo -e "${YELLOW}Warning: Key pair may not exist${NC}"
fi

# Step 6: Delete local key file
echo -e "${BLUE}Step 6: Removing local key file...${NC}"
if [ -f "${PROJECT_ROOT}/${KEY_PAIR_NAME}.pem" ]; then
  rm -f "${PROJECT_ROOT}/${KEY_PAIR_NAME}.pem"
  echo -e "${GREEN}✓ Local key file deleted${NC}"
else
  echo -e "${YELLOW}Warning: Local key file not found${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backend Infrastructure Destroyed${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Note:${NC}"
echo "  - KMS key will be deleted in 7 days (you can cancel before then)"
echo "  - To cancel KMS key deletion:"
echo "    aws kms cancel-key-deletion --key-id ${KMS_KEY_ID}"
echo ""

