# Azure Container Registry module for secure image storage
# Provisions container registry with access controls and network integration
# Inputs: Registry SKU, access policies, network rules, retention policies

resource "azurerm_container_registry" "main" {
  # Basic configuration
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # Access configuration
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.public_network_access_enabled

  # Note: Advanced features like retention_policy and trust_policy
  # are only available in Standard/Premium tiers and require
  # separate resource configurations

  tags = merge(var.tags, {
    Purpose = "container-images"
  })
}
