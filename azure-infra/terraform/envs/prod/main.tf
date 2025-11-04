# 💰 PayFlow Production Infrastructure
# This file creates all the Azure resources needed to run your PayFlow application

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Create a resource group (like a folder for all your Azure resources)
resource "azurerm_resource_group" "main" {
  name     = "payflow-production"
  location = "East US"

  tags = {
    Project     = "PayFlow"
    Environment = "Production"
    CreatedBy   = "Terraform"
  }
}

# 🏠 Create the hub network (central shared services)
module "hub" {
  source = "../../modules/hub"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = azurerm_resource_group.main.tags
  vm_admin_password   = var.vm_admin_password
  vm_ssh_public_key   = var.vm_ssh_public_key
}

# 🏢 Create the main app network (primary region)
module "app_network" {
  source = "../../modules/spoke"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.1.0.0/16"]
  hub_network_id      = module.hub.network_id
  hub_network_name    = module.hub.network_name
  name_prefix         = "payflow-primary"
  tags                = azurerm_resource_group.main.tags
}

# 🏢 Create the secondary app network (for disaster recovery)
module "app_network_secondary" {
  source = "../../modules/spoke"

  resource_group_name = azurerm_resource_group.main.name
  location            = "West US 2"     # Secondary region
  address_space       = ["10.2.0.0/16"] # Different IP range
  hub_network_id      = module.hub.network_id
  hub_network_name    = module.hub.network_name
  name_prefix         = "payflow-secondary"
  tags                = azurerm_resource_group.main.tags
}

# 📊 Create monitoring workspace
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_name      = "payflow-monitoring"
  tags                = azurerm_resource_group.main.tags
}

# 🚢 Create primary Kubernetes cluster
module "kubernetes" {
  source = "../../modules/aks"

  cluster_name               = "payflow-cluster-primary"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  subnet_id                  = module.app_network.kubernetes_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = azurerm_resource_group.main.tags
}

# 🚢 Create secondary Kubernetes cluster (for disaster recovery)
module "kubernetes_secondary" {
  source = "../../modules/aks"

  cluster_name               = "payflow-cluster-secondary"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = "West US 2"
  subnet_id                  = module.app_network_secondary.kubernetes_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = azurerm_resource_group.main.tags
}

# 🏪 Create container registry
module "container_registry" {
  source = "../../modules/acr"

  registry_name       = "payflowregistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = azurerm_resource_group.main.tags
}

# 🔐 Create Key Vault for secrets (in hub network)
module "keyvault" {
  source = "../../modules/keyvault"

  vault_name          = "payflow-secrets"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.hub.keyvault_subnet_id
  tags                = azurerm_resource_group.main.tags

  # Pass secrets from variables
  database_password = var.database_password
  redis_password    = var.redis_password
  api_key           = var.api_key
  
  # Pass service principal for CI/CD access (from GitHub secrets)
  service_principal_client_id = var.service_principal_client_id
  
  # Skip DNS link creation to avoid conflicts
  create_dns_link = false
}

# 🔐 Create workload identity for primary cluster
module "workload_identity_primary" {
  source = "../../modules/workload-identity"

  name_prefix          = "payflow-primary"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  oidc_issuer_url      = module.kubernetes.oidc_issuer_url
  key_vault_id         = module.keyvault.vault_id
  tenant_id            = data.azurerm_client_config.current.tenant_id
  namespace            = "payflow"
  service_account_name = "payflow-sa"
  tags                 = azurerm_resource_group.main.tags

  depends_on = [
    module.kubernetes,
    module.keyvault
  ]
}

# 🔐 Create workload identity for secondary cluster
module "workload_identity_secondary" {
  source = "../../modules/workload-identity"

  name_prefix          = "payflow-secondary"
  resource_group_name  = azurerm_resource_group.main.name
  location             = "West US 2"
  oidc_issuer_url      = module.kubernetes_secondary.oidc_issuer_url
  key_vault_id         = module.keyvault.vault_id
  tenant_id            = data.azurerm_client_config.current.tenant_id
  namespace            = "payflow"
  service_account_name = "payflow-sa"
  tags                 = azurerm_resource_group.main.tags

  depends_on = [
    module.kubernetes_secondary,
    module.keyvault
  ]
}

