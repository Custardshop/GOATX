$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    try { [System.Diagnostics.Process]::Start($psi) | Out-Null } catch {}
    exit
}

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

# ============================================================
# [01] Kernel + Timer (TSC optimal for Win10)
# ============================================================
$Tweak_KernelTimer = {
    bcdedit /deletevalue useplatformclock 2>$null | Out-Null
    bcdedit /deletevalue useplatformtick 2>$null | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
    bcdedit /set tscsyncpolicy Enhanced | Out-Null
    bcdedit /set nx OptOut | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [02] Timer Resolution
# ============================================================
$Tweak_TimerResolution = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [03] Process Priority
# ============================================================
$Tweak_ProcessPriority = {
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
}

# ============================================================
# [04] IRQ MSI Mode
# ============================================================
$Tweak_IrqMsiMode = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -ErrorAction SilentlyContinue | ForEach-Object {
        $msiPath = ($_.PSPath + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties')
        if (Test-Path $msiPath) {
            Set-ItemProperty -Path $msiPath -Name MSISupported -Value 1 -Type DWord -Force
            $affinityPath = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
            if (-not (Test-Path $affinityPath)) { New-Item -Path $affinityPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $affinityPath -Name DevicePriority -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# [05] Memory Management
# ============================================================
$Tweak_MemoryManagement = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SystemCacheDirtyPageThreshold /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f | Out-Null
    powercfg -h off | Out-Null
    taskkill /f /im OneDrive.exe 2>$null | Out-Null
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null | Out-Null
}

# ============================================================
# [06] Storage
# ============================================================
$Tweak_Storage = {
    fsutil behavior set disable8dot3 1 | Out-Null
    fsutil behavior set disabledeletenotify 0 | Out-Null
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue
    }
}

# ============================================================
# [07] Input and USB
# ============================================================
$Tweak_InputUSB = {
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
}

# ============================================================
# [08] Nagle Algorithm
# ============================================================
$Tweak_Nagle = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name TcpDelAckTicks -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# [09] Visual Effects
# ============================================================
$Tweak_VisualEffects = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f | Out-Null
}

# ============================================================
# [10] GameBar DVR + Game Mode OFF
# ============================================================
$Tweak_GameBarDVR = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableXamlStartMenu /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v GamePanelStartupTipIndex /t REG_DWORD /d 3 /f | Out-Null
}

# ============================================================
# [11] Processor Power
# ============================================================
$Tweak_ProcessorPower = {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    powercfg /hibernate off | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [12] CPU Core Parking
# ============================================================
$Tweak_CoreParking = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v ValueMin /t REG_DWORD /d 0 /f | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMAXCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS1INITIALPERF 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS0FLOORPERF 100 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
}

# ============================================================
# [13] GPU and Display (HAGS OFF)
# ============================================================
$Tweak_GpuDisplay = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\DirectX\GraphicsSettings" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f | Out-Null
}

# ============================================================
# [14] Audio Latency
# ============================================================
$Tweak_AudioLatency = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
}

# ============================================================
# [15] Network and DNS
# ============================================================
$Tweak_NetworkDNS = {
    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null
    netsh int tcp set global chimney=disabled | Out-Null
    netsh int tcp set global rsc=disabled | Out-Null
    netsh int tcp set heuristics disabled | Out-Null
    netsh int tcp set global ecncapability=enabled | Out-Null
    netsh int tcp set global fastopen=enabled | Out-Null
    netsh int udp set global uro=disabled | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTTL /t REG_DWORD /d 64 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisabledComponents /t REG_DWORD /d 255 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnablePMTUDiscovery /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableRSS /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableTCPChimney /t REG_DWORD /d 0 /f | Out-Null
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
}

# ============================================================
# [16] Privacy and Telemetry
# ============================================================
$Tweak_PrivacyTelemetry = {
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
}

# ============================================================
# [17] Windows Services
# FIX: removed WSearch from autoList (moved to [79] full kill)
# ============================================================
$Tweak_Services = {
    $disableList = @('DiagTrack','MapsBroker','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','Fax','RetailDemo','RemoteRegistry','WerSvc')
    foreach ($s in $disableList) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    $autoList = @('Audiosrv','AudioEndpointBuilder','Dhcp','NlaSvc','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','LanmanWorkstation','LanmanServer')
    foreach ($s in $autoList) { sc.exe config $s start= auto 2>$null | Out-Null; sc.exe start $s 2>$null | Out-Null }
}

