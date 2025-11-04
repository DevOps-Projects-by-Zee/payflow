# 📤 App Network Outputs
# These are the important details your app services need

output "network_id" {
  description = "The app network ID"
  value       = azurerm_virtual_network.spoke.id
}

output "network_name" {
  description = "The app network name"
  value       = azurerm_virtual_network.spoke.name
}

output "kubernetes_subnet_id" {
  description = "Where to put your Kubernetes cluster"
  value       = azurerm_subnet.kubernetes.id
}

output "database_subnet_id" {
  description = "Where to put your database"
  value       = azurerm_subnet.database.id
}

output "cache_subnet_id" {
  description = "Where to put your Redis cache"
  value       = azurerm_subnet.cache.id
}