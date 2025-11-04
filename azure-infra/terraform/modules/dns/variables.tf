# Input variables for DNS module
# Defines parameters for DNS zone creation and record management
# Inputs: Domain name, Front Door endpoint, validation settings, email configuration

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name (e.g., gameapp.games)"
  type        = string
  default     = "gameapp.games"
}

variable "frontdoor_endpoint" {
  description = "Azure Front Door endpoint URL"
  type        = string
  default     = null
}

variable "create_validation_txt" {
  description = "Create TXT record for domain validation"
  type        = bool
  default     = false
}

variable "validation_txt_record" {
  description = "TXT record value for domain validation"
  type        = string
  default     = ""
}

variable "enable_email_records" {
  description = "Enable email-related DNS records (MX, SPF, DMARC)"
  type        = bool
  default     = false
}

variable "mx_exchange" {
  description = "MX exchange server for email records"
  type        = string
  default     = "mail.gameapp.games"
}

variable "tags" {
  description = "Tags to apply to DNS resources"
  type        = map(string)
  default     = {}
}
