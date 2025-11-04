variable "broker_name" {
  description = "Name for the Amazon MQ broker"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the broker (private subnets)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "username" {
  description = "RabbitMQ username"
  type        = string
  default     = "payflow"
}

variable "password" {
  description = "RabbitMQ password (from Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "host_instance_type" {
  description = "Instance type for the broker (mq.t3.micro for cost savings)"
  type        = string
  default     = "mq.t3.micro" # Smallest instance for cost optimization
}

variable "deployment_mode" {
  description = "Deployment mode: SINGLE_INSTANCE (cheaper) or ACTIVE_STANDBY_MULTI_AZ (HA)"
  type        = string
  default     = "SINGLE_INSTANCE" # Cost-effective default
}

variable "enable_general_logs" {
  description = "Enable general logging (costs extra)"
  type        = bool
  default     = false # Disable to save costs
}

variable "enable_audit_logs" {
  description = "Enable audit logging (costs extra)"
  type        = bool
  default     = false # Disable to save costs
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

