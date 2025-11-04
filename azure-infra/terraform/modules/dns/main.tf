# DNS Module for PayFlow
# Manages Azure DNS zones and records for custom domain
# Inputs: Domain name, Front Door endpoint, DNS configuration
# Outputs: DNS zone ID, name servers, required records

# Public DNS Zone for gameapp.games
resource "azurerm_dns_zone" "public" {
  name                = var.domain_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# CNAME Record: gameapp.games → Front Door endpoint
resource "azurerm_dns_cname_record" "apex" {
  count               = var.frontdoor_endpoint != null ? 1 : 0
  name                = "@"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  record              = var.frontdoor_endpoint

  tags = var.tags
}

# CNAME Record: www.gameapp.games → Front Door endpoint
resource "azurerm_dns_cname_record" "www" {
  count               = var.frontdoor_endpoint != null ? 1 : 0
  name                = "www"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  record              = var.frontdoor_endpoint

  tags = var.tags
}

# TXT Record for domain validation (if required by Front Door)
resource "azurerm_dns_txt_record" "validation" {
  count               = var.create_validation_txt ? 1 : 0
  name                = "@"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    value = var.validation_txt_record
  }

  tags = var.tags
}

# TXT Record for SPF (email security)
resource "azurerm_dns_txt_record" "spf" {
  name                = "@"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    value = "v=spf1 -all"
  }

  tags = var.tags
}

# TXT Record for DMARC (email security)
resource "azurerm_dns_txt_record" "dmarc" {
  name                = "_dmarc"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    value = "v=DMARC1; p=reject; rua=mailto:dmarc@gameapp.games"
  }

  tags = var.tags
}

# MX Record for email (if needed for troubleshooting)
resource "azurerm_dns_mx_record" "email" {
  count               = var.enable_email_records ? 1 : 0
  name                = "@"
  zone_name           = azurerm_dns_zone.public.name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    preference = 10
    exchange   = var.mx_exchange
  }

  tags = var.tags
}
