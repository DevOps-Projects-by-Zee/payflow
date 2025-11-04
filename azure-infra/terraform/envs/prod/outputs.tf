# 📤 Production Environment Outputs
# After Terraform creates your infrastructure, these are the important details you need

output "resource_group_name" {
  description = "Name of your Azure resource group"
  value       = azurerm_resource_group.main.name
}

output "kubernetes_cluster_name" {
  description = "Name of your primary Kubernetes cluster"
  value       = module.kubernetes.cluster_name
}

output "kubernetes_cluster_name_secondary" {
  description = "Name of your secondary Kubernetes cluster"
  value       = module.kubernetes_secondary.cluster_name
}

output "container_registry_url" {
  description = "URL of your container registry (for docker push/pull)"
  value       = module.container_registry.login_server
}

output "database_hostname" {
  description = "Database hostname (private network only)"
  value       = module.database.server_fqdn
}

output "database_name" {
  description = "Name of your application database"
  value       = module.database.database_name
}

output "cache_hostname" {
  description = "Redis cache hostname"
  value       = module.cache.hostname
}

output "servicebus_namespace" {
  description = "Service Bus namespace name"
  value       = module.servicebus.namespace_name
}

output "servicebus_namespace_endpoint" {
  description = "Service Bus namespace endpoint"
  value       = module.servicebus.namespace_endpoint
  sensitive   = true
}

output "servicebus_transactions_queue" {
  description = "Transactions queue name"
  value       = module.servicebus.transactions_queue_name
}

output "servicebus_notifications_queue" {
  description = "Notifications queue name"
  value       = module.servicebus.notifications_queue_name
}

output "workload_identity_primary_client_id" {
  description = "Managed Identity Client ID for primary cluster (use in service account annotation)"
  value       = module.workload_identity_primary.managed_identity_client_id
}

output "workload_identity_secondary_client_id" {
  description = "Managed Identity Client ID for secondary cluster (use in service account annotation)"
  value       = module.workload_identity_secondary.managed_identity_client_id
}

output "key_vault_name" {
  description = "Key Vault name (for External Secrets configuration)"
  value       = module.keyvault.vault_name
}

output "database_secondary_server_name" {
  description = "Secondary PostgreSQL server name (for disaster recovery)"
  value       = module.database_secondary.server_name
}

output "database_secondary_fqdn" {
  description = "Secondary PostgreSQL server FQDN (for disaster recovery)"
  value       = module.database_secondary.server_fqdn
}

output "cache_secondary_hostname" {
  description = "Secondary Redis cache hostname (for disaster recovery)"
  value       = module.cache_secondary.hostname
}

output "servicebus_secondary_namespace" {
  description = "Secondary Service Bus namespace name (for disaster recovery)"
  value       = module.servicebus_secondary.namespace_name
}

output "key_vault_url" {
  description = "URL of your Key Vault (for storing secrets)"
  value       = module.keyvault.vault_uri
}

output "frontdoor_endpoint" {
  description = "Front Door endpoint URL"
  value       = module.frontdoor.endpoint
}

output "frontdoor_custom_domain" {
  description = "Your custom domain endpoint"
  value       = module.frontdoor.custom_domain_endpoint
}

output "dns_configuration" {
  description = "DNS records you need to create"
  value       = module.frontdoor.dns_configuration
}

output "dns_zone_name_servers" {
  description = "Name servers for your DNS zone"
  value       = module.dns.name_servers
}

output "dns_zone_id" {
  description = "DNS zone ID"
  value       = module.dns.zone_id
}

output "test_vm_name" {
  description = "Test VM name for Bastion access"
  value       = module.hub.test_vm_name
}

output "test_vm_private_ip" {
  description = "Test VM private IP address"
  value       = module.hub.test_vm_private_ip
}

output "test_vm_public_ip" {
  description = "Test VM public IP address for direct SSH access"
  value       = module.hub.test_vm_public_ip
}

output "test_vm_username" {
  description = "Test VM admin username"
  value       = module.hub.test_vm_username
}

output "bastion_connection_info" {
  description = "Information for connecting to the test VM via Bastion"
  value = {
    vm_name     = module.hub.test_vm_name
    vm_username = "azureuser"
    vm_password = "Set in terraform.tfvars or GitHub secrets"
    bastion_url = "https://${module.hub.bastion_host_name}.eastus.cloudapp.azure.com"
  }
}

output "vm_access_via_bastion" {
  description = "Information for accessing the test VM via Azure Bastion (secure gateway)"
  value = {
    vm_name      = module.hub.test_vm_name
    vm_username  = module.hub.test_vm_username
    private_ip   = module.hub.test_vm_private_ip
    bastion_url = "https://portal.azure.com → Navigate to VM → Connect → Bastion"
    note         = "Test VM is private - only accessible via Azure Bastion for security"
  }
}

output "bastion_access" {
  description = "How to access your private cluster via Bastion"
  value = {
    bastion_name = module.hub.bastion_host_name
    public_ip    = module.hub.bastion_public_ip
    access_url   = "https://${module.hub.bastion_public_ip}"
  }
}

output "next_steps" {
  description = "What to do after deployment"
  value       = <<-EOT
    🎉 Your PayFlow infrastructure is ready!
    
    Next steps:
    1. Direct SSH access: ssh ${module.hub.test_vm_username}@${module.hub.test_vm_public_ip}
    2. Bastion access: https://${module.hub.bastion_public_ip}
    3. Connect to your cluster: az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.kubernetes.cluster_name}
    4. Add your database password to Key Vault
    5. Deploy your app: kubectl apply -k deploy/kustomize/overlays/prod-primary/
    6. Check your app: kubectl get pods
    
    VM Access Options:
    - Direct SSH: ssh ${module.hub.test_vm_username}@${module.hub.test_vm_public_ip}
    - Bastion (private): https://${module.hub.bastion_public_ip}
    
    Database connection: ${module.database.connection_string_template}
    Cache connection: ${module.cache.connection_string_template}
    
    Monitoring workspace: ${module.monitoring.log_analytics_workspace_id}
    
    Front Door: ${module.frontdoor.endpoint}
    Custom Domain: ${module.frontdoor.custom_domain_endpoint}
    DNS Zone: ${module.dns.zone_id}
    Name Servers: ${join(", ", module.dns.name_servers)}
    
    Primary cluster: ${module.kubernetes.cluster_name}
    Secondary cluster: ${module.kubernetes_secondary.cluster_name}
    
    Monitoring:
    - Log Analytics: ${module.monitoring.log_analytics_workspace_name}
    - Grafana: ${module.monitoring.managed_grafana_endpoint}
    - Prometheus: ${module.monitoring.managed_prometheus_workspace_name}
  EOT
}