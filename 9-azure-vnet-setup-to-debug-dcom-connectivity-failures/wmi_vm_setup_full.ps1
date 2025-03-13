# This version is reusable and accepts arguments and has a bit of logging and error handling.

# Accept the target IP address as a parameter
param (
    [Parameter(Mandatory = $false)]
    [string]$TargetIP,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Show help menu
if ($Help) {
    Write-Host @"
WMI/DCOM Configuration Script
============================

DESCRIPTION
    Configures WMI and DCOM settings for communication between servers.
    Sets up necessary firewall rules and tests connectivity.

USAGE
    ./setup.ps1 -TargetIP <ip_address>
    ./setup.ps1 -Help

PARAMETERS
    -TargetIP <string>
        The IP address of the target machine to test DCOM/WMI connectivity
        Example: -TargetIP "172.19.129.12"

    -Help
        Shows this help message

EXAMPLES
    # Configure and test connection to app server
    ./setup.ps1 -TargetIP "172.19.129.12"

    # Show this help menu
    ./setup.ps1 -Help

NOTES
    - Requires administrative privileges
    - Logs are written to C:\Users\Administrator\Desktop\wmi_setup.log
    - Configures DCOM ports (135 and dynamic ports)
    - Sets up WMI service and required firewall rules

"@ -ForegroundColor Cyan
    exit 0
}

# If the target IP is not provided, show error and help
if (-not $TargetIP) {
    Write-Host "Error: Target IP address is required" -ForegroundColor Red
    Write-Host "Use -Help for usage information" -ForegroundColor Yellow
    exit 1
}

# Create a logging function that will echo the message to the console and write it to a log file
function Log-Message {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    # Create timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Format the log message
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    # Set console color based on level
    $color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        default   { 'White' }
    }
    
    # Write to console with color
    Write-Host $formattedMessage -ForegroundColor $color
    
    # Write to log file
    Add-Content -Path "./wmi_setup.log" -Value $formattedMessage
}

Log-Message "Starting WMI/DCOM setup script"

# Install NuGet package provider
Log-Message "Installing NuGet package provider..." -Level Info
try {
    $result = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
    Log-Message "NuGet package provider installed successfully: Version $($result.Version)" -Level Info
    
    # Verify installation
    $provider = Get-PackageProvider -Name NuGet -ErrorAction Stop
    Log-Message "Verified NuGet provider: Name=$($provider.Name), Version=$($provider.Version)" -Level Info
} 
catch {
    Log-Message "Failed to install NuGet package provider: $($_.Exception.Message)" -Level Error
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    
    # Log additional error details if available
    if ($_.ErrorDetails) {
        Log-Message "Error Details: $($_.ErrorDetails)" -Level Error
    }
    
    Write-Host "`nScript cannot continue without NuGet package provider. Exiting..." -ForegroundColor Red
    exit 1
}

# Update Windows
Log-Message "Starting Windows Update module installation..." -Level Info
try {
    # Check if module is already installed
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Log-Message "PSWindowsUpdate module is already installed" -Level Info
        $moduleInfo = Get-Module -ListAvailable -Name PSWindowsUpdate | Select-Object -First 1
        Log-Message "Current version: $($moduleInfo.Version)" -Level Info
    } else {
        Log-Message "Installing PSWindowsUpdate module..." -Level Info
        $result = Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction Stop
        
        # Verify installation
        $moduleInfo = Get-Module -ListAvailable -Name PSWindowsUpdate | Select-Object -First 1
        if ($moduleInfo) {
            Log-Message "PSWindowsUpdate module installed successfully: Version $($moduleInfo.Version)" -Level Info
        } else {
            throw "Module installation completed but module not found in Get-Module"
        }
    }
} 
catch {
    Log-Message "Failed to install PSWindowsUpdate module: $($_.Exception.Message)" -Level Error
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    
    if ($_.ErrorDetails) {
        Log-Message "Error Details: $($_.ErrorDetails)" -Level Error
    }
    
    Write-Host "`nScript cannot continue without PSWindowsUpdate module. Exiting..." -ForegroundColor Red
    exit 1
}

