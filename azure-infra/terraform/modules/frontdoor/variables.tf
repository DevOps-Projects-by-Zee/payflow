# 🌐 Front Door Variables
# Simple configuration for active-passive failover

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "frontdoor_name" {
  description = "Name of the Front Door profile"
  type        = string
  default     = "fd-payflow"
}

variable "domain_name" {
  description = "Your custom domain (e.g., gameapp.games)"
  type        = string
  default     = "gameapp.games"
}

variable "primary_origin_host" {
  description = "Primary region AKS ingress endpoint"
  type        = string
}

variable "secondary_origin_host" {
  description = "Secondary region AKS ingress endpoint (for failover)"
  type        = string
}

variable "health_probe_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "health_probe_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 60
}

variable "session_affinity_enabled" {
  description = "Enable session affinity (keep users on same server)"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "enable_managed_certificate" {
  description = "Enable automatic SSL certificate"
  type        = bool
  default     = true
}

variable "dns_zone_id" {
  description = "DNS zone ID for custom domain"
  type        = string
  default     = null
}

variable "tags" {
  description = "Labels for cost tracking"
  type        = map(string)
  default     = {}
}