# ============================================================
# [18] Junk and Log Cleanup
# FIX: per-log timeout 3s to prevent hang on stuck logs
# ============================================================
$Tweak_JunkCleanup = {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    # FIX: timeout 3s per log to prevent infinite hang
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
        Where-Object { $_.RecordCount -gt 0 -and $_.IsEnabled } |
        ForEach-Object {
            $logName = $_.LogName
            $logJob = Start-Job -ScriptBlock {
                param($ln)
                wevtutil.exe cl $ln 2>$null
            } -ArgumentList $logName
            $done = Wait-Job $logJob -Timeout 3
            if (-not $done) { Stop-Job $logJob -Force }
            Remove-Job $logJob -Force -ErrorAction SilentlyContinue
        }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

# ============================================================
# [19] Interrupt Affinity
# GPU = Core 1, NIC = Core 2, USB = Core 3
# ============================================================
$Tweak_InterruptAffinity = {
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
}

# ============================================================
# [20] NIC Advanced
# ============================================================
$Tweak_NICAdvanced = {
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
}

# ============================================================
# [21] Hyper-V and VBS
# ============================================================
$Tweak_HyperV = {
    dism /Online /Disable-Feature /FeatureName:Microsoft-Hyper-V-All /NoRestart 2>$null | Out-Null
    bcdedit /set hypervisorlaunchtype off | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\LSA" /v LsaCfgFlags /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [22] Timer Resolution Runtime
# ============================================================
$Tweak_TimerResRuntime = {
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
    $helperPath = "$env:SystemRoot\System32\PRIME_TimerRes.ps1"
    @'
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W{[DllImport("ntdll.dll")]public static extern uint NtSetTimerResolution(uint d,bool s,out uint c);}'
$c=0;[W]::NtSetTimerResolution(5000,$true,[ref]$c)
while($true){Start-Sleep -Seconds 120}
'@ | Out-File $helperPath -Encoding Unicode -Force
    schtasks /Create /TN "PRIME_TimerResolution" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helperPath`"" /SC ONLOGON /RL HIGHEST /F 2>$null | Out-Null
}

# ============================================================
# [23] Spectre and Meltdown
# ============================================================
$Tweak_SpectreMeltdown = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f | Out-Null
}

# ============================================================
# [24] Memory Compression
# ============================================================
$Tweak_MemCompression = {
    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
}

# ============================================================
# [25] NVIDIA Low Latency
# ============================================================
$Tweak_NvidiaLowLatency = {
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
}

# ============================================================
# [26] NVIDIA Shader + ReBAR
# ============================================================
$Tweak_NvidiaShader = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc -match 'NVIDIA'
    } | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name 'RMEnableAppSpecificProfile' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'ShaderCache' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMFrmForceMaxFramesToRender' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name 'RMEnableReBar' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# [27] Exploit Protection
# ============================================================
$Tweak_ExploitProtection = {
    Set-ProcessMitigation -System -Disable CFG -ErrorAction SilentlyContinue
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableExceptionChainValidation /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v MoveImages /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [28] Windows Defender
# ============================================================
$Tweak_DefenderRealtime = {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
    Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [29] Background Apps
# ============================================================
$Tweak_BackgroundApps = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f | Out-Null
}

# ============================================================
# [30] Delivery Optimization
# ============================================================
$Tweak_DeliveryOptimization = {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
    Stop-Service DoSvc -Force -ErrorAction SilentlyContinue
    sc.exe config DoSvc start= disabled 2>$null | Out-Null
}

# ============================================================
# [31] Device Power
# ============================================================
$Tweak_DevicePower = {
    Get-WmiObject -Class Win32_USBHub -ErrorAction SilentlyContinue | ForEach-Object {
        $pnpId = $_.PNPDeviceID; $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (Test-Path "$regPath\WDF") { Set-ItemProperty -Path "$regPath\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    }
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerStateEnabled /t REG_DWORD /d 0 /f 2>$null | Out-Null
}

# ============================================================
# [32] GPU Cache Cleanup
# ============================================================
$Tweak_GpuCacheCleanup = {
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\GLCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\AMD\DxCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# ============================================================
# [33] MPO Disable
# ============================================================
$Tweak_MPODisable = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f | Out-Null
}

# ============================================================
# [34] PCI-E ASPM
# ============================================================
$Tweak_PciEAspm = {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PnP\Pci" /v DisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f2c1-98bb-455b-9e09-ae4c1e16cb45" /v Attributes /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v NvmeDisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
}

# ============================================================
# [35] Connected Standby
# ============================================================
$Tweak_ConnectedStandby = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v CsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v PlatformAoAcOverride /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v AwayModeEnabled /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [36] Telemetry Tasks
# ============================================================
$Tweak_TelemetryTasks = {
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
}

# ============================================================
# [37] Windows Ads and Tips
# ============================================================
$Tweak_WindowsAdsTips = {
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
}

# ============================================================
# [38] Additional Services
# ============================================================
$Tweak_AdditionalServices = {
    $extraDisable = @(
        'WpnService','WaaSMedicSvc','SSDPSRV','fdPHost','FDResPub',
        'CDPSvc','CDPUserSvc','PcaSvc','TroubleShootingSvc','DusmSvc',
        'InstallService','PhoneSvc','TapiSrv','SEMgrSvc','SharedAccess',
        'RemoteAccess','lmhosts','WpcMonSvc','ScDeviceEnum','SCardSvr',
        'MessagingService','PimIndexMaintenanceSvc','OneSyncSvc','AJRouter'
    )
    foreach ($s in $extraDisable) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
}

# ============================================================
# [39] Overlay Killer (GameBar only)
# ============================================================
$Tweak_OverlayKiller = {
    reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [40] Network Noise
# ============================================================
$Tweak_NetworkNoise = {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableBandwidthThrottling /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableLargeMtu /t REG_DWORD /d 0 /f | Out-Null
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\SSDPSRV" /v Start /t REG_DWORD /d 4 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\fdPHost" /v Start /t REG_DWORD /d 4 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\FDResPub" /v Start /t REG_DWORD /d 4 /f | Out-Null
}

# ============================================================
# [41] Diagnostic Services
# ============================================================
$Tweak_DiagnosticServices = {
    $diagList = @('DPS','WdiServiceHost','WdiSystemHost','diagnosticshub.standardcollector.service','diagsvc','TroubleShootingSvc')
    foreach ($s in $diagList) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v LoggingDisabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v AutoApproveOSDumps /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [42] System Restore Off
# FIX: timeout 10s for vssadmin to prevent hang
# ============================================================
$Tweak_SystemRestoreOff = {
    Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    # FIX: timeout 10s for vssadmin which can hang on locked VSS
    $vssJob = Start-Job -ScriptBlock { vssadmin delete shadows /all /quiet 2>$null }
    $done = Wait-Job $vssJob -Timeout 10
    if (-not $done) { Stop-Job $vssJob -Force }
    Remove-Job $vssJob -Force -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [43] Additional Services v2
# ============================================================
$Tweak_AdditionalServices2 = {
    $extraDisable2 = @(
        'iphlpsvc','WinRM','wercplsupport','WerSvc','WMPNetworkSvc',
        'UevAgentService','DsSvc','DialogBlockingService','lfsvc','wisvc',
        'WalletService','DsRoleSvc','NcaSvc','NcdAutoSetup','icssvc','SEMgrSvc'
    )
    foreach ($s in $extraDisable2) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
}

# ============================================================
# [44] Spotlight and Clipboard
# ============================================================
$Tweak_SpotlightClipboard = {
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
}

# ============================================================
# [45] NVIDIA Telemetry
# ============================================================
$Tweak_NvidiaTelemetry = {
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
}

# ============================================================
# [46] News + Interests + Copilot
# ============================================================
$Tweak_CopilotRecall = {
    reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f | Out-Null
    Stop-Process -Name "Widgets" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "WidgetService" -Force -ErrorAction SilentlyContinue
}

# ============================================================
# [47] Storage Sense + Edge
# ============================================================
$Tweak_StorageEdge = {
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
}

# ============================================================
# [48] Boot and Login Speed
# ============================================================
$Tweak_BootLoginSpeed = {
    bcdedit /set bootmenupolicy standard | Out-Null
    bcdedit /set bootlog no | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLogonBackgroundImage /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStatusMessages /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [49] Autologger Disable
# ============================================================
$Tweak_AutologgerDisable = {
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
}

# ============================================================
# [50] Pagefile Optimize
# ============================================================
$Tweak_PagefileOptimize = {
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
}

# ============================================================
# [51] SmartScreen + AutoPlay
# ============================================================
$Tweak_SmartScreen = {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d Off /f | Out-Null
    reg add "HKCU\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV9 /t REG_DWORD /d 0 /f | Out-Null
    Set-MpPreference -PUAProtection 0 -ErrorAction SilentlyContinue
    reg add "HKLM\SOFTWARE\Microsoft\Windows Script Host\Settings" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /v DisableAutoplay /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f | Out-Null
}

# ============================================================
# [52] Scheduled Tasks v2
# ============================================================
$Tweak_ScheduledTasks2 = {
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
}

# ============================================================
# [53] LSO + RSS Queues
# ============================================================
$Tweak_LSOandRSS = {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        Disable-NetAdapterLso -Name $n -IPv4 -IPv6 -ErrorAction SilentlyContinue
        $maxRss = (Get-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -ErrorAction SilentlyContinue).RegistryValue
        if ($maxRss) { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -RegistryValue $maxRss -ErrorAction SilentlyContinue }
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*ReceiveBuffers' -RegistryValue 2048 -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*TransmitBuffers' -RegistryValue 2048 -ErrorAction SilentlyContinue } catch {}
    }
}

# ============================================================
# [54] TCP Window / BDP Tuning
# ============================================================
$Tweak_TCPWindowTuning = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 262144 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxFreeTcbs /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /t REG_DWORD /d 65534 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxHashTableSize /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /t REG_DWORD /d 65536 /f | Out-Null
}

# ============================================================
# [55] WiFi Optimize
# ============================================================
$Tweak_WiFiOptimize = {
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
}

# ============================================================
# [56] TCP Congestion
# ============================================================
$Tweak_TCPCongestion = {
    netsh int tcp set supplemental template=Internet congestionprovider=cubic | Out-Null
    netsh int tcp set supplemental template=Internet initialrto=1000 | Out-Null
    netsh int tcp set supplemental template=Internet icw=10 | Out-Null
    netsh int tcp set supplemental template=Datacenter congestionprovider=cubic | Out-Null
    netsh int tcp set supplemental template=Datacenter initialrto=750 | Out-Null
    netsh int tcp set supplemental template=Datacenter icw=10 | Out-Null
}

# ============================================================
# [57] UDP Buffer
# ============================================================
$Tweak_UDPBuffer = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DatagramSendBufferLength /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DatagramReceiveBufferLength /t REG_DWORD /d 65536 /f | Out-Null
    netsh int udp set global uro=disabled | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxForwardBufferMemory /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxNumForwardPackets /t REG_DWORD /d 65536 /f | Out-Null
}

# ============================================================
# [58] NIC Flow + RSS Core
# ============================================================
$Tweak_NICFlowControl = {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Packet Coalescing' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*RssBaseProcNumber' -RegistryValue 2 -ErrorAction SilentlyContinue } catch {}
        $cores = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*MaxRssProcessors' -RegistryValue $cores -ErrorAction SilentlyContinue } catch {}
        try { Disable-NetAdapterBinding -Name $n -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue } catch {}
    }
}

# ============================================================
# [59] QoS + DSCP
# ============================================================
$Tweak_QoS = {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTOSValue /t REG_DWORD /d 184 /f | Out-Null
}

# ============================================================
# [60] NIC Power Deep
# ============================================================
$Tweak_NICPowerDeep = {
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
}

# ============================================================
# [61] DNS Cache + Flush
# ============================================================
$Tweak_DNSCache = {
    ipconfig /flushdns | Out-Null; nbtstat -R | Out-Null; nbtstat -RR | Out-Null; arp -d * 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v MaxCacheEntryTtlLimit /t REG_DWORD /d 86400 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v MaxSOACacheEntryTtlLimit /t REG_DWORD /d 120 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v NegativeCacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v NetFailureCacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v NegativeSOACacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object { Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2 -ErrorAction SilentlyContinue }
}

# ============================================================
# [62] TCP KeepAlive + SYN Protection
# ============================================================
$Tweak_TCPKeepAlive = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v KeepAliveTime /t REG_DWORD /d 300000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v KeepAliveInterval /t REG_DWORD /d 1000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNumConnections /t REG_DWORD /d 16777214 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SynAttackProtect /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxConnectResponseRetransmissions /t REG_DWORD /d 2 /f | Out-Null
}

# ============================================================
# [63] MMCSS Deep Tuning
# ============================================================
$Tweak_MMCSSDeep = {
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
}

# ============================================================
# [64] NVIDIA Profile
# ============================================================
$Tweak_NvidiaProfile = {
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
}

# ============================================================
# [65] USB Power Deep
# ============================================================
$Tweak_USBPowerDeep = {
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
}

# ============================================================
# [66] NTFS Deep
# ============================================================
$Tweak_NTFSDeep = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsMemoryUsage /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 2147483649 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v PathCache /t REG_DWORD /d 128 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v Win31FileSystem /t REG_DWORD /d 0 /f | Out-Null
    sc.exe stop EFS 2>$null | Out-Null; sc.exe config EFS start= disabled 2>$null | Out-Null
}

# ============================================================
# [67] CPU Scheduling Deep
# FIX: wrapped Get-PhysicalDisk in try-catch
# ============================================================
$Tweak_CPUScheduling = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v IRQ8Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SecondLevelDataCache /t REG_DWORD /d 0 /f | Out-Null
    try { $hasHDD = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' } } catch { $hasHDD = $null }
    if ($hasHDD) {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 3 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    } else {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    }
}

# ============================================================
# [68] VBS/HVCI Core Isolation
# ============================================================
$Tweak_VBSHVCI = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\LSA" /v LsaCfgFlags /t REG_DWORD /d 0 /f | Out-Null
    bcdedit /set vsmlaunchtype Off 2>$null | Out-Null
}

# ============================================================
# [69] NVMe Deep
# ============================================================
$Tweak_NVMeDeep = {
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
}

# ============================================================
# [70] LargeSystemCache + IoPageLockLimit
# ============================================================
$Tweak_LargeSystemCache = {
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    if ($ram -ge 16) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 1 /f | Out-Null }
    else { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f | Out-Null }
    $ramMB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $ioLock = [math]::Round($ramMB * 0.75 * 4096)
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v IoPageLockLimit /t REG_DWORD /d $ioLock /f | Out-Null
}

# ============================================================
# [71] Misc Services
# ============================================================
$Tweak_MiscServices = {
    sc.exe stop Spooler 2>$null | Out-Null; sc.exe config Spooler start= disabled 2>$null | Out-Null
    sc.exe stop SessionEnv 2>$null | Out-Null; sc.exe config SessionEnv start= disabled 2>$null | Out-Null
    sc.exe stop TermService 2>$null | Out-Null; sc.exe config TermService start= disabled 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f | Out-Null
    sc.exe stop lfsvc 2>$null | Out-Null; sc.exe config lfsvc start= disabled 2>$null | Out-Null
    sc.exe stop WalletService 2>$null | Out-Null; sc.exe config WalletService start= disabled 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CDP" /v RomeSdkConsumerUserSettings /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [72] UWP Background Disable
# ============================================================
$Tweak_UWPBackgroundDisable = {
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
}

# ============================================================
# [73] ETW Session Disable
# ============================================================
$Tweak_ETWDisable = {
    $etwSessions = @('DiagLog','Diagtrack-Listener','WiFiSession','UserNotPresentTraceSession','NtfsLog')
    foreach ($session in $etwSessions) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$session" /v Start /t REG_DWORD /d 0 /f 2>$null | Out-Null }
}

# ============================================================
# [74] CSRSS Priority
# ============================================================
$Tweak_CSRSSPriority = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v CpuPriorityClass /t REG_DWORD /d 4 /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v IoPriority /t REG_DWORD /d 3 /f 2>$null | Out-Null
}

# ============================================================
# [75] DWM Optimization
# ============================================================
$Tweak_DWMOptimize = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v CpuPriorityClass /t REG_DWORD /d 4 /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v IoPriority /t REG_DWORD /d 3 /f 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v AlwaysHibernateThumbnails /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [76] Force Fullscreen Exclusive (Disable FSO)
# ============================================================
$Tweak_FullscreenExclusive = {
    reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_DXGIHonorFSEWindowsCompatible /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_EFSEFeatureEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v FullscreenOptimizations /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v DirectXUserGlobalSettings /t REG_SZ /d "SwapEffect=0;VRROptimizeEnable=0;" /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f | Out-Null
}

# ============================================================
# [77] Ultimate Performance Plan
# ============================================================
$Tweak_UltimatePerformance = {
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
    $plans = powercfg -list
    $match = ($plans | Select-String 'e9a42b02-d5df-448d-aa00-03f14749eb61').ToString()
    if ($match -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        $guid = $Matches[1]
        powercfg /setactive $guid | Out-Null
    } else {
        powercfg /setactive SCHEME_CURRENT | Out-Null
    }
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTPOL 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTHRESHOLD 1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTHRESHOLD 10 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTIME 1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTIME 1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR DISTRIBUTEUTILITIES 1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLESCALING 1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLECHECK 200 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
}

# ============================================================
# [78] Force Max Refresh Rate
# ============================================================
$Tweak_MaxRefreshRate = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Video' -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
            $devPath = ($_.PSPath + '\0000')
            if (Test-Path $devPath) {
                Set-ItemProperty -Path $devPath -Name 'DefaultSettings.XVRefreshRate' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $devPath -Name 'DefaultSettings.VRefreshRate' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $devPath -Name 'DefaultSettings.YResolution' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $devPath -Name 'DefaultSettings.XResolution' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $devPath -Name 'RefreshRate' -Value -1 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        }
    }
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f | Out-Null
    reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v VrrEnabled /t REG_DWORD /d 0 /f 2>$null | Out-Null
}

# ============================================================
# [79] Windows Search Full Kill
# FIX: WSearch removed from [17] autoList - now fully disabled here
# ============================================================
$Tweak_WSearchKill = {
    sc.exe stop WSearch 2>$null | Out-Null
    sc.exe config WSearch start= disabled 2>$null | Out-Null
    Stop-Process -Name "SearchIndexer" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "SearchProtocolHost" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "SearchFilterHost" -Force -ErrorAction SilentlyContinue
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\WSearch" /v Start /t REG_DWORD /d 4 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowSearchToUseLocation /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortanaAboveLock /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v PreventRemoteQueries /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f | Out-Null
    Disable-ScheduledTask -TaskName '\Microsoft\Windows\Shell\IndexerAutomaticMaintenance' -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName '\Microsoft\Windows\Windows Search\UsbCeip' -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName '\Microsoft\Windows\Windows Search\ScheduledBackoff' -ErrorAction SilentlyContinue | Out-Null
    Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Projects\SystemIndex\Indexer\CiFiles\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# ============================================================
# [80] Action Center + Notification Kill
# ============================================================
$Tweak_ActionCenterKill = {
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.LowDisk" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkyDrive.Desktop" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.Windows.Cortana" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkypeApp_kzf8qxf38zg5c" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.Windows.Photos" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.MicrosoftEdge" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.BingNews" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.BingWeather" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.XboxGameCallableUI" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.WindowsFeedbackHub" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.GetHelp" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.Getstarted" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f | Out-Null
    sc.exe stop SecurityHealthService 2>$null | Out-Null
    sc.exe config SecurityHealthService start= disabled 2>$null | Out-Null
    sc.exe stop WpnService 2>$null | Out-Null
    sc.exe config WpnService start= disabled 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start /t REG_DWORD /d 4 /f | Out-Null
}

# ============================================================
# [81] Bluetooth + Touch + Handwriting
# ============================================================
$Tweak_BluetoothTouchDisable = {
    $btServices = @('bthserv','BthAvctpSvc','BluetoothUserService')
    foreach ($s in $btServices) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' } | ForEach-Object {
        Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    }
    $touchServices = @('TabletInputService','TextInputManagementService','TouchInputService','frameServer')
    foreach ($s in $touchServices) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTabletKeyboardButton /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PenWorkspace" /v PenWorkspaceAppSuggestionsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f | Out-Null
    sc.exe stop GameInputSvc 2>$null | Out-Null; sc.exe config GameInputSvc start= disabled 2>$null | Out-Null
}

# ============================================================
# [82] BCD Quiet Boot + Timeout Zero
# ============================================================
$Tweak_BCDQuietBoot = {
    bcdedit /set timeout 0 | Out-Null
    bcdedit /set quietboot yes | Out-Null
    bcdedit /set bootmenupolicy standard | Out-Null
    bcdedit /set bootlog no | Out-Null
    bcdedit /set recoveryenabled no | Out-Null
    bcdedit /deletevalue {current} custom:2600002d 2>$null | Out-Null
    bcdedit /set debug off | Out-Null
    bcdedit /set bootdebug off | Out-Null
    bcdedit /set {globalsettings} custom:16000067 false 2>$null | Out-Null
    bcdedit /set {globalsettings} custom:16000069 false 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v AutoReboot /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v CrashDumpEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v LogEvent /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v SendAlert /t REG_DWORD /d 0 /f | Out-Null
    bcdedit /set bootstatuspolicy IgnoreAllFailures | Out-Null
}

# ============================================================
# [83] Focus Assist Auto
# ============================================================
$Tweak_FocusAssist = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default`$windows.data.notifications.quiethourssettings\windows.data.notifications.quiethourssettings" /v Data /t REG_BINARY /d 020000004e07e7070b000a001200280030003800010000001e0000000101 /f 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_ALLOW_TOASTS_WHILE_IN_DND /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_WHILE_IN_DND /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_GAMING_FOCUS_ACTIVE /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Default\.Current" /ve /t REG_SZ /d "" /f 2>$null | Out-Null
    reg add "HKCU\AppEvents\Schemes\Apps\.Default\SystemNotification\.Current" /ve /t REG_SZ /d "" /f 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableBalloonTips /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# MASTER TABLE - 83 TWEAKS
# ============================================================
$AllTweaks = [ordered]@{
    "[01] Kernel + Timer (TSC)"        = $Tweak_KernelTimer
    "[02] Timer Resolution"            = $Tweak_TimerResolution
    "[03] Process Priority"            = $Tweak_ProcessPriority
    "[04] IRQ MSI Mode"                = $Tweak_IrqMsiMode
    "[05] Memory Management"           = $Tweak_MemoryManagement
    "[06] Storage Optimizations"       = $Tweak_Storage
    "[07] Input and USB"               = $Tweak_InputUSB
    "[08] Nagle Algorithm"             = $Tweak_Nagle
    "[09] Visual Effects"              = $Tweak_VisualEffects
    "[10] GameBar DVR + GameMode OFF"  = $Tweak_GameBarDVR
    "[11] Processor Power"             = $Tweak_ProcessorPower
    "[12] CPU Core Parking"            = $Tweak_CoreParking
    "[13] GPU Display (HAGS OFF)"      = $Tweak_GpuDisplay
    "[14] Audio Latency"               = $Tweak_AudioLatency
    "[15] Network and DNS"             = $Tweak_NetworkDNS
    "[16] Privacy and Telemetry"       = $Tweak_PrivacyTelemetry
    "[17] Windows Services"            = $Tweak_Services
    "[18] Junk and Log Cleanup"        = $Tweak_JunkCleanup
    "[19] Interrupt Affinity"          = $Tweak_InterruptAffinity
    "[20] NIC Advanced"                = $Tweak_NICAdvanced
    "[21] Hyper-V and VBS"            = $Tweak_HyperV
    "[22] Timer Resolution Runtime"    = $Tweak_TimerResRuntime
    "[23] Spectre and Meltdown"        = $Tweak_SpectreMeltdown
    "[24] Memory Compression"          = $Tweak_MemCompression
    "[25] NVIDIA Low Latency"          = $Tweak_NvidiaLowLatency
    "[26] NVIDIA Shader + ReBAR"       = $Tweak_NvidiaShader
    "[27] Exploit Protection"          = $Tweak_ExploitProtection
    "[28] Windows Defender"            = $Tweak_DefenderRealtime
    "[29] Background Apps"             = $Tweak_BackgroundApps
    "[30] Delivery Optimization"       = $Tweak_DeliveryOptimization
    "[31] Device Power"                = $Tweak_DevicePower
    "[32] GPU Cache Cleanup"           = $Tweak_GpuCacheCleanup
    "[33] MPO Disable"                 = $Tweak_MPODisable
    "[34] PCI-E ASPM"                  = $Tweak_PciEAspm
    "[35] Connected Standby"           = $Tweak_ConnectedStandby
    "[36] Telemetry Tasks"             = $Tweak_TelemetryTasks
    "[37] Windows Ads and Tips"        = $Tweak_WindowsAdsTips
    "[38] Additional Services"         = $Tweak_AdditionalServices
    "[39] Overlay Killer (GameBar)"    = $Tweak_OverlayKiller
    "[40] Network Noise"               = $Tweak_NetworkNoise
    "[41] Diagnostic Services"         = $Tweak_DiagnosticServices
    "[42] System Restore Off"          = $Tweak_SystemRestoreOff
    "[43] Additional Services v2"      = $Tweak_AdditionalServices2
    "[44] Spotlight and Clipboard"     = $Tweak_SpotlightClipboard
    "[45] NVIDIA Telemetry"            = $Tweak_NvidiaTelemetry
    "[46] News + Interests + Copilot"  = $Tweak_CopilotRecall
    "[47] Storage Sense + Edge"        = $Tweak_StorageEdge
    "[48] Boot and Login Speed"        = $Tweak_BootLoginSpeed
    "[49] Autologger Disable"          = $Tweak_AutologgerDisable
    "[50] Pagefile Optimize"           = $Tweak_PagefileOptimize
    "[51] SmartScreen + AutoPlay"      = $Tweak_SmartScreen
    "[52] Scheduled Tasks v2"          = $Tweak_ScheduledTasks2
    "[53] LSO + RSS Queues"            = $Tweak_LSOandRSS
    "[54] TCP Window / BDP Tuning"     = $Tweak_TCPWindowTuning
    "[55] WiFi Optimize"               = $Tweak_WiFiOptimize
    "[56] TCP Congestion"              = $Tweak_TCPCongestion
    "[57] UDP Buffer"                  = $Tweak_UDPBuffer
    "[58] NIC Flow + RSS Core"         = $Tweak_NICFlowControl
    "[59] QoS + DSCP"                  = $Tweak_QoS
    "[60] NIC Power Deep"              = $Tweak_NICPowerDeep
    "[61] DNS Cache + Flush"           = $Tweak_DNSCache
    "[62] TCP KeepAlive + SYN"         = $Tweak_TCPKeepAlive
    "[63] MMCSS Deep Tuning"           = $Tweak_MMCSSDeep
    "[64] NVIDIA Profile"              = $Tweak_NvidiaProfile
    "[65] USB Power Deep"              = $Tweak_USBPowerDeep
    "[66] NTFS Deep"                   = $Tweak_NTFSDeep
    "[67] CPU Scheduling Deep"         = $Tweak_CPUScheduling
    "[68] VBS/HVCI Core Isolation"     = $Tweak_VBSHVCI
    "[69] NVMe Deep"                   = $Tweak_NVMeDeep
    "[70] LargeSystemCache + IoPage"   = $Tweak_LargeSystemCache
    "[71] Misc Services"               = $Tweak_MiscServices
    "[72] UWP Background Disable"      = $Tweak_UWPBackgroundDisable
    "[73] ETW Session Disable"         = $Tweak_ETWDisable
    "[74] CSRSS Priority"              = $Tweak_CSRSSPriority
    "[75] DWM Optimization"            = $Tweak_DWMOptimize
    "[76] Force Fullscreen Exclusive"  = $Tweak_FullscreenExclusive
    "[77] Ultimate Performance Plan"   = $Tweak_UltimatePerformance
    "[78] Force Max Refresh Rate"      = $Tweak_MaxRefreshRate
    "[79] Windows Search Full Kill"    = $Tweak_WSearchKill
    "[80] Action Center + Notif Kill"  = $Tweak_ActionCenterKill
    "[81] Bluetooth + Touch + HW"      = $Tweak_BluetoothTouchDisable
    "[82] BCD Quiet Boot + Timeout"    = $Tweak_BCDQuietBoot
    "[83] Focus Assist Auto"           = $Tweak_FocusAssist
}

# ============================================================
# GUI
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "PRIME Optimizer - 83 Tweaks"
$form.Size = New-Object System.Drawing.Size(520, 380)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$form.ForeColor = [System.Drawing.Color]::FromArgb(224, 220, 210)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "PRIME OPTIMIZER"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(232, 197, 71)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(160, 20)
$form.Controls.Add($titleLabel)

$subLabel = New-Object System.Windows.Forms.Label
$subLabel.Text = "83 Windows Performance Tweaks"
$subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subLabel.ForeColor = [System.Drawing.Color]::FromArgb(122, 117, 112)
$subLabel.AutoSize = $true
$subLabel.Location = New-Object System.Drawing.Point(170, 52)
$form.Controls.Add($subLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(30, 90)
$progressBar.Size = New-Object System.Drawing.Size(445, 22)
$progressBar.Style = "Continuous"
$progressBar.Minimum = 0
$progressBar.Maximum = 83
$progressBar.Value = 0
$progressBar.ForeColor = [System.Drawing.Color]::FromArgb(232, 197, 71)
$form.Controls.Add($progressBar)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready to optimize..."
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(160, 156, 148)
$lblStatus.Size = New-Object System.Drawing.Size(445, 20)
$lblStatus.Location = New-Object System.Drawing.Point(30, 120)
$form.Controls.Add($lblStatus)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(160, 156, 148)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$logBox.Location = New-Object System.Drawing.Point(30, 145)
$logBox.Size = New-Object System.Drawing.Size(445, 140)
$form.Controls.Add($logBox)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "START OPTIMIZATION"
$btnRun.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnRun.BackColor = [System.Drawing.Color]::FromArgb(232, 197, 71)
$btnRun.ForeColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$btnRun.FlatStyle = "Flat"
$btnRun.Size = New-Object System.Drawing.Size(445, 38)
$btnRun.Location = New-Object System.Drawing.Point(30, 300)
$btnRun.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnRun)

# ============================================================
# MAIN EXECUTION - Original style (direct invocation)
# ============================================================
$btnRun.Add_Click({
    $btnRun.Enabled = $false
    $btnRun.Text = "RUNNING..."
    $logBox.Clear()

    $i = 0
    $total = $AllTweaks.Count

    foreach ($key in $AllTweaks.Keys) {
        $i++
        $lblStatus.Text = "[$i/$total] $key"
        $progressBar.Value = $i
        $logBox.AppendText("[$i/$total] $key ...")
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()

        try {
            & $AllTweaks[$key]
            $logBox.AppendText(" OK`r`n")
        } catch {
            $logBox.AppendText(" FAIL`r`n")
        }
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $lblStatus.Text = "COMPLETE"
    $btnRun.Text = "REBOOT NOW"
    $btnRun.Enabled = $true

    $logBox.AppendText("`r`n=== ALL 83 TWEAKS FINISHED ===`r`nReboot recommended.`r`n")
    $logBox.ScrollToCaret()

    [System.Windows.Forms.MessageBox]::Show(
        "All 83 tweaks completed.`r`nReboot recommended.",
        "PRIME Optimizer",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $btnRun.Add_Click({
        $form.Close()
    })
})

# ============================================================
# SHOW FORM
# ============================================================
[System.Windows.Forms.Application]::Run($form)
