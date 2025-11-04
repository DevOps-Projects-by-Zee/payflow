# Monitoring Module Variables
# Defines input variables for Azure monitoring configuration
# Inputs: Resource group, location, workspace configuration, AKS cluster IDs

variable "resource_group_name" {
  description = "Name of the resource group where monitoring resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for monitoring resources deployment (e.g., eastus, westus2)"
  type        = string
}

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = "law-payflow"
}

variable "sku" {
  description = "SKU for Log Analytics workspace (PerGB2018, Free, Standard, Premium, Standalone, Unlimited, CapacityReservation)"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["PerGB2018", "Free", "Standard", "Premium", "Standalone", "Unlimited", "CapacityReservation"], var.sku)
    error_message = "SKU must be one of the supported Log Analytics workspace SKUs."
  }
}

variable "retention_days" {
  description = "Number of days to retain logs (30-730 for PerGB2018, 30-2555 for other SKUs)"
  type        = number
  default     = 30
  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 2555
    error_message = "Retention days must be between 30 and 2555."
  }
}

variable "tags" {
  description = "Tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}


