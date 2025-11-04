variable "topic_name" {
  description = "Name for the SNS topic"
  type        = string
}

variable "resource_name" {
  description = "Resource name prefix for alarms"
  type        = string
}

variable "email_endpoint" {
  description = "Email address for alerts (optional - must verify manually)"
  type        = string
  default     = null
}

variable "enable_cpu_alarm" {
  description = "Enable CPU usage alarm"
  type        = bool
  default     = true
}

variable "enable_memory_alarm" {
  description = "Enable memory usage alarm"
  type        = bool
  default     = true
}

variable "enable_health_alarm" {
  description = "Enable service health alarm"
  type        = bool
  default     = true
}

variable "enable_db_alarm" {
  description = "Enable database connection alarm"
  type        = bool
  default     = false # Disable if not needed to save costs
}

variable "cpu_threshold" {
  description = "CPU threshold percentage"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Memory threshold percentage"
  type        = number
  default     = 85
}

variable "db_connection_threshold" {
  description = "Database connection threshold"
  type        = number
  default     = 50
}

variable "db_instance_id" {
  description = "RDS instance identifier (for DB alarms)"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ALB target group ARN (for health alarms)"
  type        = string
  default     = ""
}

variable "load_balancer_arn" {
  description = "ALB ARN (for health alarms)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

