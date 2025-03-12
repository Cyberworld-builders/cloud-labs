# Create a VNet with three address spaces and NSG to emulate Meraki.

# Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "lenel-vnet"
  address_space       = ["10.0.0.0/16", "172.19.0.0/16", "10.61.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet for Application Server (172.19.129.0/24)
resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.19.129.0/24"]
}

# Subnet for NVR (10.61.108.0/24)
resource "azurerm_subnet" "nvr_subnet" {
  name                 = "nvr-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.61.108.0/24"]
}


# Network Security Group (NSG) for DCOM traffic
resource "azurerm_network_security_group" "nsg" {
  name                = "lenel-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-dcom-135"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "135"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-dcom-dynamic"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1024-65535"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-dcom-outbound"
    priority                   = 102
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["135", "1024-65535"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with subnets
resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nvr_nsg_assoc" {
  subnet_id                 = azurerm_subnet.nvr_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IP for Application Server (for RDP)
resource "azurerm_public_ip" "app_public_ip" {
  name                = "app-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Network Interface for Application Server
resource "azurerm_network_interface" "app_nic" {
  name                = "app-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "app-ip-config"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.19.129.12"
    public_ip_address_id          = azurerm_public_ip.app_public_ip.id
  }
}
