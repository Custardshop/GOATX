# ============================================================
#  G O A T X   L E G E N D A R Y   E D I T I O N
#  Windows 10 22H2 Ultimate Optimization Suite
#  75 System Tweaks | Animated Cyberpunk UI | GDI+ Assets
# ============================================================

# ── [ADMIN ELEVATION] ──────────────────────────────────────
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

# ── [HIDE CONSOLE] ─────────────────────────────────────────
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
#  PROGRAMMATIC IMAGE & ICON GENERATION ENGINE
# ============================================================

function New-AppIcon {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::FromArgb(12, 12, 24))

    $cp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cp.AddEllipse(4, 4, $Size - 8, $Size - 8)
    $pb = New-Object System.Drawing.Drawing2D.PathGradientBrush($cp)
    $pb.CenterPoint = New-Object System.Drawing.PointF($Size * 0.38, $Size * 0.35)
    $pb.CenterColor = [System.Drawing.Color]::FromArgb(130, 220, 255)
    $pb.SurroundColors = @([System.Drawing.Color]::FromArgb(25, 50, 100))
    $g.FillPath($pb, $cp)

    $rp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 180, 255), 2)
    $g.DrawEllipse($rp, 5, 5, $Size - 10, $Size - 10)
    $ip = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(30, 140, 220), 1)
    $g.DrawEllipse($ip, 10, 10, $Size - 20, $Size - 20)

    $fs = [Math]::Round($Size * 0.44)
    $fn = New-Object System.Drawing.Font("Consolas", $fs, 'Bold')
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $sb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 160, 255))
    $g.DrawString("G", $fn, $sb, $Size/2 + 2, $Size/2 + 2, $sf)
    $tb = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point(0, $Size/3)),
        (New-Object System.Drawing.Point($Size, $Size*2/3)),
        [System.Drawing.Color]::White, [System.Drawing.Color]::FromArgb(200, 230, 255))
    $g.DrawString("G", $fn, $tb, $Size/2, $Size/2, $sf)

    $g.Dispose()
    $hIcon = $bmp.GetHicon()
    return [System.Drawing.Icon]::FromHandle($hIcon)
}

function New-LogoImage {
    param([int]$W = 68, [int]$H = 68)
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)

    $cx = $W / 2; $cy = $H / 2; $rad = [Math]::Min($W, $H) / 2 - 5
    $pts = @()
    for ($i = 0; $i -lt 6; $i++) {
        $a = [Math]::PI / 180 * (60 * $i - 30)
        $pts += New-Object System.Drawing.PointF(($cx + $rad * [Math]::Cos($a)), ($cy + $rad * [Math]::Sin($a)))
    }
    $hp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hp.AddPolygon($pts)
    $hb = New-Object System.Drawing.Drawing2D.PathGradientBrush($hp)
    $hb.CenterPoint = New-Object System.Drawing.PointF($cx * 0.8, $cy * 0.7)
    $hb.CenterColor = [System.Drawing.Color]::FromArgb(70, 190, 255)
    $hb.SurroundColors = @([System.Drawing.Color]::FromArgb(15, 30, 60))
    $g.FillPath($hb, $hp)

    $gp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(25, 120, 220), 3)
    $g.DrawPolygon($gp, $pts)
    $bp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(110, 195, 255), 1.2)
    $g.DrawPolygon($bp, $pts)

    $fs2 = [Math]::Round($W * 0.4)
    $fn2 = New-Object System.Drawing.Font("Consolas", $fs2, 'Bold')
    $sf2 = New-Object System.Drawing.StringFormat
    $sf2.Alignment = 'Center'; $sf2.LineAlignment = 'Center'
    $gw = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 120, 200))
    $g.DrawString("G", $fn2, $gw, $cx + 1, $cy + 2, $sf2)
    $tw = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, $H * 0.3)), (New-Object System.Drawing.PointF($W, $H * 0.7)),
        [System.Drawing.Color]::White, [System.Drawing.Color]::FromArgb(160, 220, 255))
    $g.DrawString("G", $fn2, $tw, $cx, $cy + 1, $sf2)

    $cl = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(35, 100, 180), 1)
    $g.DrawLine($cl, $cx - $rad, $cy, $cx - $rad - 10, $cy)
    $g.DrawLine($cl, $cx + $rad, $cy, $cx + $rad + 10, $cy)
    $g.DrawLine($cl, $cx, $cy - $rad, $cx, $cy - $rad - 8)
    $g.DrawLine($cl, $cx, $cy + $rad, $cx, $cy + $rad + 8)
    $dt = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 180, 255))
    foreach ($pos in @(@($cx - $rad - 13, $cy - 2), @($cx + $rad + 9, $cy - 2),
                       @($cx - 2, $cy - $rad - 11), @($cx - 2, $cy + $rad + 7))) {
        $g.FillEllipse($dt, $pos[0], $pos[1], 4, 4)
    }

    $g.Dispose()
    return $bmp
}

