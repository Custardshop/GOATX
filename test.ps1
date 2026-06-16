<#
============================================================
  Windows Performance Tweaks - GUI (WinForms, terminal look)
  แก้ไข: Title+Subtitle gradient paint, Options เป็น Label สี match gradient
============================================================
#>

# --- 1. ตรวจสอบสิทธิ์ Administrator ---
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
# --- 2. กลุ่ม tweak ทั้งหมด ---
# ============================================================

$Tweak_KernelHPET = {
    bcdedit /set useplatformclock no | Out-Null
    bcdedit /set useplatformtick yes | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
    bcdedit /set tscsyncpolicy Enhanced | Out-Null
    bcdedit /set nx OptOut | Out-Null
    bcdedit /set synthetictimers yes | Out-Null
    bcdedit /set nospeculationcontrol 1 | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f | Out-Null
}

$Tweak_TimerResolution = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
}

$Tweak_ProcessPriority = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 42 /f | Out-Null
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

$Tweak_IrqMsiMode = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -ErrorAction SilentlyContinue | ForEach-Object {
        $p = ($_.PSPath + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties')
        if (Test-Path $p) { Set-ItemProperty -Path $p -Name MSISupported -Value 1 -Type DWord -Force }
    }
}

$Tweak_MemoryManagement = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SystemCacheDirtyPageThreshold /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 3 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    powercfg -h off | Out-Null
    taskkill /f /im OneDrive.exe 2>$null | Out-Null
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null | Out-Null
}

$Tweak_Storage = {
    fsutil behavior set disable8dot3 1 | Out-Null
    fsutil behavior set disablelastaccess 1 | Out-Null
    fsutil behavior set disabledeletenotify 0 | Out-Null
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue
    }
}

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

$Tweak_Nagle = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name TcpDelAckTicks -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

$Tweak_VisualEffects = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f | Out-Null
}

$Tweak_GameBarDVR = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\System\GameConfigStore" /v GameDVR_DXGIHonorFSEWindowsCompatible /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableXamlStartMenu /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v GamePanelStartupTipIndex /t REG_DWORD /d 3 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\DirectX\GraphicsSettings" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
}

$Tweak_ProcessorPower = {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    powercfg /hibernate off | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f | Out-Null
}

$Tweak_CoreParking = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v ValueMin /t REG_DWORD /d 0 /f | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMAXCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS1INITIALPERF 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS0FLOORPERF 100 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
}

$Tweak_GpuDisplay = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f | Out-Null
}

$Tweak_AudioLatency = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
}

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
    netsh int tcp set supplemental template=custom congestionprovider=cubic | Out-Null
    netsh int tcp set supplemental template=custom icw=10 | Out-Null
    netsh int tcp set supplemental template=custom initialrto=750 | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTTL /t REG_DWORD /d 64 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisabledComponents /t REG_DWORD /d 255 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnablePMTUDiscovery /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableRSS /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableTCPChimney /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 1 /f | Out-Null
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
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null
}

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

$Tweak_Services = {
    $disableList = @('DiagTrack','WSearch','MapsBroker','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','Fax','RetailDemo','RemoteRegistry','WerSvc')
    foreach ($s in $disableList) {
        sc.exe stop $s 2>$null | Out-Null
        sc.exe config $s start= disabled 2>$null | Out-Null
    }
    $autoList = @('Audiosrv','AudioEndpointBuilder','Dhcp','NlaSvc','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','LanmanWorkstation','LanmanServer')
    foreach ($s in $autoList) {
        sc.exe config $s start= auto 2>$null | Out-Null
        sc.exe start $s 2>$null | Out-Null
    }
}

$Tweak_JunkCleanup = {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
        try { wevtutil.exe cl $_.LogName } catch {}
    }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

