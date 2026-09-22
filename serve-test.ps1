# ============================================================
# serve-test.ps1 - Test the SAP hiring form on other devices
#
# Serves this folder over HTTPS on your local network.
# HTTPS is required: browsers only allow geolocation in a
# secure context (https:// or localhost).
#
# Usage:   .\serve-test.ps1
# Stop:    Ctrl+C
#
# On each test device (same Wi-Fi/LAN):
#   1. Scan the QR code or open the printed URL.
#   2. The cert is self-signed -> tap "Advanced" > "Proceed".
#   3. Allow the location permission prompt.
# ============================================================

$port = 8443
$root = $PSScriptRoot
$certDir = Join-Path $root ".certs"

# --- Find this machine's LAN IP -----------------------------
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Sort-Object -Property InterfaceMetric |
    Select-Object -First 1).IPAddress

if (-not $ip) { Write-Error "No LAN IP found. Are you connected to a network?"; exit 1 }

# --- Generate a self-signed cert once (via npx mkcert) ------
if (!(Test-Path (Join-Path $certDir 'cert.crt'))) {
    Write-Host "Generating self-signed certificate..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $certDir | Out-Null
    Push-Location $certDir
    npx --yes mkcert create-ca
    npx --yes mkcert create-cert --domains "localhost,$ip"
    Pop-Location
}

$url = "https://${ip}:${port}/sap-hiring-form.html"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Open this URL on any device on the same network:" -ForegroundColor Cyan
Write-Host "  $url" -ForegroundColor Green
Write-Host "  (accept the self-signed cert warning, then allow location)" -ForegroundColor DarkGray
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# --- QR code for easy phone access --------------------------
if (!(Test-Path (Join-Path $certDir 'node_modules\qrcode-terminal'))) {
    npm install --prefix $certDir qrcode-terminal --no-fund --no-audit --silent | Out-Null
}
$qrLib = (Join-Path $certDir 'node_modules\qrcode-terminal') -replace '\\', '/'
node -e "require('$qrLib').generate(process.argv[1], { small: true })" $url

# --- Serve the folder over HTTPS ----------------------------
# (If Windows Firewall prompts, click "Allow access")
npx --yes http-server $root -S `
    -C (Join-Path $certDir 'cert.crt') `
    -K (Join-Path $certDir 'cert.key') `
    -p $port -c-1
