# Output values for Key Vault module
# Provides vault details and access information for application integration
# Inputs: Vault URI, access policies, network endpoint information

output "vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.main.id
}

output "vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "private_endpoint_id" {
  description = "Private endpoint ID (if created)"
  value       = azurerm_private_endpoint.keyvault.id
}

output "secret_names" {
  description = "Names of secrets created in Key Vault"
  value = {
    database_password = azurerm_key_vault_secret.database_password.name
    redis_password    = azurerm_key_vault_secret.redis_password.name
    api_key           = azurerm_key_vault_secret.api_key.name
  }
}
