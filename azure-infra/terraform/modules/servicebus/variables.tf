# Service Bus Module Variables
# Input variables for Azure Service Bus configuration

variable "namespace_name" {
  description = "Name of the Service Bus namespace (must be globally unique)"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{4,50}$", var.namespace_name))
    error_message = "Namespace name must be 6-50 characters, alphanumeric and hyphens only."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for Service Bus deployment"
  type        = string
}

variable "sku" {
  description = "Service Bus SKU tier (Basic, Standard, or Premium)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}

variable "virtual_network_id" {
  description = "Virtual Network ID for DNS zone linking"
  type        = string
}

variable "tags" {
  description = "Tags to apply to Service Bus resources"
  type        = map(string)
  default     = {}
}

