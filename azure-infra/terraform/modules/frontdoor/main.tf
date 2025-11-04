# 🌐 Azure Front Door Standard - Global Load Balancer
# This module creates a Front Door Standard profile for active-passive failover
# between your primary and secondary regions

# Front Door Profile (Standard tier)
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = var.frontdoor_name
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"

  tags = var.tags
}

# Front Door Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 2
    additional_latency_in_milliseconds = 0
  }

  health_probe {
    interval_in_seconds = 60
    path                = var.health_probe_path
    protocol            = "Https"
    request_type        = "GET"
  }
}

# Primary Origin
resource "azurerm_cdn_frontdoor_origin" "primary" {
  name                          = "primary-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id

  enabled                        = true
  host_name                      = var.primary_origin_host
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = var.primary_origin_host
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

# Secondary Origin
resource "azurerm_cdn_frontdoor_origin" "secondary" {
  name                          = "secondary-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id

  enabled                        = true
  host_name                      = var.secondary_origin_host
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = var.secondary_origin_host
  priority                       = 2
  weight                         = 100
  certificate_name_check_enabled = false
}

# Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "app-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  tags = var.tags
}

# Front Door Route
resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "app-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.primary.id, azurerm_cdn_frontdoor_origin.secondary.id]

  enabled = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.main.id]
}

# Custom Domain
resource "azurerm_cdn_frontdoor_custom_domain" "main" {
  name                     = "custom-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  dns_zone_id              = var.dns_zone_id
  host_name                = var.domain_name

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

# 🛡️ WAF Policy - Protects against common attacks
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  count               = var.enable_waf ? 1 : 0
  name                = "waf${replace(var.frontdoor_name, "-", "")}"
  resource_group_name = var.resource_group_name
  sku_name            = azurerm_cdn_frontdoor_profile.main.sku_name
  enabled             = true
  mode                = "Prevention"

  # Block suspicious user agents
  custom_rule {
    name                           = "BlockBadBots"
    enabled                        = true
    priority                       = 1
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RequestHeader"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["bot", "crawler", "spider"]
      selector           = "User-Agent"
    }
  }

  tags = var.tags
}
