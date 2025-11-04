# 📝 PostgreSQL Database Settings
# These are the inputs you can customize for your database

variable "server_name" {
  description = "Name for your PostgreSQL server (must be globally unique)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region where to create the database"
  type        = string
}

variable "admin_username" {
  description = "Database administrator username"
  type        = string
  default     = "dbadmin"
}

variable "admin_password" {
  description = "Database administrator password (use a strong password!)"
  type        = string
  sensitive   = true
}

variable "database_subnet_id" {
  description = "ID of the subnet where database will live"
  type        = string
}

variable "virtual_network_id" {
  description = "ID of the virtual network for DNS setup"
  type        = string
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup storage (cross-region backup replication)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Labels to organize your resources"
  type        = map(string)
  default     = {}
}