# 🏠 Hub Network - The Central Network
# Think of this as your company's main office building
# It contains shared services that everyone needs to access

resource "azurerm_virtual_network" "hub" {
  name                = "hub-network"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.0.0.0/16"] # Our internal network space

  tags = var.tags
}

# 🔐 Subnet for Key Vault (where we store secrets)
resource "azurerm_subnet" "keyvault" {
  name                 = "keyvault-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"] # 254 IP addresses for Key Vault
}

# 📊 Subnet for monitoring tools
resource "azurerm_subnet" "monitoring" {
  name                 = "monitoring-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"] # 254 IP addresses for monitoring
}

# 🚪 Special subnet for Azure Bastion (secure remote access)
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # This exact name is required by Azure
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/24"] # 254 IP addresses for Bastion
}

# 💻 Subnet for test VM
resource "azurerm_subnet" "vm" {
  name                 = "vm-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.4.0/24"] # 254 IP addresses for VMs
}

# 🛡️ Basic security rules for the hub network
resource "azurerm_network_security_group" "hub" {
  name                = "hub-security-group"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow communication within our network
  security_rule {
    name                       = "allow-internal-traffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

# 🚪 Azure Bastion Host - Secure Access Gateway
# This is your secure way to access private resources like AKS

# Public IP for Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "bastion-public-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "payflow-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

# 🔗 Link Private DNS Zones to Hub Network
# This allows VMs in the hub network to resolve private DNS names

# PostgreSQL Private DNS Zone Link
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "hub-postgres-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.postgres.database.azure.com"
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

# Redis Private DNS Zone Link
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "hub-redis-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.redis.cache.windows.net"
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

# Key Vault Private DNS Zone Link
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "hub-keyvault-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = "privatelink.vaultcore.azure.net"
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

# 💻 Test VM for Bastion Access (Jumpserver)
# This VM acts as a jumpserver to access private AKS clusters via Bastion
# Security: NO public IP - only accessible via Azure Bastion (secure gateway)

# Note: Azure Bastion is the secure gateway - you access it via Azure Portal/CLI
# Flow: Internet → Azure Bastion (managed service) → Test VM (jumpserver) → AKS
# No public IP needed - all access goes through Bastion for security

# Network Security Group for VM
resource "azurerm_network_security_group" "vm" {
  name                = "test-vm-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow SSH from Bastion subnet only (secure access via Bastion)
  security_rule {
    name                       = "allow-ssh-from-bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.bastion.address_prefixes[0] # Bastion subnet CIDR (10.0.3.0/24)
    destination_address_prefix = "*"
  }

  # Allow outbound internet access
  security_rule {
    name                       = "allow-outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Network Interface for VM
# Security: No public IP - only accessible via Azure Bastion
resource "azurerm_network_interface" "vm" {
  name                = "test-vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    # No public IP - only accessible via Azure Bastion for security
  }

  tags = var.tags
}

# Associate NSG with VM subnet
resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "test" {
  name                = "test-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B1s" # Small VM for testing
  admin_username      = "azureuser"

  # Enable both password and SSH key authentication
  disable_password_authentication = false
  admin_password                  = var.vm_admin_password

  # SSH key configuration (optional)
  dynamic "admin_ssh_key" {
    for_each = var.vm_ssh_public_key != null ? [1] : []
    content {
      username   = "azureuser"
      public_key = var.vm_ssh_public_key
    }
  }

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = var.tags
}