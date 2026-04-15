param(
  [string]$From = $env:QQ_SMTP_USER,
  [string]$AuthCode = $env:QQ_SMTP_AUTH_CODE,
  [string]$To = '1943358991@qq.com',
  [string]$Subject = 'RenMai project update',
  [string]$Body,
  [string]$BodyFile,
  [string]$ConfigFile,
  [string[]]$Attachments,
  [string]$SmtpServer = 'smtp.qq.com',
  [int]$Port = 587,
  [switch]$AsHtml,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Value {
  param(
    [string]$Name,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Missing required value: $Name"
  }
}

function Split-Recipients {
  param([string]$RawRecipients)

  return @(
    $RawRecipients `
      -split '[,;]' `
      | ForEach-Object { $_.Trim() } `
      | Where-Object { $_ }
  )
}

function Load-ConfigFile {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Config file not found: $Path"
  }

  . $Path
}

if (-not $ConfigFile) {
  $defaultConfigFile = Join-Path $PSScriptRoot 'mail.local.ps1'
  if (Test-Path -LiteralPath $defaultConfigFile) {
    $ConfigFile = $defaultConfigFile
  }
}

Load-ConfigFile -Path $ConfigFile

if (-not $PSBoundParameters.ContainsKey('From')) {
  $From = $env:QQ_SMTP_USER
}
if (-not $PSBoundParameters.ContainsKey('AuthCode')) {
  $AuthCode = $env:QQ_SMTP_AUTH_CODE
}
if (-not $PSBoundParameters.ContainsKey('To') -and $env:QQ_SMTP_DEFAULT_TO) {
  $To = $env:QQ_SMTP_DEFAULT_TO
}

if ($BodyFile) {
  if (-not (Test-Path -LiteralPath $BodyFile)) {
    throw "Body file not found: $BodyFile"
  }
  $Body = Get-Content -LiteralPath $BodyFile -Raw -Encoding UTF8
}

Require-Value -Name 'From' -Value $From
Require-Value -Name 'AuthCode' -Value $AuthCode
Require-Value -Name 'To' -Value $To
Require-Value -Name 'Subject' -Value $Subject
Require-Value -Name 'Body or BodyFile' -Value $Body

$recipients = @(Split-Recipients -RawRecipients $To)
if ($recipients.Count -eq 0) {
  throw 'No valid recipients found.'
}

if ($DryRun) {
  Write-Host 'Dry run only. No email was sent.' -ForegroundColor Yellow
  Write-Host "SMTP    : ${SmtpServer}:$Port"
  Write-Host "From    : $From"
  Write-Host "To      : $($recipients -join ', ')"
  Write-Host "Subject : $Subject"
  Write-Host "BodyLen : $($Body.Length)"
  if ($Attachments) {
    Write-Host "Attach  : $($Attachments -join ', ')"
  }
  exit 0
}

$mailMessage = [System.Net.Mail.MailMessage]::new()
$smtpClient = [System.Net.Mail.SmtpClient]::new($SmtpServer, $Port)

try {
  $mailMessage.From = $From
  foreach ($recipient in $recipients) {
    [void]$mailMessage.To.Add($recipient)
  }

  $mailMessage.Subject = $Subject
  $mailMessage.SubjectEncoding = [System.Text.Encoding]::UTF8
  $mailMessage.Body = $Body
  $mailMessage.BodyEncoding = [System.Text.Encoding]::UTF8
  $mailMessage.IsBodyHtml = $AsHtml.IsPresent

  if ($Attachments) {
    foreach ($attachmentPath in $Attachments) {
      if (-not (Test-Path -LiteralPath $attachmentPath)) {
        throw "Attachment not found: $attachmentPath"
      }
      $attachment = [System.Net.Mail.Attachment]::new($attachmentPath)
      [void]$mailMessage.Attachments.Add($attachment)
    }
  }

  $smtpClient.EnableSsl = $true
  $smtpClient.Credentials = [System.Net.NetworkCredential]::new($From, $AuthCode)
  $smtpClient.Send($mailMessage)

  Write-Host "Email sent to $($recipients -join ', ')." -ForegroundColor Green
}
finally {
  if ($mailMessage.Attachments.Count -gt 0) {
    foreach ($attachment in $mailMessage.Attachments) {
      $attachment.Dispose()
    }
  }
  $mailMessage.Dispose()
  $smtpClient.Dispose()
}
