# Optimize Windows for Maximum RDP Performance
Write-Host "🚀 Starting full system optimization..."

# Initialize guid variable
$guid = $null

# Enable Ultimate Performance power plan
try {
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
    $ultimatePlan = powercfg -list | Select-String "Ultimate"
    if ($ultimatePlan) {
        $guid = $ultimatePlan.Line.Split()[3]
        powercfg -setactive $guid
        Write-Host "✅ Ultimate Performance power plan activated"
    } else {
        throw "Ultimate Performance plan not found"
    }
} catch {
    powercfg -setactive SCHEME_MIN
    $guid = "SCHEME_MIN"
    Write-Host "⚠️ Fallback: High Performance power plan activated"
}

# Maximize CPU performance
if ($guid -and $guid -ne "SCHEME_MIN") {
    try {
        powercfg -setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMAX 100
        powercfg -setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMIN 100
        powercfg -setdcvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMAX 100
        powercfg -setdcvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMIN 100
        powercfg -setactive $guid
        Write-Host "✅ CPU throttle settings set to max"
    } catch {
        Write-Host "⚠️ CPU power settings could not be applied"
    }
} else {
    Write-Host "⚠️ Skipping CPU throttle settings (using fallback power plan)"
}

# Disable visual effects
try {
    # Ensure registry path exists
    $visualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (!(Test-Path $visualEffectsPath)) {
        New-Item -Path $visualEffectsPath -Force | Out-Null
    }
    Set-ItemProperty -Path $visualEffectsPath -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
    Write-Host "✅ Visual effects disabled"
} catch {
    Write-Host "⚠️ Could not disable visual effects"
}

# Disable hibernation
try {
    powercfg -hibernate off
    Write-Host "✅ Hibernation disabled"
} catch {
    Write-Host "⚠️ Could not disable hibernation"
}

# Optimize Pagefile
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $ram = [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)
    $size = $ram * 2 * 1024
    
    # Disable automatic managed pagefile
    $cs | Set-CimInstance -Property @{AutomaticManagedPagefile = $false}
    
    # Remove existing pagefiles
    Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue | Remove-CimInstance -ErrorAction SilentlyContinue
    
    # Create new pagefile
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{ 
        Name = "C:\pagefile.sys"; 
        InitialSize = $size; 
        MaximumSize = $size 
    } -ErrorAction Stop
    
    Write-Host "✅ Pagefile set to ${size}MB (${ram}GB RAM detected)"
} catch {
    Write-Host "⚠️ Could not optimize pagefile: $($_.Exception.Message)"
}

# Disable unnecessary services
try {
    $servicesToDisable = @("WSearch", "MapsBroker", "Fax", "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "WMPNetworkSvc")
    foreach ($serviceName in $servicesToDisable) {
        try {
            $service = Get-Service $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -eq "Running") {
                    Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
                }
                Set-Service $serviceName -StartupType Disabled -ErrorAction Stop
                Write-Host "✓ Disabled: $serviceName"
            } else {
                Write-Host "ℹ Service not found: $serviceName"
            }
        } catch {
            Write-Host "⚠️ Could not disable $serviceName"
        }
    }
} catch {
    Write-Host "⚠️ Error processing services"
}

# Disk I/O Optimization
try {
    fsutil behavior set disablelastaccess 1
    Write-Host "✓ Disabled last access time updates"
    
    # Only defrag if it's an HDD (not SSD)
    try {
        $driveType = (Get-PhysicalDisk | Where-Object {$_.DeviceId -eq 0}).MediaType
        if ($driveType -eq "HDD") {
            defrag C: /O /U /V
            Write-Host "✓ Disk defragmentation completed"
        } else {
            Write-Host "ℹ Skipping defrag (SSD detected)"
        }
    } catch {
        Write-Host "⚠️ Could not determine drive type or defrag"
    }
    
    Write-Host "✅ Disk I/O optimized"
} catch {
    Write-Host "⚠️ Disk optimization incomplete: $($_.Exception.Message)"
}

# GPU Passthrough (RemoteFX / WDDM)
try {
    $rdpPath = 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    if (Test-Path $rdpPath) {
        Set-ItemProperty -Path $rdpPath -Name "UseHardwareRendering" -Value 1 -ErrorAction Stop
        Write-Host "✅ GPU passthrough enabled (if available)"
    } else {
        Write-Host "⚠️ RDP registry path not found"
    }
} catch {
    Write-Host "⚠️ Could not enable GPU passthrough"
}

# Final system responsiveness tweak
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 24 -ErrorAction Stop
    Write-Host "✅ System priority control set for responsiveness"
} catch {
    Write-Host "⚠️ Could not set priority control"
}

Write-Host ""
Write-Host "🎉 Optimization Complete! A restart is recommended for all changes to take effect."