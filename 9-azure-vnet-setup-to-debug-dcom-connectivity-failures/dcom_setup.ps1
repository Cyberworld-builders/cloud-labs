# dcom_setup.ps1
$myIP = (Get-NetIPAddress | Where-Object { $_.InterfaceAlias -like "Ethernet*" }).IPAddress
$remoteIP = if ($myIP -eq "172.19.129.12") { "10.61.108.20" } else { "172.19.129.12" }

# Enable DCOM
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y" -Force
Set-ItemProperty -Path $regPath -Name "DefaultAuthenticationLevel" -Value 2
Set-ItemProperty -Path $regPath -Name "DefaultImpersonationLevel" -Value 2
Write-Host "DCOM enabled."

# Simulate NVR on 10.61.108.20
if ($myIP -eq "10.61.108.20") {
    Set-Service -Name "Winmgmt" -StartupType Automatic
    Start-Service -Name "Winmgmt"
    Write-Host "WMI service (NVR simulation) running."
}

# Firewall Rules
New-NetFirewallRule -Name "DCOM-135" -DisplayName "Allow DCOM TCP 135" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow -Enabled True -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "DCOM-Dynamic" -DisplayName "Allow DCOM Dynamic Ports" -Direction Inbound -Protocol TCP -LocalPort 1024-65535 -Action Allow -Enabled True -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "DCOM-Outbound" -DisplayName "Allow DCOM Outbound" -Direction Outbound -Protocol TCP -LocalPort 135,1024-65535 -Action Allow -Enabled True -ErrorAction SilentlyContinue
Write-Host "Firewall rules set."

# Test Connectivity
Test-NetConnection -ComputerName $remoteIP -Port 135 | Format-Table -AutoSize

# Test DCOM (from app-vm)
if ($myIP -eq "172.19.129.12") {
    try {
        $wmiTest = Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20" -ErrorAction Stop
        Write-Host "DCOM test successful: Connected to $($wmiTest.Name)"
    } catch {
        Write-Host "DCOM test failed: $_"
    }
}

Read-Host "Press Enter to exit..."