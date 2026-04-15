$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    $pythonCommand = @('python')
} else {
    $python = Get-Command py -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Host "Python is not installed or not available in PATH." -ForegroundColor Red
        exit 1
    }
    $pythonCommand = @('py', '-3')
}

Write-Host "Refreshing source bundle and package scaffold..." -ForegroundColor Green
powershell -ExecutionPolicy Bypass -File .\scripts\export-softcopyright-code.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

powershell -ExecutionPolicy Bypass -File .\scripts\new-softcopyright-package.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Generating PDFs and screenshots..." -ForegroundColor Green
if ($pythonCommand.Length -gt 1) {
    & $pythonCommand[0] $pythonCommand[1] .\scripts\generate-softcopyright-assets.py
} else {
    & $pythonCommand[0] .\scripts\generate-softcopyright-assets.py
}
exit $LASTEXITCODE