# Install updates
Log-Message "Starting Windows Update installation process..." -Level Info
try {
    # Check if module is loaded
    if (-not (Get-Module -Name PSWindowsUpdate)) {
        Import-Module PSWindowsUpdate -ErrorAction Stop
        Log-Message "PSWindowsUpdate module loaded successfully" -Level Info
    }

    # Check for available updates first
    Log-Message "Checking for available updates..." -Level Info
    $updates = Get-WUList -ErrorAction Stop
    
    if ($updates) {
        Log-Message "Found $($updates.Count) update(s) available:" -Level Info
        foreach ($update in $updates) {
            Log-Message "- $($update.Title)" -Level Info
        }

        # Install updates
        Log-Message "Beginning update installation..." -Level Info
        $installResult = Get-WUInstall -AcceptAll -AutoReboot -ErrorAction Stop
        
        Log-Message "Update installation completed. System may require reboot." -Level Warning
        
        # Log if reboot is pending
        $rebootPending = Get-WURebootStatus -ErrorAction Stop
        if ($rebootPending) {
            Log-Message "System restart is required to complete updates" -Level Warning
        }
    } else {
        Log-Message "No updates available for installation" -Level Info
    }
} 
catch {
    $errorMsg = $_.Exception.Message
    Log-Message "Failed to install Windows Updates: $errorMsg" -Level Error
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    
    # Additional error context
    switch -Wildcard ($errorMsg) {
        "*No connection could be made*" {
            Log-Message "Network connectivity issue detected. Check internet connection." -Level Error
        }
        "*unauthorized*" {
            Log-Message "Authorization error. Check Windows Update service permissions." -Level Error
        }
        "*service not running*" {
            Log-Message "Windows Update service is not running." -Level Error
        }
        default {
            Log-Message "Unexpected error occurred during update process." -Level Error
        }
    }
    
    # Check Windows Update service status
    try {
        $wuService = Get-Service wuauserv
        Log-Message "Windows Update Service Status: $($wuService.Status)" -Level Info
    } catch {
        Log-Message "Unable to check Windows Update service status" -Level Error
    }
    
    Write-Host "`nWindows Update installation failed. Check logs for details." -ForegroundColor Red
    exit 1
}

# Enable and start WMI service
Log-Message "Enabling and starting WMI service"
Set-Service -Name "Winmgmt" -StartupType Automatic
Start-Service -Name "Winmgmt"

# Create or update firewall rules for DCOM
Log-Message "Configuring DCOM firewall rules..." -Level Info
try {
    # Check and configure DCOM 135 rule
    $rule135 = Get-NetFirewallRule -Name "DCOM-135-Inbound" -ErrorAction SilentlyContinue
    if ($rule135) {
        Log-Message "DCOM-135-Inbound rule exists, ensuring correct configuration..." -Level Info
        Set-NetFirewallRule -Name "DCOM-135-Inbound" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 135 `
            -Action Allow `
            -Enabled True
    } else {
        Log-Message "Creating DCOM-135-Inbound rule..." -Level Info
        New-NetFirewallRule -Name "DCOM-135-Inbound" `
            -DisplayName "Allow DCOM TCP 135 Inbound" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 135 `
            -Action Allow `
            -Enabled True
    }

    # Check and configure DCOM Dynamic Ports rule
    $ruleDynamic = Get-NetFirewallRule -Name "DCOM-Dynamic-Inbound" -ErrorAction SilentlyContinue
    if ($ruleDynamic) {
        Log-Message "DCOM-Dynamic-Inbound rule exists, ensuring correct configuration..." -Level Info
        Set-NetFirewallRule -Name "DCOM-Dynamic-Inbound" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 1024-65535 `
            -Action Allow `
            -Enabled True
    } else {
        Log-Message "Creating DCOM-Dynamic-Inbound rule..." -Level Info
        New-NetFirewallRule -Name "DCOM-Dynamic-Inbound" `
            -DisplayName "Allow DCOM Dynamic Ports Inbound" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 1024-65535 `
            -Action Allow `
            -Enabled True
    }

    # Verify rules
    $rules = Get-NetFirewallRule -Name "DCOM-*" | Select-Object Name, Enabled, Action
    foreach ($rule in $rules) {
        Log-Message "Firewall rule status: $($rule.Name) - Enabled: $($rule.Enabled), Action: $($rule.Action)" -Level Info
    }
}
catch {
    Log-Message "Error configuring firewall rules: $($_.Exception.Message)" -Level Error
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    # Continue execution as this isn't fatal
    Log-Message "Continuing despite firewall rule configuration error..." -Level Warning
}

# Test DCOM connection to the Lenel App machine
Log-Message "Testing DCOM connection to the Lenel App machine"
Test-NetConnection -ComputerName $TargetIP -Port 135

# Configure DCOM
Log-Message "Configuring DCOM"
$regPath = "HKLM:\SOFTWARE\Microsoft\Ole"
Set-ItemProperty -Path $regPath -Name "EnableDCOM" -Value "Y" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "DefaultAuthenticationLevel" -Value 2 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name "DefaultImpersonationLevel" -Value 2 -ErrorAction SilentlyContinue
Log-Message "DCOM enabled."

Log-Message "Setting DCOM permissions"
$acl = Get-Acl "HKLM:\SOFTWARE\Microsoft\Rpc" -ErrorAction SilentlyContinue
$rule = New-Object System.Security.AccessControl.RegistryAccessRule("NETWORK SERVICE", "FullControl", "Allow")
$acl.SetAccessRule($rule)
Set-Acl -Path "HKLM:\SOFTWARE\Microsoft\Rpc" -AclObject $acl -ErrorAction SilentlyContinue
Log-Message "Set DCOM permissions."

Log-Message "Testing DCOM connection to the Lenel App machine"
try {
    $wmiTest = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $TargetIP -ErrorAction Stop
    Log-Message "DCOM test successful: Connected to $($wmiTest.Name)"
} catch {
    Log-Message "DCOM test failed: $_"
}