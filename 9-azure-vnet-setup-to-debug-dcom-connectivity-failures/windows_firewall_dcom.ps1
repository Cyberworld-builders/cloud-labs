# windows_firewall_dcom.ps1

# Disable Windows Firewall for debugging
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Enable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Add Windows Firewall Rules
New-NetFirewallRule -Name "DCOM-135" -DisplayName "Allow DCOM TCP 135" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow -Enabled True -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "DCOM-Dynamic" -DisplayName "Allow DCOM Dynamic Ports" -Direction Inbound -Protocol TCP -LocalPort 1024-65535 -Action Allow -Enabled True -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "DCOM-Outbound" -DisplayName "Allow DCOM Outbound" -Direction Outbound -Protocol TCP -LocalPort 135,1024-65535 -Action Allow -Enabled True -ErrorAction SilentlyContinue

# Test Connectivity
Test-NetConnection -ComputerName $remoteIP -Port 135 | Format-Table -AutoSize