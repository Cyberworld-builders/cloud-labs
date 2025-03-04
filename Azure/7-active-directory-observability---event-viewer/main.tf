# Variables

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

# Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "ad-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "ad-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for DC1
resource "azurerm_public_ip" "dc1_pip" {
  name                = "dc1-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Network Interface for DC1
resource "azurerm_network_interface" "dc1_nic" {
  name                = "dc1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.dc1_pip.id
  }
}

# Windows Server VM for DC1
resource "azurerm_windows_virtual_machine" "dc1" {
  name                  = "dc1-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2s_v3" # 2 vCPUs, 8 GB RAM
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.dc1_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# This security group makes this warning go away. In production, this would not be best 
# practices for security. We would want the rule to be more granular and not allow traffic from the web. 
# We would want a vpn or at the very least a bastion but I'm just doing a lab in a sandbox so we don't 
# want to take the time to set up a vpn or pay for an extra vm as a bastion. 
# Once I prove what I want to test I'll do a `terraform destroy` and none of this will exist.

# Network Security Group
resource "azurerm_network_security_group" "dc1_nsg" {
  name                = "dc1-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "3389"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "dc1_nsg_association" {
  network_interface_id      = azurerm_network_interface.dc1_nic.id
  network_security_group_id = azurerm_network_security_group.dc1_nsg.id
}

# Enable Azure Security Center (Microsoft Defender for Cloud) - Required for JIT
resource "azurerm_security_center_subscription_pricing" "example" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

# Output
output "dc1_public_ip" {
  value = azurerm_public_ip.dc1_pip.ip_address
}
