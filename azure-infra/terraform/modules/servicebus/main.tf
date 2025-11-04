# 💬 Azure Service Bus - Message Queue Service
# This creates a managed message queue service for PayFlow application
# Purpose: Replaces RabbitMQ with Azure-managed service for better reliability and scalability

# Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = var.namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku # Basic, Standard, or Premium
  
  # Security: Private endpoint only (no public access)
  public_network_access_enabled = false
  
  # Identity: Use system-assigned managed identity for authentication
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Service Bus Queue for Transactions
resource "azurerm_servicebus_queue" "transactions" {
  name         = "transactions"
  namespace_id = azurerm_servicebus_namespace.main.id

  # Queue configuration
  max_delivery_count = 10        # Retry failed messages 10 times
  lock_duration      = "PT30S"   # Lock duration: 30 seconds
  max_size_in_megabytes = 1024   # 1 GB max queue size
  
  # Dead letter queue enabled
  dead_lettering_on_message_expiration = true
  default_message_ttl                  = "PT10M" # 10 minutes TTL
  
  # Duplicate detection
  duplicate_detection_history_time_window = "PT1M" # 1 minute window

  depends_on = [azurerm_servicebus_namespace.main]
}

# Service Bus Queue for Notifications
resource "azurerm_servicebus_queue" "notifications" {
  name         = "notifications"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count = 5
  lock_duration     = "PT30S"
  max_size_in_megabytes = 256  # 256 MB for notifications
  
  dead_lettering_on_message_expiration = true
  default_message_ttl                  = "PT5M" # 5 minutes TTL
  
  duplicate_detection_history_time_window = "PT1M"

  depends_on = [azurerm_servicebus_namespace.main]
}

# Service Bus Queue for Dead Letter Queue (failed transactions)
resource "azurerm_servicebus_queue" "transactions_dlq" {
  name         = "transactions-dlq"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count = 1
  lock_duration     = "PT5M"
  max_size_in_megabytes = 512  # 512 MB for DLQ
  
  # No expiration for DLQ - manual review needed
  default_message_ttl = "P7D" # 7 days retention

  depends_on = [azurerm_servicebus_namespace.main]
}

# Authorization Rule: Send and Listen (for applications)
resource "azurerm_servicebus_queue_authorization_rule" "transactions_send_listen" {
  name     = "transactions-send-listen"
  queue_id = azurerm_servicebus_queue.transactions.id

  send   = true
  listen = true
  manage = false # No management permissions for security
}

resource "azurerm_servicebus_queue_authorization_rule" "notifications_send_listen" {
  name     = "notifications-send-listen"
  queue_id = azurerm_servicebus_queue.notifications.id

  send   = true
  listen = true
  manage = false
}

# Private DNS Zone for Service Bus
resource "azurerm_private_dns_zone" "servicebus" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "${var.namespace_name}-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.virtual_network_id
  registration_enabled   = false

  tags = var.tags

  depends_on = [azurerm_private_dns_zone.servicebus]
}

# Private Endpoint for Service Bus (secure access from VNet)
resource "azurerm_private_endpoint" "servicebus" {
  name                = "${var.namespace_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.namespace_name}-psc"
    private_connection_resource_id = azurerm_servicebus_namespace.main.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "${var.namespace_name}-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.servicebus.id]
  }

  tags = var.tags

  depends_on = [
    azurerm_servicebus_namespace.main,
    azurerm_private_dns_zone.servicebus,
    azurerm_private_dns_zone_virtual_network_link.servicebus
  ]
}

