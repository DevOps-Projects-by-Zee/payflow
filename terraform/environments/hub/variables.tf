# ============================================
# PayFlow Hub Environment Variables
# ============================================

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
  default     = "payflow"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "enable_bastion_host" {
  description = "Enable bastion host for EKS access"
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Bastion instance type"
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion. If empty, IP will be auto-detected automatically. Leave empty for automatic detection."
  type        = list(string)
  default     = [] # If empty, Terraform will auto-detect your public IP

  # Note: Validation happens in locals.bastion_allowed_cidrs, not here
  # This allows empty list for auto-detection, then validation ensures we have something

  validation {
    condition = alltrue([
      for cidr in var.bastion_allowed_cidrs : can(cidrhost(cidr, 0))
    ]) || length(var.bastion_allowed_cidrs) == 0 # Allow empty for auto-detection
    error_message = "All CIDR blocks must be valid CIDR notation (e.g., 203.0.113.0/24 or 203.0.113.1/32)."
  }

  validation {
    condition     = !contains(var.bastion_allowed_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not allowed for security. Use your specific IP address (e.g., YOUR_IP/32) or leave empty for automatic detection."
  }
}

variable "bastion_key_pair_name" {
  description = "AWS Key Pair name for bastion SSH access"
  type        = string
  # Must be created manually: aws ec2 create-key-pair --key-name payflow-bastion --query 'KeyMaterial' --output text > payflow-bastion.pem
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization (dev) vs Multi-AZ (prod)"
  type        = bool
  default     = false # Default to Multi-AZ for HA
}

variable "enable_route53_private_dns" {
  description = "Enable Route53 private zone for internal DNS"
  type        = bool
  default     = false
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (created by init-backend.sh)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.terraform_state_bucket))
    error_message = "Bucket name must be valid S3 bucket name format."
  }
}

