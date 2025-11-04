# Azure Monitoring Module for PayFlow
# Sets up comprehensive monitoring with Log Analytics, Managed Prometheus, and Managed Grafana
# Inputs: Resource group, location, monitoring configuration

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_days

  tags = var.tags
}

# Azure Monitor Workspace (Managed Prometheus)
resource "azurerm_monitor_workspace" "prometheus" {
  name                = "${var.workspace_name}-prometheus"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Cost-aware defaults
  public_network_access_enabled = true

  tags = var.tags
}

# Azure Managed Grafana (Enabled for production monitoring)
resource "azurerm_dashboard_grafana" "main" {
  name                = "payflow-grafana"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Use Standard SKU (Premium not available in current provider version)
  sku = "Standard"

  # Enable Azure Monitor integration
  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }

  # Enable Log Analytics integration
  grafana_major_version = "11" # Use latest version with new provider

  # Network access
  public_network_access_enabled = true

  tags = var.tags
}

# Note: Data Collection Rules will be configured manually in Azure Portal
# This provides the foundation infrastructure for monitoring
# AKS clusters will automatically send logs to Log Analytics workspace
