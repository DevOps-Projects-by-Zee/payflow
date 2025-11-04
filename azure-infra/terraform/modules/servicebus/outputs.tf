# Service Bus Module Outputs
# Provides Service Bus connection information for applications

output "namespace_id" {
  description = "Service Bus namespace ID"
  value       = azurerm_servicebus_namespace.main.id
}

output "namespace_name" {
  description = "Service Bus namespace name"
  value       = azurerm_servicebus_namespace.main.name
}

output "namespace_endpoint" {
  description = "Service Bus namespace endpoint (for private endpoint)"
  value       = azurerm_servicebus_namespace.main.default_primary_connection_string
  sensitive   = true
}

output "transactions_queue_name" {
  description = "Transactions queue name"
  value       = azurerm_servicebus_queue.transactions.name
}

output "notifications_queue_name" {
  description = "Notifications queue name"
  value       = azurerm_servicebus_queue.notifications.name
}

output "transactions_dlq_name" {
  description = "Transactions dead letter queue name"
  value       = azurerm_servicebus_queue.transactions_dlq.name
}

output "transactions_connection_string" {
  description = "Connection string for transactions queue (use authorization rule)"
  value       = azurerm_servicebus_queue_authorization_rule.transactions_send_listen.primary_connection_string
  sensitive   = true
}

output "notifications_connection_string" {
  description = "Connection string for notifications queue"
  value       = azurerm_servicebus_queue_authorization_rule.notifications_send_listen.primary_connection_string
  sensitive   = true
}

output "connection_string_template" {
  description = "Connection string template (replace with actual connection string from Key Vault)"
  value       = "Endpoint=sb://${azurerm_servicebus_namespace.main.name}.servicebus.windows.net/;SharedAccessKeyName=...;SharedAccessKey=..."
}