$Tweak_IniCompat = {
    $systemIni = Join-Path $env:windir 'system.ini'
    $winIni = Join-Path $env:windir 'win.ini'
    $ini = @"
; for 16-bit app support
[386Enh]
MinTimeSlice=1
AvgTimeSlice=1
MaxTimeSlice=1
WinTimeSlice=1,1
NetAsyncTimeout=0
SyncTimeDivisor=1
TimeWindowMinutes=0
Latency=1
SampleRate=1
UseHWTimeStamp=1
Auto-Detect-CPU=TRUE
CpuSnooze=0
MaxBiosPipes=128
MinBiosPipes=128
DoubleBuffer=0
Chunksize=5000000
LoadTop=0
SystemReg=0
FastBlt=1

[drivers]
wave=mmdrv.dll
timer=timer.drv

[mci]
mciwave=mmsystem.dll

[timer]
TimeSliceUpdateTickCount=1

[NonWindowsApp]
MouseExclusive=1
"@
    Copy-Item $systemIni "$systemIni.backup" -Force -ErrorAction SilentlyContinue
    Copy-Item $winIni "$winIni.backup" -Force -ErrorAction SilentlyContinue
    Add-Content $systemIni "`r`n$ini"
    Add-Content $winIni "`r`n$ini"
}

# ============================================================
# --- 3. รายการปุ่ม ---
# ============================================================

$AllTweaks = [ordered]@{
    "[01] Kernel and HPET"             = $Tweak_KernelHPET
    "[02] Timer Resolution"            = $Tweak_TimerResolution
    "[03] Process Priority"            = $Tweak_ProcessPriority
    "[04] IRQ MSI Mode"                = $Tweak_IrqMsiMode
    "[05] Memory Management"          = $Tweak_MemoryManagement
    "[06] Storage Optimizations"       = $Tweak_Storage
    "[07] Input and USB"               = $Tweak_InputUSB
    "[08] Nagle Algorithm"             = $Tweak_Nagle
    "[09] Visual Effects"              = $Tweak_VisualEffects
    "[10] Game Bar and DVR"            = $Tweak_GameBarDVR
    "[11] Processor Power"             = $Tweak_ProcessorPower
    "[12] CPU Core Parking"            = $Tweak_CoreParking
    "[13] GPU and Display"             = $Tweak_GpuDisplay
    "[14] Audio Latency"               = $Tweak_AudioLatency
    "[15] Network and DNS"             = $Tweak_NetworkDNS
    "[16] Privacy and Telemetry"       = $Tweak_PrivacyTelemetry
    "[17] Windows Services"            = $Tweak_Services
    "[18] Junk and Log Cleanup"        = $Tweak_JunkCleanup
    "[20] System.ini / Win.ini Compat" = $Tweak_IniCompat
}

# ============================================================
# --- 4. GUI ---
# ============================================================

# State
$script:selectedIndex = 0
$script:isRunning     = $false
$script:optionCount   = 2
$script:labelControls = @()
$script:options = @(
    @{ Label = "[1] High"; Action = "high" }
    @{ Label = "[2] Exit"; Action = "exit" }
)

# --- สี Gradient ทั้งหมด ---
# สีสว่าง (selected / title)
$script:GradBright = @(
    [System.Drawing.Color]::FromArgb(80, 200, 255),
    [System.Drawing.Color]::FromArgb(180, 120, 255),
    [System.Drawing.Color]::FromArgb(255, 120, 180)
)
# สีกลาง (subtitle)
$script:GradMid = @(
    [System.Drawing.Color]::FromArgb(100, 180, 220),
    [System.Drawing.Color]::FromArgb(160, 130, 220),
    [System.Drawing.Color]::FromArgb(220, 140, 190)
)
# สีมืด (unselected option) — ต้องสว่างพอให้เห็นชัดที่ opacity 0.75
$script:GradDim = @(
    [System.Drawing.Color]::FromArgb(60, 110, 140),
    [System.Drawing.Color]::FromArgb(110, 70, 140),
    [System.Drawing.Color]::FromArgb(140, 70, 100)
)
$script:GradPos = @(0.0, 0.5, 1.0)

# สี hint
$clrBg   = [System.Drawing.Color]::Black
$clrHint = [System.Drawing.Color]::FromArgb(120, 120, 120)

# --- สร้างหน้าต่าง ---
$form = New-Object System.Windows.Forms.Form
$form.Text            = "GOATX"
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox     = $false
$form.BackColor       = $clrBg
$form.TopMost         = $true
$form.KeyPreview      = $true
$form.Opacity         = 1
$form.ClientSize      = New-Object System.Drawing.Size(450, 235)

# Panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock      = "Fill"
$panel.BackColor = $clrBg
$panel.TabStop   = $true
$form.Controls.Add($panel)

