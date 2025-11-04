# Output values for ACR module
# Provides registry details and credentials for image push/pull operations
# Inputs: Registry URL, login server, access credentials for AKS integration

output "login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.main.login_server
}

output "registry_id" {
  description = "ACR registry ID"
  value       = azurerm_container_registry.main.id
}
