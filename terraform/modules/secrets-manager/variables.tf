# ============================================
# PayFlow Secrets Manager Module Variables
# ============================================

variable "project_name" {
  description = "Project name (used in secret naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (production, development)"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting secrets"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for IAM policy"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "payflow"
}

variable "db_host" {
  description = "Database host (will be set after RDS creation)"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "payflow"
}

variable "redis_host" {
  description = "Redis host (will be set after ElastiCache creation)"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Redis port"
  type        = string
  default     = "6379"
}

variable "rabbitmq_username" {
  description = "RabbitMQ username"
  type        = string
  default     = "payflow"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "dr_region" {
  description = "Disaster recovery region for secret replication"
  type        = string
  default     = ""
}

variable "enable_secret_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of Lambda function for secret rotation"
  type        = string
  default     = ""
}

