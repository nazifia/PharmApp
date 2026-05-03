# PharmApp LAN Server Launcher

# Get first non-loopback IPv4
$localIP = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -First 1).IPAddress

if (-not $localIP) {
    Write-Error "Could not detect local IP. Check network connection."
    exit 1
}

$port = 8000
$serverUrl = "http://${localIP}:${port}/api"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PharmApp LAN Server" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Local IP  : $localIP" -ForegroundColor White
Write-Host "  Server URL: $serverUrl" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  On each device, EITHER:" -ForegroundColor Yellow
Write-Host "  [A] Settings > Network > Auto-discover  (tap once)" -ForegroundColor Green
Write-Host "  [B] Settings > Network > Server URL" -ForegroundColor Yellow
Write-Host "      Enter: $serverUrl" -ForegroundColor White
Write-Host ""
Write-Host "  Press Ctrl+C to stop server" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

& ".\venv\Scripts\Activate.ps1"

# Start mDNS broadcaster in background job
$mdnsJob = Start-Job -ScriptBlock {
    param($p) python mdns_broadcast.py $p
} -ArgumentList $port

Write-Host "[mDNS] Broadcaster started (Job ID: $($mdnsJob.Id))" -ForegroundColor DarkGray

try {
    python manage.py runserver "0.0.0.0:${port}"
} finally {
    Stop-Job -Job $mdnsJob -ErrorAction SilentlyContinue
    Remove-Job -Job $mdnsJob -ErrorAction SilentlyContinue
    Write-Host "[mDNS] Broadcaster stopped." -ForegroundColor DarkGray
}
