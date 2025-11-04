# ============================================
# PayFlow Global Variables
# ============================================
# Purpose: Variables shared across all environments and modules
# Usage: These are default values, can be overridden per environment

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "payflow"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "default_region" {
  description = "Default AWS region for deployments"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery AWS region (optional)"
  type        = string
  default     = "us-west-2"
}

# ============================================
# Global Tags
# ============================================
# These tags are applied to all resources for cost tracking and organization

variable "global_tags" {
  description = "Tags to apply to all resources across environments"
  type        = map(string)
  default = {
    Project    = "payflow"
    Owner      = "platform-team"
    Repository = "payflow-infrastructure"
  }
}

