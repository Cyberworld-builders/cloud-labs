Below is a revised version of the instructions, excluding the actual Lenel setup and focusing on simulating an NVR environment on `nvr-vm` (10.61.108.20) using PowerShell commands. We’ll configure DCOM on both `app-vm` (172.19.129.12) and `nvr-vm` entirely with PowerShell, leveraging WMI as a stand-in for the NVR’s DCOM services. This keeps everything scriptable and verifiable, aligning with your request to start fresh and simulate the scenario.

---

### Step 1: Simulate NVR on `nvr-vm` (10.61.108.20)
Since we’re not installing Lenel LNVR, we’ll simulate an NVR by ensuring WMI (which uses DCOM) is fully operational, mimicking a video service endpoint.

#### Prerequisites
- **RDP Access**: Log into `nvr-vm` via RDP using the public IP (`nvr_public_ip` output) with `adminuser` and `P@ssw0rd1234!` (or your updated password).
- **PowerShell**: Run all commands as Administrator.

#### Setup Process (PowerShell)
1. **Install Windows Updates**:

- manually install the NuGet provider:
    ```powershell
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    ```
- Then retry the module installation:
  ```powershell
  Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
  ```

   ```powershell
   Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck
   Get-WUInstall -AcceptAll -AutoReboot
   ```
   - Ensures the OS is patched for stability.

2. **Simulate NVR with WMI**:
   - Enable and start the WMI service (a DCOM-based service):
     ```powershell
     Set-Service -Name "Winmgmt" -StartupType Automatic
     Start-Service -Name "Winmgmt"
     ```
   - Verify it’s running:
     ```powershell
     Get-Service -Name "Winmgmt" | Select-Object Name, Status, StartType
     ```

3. **Verify Network Configuration**:
   - Confirm IP:
     ```powershell
     Get-NetIPAddress | Where-Object { $_.IPAddress -eq "10.61.108.20" }
     ```
   - Test connectivity to `app-vm`:
     ```powershell
     Test-NetConnection -ComputerName "172.19.129.12" -Port 135
     ```
     - Expect `TcpTestSucceeded : True`.

---

### Step 2: Configure DCOM on Both VMs with PowerShell
We’ll use PowerShell to enable DCOM, set permissions, and configure the firewall, replacing manual `dcomcnfg` steps.

#### On `nvr-vm` (10.61.108.20) - Simulated NVR Side
1. **Enable DCOM**:
   ```powershell
   $regPath = "HKLM:\SOFTWARE\Microsoft\Ole"
   Set-ItemProperty -Path $regPath -Name "EnableDCOM" -Value "Y" -Force
   Set-ItemProperty -Path $regPath -Name "DefaultAuthenticationLevel" -Value 2 # Connect
   Set-ItemProperty -Path $regPath -Name "DefaultImpersonationLevel" -Value 2 # Identify
   Write-Host "DCOM enabled with Connect authentication and Identify impersonation."
   ```

2. **Set DCOM Permissions**:
   - Add `NETWORK SERVICE` (common for services) to DCOM permissions using `Set-DCOMPermission` (if available) or registry tweaks:
   ```powershell
   # Note: Full permission setting requires COM admin tools or a custom script. Simplifying here:
   $acl = Get-Acl "HKLM:\SOFTWARE\Microsoft\Rpc"
   $rule = New-Object System.Security.AccessControl.RegistryAccessRule("NETWORK SERVICE", "FullControl", "Allow")
   $acl.SetAccessRule($rule)
   Set-Acl "HKLM:\SOFTWARE\Microsoft\Rpc" $acl
   Write-Host "Added NETWORK SERVICE to RPC permissions (simplified)."
   ```
   - For precise DCOM permissions, you’d need Lenel-specific COM objects; this simulates broad access.

3. **Configure Windows Firewall**:
   ```powershell
   New-NetFirewallRule -Name "DCOM-135" -DisplayName "Allow DCOM TCP 135" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow -Enabled True
   New-NetFirewallRule -Name "DCOM-Dynamic" -DisplayName "Allow DCOM Dynamic Ports" -Direction Inbound -Protocol TCP -LocalPort 1024-65535 -Action Allow -Enabled True
   New-NetFirewallRule -Name "DCOM-Outbound" -DisplayName "Allow DCOM Outbound" -Direction Outbound -Protocol TCP -LocalPort 135,1024-65535 -Action Allow -Enabled True
   Get-NetFirewallRule -Name "DCOM*" | Format-Table Name, Enabled, Direction, Action
   ```

