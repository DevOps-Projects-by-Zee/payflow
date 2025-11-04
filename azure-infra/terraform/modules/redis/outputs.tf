# 📤 Redis Cache Outputs
# These are the connection details your app needs

output "cache_name" {
  description = "Redis cache name"
  value       = azurerm_redis_cache.main.name
}

output "hostname" {
  description = "Redis cache hostname"
  value       = azurerm_redis_cache.main.hostname
}

output "ssl_port" {
  description = "Redis secure port number"
  value       = azurerm_redis_cache.main.ssl_port
}

output "primary_access_key" {
  description = "Redis access key (store this securely!)"
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

# Connection string template (replace PASSWORD with access key)
output "connection_string_template" {
  description = "Example connection string for your app"
  value       = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port},password=PASSWORD,ssl=True"
}