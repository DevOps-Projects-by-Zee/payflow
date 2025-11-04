# Input variables for ACR module
# Defines parameters for container registry configuration and access control
# Inputs: Registry name, SKU selection, access permissions, network settings

variable "resource_group_name" {
  description = "Name of the resource group where ACR will be created"
  type        = string
}

variable "location" {
  description = "Azure region for ACR deployment (e.g., eastus, westus2)"
  type        = string
}

variable "registry_name" {
  description = "Name of the container registry (globally unique, alphanumeric only)"
  type        = string
  default     = "acrpayflow"
  validation {
    condition     = can(regex("^[a-zA-Z0-9]+$", var.registry_name)) && length(var.registry_name) >= 5 && length(var.registry_name) <= 50
    error_message = "Registry name must be 5-50 characters, alphanumeric only, and globally unique."
  }
}

variable "sku" {
  description = "ACR SKU tier (Basic: $5/month, Standard: $20/month, Premium: $500/month)"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "Enable admin user for ACR (useful for development, disable for production)"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access (disable for enhanced security)"
  type        = bool
  default     = true
}

variable "retention_policy_days" {
  description = "Days to retain untagged manifests (7-365, only available for Standard/Premium)"
  type        = number
  default     = 7
  validation {
    condition     = var.retention_policy_days >= 1 && var.retention_policy_days <= 365
    error_message = "Retention policy must be between 1 and 365 days."
  }
}

variable "tags" {
  description = "Labels to organize your resources for cost tracking"
  type        = map(string)
  default     = {}
}
