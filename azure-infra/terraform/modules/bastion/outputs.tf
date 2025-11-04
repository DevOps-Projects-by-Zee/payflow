# Bastion Module Outputs
# Output values for Azure Bastion resources

output "bastion_id" {
  description = "ID of the Azure Bastion host"
  value       = azurerm_bastion_host.main.id
}

output "bastion_name" {
  description = "Name of the Azure Bastion host"
  value       = azurerm_bastion_host.main.name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host"
  value       = azurerm_public_ip.bastion.ip_address
}

output "bastion_public_ip_id" {
  description = "ID of the Bastion public IP"
  value       = azurerm_public_ip.bastion.id
}

output "bastion_subnet_id" {
  description = "ID of the Bastion subnet"
  value       = azurerm_subnet.bastion.id
}

output "bastion_nsg_id" {
  description = "ID of the Bastion network security group"
  value       = azurerm_network_security_group.bastion.id
}

output "bastion_url" {
  description = "URL to access the Bastion host"
  value       = "https://${azurerm_public_ip.bastion.ip_address}"
}
