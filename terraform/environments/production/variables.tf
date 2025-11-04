# ============================================
# PayFlow Production Environment Variables
# ============================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "payflow"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (from Hub)"
  type        = string
}

variable "node_key_pair_name" {
  description = "AWS Key Pair name for node SSH access"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "alert_email" {
  description = "Email address for CloudWatch alarms (must verify manually)"
  type        = string
  default     = ""
}

