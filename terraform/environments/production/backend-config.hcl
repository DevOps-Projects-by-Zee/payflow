# ============================================
# Production Environment Backend Configuration
# ============================================
bucket         = "payflow-terraform-state-93f6fb91"
key            = "production/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
kms_key_id     = "arn:aws:kms:us-east-1:334091769766:key/7a57ad9d-c6f5-45ff-bbfc-ce1cdcc410cd"
dynamodb_table = "payflow-terraform-locks"
