# 📤 Kubernetes Cluster Outputs
# These are the important details you need to connect to your cluster

output "cluster_id" {
  description = "Kubernetes cluster ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "Kubernetes cluster URL (private)"
  value       = azurerm_kubernetes_cluster.main.private_fqdn
}

# Don't expose the full kubeconfig in output for security
# Instead, users should run: az aks get-credentials --resource-group RG --name CLUSTER_NAME

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "workload_identity_enabled" {
  description = "Whether workload identity is enabled"
  value       = azurerm_kubernetes_cluster.main.workload_identity_enabled
}