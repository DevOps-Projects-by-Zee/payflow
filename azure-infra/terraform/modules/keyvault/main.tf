# 🔐 Key Vault - Secure Secret Storage
# This creates a secure place to store your application secrets

# Get current Azure client info
data "azurerm_client_config" "current" {}

# Create the Key Vault
resource "azurerm_key_vault" "main" {
  name                = var.vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Security settings
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Network access - temporarily public for initial deployment
  public_network_access_enabled = true

  # Network rules - allow current IP for initial setup
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  # Access policies - allow current user to manage secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    # Full permissions for demo purposes
    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Backup", "Restore", "Recover"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover"
    ]
  }

  # Access policy for CI/CD service principal (using GitHub secrets)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = var.service_principal_client_id

    # Permissions needed for CI/CD
    key_permissions = [
      "Get", "List"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]

    certificate_permissions = [
      "Get", "List"
    ]
  }

  tags = var.tags
}

# Private endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = var.tags
}

# Private DNS zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link DNS zone to the virtual network (conditional to avoid conflicts)
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count = var.create_dns_link ? 1 : 0
  
  name                  = "${var.vault_name}-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = data.azurerm_virtual_network.current.id
  tags                  = var.tags
}

# Get subnet info for DNS linking
data "azurerm_subnet" "current" {
  name                 = split("/", var.subnet_id)[10]
  resource_group_name  = split("/", var.subnet_id)[4]
  virtual_network_name = split("/", var.subnet_id)[8]
}

# Get virtual network info for DNS linking
data "azurerm_virtual_network" "current" {
  name                = split("/", var.subnet_id)[8]
  resource_group_name = split("/", var.subnet_id)[4]
}

# Create secrets from variables
resource "azurerm_key_vault_secret" "database_password" {
  name         = "payflow-database-password"
  value        = var.database_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "payflow-redis-password"
  value        = var.redis_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "payflow-api-key"
  value        = var.api_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
}
