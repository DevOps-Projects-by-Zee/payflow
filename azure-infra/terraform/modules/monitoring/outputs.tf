# Monitoring Module Outputs
# Provides monitoring resource information for other modules and applications
# Outputs: Log Analytics workspace, Managed Prometheus, Managed Grafana details

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "The name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_key" {
  description = "The primary shared key for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "managed_prometheus_workspace_id" {
  description = "The ID of the Azure Monitor workspace (Managed Prometheus)"
  value       = azurerm_monitor_workspace.prometheus.id
}

output "managed_prometheus_workspace_name" {
  description = "The name of the Azure Monitor workspace (Managed Prometheus)"
  value       = azurerm_monitor_workspace.prometheus.name
}

output "managed_grafana_id" {
  description = "The ID of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.main.id
}

output "managed_grafana_name" {
  description = "The name of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.main.name
}

output "managed_grafana_endpoint" {
  description = "The endpoint URL of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.main.endpoint
}


