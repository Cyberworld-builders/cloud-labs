# Azure VNet Setup to Debug DCOM Connectivity Failures #9

**Objective**: Deploy an Azure infrastructure with a Virtual Network (VNet) to replicate and troubleshoot network connectivity issues affecting DCOM communication between a Lenel OnGuard application server and an NVR. Goal is to screen grab examples of DCOM troubleshooting steps for client recommendations.

**Details**: 
- Simulate client setup: Application Server (Lenel OnGuard 8.2.524.126, IP: 172.19.129.12) and NVR (Lenel LNVR 7.8.197, IP: 10.61.108.20).
- Configure VNet with subnets mimicking client network (172.19.129.0/24, 10.61.108.0/24).
- Focus on DCOM connectivity (TCP 135, dynamic ports 1024-65535) and local firewall settings.
- Test scenarios: Blocked ports, DCOM misconfiguration, and successful video retrieval.

**Sidenote**: While network connectivity is the primary focus, authorization (e.g., DCOM permissions, service account issues) isn’t fully ruled out and will be checked if connectivity tests are inconclusive.

**Deliverable**: Screenshots and notes in Cloud Labs repo (link: [insert repo URL]).

## Getting Started
We're going to express all of the network and compute resources in Terraform code. The pro vider will be configured to use the currently logged in user for speed and simplicity.

Included will be powershell scripts to automate the configuration of the server and endpoint machines. We will start with fresh os installs and run each command manually in a shell. Once the entire script is validated, we should be able to run it as a part of the TF run for rapid portability.

The following is a initial suggestion from Grok:

Below is the updated Terraform code tailored to your requirements: it uses the current logged-in user for the Azure provider, includes a variable for the subscription ID (set via a `.tfvars` file), creates a new resource group, and deploys the infrastructure (VNet, subnets, NSGs, and two Windows VMs) as before. I’ve also included a PowerShell script to run DCOM troubleshooting commands on the VMs, starting with a fresh Windows install for manual verification. Later, we can adapt this for automation using Azure’s equivalent of EC2 userdata (Azure Custom Script Extension).

---

### Terraform Code (`main.tf`)

```hcl
# Terraform configuration
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Configure the Azure provider to use the current logged-in user
provider "azurerm" {
  features {}
  # Subscription ID will be set via variable (no explicit credentials, uses az login context)
  subscription_id = var.subscription_id
}

# Variables
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  default     = "East US" # Adjust as needed
}

# New Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "lenel-dcom-troubleshooting-rg"
  location = var.location
}

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
    destination_port_range     = "135,1024-65535"
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

# Public IP for NVR (for RDP)
resource "azurerm_public_ip" "nvr_public_ip" {
  name                = "nvr-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Network Interface for NVR
resource "azurerm_network_interface" "nvr_nic" {
  name                = "nvr-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nvr-ip-config"
    subnet_id                     = azurerm_subnet.nvr_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.61.108.20"
    public_ip_address_id          = azurerm_public_ip.nvr_public_ip.id
  }
}

# Windows VM for Application Server
resource "azurerm_windows_virtual_machine" "app_vm" {
  name                  = "app-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "adminuser"
  admin_password        = "P@ssw0rd1234!" # Replace with a secure password
  network_interface_ids = [azurerm_network_interface.app_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# Windows VM for NVR
resource "azurerm_windows_virtual_machine" "nvr_vm" {
  name                  = "nvr-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "adminuser"
  admin_password        = "P@ssw0rd1234!" # Replace with a secure password
  network_interface_ids = [azurerm_network_interface.nvr_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# Outputs
output "app_public_ip" {
  value = azurerm_public_ip.app_public_ip.ip_address
}

output "nvr_public_ip" {
  value = azurerm_public_ip.nvr_public_ip.ip_address
}
```

---

### `.tfvars` File (`terraform.tfvars`)

Create a file named `terraform.tfvars` in the same directory to set the subscription ID:

```hcl
subscription_id = "your-subscription-id-here" # Replace with your Azure subscription ID
```

- Get your subscription ID by running `az account show --query id -o tsv` after `az login`.

---

### PowerShell Script (`dcom_troubleshooting.ps1`)

This script includes the DCOM troubleshooting steps from my earlier response, broken into verifiable commands. Run it manually on each VM via RDP initially. Comments explain each step.

