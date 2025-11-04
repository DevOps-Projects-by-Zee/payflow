# ============================================
# PayFlow Hub VPC Module Variables
# ============================================

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for Hub VPC"
  type        = string
  default     = "10.0.0.0/16"
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

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization (dev) vs Multi-AZ (prod)"
  type        = bool
  default     = false # Default to Multi-AZ for HA
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

