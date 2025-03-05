# Active Directory Observability - Event Viewer #7

Given your background as a cloud architect and preference for Azure with Terraform, setting up an Active Directory (AD) sandbox in Azure is a perfect fit. This approach leverages your cloud expertise, provides scalability, and lets you manage infrastructure as code (IaC). Below is a detailed guide to launching an AD sandbox in Azure using Terraform, tailored for practicing domain controllers (DCs) and Group Policy Objects (GPOs).

---

### Prerequisites
- **Azure Subscription**: Ensure you have an active subscription (a free trial with $200 credit works for testing).
- **Terraform**: Installed locally (e.g., via `brew`, `choco`, or direct download) or use Azure Cloud Shell (Terraform is pre-installed).
- **Azure CLI**: Installed and authenticated (`az login`) to manage credentials.
- **Basic Tools**: A text editor (e.g., VS Code) for Terraform files and an RDP client to connect to VMs.

---

### High-Level Plan
1. Define an Azure topology (VNet, subnets, VMs).
2. Write Terraform code to provision:
   - A virtual network (VNet) and subnet.
   - One or two Windows Server VMs (for DCs).
   - Optionally, a Windows 10 VM (for GPO testing).
3. Configure the first VM as a domain controller.
4. Set up GPOs and test the environment.

---

### Step 1: Azure Topology
For an AD sandbox:
- **Resource Group**: A container for all resources (e.g., `ad-sandbox-rg`).
- **VNet**: A private network (e.g., `10.0.0.0/16`).
- **Subnet**: A single subnet for simplicity (e.g., `10.0.1.0/24`).
- **VMs**:
  - `DC1` (Windows Server 2022) - Primary DC.
  - `DC2` (optional, Windows Server 2022) - Secondary DC.
  - `Client1` (optional, Windows 10) - GPO test machine.
- **Public IPs**: For RDP access (can be removed later for security).

---

### Step 2: Terraform Code
Here’s a sample Terraform configuration to set up a basic AD sandbox with one DC. You can expand it for additional VMs.

#### Directory Structure
```
ad-sandbox/
├── main.tf         # Main configuration
├── variables.tf    # Variable definitions
├── outputs.tf      # Outputs (e.g., public IPs)
└── terraform.tfvars # Variable values
```

#### `main.tf`
```hcl
provider "azurerm" {
  features {}
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
```

#### `variables.tf`
```hcl
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
```

#### `terraform.tfvars`
```hcl
resource_group_name = "ad-sandbox-rg"
location            = "eastus"
admin_username      = "azureadmin"
admin_password      = "P@ssw0rd1234!" # Use a strong password
```

#### `outputs.tf`
```hcl
output "dc1_public_ip" {
  value = azurerm_public_ip.dc1_pip.ip_address
}
```

---

### Step 3: Deploy with Terraform
1. **Initialize Terraform**:
   ```bash
   terraform init
   ```
2. **Plan the Deployment**:
   ```bash
   terraform plan
   ```
3. **Apply the Configuration**:
   ```bash
   terraform apply
   ```
   - Confirm with `yes` when prompted.
   - Wait 5-10 minutes for provisioning.

4. **Retrieve Public IP**:
   - After deployment, Terraform outputs `dc1_public_ip`. Use it to RDP into the VM.

---

### Step 4: Configure the Domain Controller
1. **RDP to DC1**:
   - Use the public IP with `azureadmin` and your password.
2. **Set Static IP**:
   - In the VM, confirm the NIC is set to `10.0.1.10` (already done via Terraform) and set DNS to itself (`10.0.1.10`).
3. **Install AD DS**:
   - Open **Server Manager** > **Add Roles and Features** > Install **Active Directory Domain Services**.
4. **Promote to DC**:
   - Post-installation, promote it to a DC with a new forest (e.g., `sandbox.local`).
   - Restart the VM after promotion.

---

### Step 5: Expand the Sandbox
To add a second DC or a client VM, extend the Terraform code:
- **Second DC**: Duplicate the `public_ip`, `network_interface`, and `windows_virtual_machine` blocks with a new IP (e.g., `10.0.1.11`).
- **Client VM**: Use a `source_image_reference` for Windows 10:
  ```hcl
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "21h2-pro"
    version   = "latest"
  }
  ```
- Join additional VMs to the domain post-deployment.

---

### Step 6: Configure GPOs
- On `DC1`, open `gpmc.msc` and create/test GPOs (e.g., restrict Control Panel, set wallpaper).
- If you added a client VM, join it to `sandbox.local`, log in with a domain account, and verify GPO application.

---

### Tips for Cloud Architects
- **Security**: After initial setup, replace public IPs with a VPN (e.g., Azure VPN Gateway) or Bastion for secure access.
- **Cost Management**: Use `terraform destroy` to tear down resources when done, as Azure VMs accrue costs.
- **Automation**: Add a `user_data` or `custom_data` script to `azurerm_windows_virtual_machine` to automate AD DS installation (requires PowerShell DSC or similar).
- **Scaling**: Practice multi-region DCs or Azure AD Connect integration for hybrid scenarios.

---

This setup gives you a fully functional AD sandbox in Azure, manageable via Terraform. Let me know if you want to refine the code further (e.g., NSGs, automation scripts) or troubleshoot any deployment steps!


**PowerShell Script for AD DS Deployment**
```ps1
#
# Windows PowerShell script for AD DS Deployment
#

Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "7-ad-lab.sandbox" `
-DomainNetbiosName "7-AD-LAB" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true


```