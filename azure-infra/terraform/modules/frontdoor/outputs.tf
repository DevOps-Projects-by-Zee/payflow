# 🌐 Front Door Outputs
# What you need to know about your load balancer

output "frontdoor_id" {
  description = "Front Door profile resource ID"
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "frontdoor_name" {
  description = "Front Door profile name"
  value       = azurerm_cdn_frontdoor_profile.main.name
}

output "endpoint" {
  description = "Front Door endpoint URL"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "custom_domain_endpoint" {
  description = "Your custom domain endpoint"
  value       = azurerm_cdn_frontdoor_custom_domain.main.host_name
}

output "custom_domain_id" {
  description = "Custom domain ID"
  value       = azurerm_cdn_frontdoor_custom_domain.main.id
}

output "waf_policy_id" {
  description = "Web Application Firewall policy ID"
  value       = var.enable_waf ? azurerm_cdn_frontdoor_firewall_policy.main[0].id : null
}

# DNS Configuration Summary
output "dns_configuration" {
  description = "DNS records you need to create"
  value = {
    domain_name        = var.domain_name
    frontdoor_endpoint = azurerm_cdn_frontdoor_endpoint.main.host_name
    ssl_enabled        = true
  }
}
