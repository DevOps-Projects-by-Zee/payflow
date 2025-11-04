# Output values for DNS module
# Provides DNS zone information and required records for registrar configuration
# Inputs: DNS zone ID, name servers, record values, configuration details

output "zone_id" {
  description = "DNS zone resource ID"
  value       = azurerm_dns_zone.public.id
}

output "zone_name" {
  description = "DNS zone name"
  value       = azurerm_dns_zone.public.name
}

output "name_servers" {
  description = "Name servers for the DNS zone (configure at registrar)"
  value       = azurerm_dns_zone.public.name_servers
}

output "name_servers_list" {
  description = "List of name servers for easy copy-paste"
  value = [
    for ns in azurerm_dns_zone.public.name_servers : ns
  ]
}

output "frontdoor_cname" {
  description = "CNAME record value for Front Door integration"
  value       = var.frontdoor_endpoint
}

# DNS Records Summary for Registrar Configuration
output "dns_records_summary" {
  description = "Summary of DNS records to configure at registrar"
  value = {
    zone_name    = azurerm_dns_zone.public.name
    name_servers = azurerm_dns_zone.public.name_servers
    records = {
      apex_cname = {
        name  = "@"
        type  = "CNAME"
        value = var.frontdoor_endpoint
        ttl   = 300
      }
      www_cname = {
        name  = "www"
        type  = "CNAME"
        value = var.frontdoor_endpoint
        ttl   = 300
      }
      spf_txt = {
        name  = "@"
        type  = "TXT"
        value = "v=spf1 -all"
        ttl   = 300
      }
      dmarc_txt = {
        name  = "_dmarc"
        type  = "TXT"
        value = "v=DMARC1; p=reject; rua=mailto:dmarc@gameapp.games"
        ttl   = 300
      }
    }
  }
}

# Registrar Configuration Instructions
output "registrar_instructions" {
  description = "Step-by-step instructions for registrar configuration"
  value       = <<-EOT
  ================================================================================
  DNS CONFIGURATION INSTRUCTIONS FOR REGISTRAR
  ================================================================================
  
  Domain: ${var.domain_name}
  
  STEP 1: UPDATE NAME SERVERS
  Replace your registrar's name servers with these Azure DNS name servers:
  
  ${join("\n  ", azurerm_dns_zone.public.name_servers)}
  
  STEP 2: VERIFY PROPAGATION
  After updating name servers, wait 24-48 hours for DNS propagation.
  Verify with: dig ${var.domain_name} NS
  
  STEP 3: HTTPS VALIDATION
  Once DNS propagates, Front Door will automatically provision SSL certificate.
  Test with: curl -I https://${var.domain_name}
  
  ================================================================================
  IMPORTANT NOTES:
  - Keep apex (@) record at registrar if they don't support CNAME
  - www subdomain will work with CNAME record
  - SSL certificate provisioning may take 10-15 minutes after DNS propagation
  - Monitor Front Door custom domain status in Azure Portal
  ================================================================================
  EOT
}
