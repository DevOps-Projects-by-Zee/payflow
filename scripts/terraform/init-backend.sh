#!/bin/bash
# ============================================
# Initialize Terraform Backend Infrastructure
# ============================================
# Purpose: Create S3 backend bucket and DynamoDB table BEFORE using Terraform
# Why: Terraform needs backend infrastructure to exist before it can use it
# Cost: ~$1/month (S3 storage + DynamoDB pay-per-request)
#
# This script creates:
# 1. S3 bucket for Terraform state
# 2. DynamoDB table for state locking
# 3. KMS key for state encryption
#
# Manual Steps (Learning First):
# After running this script, you'll need to:
# 1. Update backend-config.hcl with bucket name and KMS key ARN
# 2. Run: terraform init -backend-config=backend-config.hcl

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="payflow"
REGION="us-east-1"

# Check if S3 bucket already exists
EXISTING_BUCKET=$(aws s3 ls --region ${REGION} | grep "${PROJECT_NAME}-terraform-state-" | awk '{print $3}' | head -1)

if [ -n "${EXISTING_BUCKET}" ]; then
  echo -e "${YELLOW}⚠ Found existing S3 bucket: ${EXISTING_BUCKET}${NC}"
  echo -e "${YELLOW}   Using existing bucket instead of creating new one${NC}"
  BUCKET_NAME="${EXISTING_BUCKET}"
else
  BUCKET_SUFFIX=$(date +%s | sha256sum | head -c 8)  # Random suffix for uniqueness
  BUCKET_NAME="${PROJECT_NAME}-terraform-state-${BUCKET_SUFFIX}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Initializing Terraform Backend${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Create S3 bucket (if doesn't exist)
echo -e "${YELLOW}Step 1: Checking S3 bucket for Terraform state...${NC}"
if aws s3 ls s3://${BUCKET_NAME} --region ${REGION} &>/dev/null; then
  echo -e "${GREEN}✓ S3 bucket already exists: ${BUCKET_NAME}${NC}"
else
  echo -e "${YELLOW}   Creating new S3 bucket...${NC}"
  aws s3 mb s3://${BUCKET_NAME} --region ${REGION} || {
    echo -e "${RED}Error: Failed to create S3 bucket${NC}"
    exit 1
  }
  echo -e "${GREEN}✓ S3 bucket created: ${BUCKET_NAME}${NC}"
fi

# Step 2: Enable versioning
echo -e "${YELLOW}Step 2: Enabling versioning on S3 bucket...${NC}"
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Step 3: Block public access
echo -e "${YELLOW}Step 3: Blocking public access...${NC}"
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}✓ Public access blocked${NC}"

# Step 4: Create KMS key for encryption
echo -e "${YELLOW}Step 4: Creating KMS key for state encryption...${NC}"

# Check if alias already exists
if aws kms describe-key --key-id alias/${PROJECT_NAME}-terraform-state --region ${REGION} &>/dev/null; then
  echo -e "${YELLOW}⚠ KMS alias already exists, getting existing key ARN...${NC}"
  KMS_KEY_ARN=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-terraform-state --region ${REGION} --query 'KeyMetadata.Arn' --output text)
  KMS_KEY_ID=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-terraform-state --region ${REGION} --query 'KeyMetadata.KeyId' --output text)
  echo -e "${GREEN}✓ Using existing KMS key: ${KMS_KEY_ARN}${NC}"
else
  KMS_KEY_ID=$(aws kms create-key \
    --description "PayFlow Terraform State Encryption Key" \
    --region ${REGION} \
    --query 'KeyMetadata.KeyId' \
    --output text)

  KMS_KEY_ARN=$(aws kms describe-key \
    --key-id ${KMS_KEY_ID} \
    --region ${REGION} \
    --query 'KeyMetadata.Arn' \
    --output text)

  # Create alias
  aws kms create-alias \
    --alias-name alias/${PROJECT_NAME}-terraform-state \
    --target-key-id ${KMS_KEY_ID} \
    --region ${REGION}

  echo -e "${GREEN}✓ KMS key created: ${KMS_KEY_ARN}${NC}"
