# ============================================================
# GOATX Launcher — รันบน PowerShell (ไม่ต้องเป็น Admin)
# วิธีใช้:
#   irm https://github.com/Custardshop/GOATX/blob/main/GOATX.hta | iex
# ============================================================

$htaUrl  = "https://github.com/Custardshop/GOATX/blob/main/GOATX.hta"
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