```powershell
# dcom_troubleshooting.ps1
# Run this on both app-vm (172.19.129.12) and nvr-vm (10.61.108.20) to verify DCOM setup

# Step 1: Verify DCOM is Enabled
Write-Host "Checking DCOM status..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Ole"
$dcomEnabled = Get-ItemProperty -Path $regPath -Name "EnableDCOM" -ErrorAction SilentlyContinue
if ($dcomEnabled.EnableDCOM -eq "Y") {
    Write-Host "DCOM is enabled."
} else {
    Write-Host "DCOM is disabled! Enabling it..."
    Set-ItemProperty -Path $regPath -Name "EnableDCOM" -Value "Y"
}

# Step 2: Test Network Connectivity (TCP 135)
Write-Host "Testing TCP 135 to NVR (10.61.108.20)..."
Test-NetConnection -ComputerName "10.61.108.20" -Port 135 | Format-Table -AutoSize

# From NVR, test back to app server (run this section on nvr-vm)
Write-Host "Testing TCP 135 to App Server (172.19.129.12)..."
Test-NetConnection -ComputerName "172.19.129.12" -Port 135 | Format-Table -AutoSize

# Step 3: Check RPC Endpoint Mapper Service
Write-Host "Verifying RPC Endpoint Mapper service..."
Get-Service RpcEptMapper | Select-Object Name, Status, StartType

# Step 4: Check Windows Firewall Rules for DCOM
Write-Host "Checking firewall rules for TCP 135 and dynamic ports..."
$fwRules = Get-NetFirewallRule | Where-Object { $_.Enabled -eq "True" -and $_.Direction -eq "Inbound" -and ($_.LocalPort -eq "135" -or $_.LocalPort -eq "1024-65535") }
if ($fwRules) {
    Write-Host "Found firewall rules for DCOM:"
    $fwRules | Format-Table Name, DisplayName, LocalPort -AutoSize
} else {
    Write-Host "No DCOM firewall rules found! Adding basic rule for TCP 135..."
    New-NetFirewallRule -Name "Allow-DCOM-135" -DisplayName "Allow DCOM TCP 135" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow
}

# Step 5: Test DCOM Connectivity with WMI (from app-vm to nvr-vm)
Write-Host "Testing DCOM via WMI to 10.61.108.20..."
try {
    $wmiTest = Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20" -ErrorAction Stop
    Write-Host "DCOM test successful: Connected to $wmiTest.Name"
} catch {
    Write-Host "DCOM test failed: $_"
}

# Step 6: Enable Verbose DCOM Logging (optional, for deeper debugging)
Write-Host "Enabling verbose RPC logging..."
$rpcRegPath = "HKLM:\SOFTWARE\Microsoft\Rpc"
Set-ItemProperty -Path $rpcRegPath -Name "DebugOutput" -Value 3 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $rpcRegPath -Name "DebugOutputFile" -Value "C:\rpcdebug.log" -ErrorAction SilentlyContinue
Write-Host "RPC logging enabled. Reproduce issue and check C:\rpcdebug.log."

# Pause to review output
Read-Host "Press Enter to exit..."
```

---

### How to Use This

1. **Terraform Setup**:
   - Save `main.tf` and `terraform.tfvars` in a directory.
   - Ensure you’re logged into Azure CLI (`az login`).
   - Run:
     ```
     terraform init
     terraform plan
     terraform apply
     ```
   - Note the output IPs for RDP access.

2. **PowerShell Script**:
   - RDP into `app-vm` (using `app_public_ip`) and `nvr-vm` (using `nvr_public_ip`) with `adminuser` and `P@ssw0rd1234!`.
   - Copy `dcom_troubleshooting.ps1` to each VM.
   - Open PowerShell as Administrator and run:
     ```
     .\dcom_troubleshooting.ps1
     ```
   - Verify each step’s output manually, taking screenshots for your Cloud Labs repo.

3. **Later Automation**:
   - Use `azurerm_virtual_machine_extension` with the Custom Script Extension to run the PowerShell script automatically:
     ```hcl
     resource "azurerm_virtual_machine_extension" "app_script" {
       name                 = "app-dcom-script"
       virtual_machine_id   = azurerm_windows_virtual_machine.app_vm.id
       publisher            = "Microsoft.Compute"
       type                 = "CustomScriptExtension"
       type_handler_version = "1.10"

       settings = <<SETTINGS
         {
           "fileUris": ["https://your-storage.blob.core.windows.net/scripts/dcom_troubleshooting.ps1"],
           "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File dcom_troubleshooting.ps1"
         }
       SETTINGS
     }
     ```
   - Upload the script to an Azure Storage Blob and update the URI.

---

### Notes
- **Fresh Install**: The VMs start with a clean Windows Server 2019 install, allowing manual PowerShell execution.
- **Subscription**: Set your subscription ID in `terraform.tfvars`.
- **Password**: Replace `P@ssw0rd1234!` with a secure one and store it securely.
- **Lenel**: Install Lenel manually after verifying DCOM, or add it to the script later.

What do you think? Need any tweaks to the code or script?