fi

# Step 5: Enable encryption on bucket
echo -e "${YELLOW}Step 5: Enabling encryption on S3 bucket...${NC}"
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration "{
    \"Rules\": [{
      \"ApplyServerSideEncryptionByDefault\": {
        \"SSEAlgorithm\": \"aws:kms\",
        \"KMSMasterKeyID\": \"${KMS_KEY_ID}\"
      }
    }]
  }"
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Step 6: Create DynamoDB table for state locking
echo -e "${YELLOW}Step 6: Creating DynamoDB table for state locking...${NC}"

# Check if table already exists
if aws dynamodb describe-table --table-name ${PROJECT_NAME}-terraform-locks --region ${REGION} &>/dev/null; then
  echo -e "${YELLOW}⚠ DynamoDB table already exists, skipping creation${NC}"
else
  aws dynamodb create-table \
    --table-name ${PROJECT_NAME}-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${REGION} \
    --wait
  echo -e "${GREEN}✓ DynamoDB table created: ${PROJECT_NAME}-terraform-locks${NC}"
fi

# Step 7: Update backend-config.hcl files automatically
echo -e "${YELLOW}Step 7: Updating backend-config.hcl files...${NC}"

# Get project root (script is in scripts/terraform/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENVIRONMENTS=("hub" "production" "development")
for env in "${ENVIRONMENTS[@]}"; do
  BACKEND_CONFIG="${PROJECT_ROOT}/terraform/environments/${env}/backend-config.hcl"
  
  # Create backend-config.hcl if it doesn't exist
  if [ ! -f "${BACKEND_CONFIG}" ]; then
    echo -e "${YELLOW}   Creating ${env}/backend-config.hcl...${NC}"
    cat > "${BACKEND_CONFIG}" <<EOF
# ============================================
# ${env^} Environment Backend Configuration
# ============================================
bucket         = "${BUCKET_NAME}"
key            = "${env}/terraform.tfstate"
region         = "${REGION}"
encrypt        = true
kms_key_id     = "${KMS_KEY_ARN}"
dynamodb_table = "${PROJECT_NAME}-terraform-locks"
EOF
    echo -e "${GREEN}✓ Created ${env}/backend-config.hcl${NC}"
  else
    # Update existing file
    # Update bucket name
    sed -i.bak "s/bucket.*=.*\"payflow-terraform-state-.*\"/bucket         = \"${BUCKET_NAME}\"/" "${BACKEND_CONFIG}"
    sed -i.bak "s/bucket.*=.*\"payflow-terraform-state-xxxxx\"/bucket         = \"${BUCKET_NAME}\"/" "${BACKEND_CONFIG}"
    
    # Update KMS key ARN
    sed -i.bak "s|kms_key_id.*=.*\"arn:aws:kms:.*\"|kms_key_id     = \"${KMS_KEY_ARN}\"|" "${BACKEND_CONFIG}"
    sed -i.bak "s|kms_key_id.*=.*\"arn:aws:kms:.*xxxxx.*\"|kms_key_id     = \"${KMS_KEY_ARN}\"|" "${BACKEND_CONFIG}"
    
    # Remove backup file
    rm -f "${BACKEND_CONFIG}.bak"
    
    echo -e "${GREEN}✓ Updated ${env}/backend-config.hcl${NC}"
  fi
done

# Step 8: Create AWS Key Pair for bastion access
KEY_PAIR_NAME="${PROJECT_NAME}-bastion"
echo -e "${YELLOW}Step 8: Creating AWS Key Pair for bastion access...${NC}"

