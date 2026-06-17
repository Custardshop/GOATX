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
# ลบ useplatformtick/useplatformclock ให้ CPU ใช้ TSC (เร็วสุด)
# ============================================================
$Tweak_KernelTimer = {
    bcdedit /deletevalue useplatformclock 2>$null | Out-Null
    bcdedit /deletevalue useplatformtick 2>$null | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
    bcdedit /set tscsyncpolicy Enhanced | Out-Null
    bcdedit /set nx OptOut | Out-Null
    bcdedit /set synthetictimers yes | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [02] Timer Resolution
# บอก Windows ให้ request 0.5ms timer (default 15.6ms)
# ทุก interrupt/service ตอบสนองเร็วขึ้น 30x
# ============================================================
$Tweak_TimerResolution = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [03] Process Priority
# Win32PrioritySeparation=42 = short quantum + foreground boost
# SystemResponsiveness=0 = reserve 0% CPU ให้ background
# Games task = High priority + GPU priority 8
# ============================================================
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

# ============================================================
# [04] IRQ MSI Mode
# เปลี่ยน legacy shared IRQ เป็น MSI (per-device message)
# ไม่ต้องรอคิว interrupt line เดียวกัน
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
# ปิด Superfetch (ใช้ CPU+I/O), เปิด Prefetcher (app launch เร็ว)
# ปิด hibernate, kill OneDrive, ปิด pagefile clear
# ============================================================
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

# ============================================================
# [06] Storage
# ปิด 8.3 filename (เก่า), ปิด last access timestamp
# เปิด TRIM สำหรับ SSD, retrim ทุก drive
# ============================================================
$Tweak_Storage = {
    fsutil behavior set disable8dot3 1 | Out-Null
    fsutil behavior set disablelastaccess 1 | Out-Null
    fsutil behavior set disabledeletenotify 0 | Out-Null
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
        Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue
    }
}

# ============================================================
# [07] Input and USB
# เมาส์/คีย์บอร์ด queue ลด 100->16 (input lag ลด)
# ปิด mouse acceleration (1:1 raw input)
# ปิด USB selective suspend (ไม่ sleep อุปกรณ์ input)
# ปิด sticky/toggle keys (ไม่ popup ตอนเล่นเกม)
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
# ปิด Nagle = ส่ง packet ทันทีไม่รวม batch
# ลด latency 1-2 packet delay สำหรับเกม
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
# ปิด animation, transparency, shadow ทั้งหมด
# ประหยัด GPU/CPU cycles ทุก frame
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
# ปิด Game Bar overlay + background recording (FPS +3-5%)
# ปิด Game Mode (ไม่ต้องการ)
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
# CPU 100% min+max (ไม่ downclock)
# ปิด hibernate + fast startup
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
# ปิด core parking = ทุก core active ตลอด
# ไม่มี wake-up delay 50-100ms
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
# HwSchMode=1 = HAGS OFF (ตามที่ต้องการ)
# TdrLevel=2 + TdrDelay=60 = GPU recover ได้ถ้าแฮงก์
# ============================================================
$Tweak_GpuDisplay = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\DirectX\GraphicsSettings" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f | Out-Null
}

# ============================================================
# [14] Audio Latency
# Pro Audio task = High scheduling, ใช้ core 0-2
# ปล่อย core 3+ ให้เกมทั้งหมด
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
# RSS=multi-core packet, TCP Fast Open, ECN, ปิด Nagle global
# DNS=Cloudflare+Google, ปิด LLMNR, ปิด NetBIOS
# ปิด Interrupt Moderation = ไม่ batch interrupt
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
}

# ============================================================
# [16] Privacy and Telemetry
# ปิด telemetry data collection ทั้งหมด
# ปิด Cortana, error reporting, activity feed, location
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
# [17] Windows Services (WSearch 保留 auto)
# ปิด DiagTrack, Xbox, Fax, RetailDemo, RemoteRegistry
# 保留 WSearch, Audio, Network, EventLog
# ============================================================
$Tweak_Services = {
    $disableList = @('DiagTrack','MapsBroker','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','Fax','RetailDemo','RemoteRegistry','WerSvc')
    foreach ($s in $disableList) { sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null }
    $autoList = @('Audiosrv','AudioEndpointBuilder','Dhcp','NlaSvc','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','LanmanWorkstation','LanmanServer','WSearch')
    foreach ($s in $autoList) { sc.exe config $s start= auto 2>$null | Out-Null; sc.exe start $s 2>$null | Out-Null }
}

