#Requires -RunAsAdministrator
# ═══════════════════════════════════════════════════════════════════
# PRIME — Win10 22H2 Optimizer | GUI + CLI | All 75 Tweaks
# Usage:
#   .\prime.ps1                         → Launch GUI
#   .\prime.ps1 -TweakId 38             → Run single tweak by ID
#   .\prime.ps1 -TweakId 1,15,23        → Run multiple tweaks by IDs
#   .\prime.ps1 -List                   → Show all tweak names
# ═══════════════════════════════════════════════════════════════════

param(
    [int[]]$TweakId,
    [switch]$List
)

$ErrorActionPreference = "Continue"

# ── Admin check with param passthrough ──
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = @("-NoProfile","-ExecutionPolicy","Bypass")
    if ($List) {
        $argList += "-File"; $argList += "`"$PSCommandPath`""; $argList += "-List"
    } elseif ($TweakId -and $TweakId.Count -gt 0) {
        $argList += "-File"; $argList += "`"$PSCommandPath`""; $argList += "-TweakId"; $argList += ($TweakId -join ',')
    } else {
        $argList += "-WindowStyle"; $argList += "Hidden"
        $argList += "-File"; $argList += "`"$PSCommandPath`""
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $argList -join ' '
    $psi.Verb = "runas"
    if (-not $List -and (-not $TweakId -or $TweakId.Count -eq 0)) {
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    }
    try { [System.Diagnostics.Process]::Start($psi) | Out-Null } catch {}
    exit
}

# ── List mode (CLI, no GUI) ──
if ($List) {
    $allNames = @(
        "Kernel + Timer (TSC)","Timer Resolution","Process Priority","IRQ MSI Mode",
        "Memory Management","Storage Optimizations","Input and USB","Nagle Algorithm",
        "Visual Effects","GameBar DVR + GameMode OFF","Processor Power + HP Plan",
        "CPU Core Parking","GPU Display (HAGS OFF)","Audio Latency",
        "Network + DNS + Stack Reset","Privacy and Telemetry","Windows Services",
        "Junk and Log Cleanup","Interrupt Affinity","NIC Advanced","Hyper-V and VBS",
        "Timer Resolution Runtime","Spectre and Meltdown","Memory Compression",
        "NVIDIA Low Latency","NVIDIA Shader + ReBAR","Exploit Protection",
        "Windows Defender","Background Apps","Delivery Optimization","Device Power",
        "GPU Cache Cleanup","MPO Disable","PCI-E ASPM","Connected Standby",
        "Telemetry Tasks","Windows Ads and Tips","Additional Services",
        "Overlay Killer (GameBar)","Network Noise","Diagnostic Services",
        "System Restore Off","Additional Services v2","Spotlight and Clipboard",
        "NVIDIA Telemetry","News + Copilot Disable","Storage Sense + Edge",
        "Boot and Login Speed","Autologger Disable","Pagefile Optimize",
        "SmartScreen and AutoPlay","Scheduled Tasks v2","LSO + RSS Queues",
        "TCP Window BDP","WiFi Optimize","TCP Congestion","UDP Buffer",
        "NIC Flow + RSS Core","QoS + DSCP","NIC Power Deep","DNS Cache + Flush",
        "TCP KeepAlive + SYN","MMCSS Deep Tuning","NVIDIA Profile","USB Power Deep",
        "NTFS Deep","CPU Scheduling Deep","VBS/HVCI Core Isolation","NVMe Deep",
        "LargeSystemCache + IoPage","Misc Services","UWP Background Disable",
        "ETW Session Disable","CSRSS Priority","DWM Optimization"
    )
    Write-Host ""
    Write-Host "═══ PRIME Tweaks — All 75 Entries ═══" -ForegroundColor Cyan
    for ($i = 0; $i -lt $allNames.Count; $i++) {
        Write-Host ("  [{0:D2}] {1}" -f ($i+1), $allNames[$i]) -ForegroundColor Gray
    }
    Write-Host ""
    exit
}

# ── Detect mode ──
$guiMode = (-not $TweakId -or $TweakId.Count -eq 0)

if ($guiMode) {
    Add-Type -Name Win32ShowWindow -Namespace Native -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@
    $consoleHandle = [Native.Win32ShowWindow]::GetConsoleWindow()
    if ($consoleHandle -ne [IntPtr]::Zero) {
        [Native.Win32ShowWindow]::ShowWindow($consoleHandle, 0) | Out-Null
    }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
}

# ═══════════════════════════════════════════════════════════════════
# [01] Kernel + Timer (TSC optimal for Win10)
# ═══════════════════════════════════════════════════════════════════
function Tweak-01_KernelTimer {
    bcdedit /deletevalue useplatformclock 2>$null | Out-Null
    bcdedit /deletevalue useplatformtick 2>$null | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
    bcdedit /set tscsyncpolicy Enhanced | Out-Null
    bcdedit /set nx OptOut | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[01] Kernel + Timer (TSC) .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [02] Timer Resolution
# ═══════════════════════════════════════════════════════════════════
function Tweak-02_TimerResolution {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[02] Timer Resolution .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [03] Process Priority
# ═══════════════════════════════════════════════════════════════════
function Tweak-03_ProcessPriority {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d 33554432 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" /v AdditionalCriticalWorkerThreads /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v Priority /t REG_DWORD /d 6 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f2c1-98bb-455b-9e09-ae4c1e16cb45" /v Attributes /t REG_DWORD /d 2 /f | Out-Null
    if (-not $guiMode) { Write-Host "[03] Process Priority .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [04] IRQ MSI Mode
# ═══════════════════════════════════════════════════════════════════
function Tweak-04_IrqMsiMode {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -ErrorAction SilentlyContinue | ForEach-Object {
        $msiPath = ($_.PSPath + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties')
        if (Test-Path $msiPath) {
            Set-ItemProperty -Path $msiPath -Name MSISupported -Value 1 -Type DWord -Force
            $affinityPath = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
            if (-not (Test-Path $affinityPath)) { New-Item -Path $affinityPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $affinityPath -Name DevicePriority -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $guiMode) { Write-Host "[04] IRQ MSI Mode ..................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [05] Memory Management
# ═══════════════════════════════════════════════════════════════════
function Tweak-05_MemoryManagement {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SystemCacheDirtyPageThreshold /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f | Out-Null
    powercfg -h off | Out-Null
    taskkill /f /im OneDrive.exe 2>$null | Out-Null
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[05] Memory Management ................ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [06] Storage Optimizations
# ═══════════════════════════════════════════════════════════════════
function Tweak-06_Storage {
    fsutil behavior set disable8dot3 1 | Out-Null
    fsutil behavior set disabledeletenotify 0 | Out-Null
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue
    }
    if (-not $guiMode) { Write-Host "[06] Storage Optimizations ............ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [07] Input and USB
# ═══════════════════════════════════════════════════════════════════
function Tweak-07_InputUSB {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v MouseDataQueueSize /t REG_DWORD /d 16 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v KeyboardDataQueueSize /t REG_DWORD /d 16 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Keyboard" /v KeyboardDelay /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Keyboard" /v KeyboardSpeed /t REG_SZ /d 31 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\HidUsb" /v IdleEnable /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Mouse" /v MouseHoverTime /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
    reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
    reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v Flags /t REG_SZ /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[07] Input and USB .................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [08] Nagle Algorithm
# ═══════════════════════════════════════════════════════════════════
function Tweak-08_Nagle {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name TcpDelAckTicks -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    if (-not $guiMode) { Write-Host "[08] Nagle Algorithm .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [09] Visual Effects
# ═══════════════════════════════════════════════════════════════════
function Tweak-09_VisualEffects {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[09] Visual Effects ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [10] GameBar DVR + Game Mode OFF
# ═══════════════════════════════════════════════════════════════════
function Tweak-10_GameBarDVR {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableXamlStartMenu /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v GamePanelStartupTipIndex /t REG_DWORD /d 3 /f | Out-Null
    if (-not $guiMode) { Write-Host "[10] GameBar DVR + GameMode OFF ....... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [11] Processor Power + High Performance Plan
# ═══════════════════════════════════════════════════════════════════
function Tweak-11_ProcessorPower {
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
    powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    powercfg /hibernate off | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[11] Processor Power .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [12] CPU Core Parking
# ═══════════════════════════════════════════════════════════════════
function Tweak-12_CoreParking {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v ValueMin /t REG_DWORD /d 0 /f | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMAXCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS1INITIALPERF 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS0FLOORPERF 100 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    if (-not $guiMode) { Write-Host "[12] CPU Core Parking ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [13] GPU and Display (HAGS OFF)
# ═══════════════════════════════════════════════════════════════════
function Tweak-13_GpuDisplay {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\DirectX\GraphicsSettings" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f | Out-Null
    if (-not $guiMode) { Write-Host "[13] GPU Display (HAGS OFF) ........... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [14] Audio Latency
# ═══════════════════════════════════════════════════════════════════
function Tweak-14_AudioLatency {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
    if (-not $guiMode) { Write-Host "[14] Audio Latency .................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [15] Network and DNS + Stack Reset
# ═══════════════════════════════════════════════════════════════════
function Tweak-15_NetworkDNS {
    netsh int ip reset 2>$null | Out-Null
    netsh winsock reset 2>$null | Out-Null
    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null
    netsh int tcp set global chimney=disabled | Out-Null
    netsh int tcp set global rsc=disabled | Out-Null
    netsh int tcp set heuristics disabled | Out-Null
    netsh int tcp set global ecncapability=disabled | Out-Null
    netsh int tcp set global fastopen=enabled | Out-Null
    netsh int udp set global uro=disabled | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpDelAckTicks /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTTL /t REG_DWORD /d 64 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisabledComponents /t REG_DWORD /d 255 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnablePMTUDiscovery /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableRSS /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableTCPChimney /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableTCPA /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastSendDatagramThreshold /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 16384 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /t REG_DWORD /d 16384 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v FastCopyReceiveThreshold /t REG_DWORD /d 1536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\QoS" /v "Do not use NLA" /t REG_SZ /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2 -ErrorAction SilentlyContinue
    }
    Get-NetAdapter -Physical | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        Disable-NetAdapterLso -Name $_.Name -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword '*InterruptModeration' -RegistryValue 0 -ErrorAction SilentlyContinue
    }
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Physical } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ('1.1.1.1','8.8.8.8') -ErrorAction SilentlyContinue
        Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
    }
    ipconfig /flushdns | Out-Null
    ipconfig /release | Out-Null
    ipconfig /renew | Out-Null
    if (-not $guiMode) { Write-Host "[15] Network and DNS .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [16] Privacy and Telemetry  ← FIXED: Unicode homoglyphs → ASCII
# ═══════════════════════════════════════════════════════════════════
function Tweak-16_PrivacyTelemetry {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUPowerManagement /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[16] Privacy and Telemetry ............ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [17] Windows Services
# ═══════════════════════════════════════════════════════════════════
function Tweak-17_Services {
    $disableList = @('DiagTrack','MapsBroker','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','Fax','RetailDemo','RemoteRegistry','WerSvc')
    foreach ($s in $disableList) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    $autoList = @('Audiosrv','AudioEndpointBuilder','Dhcp','NlaSvc','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','LanmanWorkstation','LanmanServer','WSearch')
    foreach ($s in $autoList) { sc.exe config $s start= auto 2>$null | Out-Null; sc.exe start $s 2>$null | Out-Null }
    if (-not $guiMode) { Write-Host "[17] Windows Services ................ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [18] Junk and Log Cleanup
# ═══════════════════════════════════════════════════════════════════
function Tweak-18_JunkCleanup {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
        Where-Object { $_.RecordCount -gt 0 -and $_.IsEnabled } |
        ForEach-Object {
            $logName = $_.LogName
            $logJob = Start-Job -ScriptBlock { param($ln) wevtutil.exe cl $ln 2>$null } -ArgumentList $logName
            $done = Wait-Job $logJob -Timeout 3
            if (-not $done) { Stop-Job $logJob -Force }
            Remove-Job $logJob -Force -ErrorAction SilentlyContinue
        }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    if (-not $guiMode) { Write-Host "[18] Junk and Log Cleanup ............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [19] Interrupt Affinity
# ═══════════════════════════════════════════════════════════════════
function Tweak-19_InterruptAffinity {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -ErrorAction SilentlyContinue | ForEach-Object {
        $desc = (Get-ItemProperty $_.PSPath -Name 'DeviceDesc' -ErrorAction SilentlyContinue).DeviceDesc
        $hwid = (Get-ItemProperty $_.PSPath -Name 'HardwareID' -ErrorAction SilentlyContinue).HardwareID
        $affPath = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
        if (-not (Test-Path $affPath)) { New-Item -Path $affPath -Force -ErrorAction SilentlyContinue | Out-Null }
        if ($hwid -and ($hwid[0] -match 'VEN_10DE' -or $hwid[0] -match 'VEN_1002')) {
            Set-ItemProperty -Path $affPath -Name 'DevicePolicy' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $affPath -Name 'AssignmentSetOverride' -Value 0x02 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if ($desc -match 'Ethernet|Network|LAN|Intel.*Connection' -or ($hwid -and ($hwid[0] -match 'VEN_8086.*DEV_15' -or $hwid[0] -match 'VEN_10EC'))) {
            Set-ItemProperty -Path $affPath -Name 'DevicePolicy' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $affPath -Name 'AssignmentSetOverride' -Value 0x04 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        if ($desc -match 'USB|xHCI|Host Controller') {
            Set-ItemProperty -Path $affPath -Name 'DevicePolicy' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $affPath -Name 'AssignmentSetOverride' -Value 0x08 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $guiMode) { Write-Host "[19] Interrupt Affinity ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [20] NIC Advanced
# ═══════════════════════════════════════════════════════════════════
function Tweak-20_NICAdvanced {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*InterruptModeration' -RegistryValue 0 -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Flow Control' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Green Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Receive Buffers' -DisplayValue '2048' -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Transmit Buffers' -DisplayValue '2048' -ErrorAction SilentlyContinue
        Disable-NetAdapterRsc -Name $n -ErrorAction SilentlyContinue
        Set-NetAdapterPowerManagement -Name $n -WakeOnMagicPacket Disabled -WakeOnPattern Disabled -ErrorAction SilentlyContinue
    }
    if (-not $guiMode) { Write-Host "[20] NIC Advanced ..................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [21] Hyper-V and VBS
# ═══════════════════════════════════════════════════════════════════
function Tweak-21_HyperV {
    dism /Online /Disable-Feature /FeatureName:Microsoft-Hyper-V-All /NoRestart 2>$null | Out-Null
    bcdedit /set hypervisorlaunchtype off | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\LSA" /v LsaCfgFlags /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[21] Hyper-V and VBS ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [22] Timer Resolution Runtime
# ═══════════════════════════════════════════════════════════════════
function Tweak-22_TimerResRuntime {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinTimer {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);
    [DllImport("ntdll.dll")]
    public static extern uint NtQueryTimerResolution(out uint MinimumResolution, out uint MaximumResolution, out uint CurrentResolution);
}
"@ -ErrorAction SilentlyContinue
    $min = 0; $max = 0; $cur = 0
    [WinTimer]::NtQueryTimerResolution([ref]$min, [ref]$max, [ref]$cur) | Out-Null
    [WinTimer]::NtSetTimerResolution($max, $true, [ref]$cur) | Out-Null
    $helperPath = "$env:SystemRoot\System32\GOATX_TimerRes.ps1"
    @'
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W{[DllImport("ntdll.dll")]public static extern uint NtSetTimerResolution(uint d,bool s,out uint c);}'
$c=0;[W]::NtSetTimerResolution(5000,$true,[ref]$c)
while($true){Start-Sleep -Seconds 120}
'@ | Out-File $helperPath -Encoding Unicode -Force
    schtasks /Create /TN "GOATX_TimerResolution" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helperPath`"" /SC ONLOGON /RL HIGHEST /F 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[22] Timer Resolution Runtime ......... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [23] Spectre and Meltdown
# ═══════════════════════════════════════════════════════════════════
function Tweak-23_SpectreMeltdown {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f | Out-Null
    if (-not $guiMode) { Write-Host "[23] Spectre and Meltdown ............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [24] Memory Compression
# ═══════════════════════════════════════════════════════════════════
function Tweak-24_MemCompression {
    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    if (-not $guiMode) { Write-Host "[24] Memory Compression ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [25] NVIDIA Low Latency
# ═══════════════════════════════════════════════════════════════════
function Tweak-25_NvidiaLowLatency {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc -match 'NVIDIA'
    } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name 'PerfLevelSrc' -Value 0x2222 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'PowerMizerEnable' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'PowerMizerLevel' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'PowerMizerLevelAC' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'DisableDynamicPstate' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'D3PCLatency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'F1TransitionLatency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMEnableVblankSynchronization' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'EnableMidBufferPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'EnableMidGfxPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'EnableMidBufferPreemptionForHighTdrTimeout' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'EnableCEPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'EnableDeepIdlePreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'EnableAsyncMidBufferPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    if (-not $guiMode) { Write-Host "[25] NVIDIA Low Latency ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [26] NVIDIA Shader + ReBAR
# ═══════════════════════════════════════════════════════════════════
function Tweak-26_NvidiaShader {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc -match 'NVIDIA'
    } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name 'RMEnableAppSpecificProfile' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'ShaderCache' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMFrmForceMaxFramesToRender' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMEnableReBar' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    if (-not $guiMode) { Write-Host "[26] NVIDIA Shader + ReBAR ............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [27] Exploit Protection
# ═══════════════════════════════════════════════════════════════════
function Tweak-27_ExploitProtection {
    Set-ProcessMitigation -System -Disable CFG -ErrorAction SilentlyContinue
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableExceptionChainValidation /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v MoveImages /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[27] Exploit Protection ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [28] Windows Defender
# ═══════════════════════════════════════════════════════════════════
function Tweak-28_DefenderRealtime {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
    Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[28] Windows Defender ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [29] Background Apps
# ═══════════════════════════════════════════════════════════════════
function Tweak-29_BackgroundApps {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f | Out-Null
    if (-not $guiMode) { Write-Host "[29] Background Apps .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [30] Delivery Optimization
# ═══════════════════════════════════════════════════════════════════
function Tweak-30_DeliveryOptimization {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
    Stop-Service DoSvc -Force -ErrorAction SilentlyContinue
    sc.exe config DoSvc start= disabled 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[30] Delivery Optimization ............ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [31] Device Power
# ═══════════════════════════════════════════════════════════════════
function Tweak-31_DevicePower {
    Get-WmiObject -Class Win32_USBHub -ErrorAction SilentlyContinue | ForEach-Object {
        $pnpId = $_.PNPDeviceID; $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (Test-Path "$regPath\WDF") { Set-ItemProperty -Path "$regPath\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    }
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerStateEnabled /t REG_DWORD /d 0 /f 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[31] Device Power ..................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [32] GPU Cache Cleanup
# ═══════════════════════════════════════════════════════════════════
function Tweak-32_GpuCacheCleanup {
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\GLCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\AMD\DxCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $guiMode) { Write-Host "[32] GPU Cache Cleanup ................ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [33] MPO Disable
# ═══════════════════════════════════════════════════════════════════
function Tweak-33_MPODisable {
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f | Out-Null
    if (-not $guiMode) { Write-Host "[33] MPO Disable ...................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [34] PCI-E ASPM
# ═══════════════════════════════════════════════════════════════════
function Tweak-34_PciEAspm {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PnP\Pci" /v DisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f2c1-98bb-455b-9e09-ae4c1e16cb45" /v Attributes /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v NvmeDisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[34] PCI-E ASPM ....................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [35] Connected Standby
# ═══════════════════════════════════════════════════════════════════
function Tweak-35_ConnectedStandby {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v CsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v PlatformAoAcOverride /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v AwayModeEnabled /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[35] Connected Standby ................ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [36] Telemetry Tasks
# ═══════════════════════════════════════════════════════════════════
function Tweak-36_TelemetryTasks {
    $tasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
        '\Microsoft\Windows\Feedback\Siuf\DmClient'
        '\Microsoft\Windows\Maps\MapsToastTask'
        '\Microsoft\Windows\Maps\MapsUpdateTask'
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
        '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask'
        '\Microsoft\Windows\PI\Sqm-Tasks'
        '\Microsoft\Windows\Maintenance\WinSAT'
        '\Microsoft\Windows\Autochk\Proxy'
        '\Microsoft\Windows\Registry\RegIdleBackup'
        '\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents'
        '\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic'
        '\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser'
        '\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange'
    )
    foreach ($t in $tasks) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
    if (-not $guiMode) { Write-Host "[36] Telemetry Tasks .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [37] Windows Ads and Tips
# ═══════════════════════════════════════════════════════════════════
function Tweak-37_WindowsAdsTips {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowInfoBar /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[37] Windows Ads and Tips ............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [38] Additional Services
# ═══════════════════════════════════════════════════════════════════
function Tweak-38_AdditionalServices {
    $extraDisable = @(
        'WpnService','WaaSMedicSvc','SSDPSRV','fdPHost','FDResPub',
        'CDPSvc','CDPUserSvc','PcaSvc','TroubleShootingSvc','DusmSvc',
        'InstallService','PhoneSvc','TapiSrv','SEMgrSvc','SharedAccess',
        'RemoteAccess','lmhosts','WpcMonSvc','ScDeviceEnum','SCardSvr',
        'MessagingService','PimIndexMaintenanceSvc','OneSyncSvc','AJRouter'
    )
    foreach ($s in $extraDisable) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    if (-not $guiMode) { Write-Host "[38] Additional Services .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [39] Overlay Killer (GameBar only)
# ═══════════════════════════════════════════════════════════════════
function Tweak-39_OverlayKiller {
    reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[39] Overlay Killer (GameBar) ......... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [40] Network Noise
# ═══════════════════════════════════════════════════════════════════
function Tweak-40_NetworkNoise {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableBandwidthThrottling /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableLargeMtu /t REG_DWORD /d 0 /f | Out-Null
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\SSDPSRV" /v Start /t REG_DWORD /d 4 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\fdPHost" /v Start /t REG_DWORD /d 4 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\FDResPub" /v Start /t REG_DWORD /d 4 /f | Out-Null
    if (-not $guiMode) { Write-Host "[40] Network Noise .................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [41] Diagnostic Services
# ═══════════════════════════════════════════════════════════════════
function Tweak-41_DiagnosticServices {
    $diagList = @('DPS','WdiServiceHost','WdiSystemHost','diagnosticshub.standardcollector.service','diagsvc','TroubleShootingSvc')
    foreach ($s in $diagList) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v LoggingDisabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v AutoApproveOSDumps /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[41] Diagnostic Services .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [42] System Restore Off
# ═══════════════════════════════════════════════════════════════════
function Tweak-42_SystemRestoreOff {
    Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    $vssJob = Start-Job -ScriptBlock { vssadmin delete shadows /all /quiet 2>$null }
    $done = Wait-Job $vssJob -Timeout 10
    if (-not $done) { Stop-Job $vssJob -Force }
    Remove-Job $vssJob -Force -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[42] System Restore Off ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [43] Additional Services v2
# ═══════════════════════════════════════════════════════════════════
function Tweak-43_AdditionalServices2 {
    $extraDisable2 = @(
        'iphlpsvc','WinRM','wercplsupport','WerSvc','WMPNetworkSvc',
        'UevAgentService','DsSvc','DialogBlockingService','lfsvc','wisvc',
        'WalletService','DsRoleSvc','NcaSvc','NcdAutoSetup','icssvc','SEMgrSvc'
    )
    foreach ($s in $extraDisable2) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    if (-not $guiMode) { Write-Host "[43] Additional Services v2 ........... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [44] Spotlight and Clipboard
# ═══════════════════════════════════════════════════════════════════
function Tweak-44_SpotlightClipboard {
    reg add "HKCU\Software\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowClipboardHistory /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowCrossDeviceClipboard /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableMmx /t REG_DWORD /d 0 /f | Out-Null
    sc.exe stop PhoneSvc 2>$null | Out-Null; sc.exe config PhoneSvc start= disabled 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[44] Spotlight and Clipboard .......... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [45] NVIDIA Telemetry
# ═══════════════════════════════════════════════════════════════════
function Tweak-45_NvidiaTelemetry {
    $nvTasks = @(
        '\NVIDIA\NvDriverUpdateCheckDaily{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
        '\NVIDIA\NvTmRep_CrashReport1_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
        '\NVIDIA\NvTmRep_CrashReport2_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
        '\NVIDIA\NvTmRep_CrashReport3_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
        '\NVIDIA\NvTmRep_CrashReport4_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
        '\NVIDIA\NvTmMon_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
    )
    foreach ($t in $nvTasks) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
    $nvTelemetryPath = "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"
    if (Test-Path $nvTelemetryPath) { Set-ItemProperty -Path $nvTelemetryPath -Name 'OptInOrOutPreference' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    if (-not $guiMode) { Write-Host "[45] NVIDIA Telemetry ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [46] News + Interests + Copilot
# ═══════════════════════════════════════════════════════════════════
function Tweak-46_CopilotRecall {
    reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f | Out-Null
    Stop-Process -Name "Widgets" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "WidgetService" -Force -ErrorAction SilentlyContinue
    if (-not $guiMode) { Write-Host "[46] News + Copilot Disable ........... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [47] Storage Sense + Edge
# ═══════════════════════════════════════════════════════════════════
function Tweak-47_StorageEdge {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeCollectionsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeSidebarEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeShoppingAssistantEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v ShowRecommendationsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v AllowTabPreloading /t REG_DWORD /d 0 /f | Out-Null
    Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
    if (-not $guiMode) { Write-Host "[47] Storage Sense + Edge ............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [48] Boot and Login Speed
# ═══════════════════════════════════════════════════════════════════
function Tweak-48_BootLoginSpeed {
    bcdedit /set bootmenupolicy standard | Out-Null
    bcdedit /set bootlog no | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLogonBackgroundImage /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStatusMessages /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[48] Boot and Login Speed ............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [49] Autologger Disable
# ═══════════════════════════════════════════════════════════════════
function Tweak-49_AutologgerDisable {
    $loggers = @(
        'DiagLog','Diagtrack-Listener','Circular Kernel Context Logger',
        'Microsoft-Windows-Rdp-Graphics-RdpIdd-Trace',
        'Microsoft-Windows-Application-Experience',
        'Microsoft-Windows-Application-Experience-Program-Inventory',
        'Microsoft-Windows-Application-Experience-Program-Telemetry',
        'Microsoft-Windows-Kernel-PnP','Microsoft-Windows-SetupPlatform',
        'Microsoft-Windows-SetupQueue','NetCore','NtfsLog','UBPM',
        'UserNotPresentTraceSession','WiFiSession','WindowsDefenderAudit'
    )
    foreach ($logger in $loggers) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$logger" /v Start /t REG_DWORD /d 0 /f 2>$null | Out-Null }
    reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" /v Value /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" /v Value /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[49] Autologger Disable ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [50] Pagefile Optimize
# ═══════════════════════════════════════════════════════════════════
function Tweak-50_PagefileOptimize {
    $cs = Get-WmiObject Win32_ComputerSystem; $cs.AutomaticManagedPagefile = $false; $cs.Put() | Out-Null
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $size = [math]::Max(4096, [math]::Round($ram * 0.5))
    $pagefile = Get-WmiObject Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ C:'"
    if ($pagefile) { $pagefile.InitialSize = $size; $pagefile.MaximumSize = $size; $pagefile.Put() | Out-Null }
    else {
        $newPF = ([WMIClass]"root\cimv2:Win32_PageFileSetting").CreateInstance()
        $newPF.Name = "C:\pagefile.sys"; $newPF.InitialSize = $size; $newPF.MaximumSize = $size; $newPF.Put() | Out-Null
    }
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -and $_.DriveLetter -ne 'C' } | ForEach-Object {
        $drive = $_.DriveLetter + ":"
        $obj = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveLetter='$drive'"
        if ($obj) { $obj.IndexingEnabled = $false; $obj.Put() | Out-Null }
    }
    if (-not $guiMode) { Write-Host "[50] Pagefile Optimize ................ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [51] SmartScreen + AutoPlay
# ═══════════════════════════════════════════════════════════════════
function Tweak-51_SmartScreen {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d Off /f | Out-Null
    reg add "HKCU\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV9 /t REG_DWORD /d 0 /f | Out-Null
    Set-MpPreference -PUAProtection 0 -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Microsoft\Windows Script Host\Settings" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /v DisableAutoplay /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f | Out-Null
    if (-not $guiMode) { Write-Host "[51] SmartScreen and AutoPlay ......... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [52] Scheduled Tasks v2
# ═══════════════════════════════════════════════════════════════════
function Tweak-52_ScheduledTasks2 {
    $tasks = @(
        '\Microsoft\Windows\DiskFootprint\Diagnostics','\Microsoft\Windows\DiskFootprint\StorageSense',
        '\Microsoft\Windows\PerfTrack\BackgroundConfigSurveyor','\Microsoft\Windows\Shell\FamilySafetyMonitor',
        '\Microsoft\Windows\Shell\FamilySafetyRefreshTask','\Microsoft\Windows\Shell\IndexerAutomaticMaintenance',
        '\Microsoft\Windows\Diagnosis\Scheduled','\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting','\Microsoft\Windows\Chkdsk\ProactiveScan',
        '\Microsoft\Windows\Defrag\ScheduledDefrag','\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
        '\Microsoft\Office\OfficeTelemetryAgentFallBack2016','\Microsoft\Office\OfficeTelemetryAgentLogOn2016',
        '\Microsoft\Office\Office ClickToRun Service Monitor',
        '\MicrosoftEdgeUpdateTaskMachineCore','\MicrosoftEdgeUpdateTaskMachineUA',
        '\Microsoft\EdgeUpdate\EdgeUpdateTaskMachineCore','\Microsoft\EdgeUpdate\EdgeUpdateTaskMachineUA'
    )
    foreach ($t in $tasks) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
    sc.exe stop edgeupdate 2>$null | Out-Null; sc.exe config edgeupdate start= disabled 2>$null | Out-Null
    sc.exe stop edgeupdatem 2>$null | Out-Null; sc.exe config edgeupdatem start= disabled 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[52] Scheduled Tasks v2 ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [53] LSO + RSS Queues
# ═══════════════════════════════════════════════════════════════════
function Tweak-53_LSOandRSS {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        Disable-NetAdapterLso -Name $n -IPv4 -IPv6 -ErrorAction SilentlyContinue
        $maxRss = (Get-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -ErrorAction SilentlyContinue).RegistryValue
        if ($maxRss) { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -RegistryValue $maxRss -ErrorAction SilentlyContinue }
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*ReceiveBuffers' -RegistryValue 2048 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*TransmitBuffers' -RegistryValue 2048 -ErrorAction SilentlyContinue } catch {}
    }
    if (-not $guiMode) { Write-Host "[53] LSO + RSS Queues ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [54] TCP Window / BDP Tuning
# ═══════════════════════════════════════════════════════════════════
function Tweak-54_TCPWindowTuning {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 262144 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxFreeTcbs /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /t REG_DWORD /d 65534 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxHashTableSize /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /t REG_DWORD /d 65536 /f | Out-Null
    if (-not $guiMode) { Write-Host "[54] TCP Window BDP .................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [55] WiFi Optimize
# ═══════════════════════════════════════════════════════════════════
function Tweak-55_WiFiOptimize {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.MediaType -eq 'Native 802.11' -or $_.InterfaceDescription -match 'Wi-Fi|Wireless|WiFi|WLAN' } | ForEach-Object {
        $n = $_.Name
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*RoamingAggressiveness' -RegistryValue 4 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*PMARPOffload' -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*PMNSOffload' -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*PacketCoalescing' -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*PreferredBand' -RegistryValue 2 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*ThroughputBooster' -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
    }
    reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v fMinimizeConnections /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[55] WiFi Optimize ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [56] TCP Congestion
# ═══════════════════════════════════════════════════════════════════
function Tweak-56_TCPCongestion {
    netsh int tcp set supplemental template=Internet congestionprovider=cubic | Out-Null
    netsh int tcp set supplemental template=Internet initialrto=1000 | Out-Null
    netsh int tcp set supplemental template=Internet icw=10 | Out-Null
    netsh int tcp set supplemental template=Datacenter congestionprovider=cubic | Out-Null
    netsh int tcp set supplemental template=Datacenter initialrto=750 | Out-Null
    netsh int tcp set supplemental template=Datacenter icw=10 | Out-Null
    if (-not $guiMode) { Write-Host "[56] TCP Congestion ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [57] UDP Buffer
# ═══════════════════════════════════════════════════════════════════
function Tweak-57_UDPBuffer {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DatagramSendBufferLength /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DatagramReceiveBufferLength /t REG_DWORD /d 65536 /f | Out-Null
    netsh int udp set global uro=disabled | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxForwardBufferMemory /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxNumForwardPackets /t REG_DWORD /d 65536 /f | Out-Null
    if (-not $guiMode) { Write-Host "[57] UDP Buffer ....................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [58] NIC Flow + RSS Core
# ═══════════════════════════════════════════════════════════════════
function Tweak-58_NICFlowControl {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Packet Coalescing' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*RssBaseProcNumber' -RegistryValue 2 -ErrorAction SilentlyContinue } catch {}
        $cores = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*MaxRssProcessors' -RegistryValue $cores -ErrorAction SilentlyContinue } catch {}
        try { Disable-NetAdapterBinding -Name $n -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue } catch {}
    }
    if (-not $guiMode) { Write-Host "[58] NIC Flow + RSS Core .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [59] QoS + DSCP
# ═══════════════════════════════════════════════════════════════════
function Tweak-59_QoS {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTOSValue /t REG_DWORD /d 184 /f | Out-Null
    if (-not $guiMode) { Write-Host "[59] QoS + DSCP ...................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [60] NIC Power Deep
# ═══════════════════════════════════════════════════════════════════
function Tweak-60_NICPowerDeep {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        Disable-NetAdapterPowerManagement -Name $n -ErrorAction SilentlyContinue
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Wake on Magic Packet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Wake on pattern match' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Green Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*AutoPowerSaveModeEnabled' -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword 'SipsEnabled' -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
    }
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    if (-not $guiMode) { Write-Host "[60] NIC Power Deep ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [61] DNS Cache + Flush
# ═══════════════════════════════════════════════════════════════════
function Tweak-61_DNSCache {
    ipconfig /flushdns | Out-Null; nbtstat -R | Out-Null; nbtstat -RR | Out-Null; arp -d * 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v MaxCacheEntryTtlLimit /t REG_DWORD /d 86400 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v MaxSOACacheEntryTtlLimit /t REG_DWORD /d 120 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v NegativeCacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v NetFailureCacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v NegativeSOACacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2 -ErrorAction SilentlyContinue }
    if (-not $guiMode) { Write-Host "[61] DNS Cache + Flush ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [62] TCP KeepAlive + SYN Protection
# ═══════════════════════════════════════════════════════════════════
function Tweak-62_TCPKeepAlive {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v KeepAliveTime /t REG_DWORD /d 300000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v KeepAliveInterval /t REG_DWORD /d 1000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNumConnections /t REG_DWORD /d 16777214 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SynAttackProtect /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxConnectResponseRetransmissions /t REG_DWORD /d 2 /f | Out-Null
    if (-not $guiMode) { Write-Host "[62] TCP KeepAlive + SYN .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [63] MMCSS Deep Tuning
# ═══════════════════════════════════════════════════════════════════
function Tweak-63_MMCSSDeep {
    $mmcss = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    reg add "$mmcss" /v AlwaysOn /t REG_DWORD /d 1 /f | Out-Null
    reg add "$mmcss" /v NoLazyMode /t REG_DWORD /d 1 /f | Out-Null
    $games = "$mmcss\Tasks\Games"
    reg add "$games" /v "GPU Priority" /t REG_DWORD /d 18 /f | Out-Null
    reg add "$games" /v Priority /t REG_DWORD /d 6 /f | Out-Null
    reg add "$games" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "$games" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
    reg add "$games" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "$games" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "$games" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "$games" /v "Latency Sensitive" /t REG_SZ /d True /f | Out-Null
    $disp = "$mmcss\Tasks\Display Post Processing"
    reg add "$disp" /v "GPU Priority" /t REG_DWORD /d 18 /f | Out-Null
    reg add "$disp" /v Priority /t REG_DWORD /d 8 /f | Out-Null
    reg add "$disp" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "$disp" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
    reg add "$disp" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "$disp" /v "Background Only" /t REG_SZ /d True /f | Out-Null
    reg add "$disp" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "$disp" /v BackgroundPriority /t REG_DWORD /d 24 /f | Out-Null
    reg add "$disp" /v "Latency Sensitive" /t REG_SZ /d True /f | Out-Null
    $audio = "$mmcss\Tasks\Pro Audio"
    reg add "$audio" /v Affinity /t REG_DWORD /d 7 /f | Out-Null
    reg add "$audio" /v "Latency Sensitive" /t REG_SZ /d True /f | Out-Null
    $audioTask = "$mmcss\Tasks\Audio"
    reg add "$audioTask" /v Affinity /t REG_DWORD /d 7 /f | Out-Null
    reg add "$audioTask" /v "Scheduling Category" /t REG_SZ /d Medium /f | Out-Null
    if (-not $guiMode) { Write-Host "[63] MMCSS Deep Tuning ............... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [64] NVIDIA Profile
# ═══════════════════════════════════════════════════════════════════
function Tweak-64_NvidiaProfile {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc -match 'NVIDIA'
    } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name 'RMEnableAppSpecificProfile' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'LowLatencyMode' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMFrmForceMaxFramesToRender' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'TextureQuality' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'PerfLevelSrc' -Value 0x2222 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RmEnableExtSs' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMForceGenSpeed' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    $nvGlobal = "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak"
    if (-not (Test-Path $nvGlobal)) { New-Item -Path $nvGlobal -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $nvGlobal -Name 'DisablePState' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $nvGlobal -Name 'DisableDynamicPstate' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    if (-not $guiMode) { Write-Host "[64] NVIDIA Profile ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [65] USB Power Deep
# ═══════════════════════════════════════════════════════════════════
function Tweak-65_USBPowerDeep {
    Get-WmiObject -Class Win32_USBHub -ErrorAction SilentlyContinue | ForEach-Object {
        $pnpId = $_.PNPDeviceID; $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (Test-Path "$regPath\WDF") { Set-ItemProperty -Path "$regPath\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
        if (Test-Path "$regPath\USB") { Set-ItemProperty -Path "$regPath\USB" -Name 'DeviceIdleEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    }
    Get-WmiObject -Class Win32_USBController -ErrorAction SilentlyContinue | ForEach-Object {
        $pnpId = $_.PNPDeviceID; $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (Test-Path "$regPath\WDF") { Set-ItemProperty -Path "$regPath\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    }
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f | Out-Null
    if (-not $guiMode) { Write-Host "[65] USB Power Deep ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [66] NTFS Deep
# ═══════════════════════════════════════════════════════════════════
function Tweak-66_NTFSDeep {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsMemoryUsage /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 2147483649 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v PathCache /t REG_DWORD /d 128 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v Win31FileSystem /t REG_DWORD /d 0 /f | Out-Null
    sc.exe stop EFS 2>$null | Out-Null; sc.exe config EFS start= disabled 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[66] NTFS Deep ........................ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [67] CPU Scheduling Deep
# ═══════════════════════════════════════════════════════════════════
function Tweak-67_CPUScheduling {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v IRQ8Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 42 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SecondLevelDataCache /t REG_DWORD /d 0 /f | Out-Null
    try { $hasHDD = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' } } catch { $hasHDD = $null }
    if ($hasHDD) {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 3 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    } else {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    }
    if (-not $guiMode) { Write-Host "[67] CPU Scheduling Deep .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [68] VBS/HVCI Core Isolation
# ═══════════════════════════════════════════════════════════════════
function Tweak-68_VBSHVCI {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\LSA" /v LsaCfgFlags /t REG_DWORD /d 0 /f | Out-Null
    bcdedit /set vsmlaunchtype Off 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[68] VBS/HVCI Core Isolation .......... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [69] NVMe Deep
# ═══════════════════════════════════════════════════════════════════
function Tweak-69_NVMeDeep {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerStateEnabled /t REG_DWORD /d 0 /f 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v NvmeDisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'HardwareID' -ErrorAction SilentlyContinue).HardwareID -match 'NVMe|stornvme'
    } | ForEach-Object {
        $affPath = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
        if (-not (Test-Path $affPath)) { New-Item -Path $affPath -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $affPath -Name 'DevicePolicy' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $affPath -Name 'AssignmentSetOverride' -Value 0x02 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters" /v IoTimeoutValue /t REG_DWORD /d 255 /f 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[69] NVMe Deep ....................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [70] LargeSystemCache + IoPageLockLimit
# ═══════════════════════════════════════════════════════════════════
function Tweak-70_LargeSystemCache {
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    if ($ram -ge 16) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 1 /f | Out-Null }
    else { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f | Out-Null }
    $ramMB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $ioLock = [math]::Round($ramMB * 0.75 * 4096)
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v IoPageLockLimit /t REG_DWORD /d $ioLock /f | Out-Null
    if (-not $guiMode) { Write-Host "[70] LargeSystemCache + IoPage ........ OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [71] Misc Services
# ═══════════════════════════════════════════════════════════════════
function Tweak-71_MiscServices {
    sc.exe stop Spooler 2>$null | Out-Null; sc.exe config Spooler start= disabled 2>$null | Out-Null
    sc.exe stop SessionEnv 2>$null | Out-Null; sc.exe config SessionEnv start= disabled 2>$null | Out-Null
    sc.exe stop TermService 2>$null | Out-Null; sc.exe config TermService start= disabled 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f | Out-Null
    sc.exe stop lfsvc 2>$null | Out-Null; sc.exe config lfsvc start= disabled 2>$null | Out-Null
    sc.exe stop WalletService 2>$null | Out-Null; sc.exe config WalletService start= disabled 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CDP" /v RomeSdkConsumerUserSettings /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[71] Misc Services ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [72] UWP Background Disable
# ═══════════════════════════════════════════════════════════════════
function Tweak-72_UWPBackgroundDisable {
    $uwpDisable = @(
        'Microsoft.Windows.Photos_8wekyb3d8bbwe','Microsoft.ZuneVideo_8wekyb3d8bbwe',
        'Microsoft.BingNews_8wekyb3d8bbwe','Microsoft.BingWeather_8wekyb3d8bbwe',
        'Microsoft.GetHelp_8wekyb3d8bbwe','Microsoft.Getstarted_8wekyb3d8bbwe',
        'Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe','Microsoft.People_8wekyb3d8bbwe',
        'Microsoft.SkypeApp_kzf8qxf38zg5c','Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe',
        'Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe','Microsoft.Xbox.TCUI_8wekyb3d8bbwe',
        'Microsoft.XboxApp_8wekyb3d8bbwe','Microsoft.XboxGameOverlay_8wekyb3d8bbwe',
        'Microsoft.XboxGamingOverlay_8wekyb3d8bbwe','Microsoft.XboxIdentityProvider_8wekyb3d8bbwe',
        'Microsoft.YourPhone_8wekyb3d8bbwe','Microsoft.WindowsMaps_8wekyb3d8bbwe',
        'Microsoft.Messaging_8wekyb3d8bbwe','Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe'
    )
    foreach ($app in $uwpDisable) {
        $appPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$app"
        reg add "$appPath" /v Disabled /t REG_DWORD /d 1 /f 2>$null | Out-Null
        reg add "$appPath" /v DisabledByUser /t REG_DWORD /d 1 /f 2>$null | Out-Null
    }
    if (-not $guiMode) { Write-Host "[72] UWP Background Disable ........... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [73] ETW Session Disable
# ═══════════════════════════════════════════════════════════════════
function Tweak-73_ETWDisable {
    $etwSessions = @('DiagLog','Diagtrack-Listener','WiFiSession','UserNotPresentTraceSession','NtfsLog')
    foreach ($session in $etwSessions) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$session" /v Start /t REG_DWORD /d 0 /f 2>$null | Out-Null }
    if (-not $guiMode) { Write-Host "[73] ETW Session Disable .............. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [74] CSRSS Priority
# ═══════════════════════════════════════════════════════════════════
function Tweak-74_CSRSSPriority {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v CpuPriorityClass /t REG_DWORD /d 4 /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v IoPriority /t REG_DWORD /d 3 /f 2>$null | Out-Null
    if (-not $guiMode) { Write-Host "[74] CSRSS Priority ................... OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# [75] DWM Optimization  ← FIXED: csrss.exe → dwm.exe
# ═══════════════════════════════════════════════════════════════════
function Tweak-75_DWMOptimize {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v CpuPriorityClass /t REG_DWORD /d 4 /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v IoPriority /t REG_DWORD /d 3 /f 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v AlwaysHibernateThumbnails /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
    if (-not $guiMode) { Write-Host "[75] DWM Optimization ................. OK" -ForegroundColor Green }
}

# ═══════════════════════════════════════════════════════════════════
# MASTER TABLE
# ═══════════════════════════════════════════════════════════════════
$TweakMap = [ordered]@{
    1  = @{ Name = "Kernel + Timer (TSC)";        Fn = { Tweak-01_KernelTimer } }
    2  = @{ Name = "Timer Resolution";            Fn = { Tweak-02_TimerResolution } }
    3  = @{ Name = "Process Priority";            Fn = { Tweak-03_ProcessPriority } }
    4  = @{ Name = "IRQ MSI Mode";                Fn = { Tweak-04_IrqMsiMode } }
    5  = @{ Name = "Memory Management";           Fn = { Tweak-05_MemoryManagement } }
    6  = @{ Name = "Storage Optimizations";       Fn = { Tweak-06_Storage } }
    7  = @{ Name = "Input and USB";               Fn = { Tweak-07_InputUSB } }
    8  = @{ Name = "Nagle Algorithm";             Fn = { Tweak-08_Nagle } }
    9  = @{ Name = "Visual Effects";              Fn = { Tweak-09_VisualEffects } }
    10 = @{ Name = "GameBar DVR + GameMode OFF";  Fn = { Tweak-10_GameBarDVR } }
    11 = @{ Name = "Processor Power + HP Plan";   Fn = { Tweak-11_ProcessorPower } }
    12 = @{ Name = "CPU Core Parking";            Fn = { Tweak-12_CoreParking } }
    13 = @{ Name = "GPU Display (HAGS OFF)";      Fn = { Tweak-13_GpuDisplay } }
    14 = @{ Name = "Audio Latency";               Fn = { Tweak-14_AudioLatency } }
    15 = @{ Name = "Network + DNS + Stack Reset"; Fn = { Tweak-15_NetworkDNS } }
    16 = @{ Name = "Privacy and Telemetry";       Fn = { Tweak-16_PrivacyTelemetry } }
    17 = @{ Name = "Windows Services";            Fn = { Tweak-17_Services } }
    18 = @{ Name = "Junk and Log Cleanup";        Fn = { Tweak-18_JunkCleanup } }
    19 = @{ Name = "Interrupt Affinity";          Fn = { Tweak-19_InterruptAffinity } }
    20 = @{ Name = "NIC Advanced";                Fn = { Tweak-20_NICAdvanced } }
    21 = @{ Name = "Hyper-V and VBS";            Fn = { Tweak-21_HyperV } }
    22 = @{ Name = "Timer Resolution Runtime";    Fn = { Tweak-22_TimerResRuntime } }
    23 = @{ Name = "Spectre and Meltdown";        Fn = { Tweak-23_SpectreMeltdown } }
    24 = @{ Name = "Memory Compression";          Fn = { Tweak-24_MemCompression } }
    25 = @{ Name = "NVIDIA Low Latency";          Fn = { Tweak-25_NvidiaLowLatency } }
    26 = @{ Name = "NVIDIA Shader + ReBAR";       Fn = { Tweak-26_NvidiaShader } }
    27 = @{ Name = "Exploit Protection";          Fn = { Tweak-27_ExploitProtection } }
    28 = @{ Name = "Windows Defender";            Fn = { Tweak-28_DefenderRealtime } }
    29 = @{ Name = "Background Apps";             Fn = { Tweak-29_BackgroundApps } }
    30 = @{ Name = "Delivery Optimization";       Fn = { Tweak-30_DeliveryOptimization } }
    31 = @{ Name = "Device Power";                Fn = { Tweak-31_DevicePower } }
    32 = @{ Name = "GPU Cache Cleanup";           Fn = { Tweak-32_GpuCacheCleanup } }
    33 = @{ Name = "MPO Disable";                 Fn = { Tweak-33_MPODisable } }
    34 = @{ Name = "PCI-E ASPM";                  Fn = { Tweak-34_PciEAspm } }
    35 = @{ Name = "Connected Standby";           Fn = { Tweak-35_ConnectedStandby } }
    36 = @{ Name = "Telemetry Tasks";             Fn = { Tweak-36_TelemetryTasks } }
    37 = @{ Name = "Windows Ads and Tips";        Fn = { Tweak-37_WindowsAdsTips } }
    38 = @{ Name = "Additional Services";         Fn = { Tweak-38_AdditionalServices } }
    39 = @{ Name = "Overlay Killer (GameBar)";    Fn = { Tweak-39_OverlayKiller } }
    40 = @{ Name = "Network Noise";               Fn = { Tweak-40_NetworkNoise } }
    41 = @{ Name = "Diagnostic Services";         Fn = { Tweak-41_DiagnosticServices } }
    42 = @{ Name = "System Restore Off";          Fn = { Tweak-42_SystemRestoreOff } }
    43 = @{ Name = "Additional Services v2";      Fn = { Tweak-43_AdditionalServices2 } }
    44 = @{ Name = "Spotlight and Clipboard";     Fn = { Tweak-44_SpotlightClipboard } }
    45 = @{ Name = "NVIDIA Telemetry";            Fn = { Tweak-45_NvidiaTelemetry } }
    46 = @{ Name = "News + Copilot Disable";      Fn = { Tweak-46_CopilotRecall } }
    47 = @{ Name = "Storage Sense + Edge";        Fn = { Tweak-47_StorageEdge } }
    48 = @{ Name = "Boot and Login Speed";        Fn = { Tweak-48_BootLoginSpeed } }
    49 = @{ Name = "Autologger Disable";          Fn = { Tweak-49_AutologgerDisable } }
    50 = @{ Name = "Pagefile Optimize";           Fn = { Tweak-50_PagefileOptimize } }
    51 = @{ Name = "SmartScreen and AutoPlay";    Fn = { Tweak-51_SmartScreen } }
    52 = @{ Name = "Scheduled Tasks v2";          Fn = { Tweak-52_ScheduledTasks2 } }
    53 = @{ Name = "LSO + RSS Queues";            Fn = { Tweak-53_LSOandRSS } }
    54 = @{ Name = "TCP Window BDP";              Fn = { Tweak-54_TCPWindowTuning } }
    55 = @{ Name = "WiFi Optimize";               Fn = { Tweak-55_WiFiOptimize } }
    56 = @{ Name = "TCP Congestion";              Fn = { Tweak-56_TCPCongestion } }
    57 = @{ Name = "UDP Buffer";                  Fn = { Tweak-57_UDPBuffer } }
    58 = @{ Name = "NIC Flow + RSS Core";         Fn = { Tweak-58_NICFlowControl } }
    59 = @{ Name = "QoS + DSCP";                  Fn = { Tweak-59_QoS } }
    60 = @{ Name = "NIC Power Deep";              Fn = { Tweak-60_NICPowerDeep } }
    61 = @{ Name = "DNS Cache + Flush";           Fn = { Tweak-61_DNSCache } }
    62 = @{ Name = "TCP KeepAlive + SYN";         Fn = { Tweak-62_TCPKeepAlive } }
    63 = @{ Name = "MMCSS Deep Tuning";           Fn = { Tweak-63_MMCSSDeep } }
    64 = @{ Name = "NVIDIA Profile";              Fn = { Tweak-64_NvidiaProfile } }
    65 = @{ Name = "USB Power Deep";              Fn = { Tweak-65_USBPowerDeep } }
    66 = @{ Name = "NTFS Deep";                   Fn = { Tweak-66_NTFSDeep } }
    67 = @{ Name = "CPU Scheduling Deep";         Fn = { Tweak-67_CPUScheduling } }
    68 = @{ Name = "VBS/HVCI Core Isolation";     Fn = { Tweak-68_VBSHVCI } }
    69 = @{ Name = "NVMe Deep";                   Fn = { Tweak-69_NVMeDeep } }
    70 = @{ Name = "LargeSystemCache + IoPage";   Fn = { Tweak-70_LargeSystemCache } }
    71 = @{ Name = "Misc Services";               Fn = { Tweak-71_MiscServices } }
    72 = @{ Name = "UWP Background Disable";      Fn = { Tweak-72_UWPBackgroundDisable } }
    73 = @{ Name = "ETW Session Disable";         Fn = { Tweak-73_ETWDisable } }
    74 = @{ Name = "CSRSS Priority";              Fn = { Tweak-74_CSRSSPriority } }
    75 = @{ Name = "DWM Optimization";            Fn = { Tweak-75_DWMOptimize } }
}

# ═══════════════════════════════════════════════════════════════════
# CLI MODE — Run by TweakId
# ═══════════════════════════════════════════════════════════════════
if (-not $guiMode) {
    foreach ($id in $TweakId) {
        if ($TweakMap.Contains($id)) {
            try { & $TweakMap[$id].Fn } catch { Write-Host "[ERROR] Tweak $id failed: $_" -ForegroundColor Red }
        } else {
            Write-Host "[SKIP] Tweak ID $id not found" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "Done. Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# ═══════════════════════════════════════════════════════════════════
# GUI MODE
# ═══════════════════════════════════════════════════════════════════
if ($guiMode) {

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "PRIME — Win10 22H2 Optimizer (75 Tweaks)"
    $form.Size = New-Object System.Drawing.Size(740, 900)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "PRIME — Win10 22H2 Optimizer"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 180, 255)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(16, 10)
    $form.Controls.Add($lblTitle)

    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = "Select All"; $btnAll.Size = New-Object System.Drawing.Size(90, 28)
    $btnAll.Location = New-Object System.Drawing.Point(16, 44)
    $btnAll.FlatStyle = "Flat"; $btnAll.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $form.Controls.Add($btnAll)

    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = "Deselect All"; $btnNone.Size = New-Object System.Drawing.Size(90, 28)
    $btnNone.Location = New-Object System.Drawing.Point(112, 44)
    $btnNone.FlatStyle = "Flat"; $btnNone.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $form.Controls.Add($btnNone)

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "RUN SELECTED"; $btnRun.Size = New-Object System.Drawing.Size(140, 32)
    $btnRun.Location = New-Object System.Drawing.Point(575, 42)
    $btnRun.FlatStyle = "Flat"
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(0, 180, 255)
    $btnRun.ForeColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
    $btnRun.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnRun)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(16, 82)
    $panel.Size = New-Object System.Drawing.Size(700, 750)
    $panel.AutoScroll = $true
    $panel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
    $form.Controls.Add($panel)

    $checkboxes = @{}
    $y = 6
    foreach ($key in $TweakMap.Keys) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = ("[{0:D2}] {1}" -f $key, $TweakMap[$key].Name)
        $cb.Tag = $key; $cb.AutoSize = $true
        $cb.Location = New-Object System.Drawing.Point(10, $y)
        $cb.ForeColor = [System.Drawing.Color]::FromArgb(210, 210, 210)
        $panel.Controls.Add($cb)
        $checkboxes[$key] = $cb
        $y += 25
    }

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Ready"; $lblStatus.Dock = "Bottom"; $lblStatus.Height = 26
    $lblStatus.TextAlign = "MiddleLeft"
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
    $lblStatus.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 22)
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $form.Controls.Add($lblStatus)

    $btnAll.Add_Click({ foreach ($cb in $checkboxes.Values) { $cb.Checked = $true } })
    $btnNone.Add_Click({ foreach ($cb in $checkboxes.Values) { $cb.Checked = $false } })

    $btnRun.Add_Click({
        $sel = @()
        foreach ($k in ($checkboxes.Keys | Sort-Object)) { if ($checkboxes[$k].Checked) { $sel += $k } }
        if ($sel.Count -eq 0) { $lblStatus.Text = "No tweaks selected!"; return }
        $btnRun.Enabled = $false
        $ok = 0; $fail = 0
        foreach ($id in ($sel | Sort-Object)) {
            $lblStatus.Text = "Running [{0:D2}] {1}..." -f $id, $TweakMap[$id].Name
            $form.Refresh()
            try { & $TweakMap[$id].Fn; $ok++ } catch { $fail++ }
        }
        $lblStatus.Text = "Done — $ok OK, $fail failed"
        $btnRun.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show("Completed: $ok`nFailed: $fail", "PRIME — Results", "OK", "Information")
    })

    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}
