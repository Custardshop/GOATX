# ============================================================
# GOATX Launcher — รันบน PowerShell (ไม่ต้องเป็น Admin)
# วิธีใช้:
#   irm https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/run.ps1 | iex
# ============================================================

$htaUrl  = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/GOATX.hta"
$htaPath = "$env:TEMP\GOATX.hta"

Write-Host "[*] Downloading GOATX..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $htaUrl -OutFile $htaPath -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[-] Download failed: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "[+] Launching GOATX..." -ForegroundColor Green
Start-Process "mshta.exe" -ArgumentList "`"$htaPath`""
