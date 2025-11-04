# ============================================
# Hub Environment Backend Configuration
# ============================================
# Purpose: Configure Terraform to use S3 backend for state storage
# Usage: terraform init -backend-config=backend-config.hcl
#
# IMPORTANT: Backend bucket must be created manually first!
# Run: scripts/terraform/init-backend.sh
# Then update this file with the bucket name and KMS key ARN

bucket         = "payflow-terraform-state-93f6fb91"  # UPDATE THIS after creating bucket
key            = "hub/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:us-east-1:334091769766:key/7a57ad9d-c6f5-45ff-bbfc-ce1cdcc410cd"  # UPDATE THIS after creating KMS key
dynamodb_table = "payflow-terraform-locks"

# Usage: terraform init -backend-config=backend-config.hcl