if aws ec2 describe-key-pairs --key-names ${KEY_PAIR_NAME} --region ${REGION} &>/dev/null; then
  echo -e "${YELLOW}⚠ Key pair already exists: ${KEY_PAIR_NAME}${NC}"
  echo -e "${YELLOW}   Checking if local key file exists...${NC}"
  if [ -f "${PROJECT_ROOT}/${KEY_PAIR_NAME}.pem" ]; then
    echo -e "${GREEN}✓ Key file exists: ${KEY_PAIR_NAME}.pem${NC}"
  else
    echo -e "${YELLOW}⚠ Key pair exists in AWS but local file missing.${NC}"
    echo -e "${YELLOW}   You'll need to export the key from AWS Console or recreate it.${NC}"
  fi
else
  echo -e "${YELLOW}   Creating new key pair...${NC}"
  aws ec2 create-key-pair \
    --key-name ${KEY_PAIR_NAME} \
    --query 'KeyMaterial' \
    --output text > ${PROJECT_ROOT}/${KEY_PAIR_NAME}.pem
  
  chmod 400 ${PROJECT_ROOT}/${KEY_PAIR_NAME}.pem
  echo -e "${GREEN}✓ Key pair created: ${KEY_PAIR_NAME}${NC}"
  echo -e "${GREEN}✓ Key file saved: ${PROJECT_ROOT}/${KEY_PAIR_NAME}.pem${NC}"
fi

# Step 9: Create terraform.tfvars files (if they don't exist)
echo -e "${YELLOW}Step 9: Creating terraform.tfvars files...${NC}"

# Detect user's IP address
MY_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s https://api.ipify.org || echo "0.0.0.0")

for env in "${ENVIRONMENTS[@]}"; do
  TFVARS="${PROJECT_ROOT}/terraform/environments/${env}/terraform.tfvars"
  TFVARS_EXAMPLE="${PROJECT_ROOT}/terraform/environments/${env}/terraform.tfvars.example"
  
  if [ ! -f "${TFVARS}" ] && [ -f "${TFVARS_EXAMPLE}" ]; then
    echo -e "${YELLOW}   Creating ${env}/terraform.tfvars from example...${NC}"
    cp "${TFVARS_EXAMPLE}" "${TFVARS}"
    
    # Auto-update bastion_allowed_cidrs with user's IP (only for hub)
    if [ "${env}" = "hub" ]; then
      sed -i.bak "s|bastion_allowed_cidrs = \[\"YOUR_IP/32\"\]|bastion_allowed_cidrs = [\"${MY_IP}/32\"]|" "${TFVARS}"
      sed -i.bak "s|bastion_allowed_cidrs = \[\"0.0.0.0/0\"\]|bastion_allowed_cidrs = [\"${MY_IP}/32\"]|" "${TFVARS}"
      rm -f "${TFVARS}.bak"
      echo -e "${GREEN}✓ Created ${env}/terraform.tfvars with your IP: ${MY_IP}/32${NC}"
    else
      echo -e "${GREEN}✓ Created ${env}/terraform.tfvars from example${NC}"
    fi
  elif [ -f "${TFVARS}" ]; then
    echo -e "${YELLOW}⚠ ${env}/terraform.tfvars already exists, skipping${NC}"
  else
    echo -e "${YELLOW}⚠ ${env}/terraform.tfvars.example not found, skipping${NC}"
  fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backend Initialization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Backend Configuration:${NC}"
echo "Bucket Name: ${BUCKET_NAME}"
echo "KMS Key ARN: ${KMS_KEY_ARN}"
echo "DynamoDB Table: ${PROJECT_NAME}-terraform-locks"
echo "Region: ${REGION}"
echo "Key Pair: ${KEY_PAIR_NAME}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ✓ Backend infrastructure created"
echo "2. ✓ Backend configuration files created/updated"
echo "3. ✓ AWS Key Pair created"
echo "4. ✓ terraform.tfvars files created"
echo ""
echo "5. Deploy Hub:"
echo "   scripts/terraform/deploy-hub.sh"
echo ""
echo -e "${YELLOW}To Destroy Everything (Cleanup):${NC}"
echo "   scripts/terraform/destroy-backend.sh"
echo "   # This will delete S3 bucket, DynamoDB table, KMS key, and key pair"
echo ""

