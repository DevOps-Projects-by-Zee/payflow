# Workload Identity Module
# Creates and configures workload identity for secure Key Vault access

# Create user-assigned managed identity for workload identity
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "id-${var.name_prefix}-workload"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Create federated identity credential for the service account
resource "azurerm_federated_identity_credential" "workload_identity" {
  name                = "fic-${var.name_prefix}-workload"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

# Grant Key Vault access to the workload identity
resource "azurerm_key_vault_access_policy" "workload_identity" {
  key_vault_id = var.key_vault_id
  tenant_id    = var.tenant_id
  object_id    = azurerm_user_assigned_identity.workload_identity.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]
}
