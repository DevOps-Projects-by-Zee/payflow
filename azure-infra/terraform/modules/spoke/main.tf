# 🏢 Spoke Network - Where Your App Lives
# Think of this as your app's building, connected to the main office (hub)

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space # e.g., ["10.1.0.0/16"]

  tags = var.tags
}

# 🚢 Subnet for Kubernetes cluster
resource "azurerm_subnet" "kubernetes" {
  name                 = "kubernetes-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["${cidrsubnet(var.address_space[0], 8, 1)}"] # Auto-calculate subnet
}

# 🗄️ Subnet for database
resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["${cidrsubnet(var.address_space[0], 8, 2)}"] # Auto-calculate subnet

  # Special permission for PostgreSQL to use this subnet
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ⚡ Subnet for Redis cache
resource "azurerm_subnet" "cache" {
  name                 = "cache-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["${cidrsubnet(var.address_space[0], 8, 3)}"] # Auto-calculate subnet
}

# 🔗 Connect this app network to the hub network
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.name_prefix}-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = var.hub_network_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.name_prefix}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = var.hub_network_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# 🛡️ Simple security - allow internal communication
resource "azurerm_network_security_group" "spoke" {
  name                = "nsg-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow apps to talk to each other
  security_rule {
    name                       = "allow-app-communication"
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

# Apply security to subnets
resource "azurerm_subnet_network_security_group_association" "kubernetes" {
  subnet_id                 = azurerm_subnet.kubernetes.id
  network_security_group_id = azurerm_network_security_group.spoke.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.spoke.id
}

resource "azurerm_subnet_network_security_group_association" "cache" {
  subnet_id                 = azurerm_subnet.cache.id
  network_security_group_id = azurerm_network_security_group.spoke.id
}