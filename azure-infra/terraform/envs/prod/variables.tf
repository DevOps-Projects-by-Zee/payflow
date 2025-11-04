# 📝 Production Environment Settings
# These are the settings you can customize for your production environment

variable "database_password" {
  description = "Password for the database administrator (use a strong password!)"
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

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "service_principal_client_id" {
  description = "Service principal client ID for CI/CD access (from GitHub secrets)"
  type        = string
}

variable "create_dns_records" {
  description = "Whether to create DNS records (set to false if they already exist)"
  type        = bool
  default     = false
}

variable "vm_admin_password" {
  description = "Admin password for the test VM"
  type        = string
  sensitive   = true
}

variable "vm_ssh_public_key" {
  description = "SSH public key for the test VM (optional)"
  type        = string
  sensitive   = true
  default     = null
}

# Optional: You can add more variables here if you want to customize other settings
# For now, we keep it simple with sensible defaults in the main.tf file