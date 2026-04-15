[CmdletBinding()]
param(
    [ValidateSet('debug', 'profile', 'release')]
    [string]$BuildMode = 'debug',
    [string]$LinkPath = 'C:\rmai'
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$windowsFlutterDir = Join-Path $projectRoot 'windows\flutter'
$ephemeralDir = Join-Path $windowsFlutterDir 'ephemeral'

$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand)
$artifactRoot = Join-Path $flutterRoot 'bin\cache\artifacts\engine\windows-x64'
$cppWrapperSource = Join-Path $artifactRoot 'cpp_client_wrapper'

if (-not (Test-Path $artifactRoot)) {
    throw "Flutter Windows artifacts not found: $artifactRoot"
}

if (Test-Path $LinkPath) {
    $linkItem = Get-Item $LinkPath -Force
    if ($linkItem.LinkType -ne 'Junction') {
        throw "Link path already exists and is not a junction: $LinkPath"
    }
    $target = @($linkItem.Target)[0]
    if ($target -ne $projectRoot) {
        throw "Link path points to a different target: $LinkPath -> $target"
    }
} else {
    New-Item -ItemType Junction -Path $LinkPath -Target $projectRoot | Out-Null
}

New-Item -ItemType Directory -Force -Path $ephemeralDir | Out-Null

$artifactFiles = @(
    'flutter_export.h',
    'flutter_windows.h',
    'flutter_messenger.h',
    'flutter_plugin_registrar.h',
    'flutter_texture_registrar.h',
    'flutter_windows.dll',
    'flutter_windows.dll.lib',
    'icudtl.dat'
)

foreach ($file in $artifactFiles) {
    Copy-Item -LiteralPath (Join-Path $artifactRoot $file) -Destination $ephemeralDir -Force
}

Copy-Item -LiteralPath $cppWrapperSource -Destination $ephemeralDir -Recurse -Force

Push-Location $LinkPath
try {
    flutter pub get
    flutter build windows "--$BuildMode"
    Write-Host ""
    Write-Host "Windows build ready:" -ForegroundColor Green
    Write-Host (Join-Path $LinkPath "build\windows\x64\runner\$(if ($BuildMode -eq 'release') { 'Release' } elseif ($BuildMode -eq 'profile') { 'Profile' } else { 'Debug' })\renmai.exe")
} finally {
    Pop-Location
}