# ============================================================
#  SYSTEM INFO GATHERING
# ============================================================
$script:SysInfo = @{}
try { $c = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name; $script:SysInfo.CPU = if ($c.Length -gt 38) { $c.Substring(0, 35) + "..." } else { $c } } catch { $script:SysInfo.CPU = "N/A" }
try { $r = [Math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1); $script:SysInfo.RAM = "${r}GB" } catch { $script:SysInfo.RAM = "N/A" }
try { $g2 = (Get-WmiObject Win32_VideoController | Select-Object -First 1).Name; $script:SysInfo.GPU = if ($g2.Length -gt 38) { $g2.Substring(0, 35) + "..." } else { $g2 } } catch { $script:SysInfo.GPU = "N/A" }
try { $o = (Get-WmiObject Win32_OperatingSystem).Caption; $script:SysInfo.OS = $o.Trim() } catch { $script:SysInfo.OS = "N/A" }

# ============================================================
#  GENERATE ASSETS
# ============================================================
$script:AppIcon = New-AppIcon -Size 64
$script:LogoBmp = New-LogoImage -W 68 -H 68

# ============================================================
# [01] Kernel + Timer (TSC)
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
    $gp = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    reg add "$gp" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    reg add "$gp" /v Priority /t REG_DWORD /d 6 /f | Out-Null
    reg add "$gp" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "$gp" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
    reg add "$gp" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "$gp" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "$gp" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
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
    $ap = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"
    reg add "$ap" /v Affinity /t REG_DWORD /d 0 /f | Out-Null
    reg add "$ap" /v "Background Only" /t REG_SZ /d False /f | Out-Null
    reg add "$ap" /v "Clock Rate" /t REG_DWORD /d 10000 /f | Out-Null
    reg add "$ap" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    reg add "$ap" /v Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "$ap" /v "Scheduling Category" /t REG_SZ /d High /f | Out-Null
    reg add "$ap" /v "SFIO Priority" /t REG_SZ /d High /f | Out-Null
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
# ============================================================
$Tweak_Services = {
    foreach ($s in @('DiagTrack','MapsBroker','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','Fax','RetailDemo','RemoteRegistry','WerSvc')) {
        sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null
    }
    foreach ($s in @('Audiosrv','AudioEndpointBuilder','Dhcp','NlaSvc','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','LanmanWorkstation','LanmanServer','WSearch')) {
        sc.exe config $s start= auto 2>$null | Out-Null; sc.exe start $s 2>$null | Out-Null
    }
}

