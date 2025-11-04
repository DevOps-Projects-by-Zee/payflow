# 🚢 Kubernetes Cluster - Where Your App Runs
# This creates a managed Kubernetes cluster to run your PayFlow application

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = "1.31" # Latest stable version

  # Keep it simple - make cluster private for security
  private_cluster_enabled = true

  # Use system-assigned identity (simpler than user-assigned)
  identity {
    type = "SystemAssigned"
  }

  # Worker nodes configuration
  default_node_pool {
    name           = "default"
    node_count     = 2              # Start with 2 nodes
    vm_size        = "Standard_B2s" # Small, cost-effective VMs
    vnet_subnet_id = var.subnet_id  # Put nodes in the app network

    # Cost optimization
    os_disk_size_gb = 30 # Small disk
    os_disk_type    = "Managed"
  }

  # Simple networking
  network_profile {
    network_plugin = "kubenet" # Azure's simple networking
    network_policy = "calico"  # Basic network security
  }

  # Enable basic monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Enable Workload Identity for Key Vault access
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags
}