# ============================================================
# Helper: สร้าง gradient text panel (สำหรับ title + subtitle)
# ============================================================
function New-GradientLabel {
    param(
        [string]$text,
        [float]$fontSize,
        [System.Drawing.FontStyle]$style,
        [System.Drawing.Color[]]$colors,
        [float[]]$positions,
        [int]$x, [int]$y, [int]$w, [int]$h
    )
    $pnl = New-Object System.Windows.Forms.Panel
    $pnl.Size      = New-Object System.Drawing.Size($w, $h)
    $pnl.Location  = New-Object System.Drawing.Point($x, $y)
    $pnl.BackColor = [System.Drawing.Color]::Transparent

    # เก็บ parameter ไว้ใน hashtable แล้ว attach ไปกับ panel
    $drawParams = @{
        Text      = $text
        FontSize  = $fontSize
        Style     = $style
        Colors    = $colors
        Positions = $positions
    }
    $pnl.Tag = $drawParams

    $pnl.Add_Paint({
        param($s, $e)
        $dp     = $s.Tag
        $font   = New-Object System.Drawing.Font("Consolas", $dp.FontSize, $dp.Style)
        $colors = $dp.Colors
        $pos    = $dp.Positions

        $e.Graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point(0, 0)),
            (New-Object System.Drawing.Point($s.Width, 0)),
            $colors[0], $colors[$colors.Length - 1]
        )
        if ($colors.Length -gt 2) {
            $blend = New-Object System.Drawing.Drawing2D.ColorBlend
            $blend.Colors    = $colors
            $blend.Positions = $pos
            $brush.InterpolationColors = $blend
        }

        $sf  = New-Object System.Drawing.StringFormat
        $sf.Alignment     = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

        $rect = New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)
        $e.Graphics.DrawString($dp.Text, $font, $brush, $rect, $sf)

        $brush.Dispose(); $font.Dispose(); $sf.Dispose()
    })

    $panel.Controls.Add($pnl)
    return $pnl
}

# ============================================================
# Title (gradient paint panel)
# ============================================================
New-GradientLabel -text "G O A T X" -fontSize 22 `
    -style ([System.Drawing.FontStyle]::Bold) `
    -colors $script:GradBright -positions $script:GradPos `
    -x 10 -y 20 -w 430 -h 42 | Out-Null

# ============================================================
# Subtitle (gradient paint panel)
# ============================================================
New-GradientLabel -text "[+] CMD GOATX BY CUSTARD [+]" -fontSize 10 `
    -style ([System.Drawing.FontStyle]::Regular) `
    -colors $script:GradMid -positions $script:GradPos `
    -x 10 -y 66 -w 430 -h 22 | Out-Null

# ============================================================
# Options — ใช้ Label ปกติ (เสถียร) แล้ว set ForeColor
# เป็นสี solid จาก palette เดียวกับ gradient
# ============================================================

# สี solid ที่ match gradient
$clrOptHi  = [System.Drawing.Color]::FromArgb(130, 160, 255)   # ม่วง-ฟ้าสว่าง (selected)
$clrOptDim = [System.Drawing.Color]::FromArgb(90, 75, 110)     # ม่วงมืด (unselected)

$fontOpt = New-Object System.Drawing.Font("Consolas", 12)

$optStartY  = 104
$optSpacing = 32

for ($i = 0; $i -lt $script:optionCount; $i++) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = if ($i -eq 0) { "> " + $script:options[$i].Label } else { "  " + $script:options[$i].Label }
    $lbl.Font      = $fontOpt
    $lbl.ForeColor = if ($i -eq 0) { $clrOptHi } else { $clrOptDim }
    $lbl.AutoSize  = $false
    $lbl.Size      = New-Object System.Drawing.Size(430, 28)
    $lbl.Location  = New-Object System.Drawing.Point(10, ($optStartY + $i * $optSpacing))
    $lbl.TextAlign = "MiddleLeft"
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $lbl.Tag       = $i
    $lbl.Add_Click({
        param($s, $e)
        if (-not $script:isRunning) {
            $script:selectedIndex = [int]$s.Tag
            Update-Highlight
            Execute-Selection
        }
    })
    $panel.Controls.Add($lbl)
    $script:labelControls += $lbl
}

