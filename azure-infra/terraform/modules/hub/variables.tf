# 📝 Hub Network Settings
# These are the inputs you can customize for your hub network

variable "resource_group_name" {
  description = "Name of the Azure resource group (like a folder for your resources)"
  type        = string
}

variable "location" {
  description = "Azure region where to create resources (e.g., East US, West Europe)"
  type        = string
}

variable "tags" {
  description = "Labels to organize your resources (e.g., Environment = Production)"
  type        = map(string)
  default     = {}
}

variable "vm_admin_password" {
  description = "Admin password for the test VM"
  type        = string
  sensitive   = true
}

variable "vm_ssh_public_key" {
  description = "SSH public key for the test VM (optional)"
  type        = string
  default     = null
  sensitive   = true
}