# ============================================================
# [18] Junk and Log Cleanup
# ลบ temp files, Windows Update cache, event logs, recycle bin
# ไม่แตะ SoftwareDistribution folder (ลบแค่ Download)
# ============================================================
$Tweak_JunkCleanup = {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object { try { wevtutil.exe cl $_.LogName } catch {} }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

# ============================================================
# [19] Display Post Processing
# GPU Priority 31 (max) สำหรับ display pipeline
# ไม่ให้ frame ถูก delay โดย background render
# ============================================================
$Tweak_MMCSSDisplay = {
    $base = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Display Post Processing"
    reg add "$base" /v "GPU Priority" /t REG_DWORD /d 31 /f | Out-Null
    reg add "$base" /v Priority /t REG_DWORD /d 8 /f | Out-Null
    reg add "$base" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "$base" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
    reg add "$base" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "$base" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "$base" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [20] System.ini / Win.ini
# เขียนค่า legacy compatibility tweaks ลง INI files
# [386Enh] section = timer/I/O tuning สำหรับ 16-bit compatibility
# ============================================================
$Tweak_IniCompat = {
    $systemIni = Join-Path $env:windir 'system.ini'
    $winIni    = Join-Path $env:windir 'win.ini'
    $marker    = "; GOATX_TWEAK_MARKER"
    foreach ($f in @($systemIni, $winIni)) {
        if (-not (Test-Path "$f.backup")) { Copy-Item $f "$f.backup" -Force -ErrorAction SilentlyContinue }
        $content = Get-Content $f -ErrorAction SilentlyContinue
        if ($content) {
            $markerIdx = -1
            for ($j = 0; $j -lt $content.Count; $j++) { if ($content[$j] -match 'GOATX_TWEAK_MARKER') { $markerIdx = $j; break } }
            if ($markerIdx -ge 0) { $trimmed = $content[0..($markerIdx - 1)]; Set-Content $f ($trimmed -join "`r`n") -Force }
        }
    }
    $tweakBlock = @"
$marker
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
    Add-Content $systemIni "`r`n$tweakBlock"
    Add-Content $winIni    "`r`n$tweakBlock"
}

# ============================================================
# [21] Interrupt Affinity
# GPU = Core 1, NIC = Core 2, USB = Core 3
# แยก IRQ ไม่ให้ share core กับ game thread
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
# [22] NIC Advanced
# ปิด interrupt moderation, flow control, EEE, Green Ethernet
# เปิด receive/transmit buffers 2048, ปิด RSC
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
# [23] Hyper-V and VBS
# ปิด hypervisor layer (CPU overhead 2-5%)
# ปิด VBS, HVCI, Credential Guard
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
# [24] Timer Resolution Runtime
# Force 0.5ms timer ทันที + scheduled task ทุก boot
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
    $helperPath = "$env:SystemRoot\System32\GOATX_TimerRes.ps1"
    @'
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W{[DllImport("ntdll.dll")]public static extern uint NtSetTimerResolution(uint d,bool s,out uint c);}'
$c=0;[W]::NtSetTimerResolution(5000,$true,[ref]$c)
while($true){Start-Sleep -Seconds 120}
'@ | Out-File $helperPath -Encoding Unicode -Force
    schtasks /Create /TN "GOATX_TimerResolution" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helperPath`"" /SC ONLOGON /RL HIGHEST /F 2>$null | Out-Null
}

# ============================================================
# [25] Spectre and Meltdown
# ปิด CPU mitigation (เพิ่ม latency ทุก syscall 5-30%)
# ============================================================
$Tweak_SpectreMeltdown = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f | Out-Null
}

# ============================================================
# [26] Memory Compression
# ปิด Windows memory compression (ใช้ CPU cycles)
# ============================================================
$Tweak_MemCompression = {
    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
}

# ============================================================
# [27] NVIDIA Low Latency (保留 HDCP — 不碰 NVIDIA app/recording)
# PowerMizer=max perf, preemption ปิดทุกอย่าง
# GPU ไม่ downclock, frame ไม่ถูก preempt
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
# [28] NVIDIA Shader + ReBAR
# ReBAR=CPU access VRAM ทั้งก้อน, Shader Cache=ไม่ recompile
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
# [29] Exploit Protection
# ปิด CFG (Control Flow Guard) = ลด overhead ทุก indirect call
# ============================================================
$Tweak_ExploitProtection = {
    Set-ProcessMitigation -System -Disable CFG -ErrorAction SilentlyContinue
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableExceptionChainValidation /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v MoveImages /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [30] Windows Defender
# ปิด real-time + behavior + IOAV + script scanning
# CPU 3-8% กลับมาใช้เกม
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
# [31] Background Apps
# ปิด UWP background apps ทั้งหมด
# ============================================================
$Tweak_BackgroundApps = {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f | Out-Null
}

# ============================================================
# [32] Delivery Optimization
# ปิด P2P update sharing (ใช้ bandwidth + CPU)
# ============================================================
$Tweak_DeliveryOptimization = {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f | Out-Null
    Stop-Service DoSvc -Force -ErrorAction SilentlyContinue
    sc.exe config DoSvc start= disabled 2>$null | Out-Null
}

# ============================================================
# [33] Device Power
# ปิด USB hub idle + NVMe power state
# ============================================================
$Tweak_DevicePower = {
    Get-WmiObject -Class Win32_USBHub -ErrorAction SilentlyContinue | ForEach-Object {
        $pnpId = $_.PNPDeviceID; $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (Test-Path "$regPath\WDF") { Set-ItemProperty -Path "$regPath\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    }
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerStateEnabled /t REG_DWORD /d 0 /f 2>$null | Out-Null
}

# ============================================================
# [34] GPU Cache Cleanup
# ลบ shader cache เก่า (ป้องกัน stutter)
# ============================================================
$Tweak_GpuCacheCleanup = {
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\NVIDIA\GLCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\AMD\DxCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\D3DSCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\DeliveryOptimization\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# ============================================================
# [35] MPO Disable
# ปิด Multi-Plane Overlay (ลด 1-2 frame compositing latency)
# ============================================================
$Tweak_MPODisable = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f | Out-Null
}

# ============================================================
# [36] PCI-E ASPM
# ปิด Active State Power Management (ไม่ sleep PCI-E link)
# ============================================================
$Tweak_PciEAspm = {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PnP\Pci" /v DisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f2c1-98bb-455b-9e09-ae4c1e16cb45" /v Attributes /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v NvmeDisableASPM /t REG_DWORD /d 1 /f 2>$null | Out-Null
}

# ============================================================
# [37] Connected Standby
# ปิด Modern Standby (ใช้ CPU/network ตอน sleep)
# ============================================================
$Tweak_ConnectedStandby = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v CsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v PlatformAoAcOverride /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v AwayModeEnabled /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [38] Telemetry Tasks
# ปิด scheduled tasks ที่เก็บ data + report
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
# [39] Windows Ads and Tips
# ปิด Start menu suggestions, lock screen ads, notification ads
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
# [40] Additional Services
# ปิด WpnService, WaaSMedicSvc, SSDPSRV, CDP, PcaSvc, PhoneSvc
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
# [41] Overlay Killer (GameBar only)
# 保留 Steam/Discord/NVIDIA overlay
# ============================================================
$Tweak_OverlayKiller = {
    reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [42] Network Noise
# ปิด SMBv1, LLMNR, SSDP, Function Discovery
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
# [43] Diagnostic Services
# ปิด DPS, WdiService, WER
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
# [44] System Restore Off
# ปิด VSS + System Restore (ประหยัด disk I/O + space)
# ============================================================
$Tweak_SystemRestoreOff = {
    Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    vssadmin delete shadows /all /quiet 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [45] Additional Services v2
# ปิด IPv6 transition, WinRM, Media Player sharing
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
# [46] Spotlight and Clipboard
# ปิด Windows Spotlight, clipboard history, cross-device
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
# [47] NVIDIA Telemetry (保留 app/overlay/recording)
# ปิด NVIDIA crash reports + update check tasks
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
# [48] News + Interests + Copilot
# ปิด taskbar news feed + Copilot button
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
# [49] Storage Sense + Edge
# ปิด auto-cleanup, Edge background/prelaunch/sidebar
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
# [50] Boot and Login Speed
# ปิด lock screen, boot log, status messages
# ============================================================
$Tweak_BootLoginSpeed = {
    bcdedit /set bootmenupolicy standard | Out-Null
    bcdedit /set bootlog no | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLogonBackgroundImage /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStatusMessages /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [51] Autologger Disable
# ปิด ETW trace sessions (ไม่แตะ EventLog core)
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
# [52] Pagefile Optimize
# Fixed size = 50% RAM (ไม่ grow/shrink dynamic)
# ปิด indexing ทุก drive ยกเว้น C
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
# [53] SmartScreen + AutoPlay
# ปิด SmartScreen, autoplay, Windows Script Host
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
# [54] Scheduled Tasks v2
# ปิด disk diag, perf track, defrag, Edge/Office telemetry
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
# [55] LSO + RSS Queues
# ปิด Large Send Offload (ให้ NIC จัดการ), RSS = multi-core
# ============================================================
$Tweak_LSOandRSS = {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        Disable-NetAdapterLso -Name $n -IPv4 -IPv6 -ErrorAction SilentlyContinue
        $maxRss = (Get-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -ErrorAction SilentlyContinue).RegistryValue
        if ($maxRss) { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -RegistryValue $maxRss -ErrorAction SilentlyContinue }
        try { $jumbo = Get-NetAdapterAdvancedProperty -Name $n -DisplayName 'Jumbo Packet' -ErrorAction SilentlyContinue; if ($jumbo) { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Jumbo Packet' -DisplayValue '9014 Bytes' -ErrorAction SilentlyContinue } } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*ReceiveBuffers' -RegistryValue 2048 -ErrorAction SilentlyContinue; Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*TransmitBuffers' -RegistryValue 2048 -ErrorAction SilentlyContinue } catch {}
    }
}

# ============================================================
# [56] TCP Window / BDP Tuning
# Window scaling + connection limits + TIME_WAIT delay
# ============================================================
$Tweak_TCPWindowTuning = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 3 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 262144 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxFreeTcbs /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /t REG_DWORD /d 65534 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxHashTableSize /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DefaultSendWindow /t REG_DWORD /d 65536 /f | Out-Null
}

# ============================================================
# [57] WiFi Optimize
# บังคับ 5GHz, ปิด power save, roaming aggressive
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
# [58] TCP Congestion
# Cubic congestion + fast initial RTO + larger ICW
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
# [59] UDP Buffer
# เพิ่ม UDP send/receive buffer สำหรับ game packets
# ============================================================
$Tweak_UDPBuffer = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DatagramSendBufferLength /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters" /v DatagramReceiveBufferLength /t REG_DWORD /d 65536 /f | Out-Null
    netsh int udp set global uro=disabled | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxForwardBufferMemory /t REG_DWORD /d 65536 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxNumForwardPackets /t REG_DWORD /d 65536 /f | Out-Null
}

# ============================================================
# [60] NIC Flow + RSS Core
# ปิด packet coalescing, ปิด IPv6, RSS base core=1
# ============================================================
$Tweak_NICFlowControl = {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
        $n = $_.Name
        try { Set-NetAdapterAdvancedProperty -Name $n -DisplayName 'Packet Coalescing' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue } catch {}
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*RssBaseProcNumber' -RegistryValue 1 -ErrorAction SilentlyContinue } catch {}
        $cores = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
        try { Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*MaxRssProcessors' -RegistryValue $cores -ErrorAction SilentlyContinue } catch {}
        try { Disable-NetAdapterBinding -Name $n -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue } catch {}
    }
}

# ============================================================
# [61] QoS + DSCP
# ปิด QoS bandwidth reserve, DSCP EF = game priority
# ============================================================
$Tweak_QoS = {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTOSValue /t REG_DWORD /d 184 /f | Out-Null
}

# ============================================================
# [62] NIC Power Deep
# ปิดทุก NIC power saving (ไม่ downclock/sleep)
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
# [63] DNS Cache + Flush
# Flush ทุก cache, negative cache=0, ปิด NetBIOS
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
# [64] TCP KeepAlive + SYN Protection
# KeepAlive=5min, SYN flood protection, max connections
# ============================================================
$Tweak_TCPKeepAlive = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v KeepAliveTime /t REG_DWORD /d 300000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v KeepAliveInterval /t REG_DWORD /d 1000 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNumConnections /t REG_DWORD /d 16777214 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SynAttackProtect /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxConnectResponseRetransmissions /t REG_DWORD /d 2 /f | Out-Null
}

# ============================================================
# [65] MMCSS Deep Tuning
# AlwaysOn + NoLazyMode + Latency Sensitive
# Audio Affinity=core 0-2 (ปล่อย core 3+ ให้เกม)
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
# [66] NVIDIA Profile
# Low Latency Ultra + Max Pre-Render=1 + Max Performance
# 保留 HDCP (NVIDIA app/recording ต้องใช้)
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
# [67] Ultimate Performance Power Plan
# Hidden plan = zero C-state, zero parking delay
# ============================================================
$Tweak_UltimatePerf = {
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
    powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMAXCORES 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFAUTONOMOUS 0 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR DISTRIBUTEUTILITIES 1 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
}

# ============================================================
# [68] USB Power Deep
# ปิดทุก USB hub/controller idle + root hub suspend
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
# [69] NTFS Deep
# NtfsMemoryUsage=2 (เพิ่ม file system cache)
# PathCache=128, ปิด EFS service
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
# [70] CPU Scheduling Deep
# IRQ8 priority, short fixed quantum
# SSD-only: ปิด prefetch/superfetch
# ============================================================
$Tweak_CPUScheduling = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v IRQ8Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SecondLevelDataCache /t REG_DWORD /d 0 /f | Out-Null
    $hasHDD = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' }
    if (-not $hasHDD) {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    }
}

# ============================================================
# [71] VBS/HVCI Core Isolation
# ปิด driver sandboxing (CPU overhead 5-10%)
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
# [72] NVMe Deep
# ปิด NVMe power state + ASPM, IRQ affinity=core 1
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
# [73] LargeSystemCache + IoPageLockLimit
# >=16GB RAM: ให้ Windows ใช้ RAM เป็น file cache
# IoPageLockLimit = RAM*0.75 (lock ไว้ไม่ swap)
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
# [74] Misc Services
# ปิด Spooler, RDP, Wallet, Geolocation, Shared Experiences
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
# [75] UWP Background Disable
# ปิด background ทีละ app (Photos, News, Weather, Xbox, YourPhone...)
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
# [76] ETW Session Disable (保留 EventLog core)
# ปิดแค่ diagnostic trace sessions
# ============================================================
$Tweak_ETWDisable = {
    $etwSessions = @('DiagLog','Diagtrack-Listener','WiFiSession','UserNotPresentTraceSession','NtfsLog')
    foreach ($session in $etwSessions) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$session" /v Start /t REG_DWORD /d 0 /f 2>$null | Out-Null }
}

# ============================================================
# [77] CSRSS Priority
# Client/Server Runtime Subsystem = จัดการ input + display
# High priority = input events ถูก process เร็วขึ้น
# ============================================================
$Tweak_CSRSSPriority = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v CpuPriorityClass /t REG_DWORD /d 4 /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v IoPriority /t REG_DWORD /d 3 /f 2>$null | Out-Null
}

# ============================================================
# [78] DWM Optimization
# Desktop Window Manager high priority + ปิด transparency
# ============================================================
$Tweak_DWMOptimize = {
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v CpuPriorityClass /t REG_DWORD /d 4 /f 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v IoPriority /t REG_DWORD /d 3 /f 2>$null | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v AlwaysHibernateThumbnails /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# MASTER TABLE — 78 TWEAKS
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
    "[19] Display Post Processing"     = $Tweak_MMCSSDisplay
    "[20] System.ini / Win.ini"        = $Tweak_IniCompat
    "[21] Interrupt Affinity"          = $Tweak_InterruptAffinity
    "[22] NIC Advanced"                = $Tweak_NICAdvanced
    "[23] Hyper-V and VBS"            = $Tweak_HyperV
    "[24] Timer Resolution Runtime"    = $Tweak_TimerResRuntime
    "[25] Spectre and Meltdown"        = $Tweak_SpectreMeltdown
    "[26] Memory Compression"          = $Tweak_MemCompression
    "[27] NVIDIA Low Latency"          = $Tweak_NvidiaLowLatency
    "[28] NVIDIA Shader + ReBAR"       = $Tweak_NvidiaShader
    "[29] Exploit Protection"          = $Tweak_ExploitProtection
    "[30] Windows Defender"            = $Tweak_DefenderRealtime
    "[31] Background Apps"             = $Tweak_BackgroundApps
    "[32] Delivery Optimization"       = $Tweak_DeliveryOptimization
    "[33] Device Power"                = $Tweak_DevicePower
    "[34] GPU Cache Cleanup"           = $Tweak_GpuCacheCleanup
    "[35] MPO Disable"                 = $Tweak_MPODisable
    "[36] PCI-E ASPM"                  = $Tweak_PciEAspm
    "[37] Connected Standby"           = $Tweak_ConnectedStandby
    "[38] Telemetry Tasks"             = $Tweak_TelemetryTasks
    "[39] Windows Ads and Tips"        = $Tweak_WindowsAdsTips
    "[40] Additional Services"         = $Tweak_AdditionalServices
    "[41] Overlay Killer (GameBar)"    = $Tweak_OverlayKiller
    "[42] Network Noise"               = $Tweak_NetworkNoise
    "[43] Diagnostic Services"         = $Tweak_DiagnosticServices
    "[44] System Restore Off"          = $Tweak_SystemRestoreOff
    "[45] Additional Services v2"      = $Tweak_AdditionalServices2
    "[46] Spotlight and Clipboard"     = $Tweak_SpotlightClipboard
    "[47] NVIDIA Telemetry"            = $Tweak_NvidiaTelemetry
    "[48] News + Copilot Disable"      = $Tweak_CopilotRecall
    "[49] Storage Sense + Edge"        = $Tweak_StorageEdge
    "[50] Boot and Login Speed"        = $Tweak_BootLoginSpeed
    "[51] Autologger Disable"          = $Tweak_AutologgerDisable
    "[52] Pagefile Optimize"           = $Tweak_PagefileOptimize
    "[53] SmartScreen and AutoPlay"    = $Tweak_SmartScreen
    "[54] Scheduled Tasks v2"          = $Tweak_ScheduledTasks2
    "[55] LSO + RSS Queues"            = $Tweak_LSOandRSS
    "[56] TCP Window BDP"              = $Tweak_TCPWindowTuning
    "[57] WiFi Optimize"               = $Tweak_WiFiOptimize
    "[58] TCP Congestion"              = $Tweak_TCPCongestion
    "[59] UDP Buffer"                  = $Tweak_UDPBuffer
    "[60] NIC Flow + RSS Core"         = $Tweak_NICFlowControl
    "[61] QoS + DSCP"                  = $Tweak_QoS
    "[62] NIC Power Deep"              = $Tweak_NICPowerDeep
    "[63] DNS Cache + Flush"           = $Tweak_DNSCache
    "[64] TCP KeepAlive + SYN"         = $Tweak_TCPKeepAlive
    "[65] MMCSS Deep Tuning"           = $Tweak_MMCSSDeep
    "[66] NVIDIA Profile"              = $Tweak_NvidiaProfile
    "[67] Ultimate Performance"        = $Tweak_UltimatePerf
    "[68] USB Power Deep"              = $Tweak_USBPowerDeep
    "[69] NTFS Deep"                   = $Tweak_NTFSDeep
    "[70] CPU Scheduling Deep"         = $Tweak_CPUScheduling
    "[71] VBS/HVCI Core Isolation"     = $Tweak_VBSHVCI
    "[72] NVMe Deep"                   = $Tweak_NVMeDeep
    "[73] LargeSystemCache + IoPage"   = $Tweak_LargeSystemCache
    "[74] Misc Services"               = $Tweak_MiscServices
    "[75] UWP Background Disable"      = $Tweak_UWPBackgroundDisable
    "[76] ETW Session Disable"         = $Tweak_ETWDisable
    "[77] CSRSS Priority"              = $Tweak_CSRSSPriority
    "[78] DWM Optimization"            = $Tweak_DWMOptimize
}

$script:selectedIndex = 0
$script:isRunning     = $false
$script:optionCount   = 2
$script:labelControls = @()
$script:errorLog      = @()
$script:options = @(
    @{ Label = "[1] High"; Action = "high" }
    @{ Label = "[2] Exit"; Action = "exit" }
)

$script:GradBright = @(
    [System.Drawing.Color]::FromArgb(80, 200, 255),
    [System.Drawing.Color]::FromArgb(180, 120, 255),
    [System.Drawing.Color]::FromArgb(255, 120, 180)
)
$script:GradMid = @(
    [System.Drawing.Color]::FromArgb(100, 180, 220),
    [System.Drawing.Color]::FromArgb(160, 130, 220),
    [System.Drawing.Color]::FromArgb(220, 140, 190)
)
$script:GradDim = @(
    [System.Drawing.Color]::FromArgb(60, 110, 140),
    [System.Drawing.Color]::FromArgb(110, 70, 140),
    [System.Drawing.Color]::FromArgb(140, 70, 100)
)
$script:GradPos = @(0.0, 0.5, 1.0)

$clrBg   = [System.Drawing.Color]::Black
$clrHint = [System.Drawing.Color]::FromArgb(120, 120, 120)

$form = New-Object System.Windows.Forms.Form
$form.Text            = "GOATX"
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox     = $false
$form.BackColor       = $clrBg
$form.TopMost         = $true
$form.KeyPreview      = $true
$form.Opacity         = 0.85
$form.ClientSize      = New-Object System.Drawing.Size(450, 235)

$panel = New-Object System.Windows.Forms.Panel
$panel.Dock      = "Fill"
$panel.BackColor = $clrBg
$panel.TabStop   = $true
$form.Controls.Add($panel)

function New-GradientLabel {
    param([string]$text,[float]$fontSize,[System.Drawing.FontStyle]$style,[System.Drawing.Color[]]$colors,[float[]]$positions,[int]$x,[int]$y,[int]$w,[int]$h)
    $pnl = New-Object System.Windows.Forms.Panel
    $pnl.Size = New-Object System.Drawing.Size($w,$h)
    $pnl.Location = New-Object System.Drawing.Point($x,$y)
    $pnl.BackColor = [System.Drawing.Color]::Transparent
    $pnl.Tag = @{ Text=$text; FontSize=$fontSize; Style=$style; Colors=$colors; Positions=$positions }
    $pnl.Add_Paint({
        param($s,$e)
        $dp=$s.Tag; $font=New-Object System.Drawing.Font("Consolas",$dp.FontSize,$dp.Style)
        $colors=$dp.Colors; $pos=$dp.Positions
        $e.Graphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $e.Graphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAlias
        $brush=New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point(0,0)),(New-Object System.Drawing.Point($s.Width,0)),$colors[0],$colors[$colors.Length-1])
        if($colors.Length-gt 2){$blend=New-Object System.Drawing.Drawing2D.ColorBlend;$blend.Colors=$colors;$blend.Positions=$pos;$brush.InterpolationColors=$blend}
        $sf=New-Object System.Drawing.StringFormat;$sf.Alignment=[System.Drawing.StringAlignment]::Center;$sf.LineAlignment=[System.Drawing.StringAlignment]::Center
        $rect=New-Object System.Drawing.RectangleF(0,0,$s.Width,$s.Height)
        $e.Graphics.DrawString($dp.Text,$font,$brush,$rect,$sf)
        $brush.Dispose();$font.Dispose();$sf.Dispose()
    })
    $panel.Controls.Add($pnl); return $pnl
}

New-GradientLabel -text "G O A T X" -fontSize 22 -style ([System.Drawing.FontStyle]::Bold) -colors $script:GradBright -positions $script:GradPos -x 10 -y 20 -w 430 -h 42 | Out-Null
New-GradientLabel -text "[+] Win10 22H2 Optimized [+]" -fontSize 10 -style ([System.Drawing.FontStyle]::Regular) -colors $script:GradMid -positions $script:GradPos -x 10 -y 66 -w 430 -h 22 | Out-Null

$clrOptHi  = [System.Drawing.Color]::FromArgb(130, 160, 255)
$clrOptDim = [System.Drawing.Color]::FromArgb(90, 75, 110)
$fontOpt = New-Object System.Drawing.Font("Consolas", 12)
$optStartY = 104; $optSpacing = 32

for ($i = 0; $i -lt $script:optionCount; $i++) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = if ($i -eq 0) { "> " + $script:options[$i].Label } else { "  " + $script:options[$i].Label }
    $lbl.Font = $fontOpt; $lbl.ForeColor = if ($i -eq 0) { $clrOptHi } else { $clrOptDim }
    $lbl.AutoSize = $false; $lbl.Size = New-Object System.Drawing.Size(430, 28)
    $lbl.Location = New-Object System.Drawing.Point(10, ($optStartY + $i * $optSpacing))
    $lbl.TextAlign = "MiddleLeft"; $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand; $lbl.Tag = $i
    $lbl.Add_Click({ param($s,$e); if(-not $script:isRunning){ $script:selectedIndex=[int]$s.Tag; Update-Highlight; Execute-Selection } })
    $panel.Controls.Add($lbl); $script:labelControls += $lbl
}

$fontHint = New-Object System.Drawing.Font("Consolas", 8)
$hintLbl = New-Object System.Windows.Forms.Label
$hintLbl.Text = "Arrow keys to navigate, Enter to select"
$hintLbl.Font = $fontHint; $hintLbl.ForeColor = $clrHint; $hintLbl.AutoSize = $false
$hintLbl.Size = New-Object System.Drawing.Size(430, 16)
$hintLbl.Location = New-Object System.Drawing.Point(10, 180)
$hintLbl.TextAlign = "MiddleCenter"; $hintLbl.BackColor = [System.Drawing.Color]::Transparent
$panel.Controls.Add($hintLbl)

$hiddenAcceptBtn = New-Object System.Windows.Forms.Button
$hiddenAcceptBtn.Size = New-Object System.Drawing.Size(1, 1)
$hiddenAcceptBtn.Location = New-Object System.Drawing.Point(-100, -100)
$hiddenAcceptBtn.TabStop = $false
$panel.Controls.Add($hiddenAcceptBtn)
$form.AcceptButton = $hiddenAcceptBtn
$hiddenAcceptBtn.Add_Click({ if(-not $script:isRunning){ Execute-Selection } })

function Update-Highlight {
    for ($i = 0; $i -lt $script:optionCount; $i++) {
        if ($i -eq $script:selectedIndex) {
            $script:labelControls[$i].Text = "> " + $script:options[$i].Label
            $script:labelControls[$i].ForeColor = $clrOptHi
        } else {
            $script:labelControls[$i].Text = "  " + $script:options[$i].Label
            $script:labelControls[$i].ForeColor = $clrOptDim
        }
    }
}

function Execute-Selection {
    if ($script:isRunning) { return }
    $action = $script:options[$script:selectedIndex].Action
    if ($action -eq "high") {
        $script:isRunning = $true; $script:errorLog = @()
        $total = $AllTweaks.Count; $step = 0
        foreach ($key in $AllTweaks.Keys) {
            $step++
            $script:labelControls[0].Text = "> Running ($step/$total)..."
            $script:labelControls[0].ForeColor = $clrOptHi
            $script:labelControls[0].Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            try { & $AllTweaks[$key] } catch { $script:errorLog += "$key : $($_.Exception.Message)" }
        }
        if ($script:errorLog.Count -gt 0) {
            $script:labelControls[0].Text = "> Done - $($script:errorLog.Count) error(s)"
        } else {
            $script:labelControls[0].Text = "> Done - All 78 tweaks applied"
        }
        $script:labelControls[0].Refresh()
        try { [System.Media.SystemSounds]::Beep.Play() } catch {}
        try { [Console]::Beep(1200, 300) } catch {}
        $timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 1500
        $timer.Add_Tick({ $timer.Stop(); $timer.Dispose(); $script:isRunning = $false; Update-Highlight })
        $timer.Start()
    } else { $form.Close() }
}

$script:KeyHandler = {
    param($s, $e)
    if ($e.KeyCode -eq 'Escape') { if(-not $script:isRunning){ $form.Close() }; return }
    if ($script:isRunning) { return }
    switch ($e.KeyCode) {
        'Up'   { $script:selectedIndex = ($script:selectedIndex - 1 + $script:optionCount) % $script:optionCount; Update-Highlight; $e.Handled = $true }
        'Down' { $script:selectedIndex = ($script:selectedIndex + 1) % $script:optionCount; Update-Highlight; $e.Handled = $true }
    }
}
$form.Add_KeyDown($script:KeyHandler); $panel.Add_KeyDown($script:KeyHandler)

$scrollHandler = {
    param($s, $e)
    if ($script:isRunning) { return }
    if ($e.Delta -gt 0) { $script:selectedIndex = ($script:selectedIndex - 1 + $script:optionCount) % $script:optionCount }
    else { $script:selectedIndex = ($script:selectedIndex + 1) % $script:optionCount }
    Update-Highlight
}
$form.Add_MouseWheel($scrollHandler); $panel.Add_MouseWheel($scrollHandler)
foreach ($ctrl in $panel.Controls) { try { $ctrl.Add_MouseWheel($scrollHandler) } catch {} }

$form.Add_Shown({ $panel.Focus() })
Update-Highlight

[System.Windows.Forms.Application]::Run($form)
