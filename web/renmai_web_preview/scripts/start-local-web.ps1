$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$port = if ($env:RENMAI_LOCAL_PORT) { $env:RENMAI_LOCAL_PORT } else { '8788' }

Write-Host "Starting Renmai local web server on http://127.0.0.1:$port/index.html" -ForegroundColor Green
Write-Host "Keep this window open while you use the site." -ForegroundColor Yellow
Write-Host ""

& .\scripts\local-static-server.ps1 -Port $port -OpenBrowser

Write-Host ""
Write-Host "The local web server has stopped." -ForegroundColor Yellow
Read-Host "Press Enter to close"