# Hint
$fontHint = New-Object System.Drawing.Font("Consolas", 8)
$hintLbl = New-Object System.Windows.Forms.Label
$hintLbl.Text      = "Arrow keys to navigate, Enter to select"
$hintLbl.Font      = $fontHint
$hintLbl.ForeColor = $clrHint
$hintLbl.AutoSize  = $false
$hintLbl.Size      = New-Object System.Drawing.Size(430, 16)
$hintLbl.Location  = New-Object System.Drawing.Point(10, 180)
$hintLbl.TextAlign = "MiddleCenter"
$hintLbl.BackColor = [System.Drawing.Color]::Transparent
$panel.Controls.Add($hintLbl)

# --- AcceptButton (hidden) ---
$hiddenAcceptBtn = New-Object System.Windows.Forms.Button
$hiddenAcceptBtn.Size     = New-Object System.Drawing.Size(1, 1)
$hiddenAcceptBtn.Location = New-Object System.Drawing.Point(-100, -100)
$hiddenAcceptBtn.TabStop  = $false
$panel.Controls.Add($hiddenAcceptBtn)
$form.AcceptButton = $hiddenAcceptBtn
$hiddenAcceptBtn.Add_Click({
    if (-not $script:isRunning) { Execute-Selection }
})

# ============================================================
# --- 5. Highlight ---
# ============================================================

function Update-Highlight {
    for ($i = 0; $i -lt $script:optionCount; $i++) {
        if ($i -eq $script:selectedIndex) {
            $script:labelControls[$i].Text      = "> " + $script:options[$i].Label
            $script:labelControls[$i].ForeColor = $clrOptHi
        } else {
            $script:labelControls[$i].Text      = "  " + $script:options[$i].Label
            $script:labelControls[$i].ForeColor = $clrOptDim
        }
    }
}

# ============================================================
# --- 6. Execute ---
# ============================================================

function Execute-Selection {
    if ($script:isRunning) { return }
    $action = $script:options[$script:selectedIndex].Action

    if ($action -eq "high") {
        $script:isRunning = $true
        $total = $AllTweaks.Count
        $i = 0
        foreach ($key in $AllTweaks.Keys) {
            $i++
            $script:labelControls[0].Text      = "> Running ($i/$total)..."
            $script:labelControls[0].ForeColor = $clrOptHi
            $script:labelControls[0].Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            try { & $AllTweaks[$key] } catch {}
        }
        $script:labelControls[0].Text = "> Done"
        $script:labelControls[0].Refresh()
        Start-Sleep -Milliseconds 900
        $script:isRunning = $false
        Update-Highlight
    }
    else {
        $form.Close()
    }
}

# ============================================================
# --- 7. Keyboard ---
# ============================================================

$script:KeyHandler = {
    param($s, $e)
    if ($e.KeyCode -eq 'Escape') { $form.Close(); return }
    if ($script:isRunning) { return }
    switch ($e.KeyCode) {
        'Up' {
            $script:selectedIndex = ($script:selectedIndex - 1 + $script:optionCount) % $script:optionCount
            Update-Highlight; $e.Handled = $true
        }
        'Down' {
            $script:selectedIndex = ($script:selectedIndex + 1) % $script:optionCount
            Update-Highlight; $e.Handled = $true
        }
        'Return' {
            $e.Handled = $true; $e.SuppressKeyPress = $true
            Execute-Selection
        }
    }
}

$form.Add_KeyDown($script:KeyHandler)
$panel.Add_KeyDown($script:KeyHandler)

# ============================================================
# --- 8. Scroll wheel ---
# ============================================================

$scrollHandler = {
    param($s, $e)
    if ($script:isRunning) { return }
    if ($e.Delta -gt 0) {
        $script:selectedIndex = ($script:selectedIndex - 1 + $script:optionCount) % $script:optionCount
    } else {
        $script:selectedIndex = ($script:selectedIndex + 1) % $script:optionCount
    }
    Update-Highlight
}

$form.Add_MouseWheel($scrollHandler)
$panel.Add_MouseWheel($scrollHandler)
foreach ($ctrl in $panel.Controls) {
    try { $ctrl.Add_MouseWheel($scrollHandler) } catch {}
}

$form.Add_Shown({ $panel.Focus() })
Update-Highlight

# ============================================================
# --- 9. Run ---
# ============================================================

[System.Windows.Forms.Application]::Run($form)
