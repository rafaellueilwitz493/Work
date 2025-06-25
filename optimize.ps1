# Optimize Windows for Maximum RDP Performance

Write-Host "🚀 Starting full system optimization..."

# Enable Ultimate Performance power plan
try {
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    $guid = (powercfg -list | Select-String "Ultimate").Line.Split()[3]
    powercfg -setactive $guid
    Write-Host "✅ Ultimate Performance power plan activated"
} catch {
    powercfg -setactive SCHEME_MIN
    Write-Host "⚠️ Fallback: High Performance power plan activated"
}

# Maximize CPU performance
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

# Disable visual effects
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
    Write-Host "✅ Visual effects disabled"
} catch {}

# Disable hibernation
powercfg -hibernate off

# Optimize Pagefile
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $ram = [math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)
    $size = $ram * 2 * 1024
    Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile = $false}
    Get-CimInstance -ClassName Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = "C:\\pagefile.sys"; InitialSize = $size; MaximumSize = $size }
    Write-Host "✅ Pagefile set to ${size}MB"
} catch {
    Write-Host "⚠️ Could not optimize pagefile"
}

# Disable services
try {
    $disable = @("WSearch", "MapsBroker", "Fax", "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "WMPNetworkSvc")
    foreach ($svc in $disable) {
        try {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled
            Write-Host "✓ Disabled: $svc"
        } catch {}
    }
} catch {}

# Disk I/O Optimization
try {
    fsutil behavior set disablelastaccess 1
    defrag C: /O /U /V
    Write-Host "✅ Disk I/O optimized"
} catch {
    Write-Host "⚠️ Disk optimization incomplete"
}

# GPU Passthrough (RemoteFX / WDDM)
try {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UseHardwareRendering" -Value 1 -ErrorAction SilentlyContinue
    Write-Host "✅ GPU passthrough enabled (if available)"
} catch {}

# Final system responsiveness tweak
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 24
    Write-Host "✅ System priority control set for responsiveness"
} catch {}

Write-Host "🎉 Optimization Complete"

