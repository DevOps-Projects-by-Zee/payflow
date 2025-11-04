# 📝 Redis Cache Settings
# These are the inputs you can customize for your cache

variable "cache_name" {
  description = "Name for your Redis cache (must be globally unique)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region where to create the cache"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where Redis cache will be deployed (required for Premium SKU)"
  type        = string
  default     = null
}

variable "virtual_network_id" {
  description = "ID of the virtual network for DNS integration"
  type        = string
  default     = null
}

variable "tags" {
  description = "Labels to organize your resources"
  type        = map(string)
  default     = {}
}