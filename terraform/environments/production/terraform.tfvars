# ============================================
# PayFlow Production Environment Configuration
# ============================================
# Purpose: Variable values for Production environment deployment
# Security: No sensitive values - those are in AWS Secrets Manager
# Usage: Terraform automatically loads this file

# Project Configuration
project_name       = "payflow"
aws_region         = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EKS Configuration
kubernetes_version = "1.28"

# Backend Configuration
# This value comes from Hub environment outputs
terraform_state_bucket = "PLACEHOLDER-WILL-BE-SET-FROM-HUB"

# SSH Access
node_key_pair_name = "payflow-bastion" # Same key as Hub environment

# Database Configuration (Production-grade)
db_instance_class = "db.t3.small" # Multi-AZ capable

# Redis Configuration (Production-grade)  
redis_node_type = "cache.t3.micro" # Can be upgraded to Multi-AZ

# ============================================
# Security Notes:
# ============================================
# 1. No sensitive values in this file
# 2. Secrets are managed via AWS Secrets Manager
# 3. SSH keys are managed via AWS EC2 Key Pairs
# 4. terraform_state_bucket value comes from Hub deployment
# 5. Ensure payflow-bastion key pair exists before deployment
# 6. Production uses Multi-AZ for high availability