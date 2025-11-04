# 📤 Hub Network Outputs
# These are the important details other parts of your infrastructure need

output "network_id" {
  description = "The hub network ID (used to connect other networks)"
  value       = azurerm_virtual_network.hub.id
}

output "network_name" {
  description = "The hub network name"
  value       = azurerm_virtual_network.hub.name
}

output "keyvault_subnet_id" {
  description = "Where to put Key Vault resources"
  value       = azurerm_subnet.keyvault.id
}

output "monitoring_subnet_id" {
  description = "Where to put monitoring resources"
  value       = azurerm_subnet.monitoring.id
}

output "bastion_host_id" {
  description = "Bastion host ID for secure access"
  value       = azurerm_bastion_host.main.id
}

output "bastion_host_name" {
  description = "Bastion host name"
  value       = azurerm_bastion_host.main.name
}

output "bastion_public_ip" {
  description = "Bastion public IP address"
  value       = azurerm_public_ip.bastion.ip_address
}

output "test_vm_id" {
  description = "Test VM ID for Bastion access"
  value       = azurerm_linux_virtual_machine.test.id
}

output "test_vm_name" {
  description = "Test VM name"
  value       = azurerm_linux_virtual_machine.test.name
}

output "test_vm_private_ip" {
  description = "Test VM private IP address"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "test_vm_public_ip" {
  description = "Test VM public IP address (DEPRECATED - VM is now private, access via Bastion only)"
  value       = null # No public IP for security
}

output "test_vm_username" {
  description = "Test VM admin username"
  value       = "azureuser"
}