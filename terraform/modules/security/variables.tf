# ============================================
# PayFlow Security Module Variables
# ============================================

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (hub, production, development)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for bastion host and Route53 private zone"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for bastion host"
  type        = list(string)
}

variable "bastion_enabled" {
  description = "Enable bastion host for EKS access"
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Bastion instance type (t3.micro = $7/month)"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion. Must be explicitly configured for security."
  type        = list(string)
  default     = [] # Security: Force explicit configuration - do not allow 0.0.0.0/0 by default

  validation {
    condition     = length(var.bastion_allowed_cidrs) > 0
    error_message = "bastion_allowed_cidrs must be provided. Get your IP with: curl ifconfig.me"
  }

  validation {
    condition = alltrue([
      for cidr in var.bastion_allowed_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation (e.g., 203.0.113.0/24 or 203.0.113.1/32)."
  }

  validation {
    condition     = !contains(var.bastion_allowed_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not allowed for security. Use your specific IP address (e.g., YOUR_IP/32). Get your IP: curl ifconfig.me"
  }
}

variable "bastion_key_pair_name" {
  description = "AWS Key Pair name for bastion SSH access"
  type        = string
}

variable "create_private_zone" {
  description = "Create Route53 private zone for internal DNS"
  type        = bool
  default     = false
}

variable "private_zone_name" {
  description = "Route53 private zone name"
  type        = string
  default     = "payflow.aws"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (created by init-backend.sh)"
  type        = string
  default     = "" # Will be passed from hub environment
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster (for bastion IAM policy)"
  type        = string
  default     = "" # Will be passed from hub environment after cluster creation
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