# ============================================================
# [18] Junk and Log Cleanup
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
# [19] Interrupt Affinity — GPU=Core1, NIC=Core2, USB=Core3
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
using System;using System.Runtime.InteropServices;
public class WinTimer {
    [DllImport("ntdll.dll")]public static extern uint NtSetTimerResolution(uint DesiredResolution,bool SetResolution,out uint CurrentResolution);
    [DllImport("ntdll.dll")]public static extern uint NtQueryTimerResolution(out uint MinimumResolution,out uint MaximumResolution,out uint CurrentResolution);
}
"@ -ErrorAction SilentlyContinue
    $min=0;$max=0;$cur=0
    [WinTimer]::NtQueryTimerResolution([ref]$min,[ref]$max,[ref]$cur) | Out-Null
    [WinTimer]::NtSetTimerResolution($max,$true,[ref]$cur) | Out-Null
    $helperPath = "$env:SystemRoot\System32\GOATX_TimerRes.ps1"
    @'
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W{[DllImport("ntdll.dll")]public static extern uint NtSetTimerResolution(uint d,bool s,out uint c);}'
$c=0;[W]::NtSetTimerResolution(5000,$true,[ref]$c)
while($true){Start-Sleep -Seconds 120}
'@ | Out-File $helperPath -Encoding Unicode -Force
    schtasks /Create /TN "GOATX_TimerResolution" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helperPath`"" /SC ONLOGON /RL HIGHEST /F 2>$null | Out-Null
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
$Tweak_MemCompression = { Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue }

# ============================================================
# [25] NVIDIA Low Latency
# ============================================================
$Tweak_NvidiaLowLatency = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc -match 'NVIDIA'
    } | ForEach-Object {
        $p = $_.PSPath
        Set-ItemProperty -Path $p -Name 'PerfLevelSrc' -Value 0x2222 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'PowerMizerEnable' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'PowerMizerLevel' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'PowerMizerLevelAC' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'DisableDynamicPstate' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'D3PCLatency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'F1TransitionLatency' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'RMEnableVblankSynchronization' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'EnableMidBufferPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'EnableMidGfxPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'EnableMidBufferPreemptionForHighTdrTimeout' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'EnableCEPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'EnableDeepIdlePreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'EnableAsyncMidBufferPreemption' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# [26] NVIDIA Shader + ReBAR
# ============================================================
$Tweak_NvidiaShader = {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc -match 'NVIDIA'
    } | ForEach-Object {
        $p = $_.PSPath
        Set-ItemProperty -Path $p -Name 'RMEnableAppSpecificProfile' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'ShaderCache' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'RMFrmForceMaxFramesToRender' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'RMEnableReBar' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
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
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters"
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
$Tweak_MPODisable = { reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f | Out-Null }

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
    foreach ($t in @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Maps\MapsToastTask','\Microsoft\Windows\Maps\MapsUpdateTask',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
        '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
        '\Microsoft\Windows\PI\Sqm-Tasks','\Microsoft\Windows\Maintenance\WinSAT',
        '\Microsoft\Windows\Autochk\Proxy','\Microsoft\Windows\Registry\RegIdleBackup',
        '\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents',
        '\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic',
        '\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser',
        '\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange'
    )) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
}

# ============================================================
# [37] Windows Ads and Tips
# ============================================================
$Tweak_WindowsAdsTips = {
    $cdm = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    reg add "$cdm" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SoftLandingEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$cdm" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f | Out-Null
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
    foreach ($s in @('WpnService','WaaSMedicSvc','SSDPSRV','fdPHost','FDResPub','CDPSvc','CDPUserSvc','PcaSvc',
                     'TroubleShootingSvc','DusmSvc','InstallService','PhoneSvc','TapiSrv','SEMgrSvc','SharedAccess',
                     'RemoteAccess','lmhosts','WpcMonSvc','ScDeviceEnum','SCardSvr','MessagingService',
                     'PimIndexMaintenanceSvc','OneSyncSvc','AJRouter')) {
        sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null
    }
}

# ============================================================
# [39] Overlay Killer (GameBar only)
# ============================================================
$Tweak_OverlayKiller = { reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f | Out-Null }

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
    foreach ($s in @('DPS','WdiServiceHost','WdiSystemHost','diagnosticshub.standardcollector.service','diagsvc','TroubleShootingSvc')) {
        sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null
    }
    $wer = "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    reg add "$wer" /v Disabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "$wer" /v DontShowUI /t REG_DWORD /d 1 /f | Out-Null
    reg add "$wer" /v LoggingDisabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "$wer" /v AutoApproveOSDumps /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [42] System Restore Off
# ============================================================
$Tweak_SystemRestoreOff = {
    Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    vssadmin delete shadows /all /quiet 2>$null | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f | Out-Null
}

# ============================================================
# [43] Additional Services v2
# ============================================================
$Tweak_AdditionalServices2 = {
    foreach ($s in @('iphlpsvc','WinRM','wercplsupport','WerSvc','WMPNetworkSvc','UevAgentService','DsSvc',
                     'DialogBlockingService','lfsvc','wisvc','WalletService','DsRoleSvc','NcaSvc','NcdAutoSetup','icssvc','SEMgrSvc')) {
        sc.exe stop $s 2>$null | Out-Null; sc.exe config $s start= disabled 2>$null | Out-Null
    }
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
    foreach ($t in @(
        '\NVIDIA\NvDriverUpdateCheckDaily{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}',
        '\NVIDIA\NvTmRep_CrashReport1_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}',
        '\NVIDIA\NvTmRep_CrashReport2_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}',
        '\NVIDIA\NvTmRep_CrashReport3_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}',
        '\NVIDIA\NvTmRep_CrashReport4_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}',
        '\NVIDIA\NvTmMon_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}'
    )) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
    $nvPath = "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"
    if (Test-Path $nvPath) { Set-ItemProperty -Path $nvPath -Name 'OptInOrOutPreference' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
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
    $edge = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
    reg add "$edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$edge" /v EdgeCollectionsEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$edge" /v EdgeSidebarEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$edge" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$edge" /v EdgeShoppingAssistantEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "$edge" /v ShowRecommendationsEnabled /t REG_DWORD /d 0 /f | Out-Null
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
    foreach ($logger in @('DiagLog','Diagtrack-Listener','Circular Kernel Context Logger',
        'Microsoft-Windows-Rdp-Graphics-RdpIdd-Trace','Microsoft-Windows-Application-Experience',
        'Microsoft-Windows-Application-Experience-Program-Inventory',
        'Microsoft-Windows-Application-Experience-Program-Telemetry',
        'Microsoft-Windows-Kernel-PnP','Microsoft-Windows-SetupPlatform',
        'Microsoft-Windows-SetupQueue','NetCore','NtfsLog','UBPM',
        'UserNotPresentTraceSession','WiFiSession','WindowsDefenderAudit')) {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$logger" /v Start /t REG_DWORD /d 0 /f 2>$null | Out-Null
    }
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
        $drive = $_.DriveLetter + ":"; $obj = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveLetter='$drive'"
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
    foreach ($t in @(
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
    )) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
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
    $dns = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    reg add "$dns" /v MaxCacheEntryTtlLimit /t REG_DWORD /d 86400 /f | Out-Null
    reg add "$dns" /v MaxSOACacheEntryTtlLimit /t REG_DWORD /d 120 /f | Out-Null
    reg add "$dns" /v NegativeCacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "$dns" /v NetFailureCacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "$dns" /v NegativeSOACacheTime /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2 -ErrorAction SilentlyContinue
    }
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
        $p = $_.PSPath
        Set-ItemProperty -Path $p -Name 'RMEnableAppSpecificProfile' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'LowLatencyMode' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'RMFrmForceMaxFramesToRender' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'TextureQuality' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'PerfLevelSrc' -Value 0x2222 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'RmEnableExtSs' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $p -Name 'RMForceGenSpeed' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
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
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters"
        if (Test-Path "$regPath\WDF") { Set-ItemProperty -Path "$regPath\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
        if (Test-Path "$regPath\USB") { Set-ItemProperty -Path "$regPath\USB" -Name 'DeviceIdleEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
    }
    Get-WmiObject -Class Win32_USBController -ErrorAction SilentlyContinue | ForEach-Object {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters"
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
# ============================================================
$Tweak_CPUScheduling = {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v IRQ8Priority /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SecondLevelDataCache /t REG_DWORD /d 0 /f | Out-Null
    $hasHDD = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' }
    $pfPath = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if ($hasHDD) {
        reg add "$pfPath" /v EnablePrefetcher /t REG_DWORD /d 3 /f | Out-Null
        reg add "$pfPath" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
    } else {
        reg add "$pfPath" /v EnablePrefetcher /t REG_DWORD /d 0 /f | Out-Null
        reg add "$pfPath" /v EnableSuperfetch /t REG_DWORD /d 0 /f | Out-Null
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
    $ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    if ($ramGB -ge 16) { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 1 /f | Out-Null }
    else { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f | Out-Null }
    $ramMB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $ioLock = [math]::Round($ramMB * 0.75 * 4096)
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v IoPageLockLimit /t REG_DWORD /d $ioLock /f | Out-Null
}

# ============================================================
# [71] Misc Services
# ============================================================
$Tweak_MiscServices = {
    foreach ($pair in @(@('Spooler','disabled'),@('SessionEnv','disabled'),@('TermService','disabled'),@('lfsvc','disabled'),@('WalletService','disabled'))) {
        sc.exe stop $pair[0] 2>$null | Out-Null; sc.exe config $pair[0] start= $pair[1] 2>$null | Out-Null
    }
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CDP" /v RomeSdkConsumerUserSettings /t REG_DWORD /d 0 /f | Out-Null
}

# ============================================================
# [72] UWP Background Disable
# ============================================================
$Tweak_UWPBackgroundDisable = {
    foreach ($app in @('Microsoft.Windows.Photos_8wekyb3d8bbwe','Microsoft.ZuneVideo_8wekyb3d8bbwe',
        'Microsoft.BingNews_8wekyb3d8bbwe','Microsoft.BingWeather_8wekyb3d8bbwe','Microsoft.GetHelp_8wekyb3d8bbwe',
        'Microsoft.Getstarted_8wekyb3d8bbwe','Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe','Microsoft.People_8wekyb3d8bbwe',
        'Microsoft.SkypeApp_kzf8qxf38zg5c','Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe',
        'Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe','Microsoft.Xbox.TCUI_8wekyb3d8bbwe','Microsoft.XboxApp_8wekyb3d8bbwe',
        'Microsoft.XboxGameOverlay_8wekyb3d8bbwe','Microsoft.XboxGamingOverlay_8wekyb3d8bbwe',
        'Microsoft.XboxIdentityProvider_8wekyb3d8bbwe','Microsoft.YourPhone_8wekyb3d8bbwe',
        'Microsoft.WindowsMaps_8wekyb3d8bbwe','Microsoft.Messaging_8wekyb3d8bbwe','Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe')) {
        $appPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$app"
        reg add "$appPath" /v Disabled /t REG_DWORD /d 1 /f 2>$null | Out-Null
        reg add "$appPath" /v DisabledByUser /t REG_DWORD /d 1 /f 2>$null | Out-Null
    }
}

# ============================================================
# [73] ETW Session Disable
# ============================================================
$Tweak_ETWDisable = {
    foreach ($s in @('DiagLog','Diagtrack-Listener','WiFiSession','UserNotPresentTraceSession','NtfsLog')) {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$s" /v Start /t REG_DWORD /d 0 /f 2>$null | Out-Null
    }
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
#  MASTER TWEAK TABLE — 75 TWEAKS
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
    "[46] News + Copilot Disable"      = $Tweak_CopilotRecall
    "[47] Storage Sense + Edge"        = $Tweak_StorageEdge
    "[48] Boot and Login Speed"        = $Tweak_BootLoginSpeed
    "[49] Autologger Disable"          = $Tweak_AutologgerDisable
    "[50] Pagefile Optimize"           = $Tweak_PagefileOptimize
    "[51] SmartScreen and AutoPlay"    = $Tweak_SmartScreen
    "[52] Scheduled Tasks v2"          = $Tweak_ScheduledTasks2
    "[53] LSO + RSS Queues"            = $Tweak_LSOandRSS
    "[54] TCP Window BDP"              = $Tweak_TCPWindowTuning
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
}

# ============================================================
#  GUI STATE
# ============================================================
$script:FormW = 520; $script:FormH = 300
$script:selectedIndex = 0
$script:isRunning     = $false
$script:progress      = 0.0
$script:statusText    = ""
$script:optionCount   = 2
$script:labelControls = @()
$script:errorLog      = @()
$script:options = @(
    @{ Label = "[1] High Performance"; Action = "high" }
    @{ Label = "[2] Exit";            Action = "exit" }
)

# ============================================================
#  PARTICLE SYSTEM — 22 Floating Particles
# ============================================================
$script:Particles = @()
$pColors = @(@(80,200,255),@(100,160,255),@(160,130,255),@(130,200,240),@(200,140,220))
for ($i = 0; $i -lt 22; $i++) {
    $pc = $pColors[$i % $pColors.Count]
    $script:Particles += [PSCustomObject]@{
        X     = Get-Random -Min 0 -Max $script:FormW
        Y     = Get-Random -Min 0 -Max $script:FormH
        VX    = (Get-Random -Min -25 -Max 25) / 100.0
        VY    = (Get-Random -Min -25 -Max 25) / 100.0
        Size  = (Get-Random -Min 10 -Max 28) / 10.0
        Alpha = Get-Random -Min 12 -Max 48
        R     = $pc[0]; G = $pc[1]; B = $pc[2]
    }
}

# ============================================================
#  FORM & PANEL (Double-Buffered)
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "GOATX"
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(10, 10, 18)
$form.TopMost         = $true
$form.KeyPreview      = $true
$form.ClientSize      = New-Object System.Drawing.Size($script:FormW, $script:FormH)
$form.Icon            = $script:AppIcon
$form.Opacity         = 0

$panel = New-Object System.Windows.Forms.Panel
$panel.Dock      = "Fill"
$panel.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 18)
$panel.TabStop   = $true
try {
    $panel.GetType().InvokeMember("DoubleBuffered",
        [System.Reflection.BindingFlags]::SetProperty -bor
        [System.Reflection.BindingFlags]::Instance -bor
        [System.Reflection.BindingFlags]::NonPublic, $null, $panel, $true)
} catch {}
$form.Controls.Add($panel)

# ============================================================
#  CACHED GDI RESOURCES (Performance)
# ============================================================
$script:BgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)),
    (New-Object System.Drawing.Point($script:FormW, $script:FormH)),
    [System.Drawing.Color]::FromArgb(10, 10, 20),
    [System.Drawing.Color]::FromArgb(18, 14, 32))

$script:TitleShadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25, 100, 220))
$script:TitleGradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(90, 10)),
    (New-Object System.Drawing.Point(480, 55)),
    [System.Drawing.Color]::FromArgb(80, 200, 255),
    [System.Drawing.Color]::FromArgb(200, 140, 255))
$script:SubtitleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(130, 130, 170))
$script:InfoBrush     = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(75, 75, 110))
$script:ProgBGBrush   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22, 22, 38))
$script:ProgBorderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40, 80, 140), 1)
$script:ProgTextBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 120, 160))
$script:StatusBrush   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 180, 255))

# Separator gradient
$script:SepBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(18, 0)), (New-Object System.Drawing.Point(502, 0)),
    [System.Drawing.Color]::FromArgb(0, 60, 120), [System.Drawing.Color]::FromArgb(0, 60, 120))
$sepBlend = New-Object System.Drawing.Drawing2D.ColorBlend
$sepBlend.Colors   = @([System.Drawing.Color]::FromArgb(0,60,120), [System.Drawing.Color]::FromArgb(50,100,200), [System.Drawing.Color]::FromArgb(0,60,120))
$sepBlend.Positions = @(0, 0.5, 1)
$script:SepBrush.InterpolationColors = $sepBlend

# Fonts
$script:TitleFont = New-Object System.Drawing.Font("Consolas", 22, 'Bold')
$script:SubFont   = New-Object System.Drawing.Font("Consolas", 9)
$script:InfoFont  = New-Object System.Drawing.Font("Consolas", 8)
$script:ProgFont  = New-Object System.Drawing.Font("Consolas", 8, 'Bold')
$script:MenuFont  = New-Object System.Drawing.Font("Consolas", 12)

# ============================================================
#  PAINT HANDLER — Cyberpunk Background + Particles + Info
# ============================================================
$panel.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode     = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $fw = $script:FormW; $fh = $script:FormH

    # ── Background gradient ──
    $g.FillRectangle($script:BgBrush, 0, 0, $fw, $fh)

    # ── Particles ──
    foreach ($p in $script:Particles) {
        $a = [int]$p.Alpha
        # Glow halo
        $ga = [Math]::Max(0, [int]($a * 0.25))
        $gb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($ga, $p.R, $p.G, $p.B))
        $g.FillEllipse($gb, $p.X - $p.Size, $p.Y - $p.Size, $p.Size * 3, $p.Size * 3)
        $gb.Dispose()
        # Core dot
        $cb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, $p.R, $p.G, $p.B))
        $g.FillEllipse($cb, $p.X, $p.Y, $p.Size, $p.Size)
        $cb.Dispose()
    }

    # ── Logo Image ──
    try { $g.DrawImage($script:LogoBmp, 18, 12, 68, 68) } catch {}

    # ── Title with Glow ──
    $g.DrawString("G O A T X", $script:TitleFont, $script:TitleShadowBrush, 99, 16)
    $g.DrawString("G O A T X", $script:TitleFont, $script:TitleGradientBrush, 98, 15)

    # ── Subtitle ──
    $g.DrawString("Win10 22H2 Ultimate Optimizer  |  75 Tweaks", $script:SubFont, $script:SubtitleBrush, 98, 48)

    # ── System Info ──
    $g.DrawString("CPU: $($script:SysInfo.CPU)    RAM: $($script:SysInfo.RAM)", $script:InfoFont, $script:InfoBrush, 98, 67)
    $g.DrawString("GPU: $($script:SysInfo.GPU)", $script:InfoFont, $script:InfoBrush, 98, 80)

    # ── Separator ──
    $g.FillRectangle($script:SepBrush, 18, 98, 484, 1)

    # ── Progress Bar ──
    $barX = 20; $barY = 198; $barW = 440; $barH = 12
    $g.FillRectangle($script:ProgBGBrush, $barX, $barY, $barW, $barH)
    $fillW = [int]($barW * $script:progress)
    if ($fillW -gt 0) {
        $fb = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point($barX, $barY)),
            (New-Object System.Drawing.Point($barX + $fillW, $barY)),
            [System.Drawing.Color]::FromArgb(80, 200, 255),
            [System.Drawing.Color]::FromArgb(180, 120, 255))
        $g.FillRectangle($fb, $barX, $barY, $fillW, $barH)
        $fb.Dispose()
    }
    $g.DrawRectangle($script:ProgBorderPen, $barX, $barY, $barW, $barH)
    $g.DrawString("$([int]($script:progress * 100))%", $script:ProgFont, $script:ProgTextBrush, $barX + $barW + 8, $barY - 1)

    # ── Status Text ──
    if ($script:statusText) {
        $g.DrawString($script:statusText, $script:InfoFont, $script:StatusBrush, 20, 218)
    }
})

# ============================================================
#  MENU LABELS (Hover-to-Select)
# ============================================================
$optStartY = 112; $optSpacing = 36
$clrOptHi  = [System.Drawing.Color]::FromArgb(130, 190, 255)
$clrOptDim = [System.Drawing.Color]::FromArgb(65, 60, 95)
$hintFont  = New-Object System.Drawing.Font("Consolas", 7.5)

for ($i = 0; $i -lt $script:optionCount; $i++) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = if ($i -eq 0) { "> " + $script:options[$i].Label } else { "  " + $script:options[$i].Label }
    $lbl.Font      = $script:MenuFont
    $lbl.ForeColor = if ($i -eq 0) { $clrOptHi } else { $clrOptDim }
    $lbl.AutoSize  = $false
    $lbl.Size      = New-Object System.Drawing.Size(480, 32)
    $lbl.Location  = New-Object System.Drawing.Point(20, ($optStartY + $i * $optSpacing))
    $lbl.TextAlign = "MiddleLeft"
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $lbl.Tag       = $i
    $lbl.Add_Click({
        param($sender, $e)
        if (-not $script:isRunning) {
            $script:selectedIndex = [int]$sender.Tag
            Update-Highlight; Execute-Selection
        }
    })
    $lbl.Add_MouseEnter({
        param($sender, $e)
        if (-not $script:isRunning) {
            $script:selectedIndex = [int]$sender.Tag
            Update-Highlight
        }
    })
    $panel.Controls.Add($lbl)
    $script:labelControls += $lbl
}

# Hint
$hintLbl = New-Object System.Windows.Forms.Label
$hintLbl.Text      = "Arrow keys to navigate  |  Enter to select  |  Esc to exit"
$hintLbl.Font      = $hintFont
$hintLbl.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 60)
$hintLbl.AutoSize  = $false
$hintLbl.Size      = New-Object System.Drawing.Size(480, 16)
$hintLbl.Location  = New-Object System.Drawing.Point(20, 245)
$hintLbl.TextAlign = "MiddleCenter"
$hintLbl.BackColor = [System.Drawing.Color]::Transparent
$panel.Controls.Add($hintLbl)

# Accept button (hidden)
$hiddenBtn = New-Object System.Windows.Forms.Button
$hiddenBtn.Size     = New-Object System.Drawing.Size(1, 1)
$hiddenBtn.Location = New-Object System.Drawing.Point(-100, -100)
$hiddenBtn.TabStop  = $false
$panel.Controls.Add($hiddenBtn)
$form.AcceptButton  = $hiddenBtn
$hiddenBtn.Add_Click({ if (-not $script:isRunning) { Execute-Selection } })

# ============================================================
#  ANIMATION ENGINE — 20fps Particle Drift
# ============================================================
$animTimer = New-Object System.Windows.Forms.Timer
$animTimer.Interval = 50
$animTimer.Add_Tick({
    foreach ($p in $script:Particles) {
        $p.X += $p.VX; $p.Y += $p.VY
        if ($p.X -lt -15) { $p.X = $script:FormW + 10 }
        if ($p.X -gt $script:FormW + 15) { $p.X = -10 }
        if ($p.Y -lt -15) { $p.Y = $script:FormH + 10 }
        if ($p.Y -gt $script:FormH + 15) { $p.Y = -10 }
        $p.Alpha = [Math]::Max(8, [Math]::Min(55, $p.Alpha + (Get-Random -Min -3 -Max 4)))
    }
    $panel.Invalidate()
})
$animTimer.Start()

# Fade-in timer
$fadeInTimer = New-Object System.Windows.Forms.Timer
$fadeInTimer.Interval = 25
$fadeInTimer.Add_Tick({
    if ($form.IsDisposed) { $fadeInTimer.Stop(); return }
    $form.Opacity = [Math]::Min(0.93, $form.Opacity + 0.06)
    if ($form.Opacity -ge 0.93) { $fadeInTimer.Stop(); $fadeInTimer.Dispose() }
})

# ============================================================
#  FUNCTIONS
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

function Execute-Selection {
    if ($script:isRunning) { return }
    $action = $script:options[$script:selectedIndex].Action
    if ($action -eq "high") {
        $script:isRunning = $true
        $script:errorLog  = @()
        $total = $AllTweaks.Count; $step = 0
        foreach ($key in $AllTweaks.Keys) {
            $step++
            $script:progress   = $step / $total
            $script:statusText = "Applying: $key"
            $script:labelControls[0].Text      = "> Running ($step/$total)..."
            $script:labelControls[0].ForeColor = $clrOptHi
            $script:labelControls[0].Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            try { & $AllTweaks[$key] } catch { $script:errorLog += "$key : $($_.Exception.Message)" }
        }
        $script:progress   = 1.0
        $script:statusText = if ($script:errorLog.Count -gt 0) {
            "Done — $($script:errorLog.Count) error(s)"
        } else {
            "All $total optimizations applied successfully!"
        }
        $script:labelControls[0].Text = if ($script:errorLog.Count -gt 0) {
            "> Done — $($script:errorLog.Count) error(s)"
        } else {
            "> Complete — All $total tweaks applied"
        }
        $script:labelControls[0].Refresh()
        $panel.Invalidate()
        try { [Console]::Beep(1200, 300) } catch {}
        $doneTimer = New-Object System.Windows.Forms.Timer
        $doneTimer.Interval = 2500
        $doneTimer.Add_Tick({
            $doneTimer.Stop(); $doneTimer.Dispose()
            $script:isRunning  = $false
            $script:progress   = 0.0
            $script:statusText = ""
            Update-Highlight
        })
        $doneTimer.Start()
    } else {
        $form.Close()
    }
}

# ============================================================
#  EVENT HANDLERS
# ============================================================
$keyHandler = {
    param($sender, $e)
    if ($e.KeyCode -eq 'Escape') { if (-not $script:isRunning) { $form.Close() }; return }
    if ($script:isRunning) { return }
    switch ($e.KeyCode) {
        'Up'   { $script:selectedIndex = ($script:selectedIndex - 1 + $script:optionCount) % $script:optionCount; Update-Highlight; $e.Handled = $true }
        'Down' { $script:selectedIndex = ($script:selectedIndex + 1) % $script:optionCount; Update-Highlight; $e.Handled = $true }
    }
}
$form.Add_KeyDown($keyHandler); $panel.Add_KeyDown($keyHandler)

$scrollHandler = {
    param($sender, $e)
    if ($script:isRunning) { return }
    if ($e.Delta -gt 0) { $script:selectedIndex = ($script:selectedIndex - 1 + $script:optionCount) % $script:optionCount }
    else { $script:selectedIndex = ($script:selectedIndex + 1) % $script:optionCount }
    Update-Highlight
}
$form.Add_MouseWheel($scrollHandler); $panel.Add_MouseWheel($scrollHandler)
foreach ($ctrl in $panel.Controls) { try { $ctrl.Add_MouseWheel($scrollHandler) } catch {} }

# Cleanup on close
$form.Add_FormClosing({
    $animTimer.Stop(); $animTimer.Dispose()
    foreach ($d in @($script:BgBrush, $script:TitleShadowBrush, $script:TitleGradientBrush,
                     $script:SubtitleBrush, $script:InfoBrush, $script:ProgBGBrush, $script:ProgBorderPen,
                     $script:ProgTextBrush, $script:StatusBrush, $script:SepBrush,
                     $script:TitleFont, $script:SubFont, $script:InfoFont, $script:ProgFont, $script:MenuFont)) {
        try { $d.Dispose() } catch {}
    }
    try { $script:LogoBmp.Dispose() } catch {}
})

# ============================================================
#  LAUNCH
# ============================================================
$form.Add_Shown({ $panel.Focus(); $fadeInTimer.Start() })
Update-Highlight
[System.Windows.Forms.Application]::Run($form)
