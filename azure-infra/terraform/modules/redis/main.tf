# ⚡ Redis Cache - For Fast Game Data
# This creates a Redis cache to store game sessions and high scores

resource "azurerm_redis_cache" "main" {
  name                = var.cache_name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Cache size and type - Premium for VNet integration
  capacity = 1         # P1 = 6GB (smallest Premium size)
  family   = "P"       # Premium family (required for VNet)
  sku_name = "Premium" # Premium tier (supports VNet integration)

  # Network integration (only available with Premium)
  subnet_id = var.subnet_id

  # Security settings
  non_ssl_port_enabled = false # Force secure connections only
  minimum_tls_version  = "1.2" # Modern encryption

  # Memory settings
  redis_configuration {
    maxmemory_policy = "allkeys-lru" # Remove oldest data when full
  }

  tags = var.tags
}

# Private DNS zone for Redis (required for VNet integration)
resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link DNS zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "redis-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.virtual_network_id
  tags                  = var.tags
}