# 🗄️ Create PostgreSQL database (Primary)
module "database" {
  source = "../../modules/postgres"

  server_name                 = "payflow-database"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  admin_username              = "dbadmin"
  admin_password              = var.database_password # Set this in terraform.tfvars
  database_subnet_id          = module.app_network.database_subnet_id
  virtual_network_id          = module.app_network.network_id
  geo_redundant_backup_enabled = true # Enable cross-region backup replication
  tags                        = azurerm_resource_group.main.tags
}

# 🗄️ Create secondary PostgreSQL database (for disaster recovery)
module "database_secondary" {
  source = "../../modules/postgres"

  server_name                 = "payflow-database-secondary"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = "West US 2" # Secondary region
  admin_username              = "dbadmin"
  admin_password              = var.database_password # Same password for consistency
  database_subnet_id          = module.app_network_secondary.database_subnet_id
  virtual_network_id          = module.app_network_secondary.network_id
  geo_redundant_backup_enabled = false # Secondary doesn't need geo-redundant backup
  tags                        = azurerm_resource_group.main.tags

  depends_on = [module.app_network_secondary]
}

# ⚡ Create Redis cache (Primary - in spoke network)
module "cache" {
  source = "../../modules/redis"

  cache_name          = "payflow-cache"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.app_network.cache_subnet_id
  virtual_network_id  = module.app_network.network_id
  tags                = azurerm_resource_group.main.tags
}

# ⚡ Create secondary Redis cache (for disaster recovery)
module "cache_secondary" {
  source = "../../modules/redis"

  cache_name          = "payflow-cache-secondary"
  resource_group_name = azurerm_resource_group.main.name
  location            = "West US 2" # Secondary region
  subnet_id           = module.app_network_secondary.cache_subnet_id
  virtual_network_id  = module.app_network_secondary.network_id
  tags                = azurerm_resource_group.main.tags

  depends_on = [module.app_network_secondary]
}

# 💬 Create Azure Service Bus for message queue (Primary - replaces RabbitMQ)
module "servicebus" {
  source = "../../modules/servicebus"

  namespace_name       = "payflow-servicebus"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  sku                  = "Standard" # Standard tier for production
  subnet_id            = module.app_network.kubernetes_subnet_id # Use Kubernetes subnet for private endpoint
  virtual_network_id   = module.app_network.network_id
  tags                 = azurerm_resource_group.main.tags

  depends_on = [module.app_network]
}

# 💬 Create secondary Azure Service Bus (for disaster recovery)
module "servicebus_secondary" {
  source = "../../modules/servicebus"

  namespace_name       = "payflow-servicebus-secondary"
  resource_group_name  = azurerm_resource_group.main.name
  location             = "West US 2" # Secondary region
  sku                  = "Standard" # Standard tier
  subnet_id            = module.app_network_secondary.kubernetes_subnet_id
  virtual_network_id   = module.app_network_secondary.network_id
  tags                 = azurerm_resource_group.main.tags

  depends_on = [module.app_network_secondary]
}

# 🔐 Store Service Bus connection strings in Key Vault
resource "azurerm_key_vault_secret" "servicebus_transactions_connection" {
  name            = "payflow-servicebus-transactions-connection"
  value           = module.servicebus.transactions_connection_string
  key_vault_id    = module.keyvault.vault_id
  expiration_date = timeadd(timestamp(), "87600h") # 10 years from now (connection strings rarely change)
  tags            = azurerm_resource_group.main.tags

  depends_on = [module.servicebus, module.keyvault]
}

resource "azurerm_key_vault_secret" "servicebus_notifications_connection" {
  name            = "payflow-servicebus-notifications-connection"
  value           = module.servicebus.notifications_connection_string
  key_vault_id    = module.keyvault.vault_id
  expiration_date = timeadd(timestamp(), "87600h") # 10 years from now
  tags            = azurerm_resource_group.main.tags

  depends_on = [module.servicebus, module.keyvault]
}

resource "azurerm_key_vault_secret" "servicebus_namespace" {
  name            = "payflow-servicebus-namespace"
  value           = module.servicebus.namespace_name
  key_vault_id    = module.keyvault.vault_id
  expiration_date = timeadd(timestamp(), "87600h") # 10 years from now
  tags            = azurerm_resource_group.main.tags

  depends_on = [module.servicebus, module.keyvault]
}

