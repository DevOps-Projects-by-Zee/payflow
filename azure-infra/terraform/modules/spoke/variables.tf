# 📝 App Network Settings
# These are the inputs you can customize for your app network

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region (should match your hub network)"
  type        = string
}

variable "address_space" {
  description = "Network address space (e.g., ['10.1.0.0/16'])"
  type        = list(string)
}

variable "hub_network_id" {
  description = "ID of the hub network to connect to"
  type        = string
}

variable "hub_network_name" {
  description = "Name of the hub network for peering"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'payflow-primary')"
  type        = string
}

variable "tags" {
  description = "Labels to organize your resources"
  type        = map(string)
  default     = {}
}