param(
    [int]$Port = 8788,
    [switch]$OpenBrowser
)

$rootDir = Split-Path -Parent $PSScriptRoot
$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.js' = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.css' = 'text/css; charset=utf-8'
    '.svg' = 'image/svg+xml'
    '.png' = 'image/png'
    '.jpg' = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.webp' = 'image/webp'
    '.ico' = 'image/x-icon'
    '.woff' = 'font/woff'
    '.woff2' = 'font/woff2'
    '.ttf' = 'font/ttf'
    '.map' = 'application/json; charset=utf-8'
    '.txt' = 'text/plain; charset=utf-8'
}

function Get-SafeFilePath {
    param([string]$UrlPath)

    $rawPath = if ([string]::IsNullOrWhiteSpace($UrlPath) -or $UrlPath -eq '/') {
        'index.html'
    } else {
        [System.Uri]::UnescapeDataString(($UrlPath -split '\?')[0]).TrimStart('/')
    }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootDir $rawPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
    if (-not $candidate.StartsWith($rootDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidate
}

function Write-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [byte[]]$Body,
        [string]$ContentType
    )

    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.Headers['Cache-Control'] = 'no-store'
    $Response.ContentLength64 = $Body.Length
    $Response.OutputStream.Write($Body, 0, $Body.Length)
    $Response.OutputStream.Close()
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $listener.Start()
} catch {
    Write-Host "Failed to start local server on http://127.0.0.1:$Port/" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

Write-Host "Renmai local static server running at http://127.0.0.1:$Port/index.html" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Yellow

if ($OpenBrowser) {
    try {
        Start-Process "http://127.0.0.1:$Port/index.html" | Out-Null
    } catch {
        Write-Host "Failed to open the browser automatically. Open the URL manually if needed." -ForegroundColor Yellow
    }
}

try {
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
        } catch {
            break
        }

        $response = $context.Response
        try {
            $filePath = Get-SafeFilePath -UrlPath $context.Request.RawUrl
            if (-not $filePath) {
                Write-Response -Response $response -StatusCode 403 -Body ([System.Text.Encoding]::UTF8.GetBytes('Forbidden')) -ContentType 'text/plain; charset=utf-8'
                continue
            }

            if (-not [System.IO.File]::Exists($filePath)) {
                Write-Response -Response $response -StatusCode 404 -Body ([System.Text.Encoding]::UTF8.GetBytes('Not Found')) -ContentType 'text/plain; charset=utf-8'
                continue
            }

            $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            Write-Response -Response $response -StatusCode 200 -Body $bytes -ContentType $contentType
        } catch {
            $body = [System.Text.Encoding]::UTF8.GetBytes('Server Error')
            Write-Response -Response $response -StatusCode 500 -Body $body -ContentType 'text/plain; charset=utf-8'
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
