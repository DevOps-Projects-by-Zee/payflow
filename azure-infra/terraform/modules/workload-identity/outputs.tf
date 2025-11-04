# Workload Identity Module Outputs

output "managed_identity_id" {
  description = "ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.workload_identity.id
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.workload_identity.principal_id
}

output "federated_identity_credential_id" {
  description = "ID of the federated identity credential"
  value       = azurerm_federated_identity_credential.workload_identity.id
}
