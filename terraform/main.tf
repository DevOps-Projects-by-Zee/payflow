# ============================================
# PayFlow Root Terraform Configuration
# ============================================
# Purpose: Root configuration - no workspaces, separate state files per environment
# Usage: Each environment has its own directory with separate state files
#
# Architecture: Hub-and-Spoke
# - Hub: Shared services (ECR, Secrets Manager, Bastion)
# - Production: Production workloads
# - Development: Development workloads
#
# State Management: Separate S3 state files per environment
# - hub/terraform.tfstate
# - production/terraform.tfstate
# - development/terraform.tfstate

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# ============================================
# Global Tags
# ============================================
# These tags are applied to all resources across all environments
# Cost tracking: Use Environment tag to filter costs in AWS Cost Explorer

locals {
  global_tags = {
    Project    = "payflow"
    ManagedBy  = "terraform"
    Repository = "payflow-infrastructure"
    Purpose    = "learning-platform"
  }
}

# ============================================
# Output: Deployment Instructions
# ============================================
# This file doesn't create resources - it's just documentation
# Actual infrastructure is in terraform/environments/{hub,production,development}

output "deployment_info" {
  description = "Instructions for deploying PayFlow infrastructure"
  value = {
    message = "This is the root Terraform configuration. Deploy environments separately:"
    environments = {
      hub = {
        path        = "terraform/environments/hub"
        description = "Deploy hub first (shared services, ECR, Bastion)"
        command     = "cd terraform/environments/hub && terraform init -backend-config=backend-config.hcl && terraform apply"
      }
      production = {
        path        = "terraform/environments/production"
        description = "Deploy production spoke (requires hub to exist)"
        command     = "cd terraform/environments/production && terraform init -backend-config=backend-config.hcl && terraform apply"
      }
      development = {
        path        = "terraform/environments/development"
        description = "Deploy development spoke (requires hub to exist)"
        command     = "cd terraform/environments/development && terraform init -backend-config=backend-config.hcl && terraform apply"
      }
    }
    documentation = "See docs/AWS/DEPLOYMENT_MANUAL.md for step-by-step instructions"
  }
}

