# This is a simple list of commands that will need to be edited and/or copy/pasted manually. It's a good
# quick reference if you want to take your time and have more control.

# Install NuGet package provider
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Update Windows
Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck

# Install updates
Get-WUInstall -AcceptAll -AutoReboot

# Enable and start WMI service
Set-Service -Name "Winmgmt" -StartupType Automatic
Start-Service -Name "Winmgmt"

# Temporarily disable firewall
# Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# List firewall rules, filter by DisplayName containing "DCOM"
# Get-NetFirewallRule -DisplayName *DCOM* | Format-Table -AutoSize

# Create firewall rule for DCOM
New-NetFirewallRule -Name "DCOM-135-Inbound" -DisplayName "Allow DCOM TCP 135 Inbound"  -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow -Enabled True

# Create firewall rule for DCOM Dynamic Ports
New-NetFirewallRule -Name "DCOM-Dynamic-Inbound" -DisplayName "Allow DCOM Dynamic Ports Inbound" -Direction Inbound -Protocol TCP -LocalPort 1024-65535 -Action Allow -Enabled True

# Confirm firewall rules are created
# Get-NetFirewallRule -Name "DCOM-*" | Format-Table Name, DisplayName, Direction, LocalPort, Action

# Test DCOM connection the NVR server 
Test-NetConnection -ComputerName "10.61.108.20" -Port 135

# Configure DCOM
$regPath = "HKLM:\SOFTWARE\Microsoft\Ole"
Set-ItemProperty -Path $regPath -Name "EnableDCOM" -Value "Y" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "DefaultAuthenticationLevel" -Value 2 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "DefaultImpersonationLevel" -Value 2 -ErrorAction SilentlyContinue
Write-Host "DCOM enabled."

$acl = Get-Acl "HKLM:\SOFTWARE\Microsoft\Rpc" -ErrorAction SilentlyContinue
$rule = New-Object System.Security.AccessControl.RegistryAccessRule("NETWORK SERVICE", "FullControl", "Allow")
$acl.SetAccessRule($rule)
Set-Acl -Path "HKLM:\SOFTWARE\Microsoft\Rpc" -AclObject $acl -ErrorAction SilentlyContinue
Write-Host "Set DCOM permissions."

try {
    $wmiTest = Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20" -ErrorAction Stop
    Write-Host "DCOM test successful: Connected to $($wmiTest.Name)"
} catch {
    Write-Host "DCOM test failed: $_"
}
