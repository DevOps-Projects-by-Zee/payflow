# ============================================
# PayFlow Development Environment Configuration
# ============================================
# Purpose: Variable values for Development environment deployment
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

# Database Configuration (Cost-optimized for dev)
db_instance_class = "db.t3.micro" # Single-AZ for cost savings

# Redis Configuration (Cost-optimized for dev)
redis_node_type = "cache.t3.micro" # Single node for cost savings

# ============================================
# Cost Optimization Notes:
# ============================================
# 1. Development uses smaller instance types
# 2. Single-AZ deployment reduces costs
# 3. Spot instances enabled for EKS nodes (50% savings)
# 4. Can scale to zero for further cost reduction
# 5. Same security standards as production
# 6. terraform_state_bucket value comes from Hub deployment