# 📤 PostgreSQL Database Outputs
# These are the connection details your app needs

output "server_name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "server_fqdn" {
  description = "PostgreSQL server hostname (private network only)"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Name of the application database"
  value       = azurerm_postgresql_flexible_server_database.payflow.name
}

output "port" {
  description = "PostgreSQL port number"
  value       = 5432
}

output "admin_username" {
  description = "Database administrator username"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

# Connection string template (replace PASSWORD with actual password)
output "connection_string_template" {
  description = "Example connection string for your app"
  value       = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}:PASSWORD@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.payflow.name}?sslmode=require"
}