# 🔐 Store secondary Service Bus connection strings in Key Vault
resource "azurerm_key_vault_secret" "servicebus_secondary_transactions_connection" {
  name            = "payflow-servicebus-secondary-transactions-connection"
  value           = module.servicebus_secondary.transactions_connection_string
  key_vault_id    = module.keyvault.vault_id
  expiration_date = timeadd(timestamp(), "87600h") # 10 years from now
  tags            = azurerm_resource_group.main.tags

  depends_on = [module.servicebus_secondary, module.keyvault]
}

resource "azurerm_key_vault_secret" "servicebus_secondary_notifications_connection" {
  name            = "payflow-servicebus-secondary-notifications-connection"
  value           = module.servicebus_secondary.notifications_connection_string
  key_vault_id    = module.keyvault.vault_id
  expiration_date = timeadd(timestamp(), "87600h") # 10 years from now
  tags            = azurerm_resource_group.main.tags

  depends_on = [module.servicebus_secondary, module.keyvault]
}

resource "azurerm_key_vault_secret" "servicebus_secondary_namespace" {
  name            = "payflow-servicebus-secondary-namespace"
  value           = module.servicebus_secondary.namespace_name
  key_vault_id    = module.keyvault.vault_id
  expiration_date = timeadd(timestamp(), "87600h") # 10 years from now
  tags            = azurerm_resource_group.main.tags

  depends_on = [module.servicebus_secondary, module.keyvault]
}

# 🌐 Create DNS zone for custom domain (first, no dependencies)
module "dns" {
  source = "../../modules/dns"

  domain_name         = "gameapp.games"
  resource_group_name = azurerm_resource_group.main.name
  frontdoor_endpoint  = null # Will be updated after Front Door is created
  tags                = azurerm_resource_group.main.tags
}

# 🌐 Create Front Door for global load balancing
module "frontdoor" {
  source = "../../modules/frontdoor"

  frontdoor_name      = "fd-payflow"
  resource_group_name = azurerm_resource_group.main.name
  domain_name         = "gameapp.games"
  dns_zone_id         = module.dns.zone_id
  # Using placeholder origins - will be updated when ingress is deployed
  primary_origin_host   = "payflow-primary.eastus.cloudapp.azure.com"
  secondary_origin_host = "payflow-secondary.westus2.cloudapp.azure.com"
  health_probe_path     = "/health"
  tags                  = azurerm_resource_group.main.tags

  depends_on = [
    module.kubernetes,
    module.kubernetes_secondary,
    module.dns
  ]
}

# 🌐 Update DNS records with Front Door endpoint
resource "azurerm_dns_cname_record" "apex" {
  count = var.create_dns_records ? 1 : 0
  
  name                = "@"
  zone_name           = module.dns.zone_name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  record              = module.frontdoor.endpoint

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_dns_cname_record" "www" {
  count = var.create_dns_records ? 1 : 0
  
  name                = "www"
  zone_name           = module.dns.zone_name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  record              = module.frontdoor.endpoint

  tags = azurerm_resource_group.main.tags
}

# 🔗 AKS Private DNS Zone Linking
# Note: AKS private DNS zones are created automatically by Azure in managed resource groups
# These need to be linked manually after deployment using Azure CLI:
# 
# Primary AKS:
# az network private-dns link vnet create \
#   --resource-group mc_payflow-production_payflow-cluster-primary_eastus \
#   --zone-name [PRIMARY_CLUSTER_ID].privatelink.eastus.azmk8s.io \
#   --name hub-aks-primary-dns-link \
#   --virtual-network hub-network \
#   --registration-enabled false
#
# Secondary AKS:
# az network private-dns link vnet create \
#   --resource-group mc_payflow-production_payflow-cluster-secondary_westus2 \
#   --zone-name [SECONDARY_CLUSTER_ID].privatelink.westus2.azmk8s.io \
#   --name hub-aks-secondary-dns-link \
#   --virtual-network hub-network \
#   --registration-enabled false
#
# The cluster IDs can be found after deployment using:
# az aks show --resource-group payflow-production --name payflow-cluster-primary --query "privateFqdn" -o tsv
# az aks show --resource-group payflow-production --name payflow-cluster-secondary --query "privateFqdn" -o tsv