4. **Verify Listening Ports**:
   ```powershell
   netstat -ano | Find-Str "135"
   Write-Host "Check if TCP 135 is LISTENING above."
   ```

#### On `app-vm` (172.19.129.12) - Client Side
1. **Enable DCOM**:
   ```powershell
   $regPath = "HKLM:\SOFTWARE\Microsoft\Ole"
   Set-ItemProperty -Path $regPath -Name "EnableDCOM" -Value "Y" -Force
   Set-ItemProperty -Path $regPath -Name "DefaultAuthenticationLevel" -Value 2 # Connect
   Set-ItemProperty -Path $regPath -Name "DefaultImpersonationLevel" -Value 2 # Identify
   Write-Host "DCOM enabled with Connect authentication and Identify impersonation."
   ```

2. **Set DCOM Permissions**:
   ```powershell
   $acl = Get-Acl "HKLM:\SOFTWARE\Microsoft\Rpc"
   $rule = New-Object System.Security.AccessControl.RegistryAccessRule("NETWORK SERVICE", "FullControl", "Allow")
   $acl.SetAccessRule($rule)
   Set-Acl "HKLM:\SOFTWARE\Microsoft\Rpc" $acl
   Write-Host "Added NETWORK SERVICE to RPC permissions (simplified)."
   ```

3. **Configure Windows Firewall**:
   ```powershell
   New-NetFirewallRule -Name "DCOM-135" -DisplayName "Allow DCOM TCP 135" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow -Enabled True
   New-NetFirewallRule -Name "DCOM-Dynamic" -DisplayName "Allow DCOM Dynamic Ports" -Direction Inbound -Protocol TCP -LocalPort 1024-65535 -Action Allow -Enabled True
   New-NetFirewallRule -Name "DCOM-Outbound" -DisplayName "Allow DCOM Outbound" -Direction Outbound -Protocol TCP -LocalPort 135,1024-65535 -Action Allow -Enabled True
   Get-NetFirewallRule -Name "DCOM*" | Format-Table Name, Enabled, Direction, Action
   ```

4. **Verify Network**:
   ```powershell
   Get-NetIPAddress | Where-Object { $_.IPAddress -eq "172.19.129.12" }
   Test-NetConnection -ComputerName "10.61.108.20" -Port 135
   ```

---

### Step 3: Test DCOM Connectivity
Simulate Lenel’s DCOM usage by testing WMI connectivity from `app-vm` to `nvr-vm`.

#### From `app-vm`
```powershell
try {
    $wmiTest = Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20" -ErrorAction Stop
    Write-Host "DCOM test successful: Connected to $($wmiTest.Name)"
} catch {
    Write-Host "DCOM test failed: $_"
}
```

- **Success**: Indicates DCOM is working bidirectionally.
- **Failure**: Check firewall, DCOM settings, or network (NSG rules).

---

### Step 4: Simulate the Issue and Troubleshoot
1. **Baseline Test**:
   - Run the WMI test above—should work with current settings.

2. **Simulate Failure**:
   - Disable DCOM on `app-vm`:
     ```powershell
     Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "N"
     ```
   - Retest WMI:
     ```powershell
     Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20"
     ```
     - Expect failure (e.g., "RPC Server Unavailable").

3. **Re-enable and Verify**:
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y"
   Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20"
   ```

4. **Capture Output**:
   - Use `Out-File` or screenshots:
     ```powershell
     Get-WmiObject -Class Win32_ComputerSystem -ComputerName "10.61.108.20" | Out-File "C:\dcom_test.txt"
     ```

---

### Consolidated PowerShell Script
Combine into one script (`dcom_setup.ps1`) for both VMs, with conditional logic:

```powershell
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
```

- **Run**: Copy to both VMs, execute via RDP, and verify output.

---

### Next Steps
- **Deploy**: Run the script on both VMs.
- **Verify**: Check DCOM connectivity and simulate failures.
- **Document**: Save outputs/screenshots for your Cloud Labs repo.

This keeps it Lenel-free, fully PowerShell-driven, and replicable. Let me know if you need adjustments or run into issues! What’s your plan from here?