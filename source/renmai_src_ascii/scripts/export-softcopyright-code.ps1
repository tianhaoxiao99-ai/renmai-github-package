param(
    [string]$OutputPath = ""
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "softcopyright-output\renmai-web-source-bundle.txt"
}

$files = @(
    "public-chat.js",
    "index.html",
    "functions\_lib\http.js",
    "functions\_lib\ai.js",
    "functions\_lib\security.js",
    "functions\api\public-config.js",
    "functions\api\health.js",
    "functions\api\geo\geocode.js",
    "functions\api\ai\chat.js",
    "functions\api\ai\portrait.js",
    "supabase\schema.sql"
)

$builder = New-Object System.Text.StringBuilder
$utf8 = New-Object System.Text.UTF8Encoding($true)

foreach ($relativePath in $files) {
    $fullPath = Join-Path $repoRoot $relativePath

    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "文件不存在: $relativePath"
    }

    [void]$builder.AppendLine(("=" * 100))
    [void]$builder.AppendLine("FILE: $relativePath")
    [void]$builder.AppendLine(("=" * 100))

    $lineNumber = 1
    Get-Content -Path $fullPath -Encoding utf8 | ForEach-Object {
        [void]$builder.AppendLine(("{0,5}: {1}" -f $lineNumber, $_))
        $lineNumber++
    }

    [void]$builder.AppendLine("")
}

$outputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

[System.IO.File]::WriteAllText($OutputPath, $builder.ToString(), $utf8)
Write-Output "Generated: $OutputPath"

