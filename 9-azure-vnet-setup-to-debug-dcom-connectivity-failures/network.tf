# Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "lenel-vnet"
  address_space       = ["10.0.0.0/16"]
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