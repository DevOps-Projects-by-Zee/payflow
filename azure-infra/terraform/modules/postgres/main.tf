# 🗄️ PostgreSQL Database - Where Your PayFlow Data Lives
# This creates a secure, managed PostgreSQL database for your PayFlow application

# Private DNS zone for secure database access
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Connect DNS zone to your app network
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.virtual_network_id
  tags                  = var.tags
}

# Main PostgreSQL server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "16" # Latest PostgreSQL version

  # Database admin credentials
  administrator_login    = var.admin_username
  administrator_password = var.admin_password

  # Size and performance - General Purpose for HA support
  sku_name   = "GP_Standard_D2s_v3" # General Purpose tier for HA
  storage_mb = 32768                # 32GB storage

  # Security - private access only
  delegated_subnet_id           = var.database_subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false # No internet access

  # Backup settings
  backup_retention_days = 7 # Keep backups for 1 week
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled # Enable cross-region backup replication

  # High Availability configuration
  zone = "1" # Primary zone
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "3" # Use zone 3 as standby
  }

  tags = var.tags
}

# Create the application database
resource "azurerm_postgresql_flexible_server_database" "payflow" {
  name      = "payflow"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}