# 📝 Key Vault Settings
# These are the inputs you can customize for your Key Vault

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region where to create the Key Vault"
  type        = string
}

variable "vault_name" {
  description = "Name of the Key Vault (must be globally unique)"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.vault_name)) && length(var.vault_name) >= 3 && length(var.vault_name) <= 24
    error_message = "Key Vault name must be 3-24 characters, alphanumeric and hyphens only, and globally unique."
  }
}

variable "subnet_id" {
  description = "ID of the subnet where Key Vault private endpoint will be created (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Labels to organize your resources"
  type        = map(string)
  default     = {}
}

variable "database_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Password for Redis cache"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "API key for the application"
  type        = string
  sensitive   = true
}

variable "service_principal_client_id" {
  description = "Service principal client ID for CI/CD access (from GitHub secrets)"
  type        = string
}

variable "create_dns_link" {
  description = "Whether to create private DNS zone link (set to false if already exists)"
  type        = bool
  default     = false
}
