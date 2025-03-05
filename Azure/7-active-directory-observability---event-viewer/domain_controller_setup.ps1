# Ensure the script runs with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `$PSCommandPath" -Verb RunAs
    exit
}

# Configure network settings (static IP and DNS)
$interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
if ($interface) {
    # Set static IP (adjust as needed for your VNet)
    New-NetIPAddress -InterfaceAlias $interface.Name -IPAddress "10.0.1.10" -PrefixLength 24 -DefaultGateway "10.0.1.1"
    
    # Set DNS to self (DC will be DNS server)
    Set-DnsClientServerAddress -InterfaceAlias $interface.Name -ServerAddresses ("10.0.1.10")
}

# Install Active Directory Domain Services role and tools
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promote the server to a domain controller (new forest)
$password = Get-Content -Path "C:\Scripts\password.txt"
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
Install-ADDSForest -DomainName "7-ad-lab.sandbox" `
                  -DomainNetbiosName "7-AD-LAB" `
                  -ForestMode WinThreshold `
                  -DomainMode WinThreshold `
                  -InstallDns `
                  -SafeModeAdministratorPassword $securePassword `
                  -Force `
                  -NoRebootOnCompletion

# Optional: Add custom configurations (e.g., GPOs, users)
# Example: Create a test user
# New-ADUser -Name "TestUser" -SamAccountName "testuser" -AccountPassword $password -Enabled $true

# Note: The server will need to reboot manually after promotion to complete the configuration
Write-Host "AD DS installation and promotion completed. Please reboot the server to finalize the configuration."