# Bastion Module Variables
# Input variables for Azure Bastion configuration

variable "naming_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "bastion_subnet_cidr" {
  description = "CIDR block for Bastion subnet"
  type        = list(string)
  default     = ["10.0.3.0/27"] # /27 provides 32 IP addresses
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
