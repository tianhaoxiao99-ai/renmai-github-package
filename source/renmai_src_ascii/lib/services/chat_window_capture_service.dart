import 'dart:convert';
import 'dart:io';

class ChatWindowCaptureResult {
  final String processName;
  final String windowTitle;
  final String headerText;
  final String text;
  final int chunkCount;
  final List<String> warnings;
  final String? suggestedContactName;

  const ChatWindowCaptureResult({
    required this.processName,
    required this.windowTitle,
    required this.headerText,
    required this.text,
    required this.chunkCount,
    required this.warnings,
    required this.suggestedContactName,
  });
}

class ChatWindowCaptureService {
  ChatWindowCaptureService._();

  static final ChatWindowCaptureService instance = ChatWindowCaptureService._();

  Future<ChatWindowCaptureResult> captureForegroundConversation({
    int prepareDelaySeconds = 0,
    int passCount = 240,
    int pauseMilliseconds = 820,
  }) async {
    if (!Platform.isWindows) {
      throw const FileSystemException('当前版本仅支持 Windows 桌面采集。');
    }

    final scriptFile = await _ensureScriptFile();
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-PrepareDelaySeconds',
        prepareDelaySeconds.toString(),
        '-PassCount',
        passCount.toString(),
        '-PauseMilliseconds',
        pauseMilliseconds.toString(),
      ],
      runInShell: true,
    );

    final stdoutText = (result.stdout ?? '').toString().trim();
    final stderrText = (result.stderr ?? '').toString().trim();

    if (result.exitCode != 0 && stdoutText.isEmpty) {
      throw FileSystemException(
        stderrText.isEmpty ? '聊天窗口采集失败，请稍后重试。' : stderrText,
      );
    }

    if (stdoutText.isEmpty) {
      throw const FileSystemException('聊天窗口采集失败，未获得可识别内容。');
    }

    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(stdoutText) as Map<String, dynamic>;
    } catch (_) {
      throw FileSystemException(
        stderrText.isEmpty ? '聊天窗口采集返回了无法识别的结果。' : stderrText,
      );
    }

    final ok = json['ok'] == true;
    if (!ok) {
      final message = (json['error'] ?? '').toString().trim();
      throw FileSystemException(
        message.isEmpty ? '聊天窗口采集失败，请确认聊天窗口已正确打开。' : message,
      );
    }

    final warnings = (json['warnings'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final title = (json['window_title'] ?? '').toString();
    final headerText = (json['header_text'] ?? '').toString();

    return ChatWindowCaptureResult(
      processName: (json['process_name'] ?? '').toString(),
      windowTitle: title,
      headerText: headerText,
      text: (json['text'] ?? '').toString(),
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
      warnings: warnings,
      suggestedContactName: _inferContactName(
        title: title,
        headerText: headerText,
      ),
    );
  }

  Future<File> _ensureScriptFile() async {
    final directory =
        Directory('${Directory.systemTemp.path}\\renmai_capture_service');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}\\capture_chat_window.ps1');
    await file.writeAsString(_scriptSource, flush: true);
    return file;
  }

  String? _inferContactName({
    required String title,
    required String headerText,
  }) {
    final candidates = <String>[
      ...headerText
          .split(RegExp(r'[\r\n]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(4),
      title.trim(),
    ];

    for (final item in candidates) {
      final normalized = item
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\s*[-|]\s*(QQ|Weixin|WeChat).*$'), '')
          .trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (normalized == 'QQ' ||
          normalized.toLowerCase() == 'wechat' ||
          normalized.toLowerCase() == 'weixin') {
        continue;
      }

      final chineseMatch =
          RegExp(r'([\u4e00-\u9fa5]{2,8})').firstMatch(normalized);
      if (chineseMatch != null) {
        return chineseMatch.group(1);
      }

      final latinMatch =
          RegExp(r'([A-Za-z][A-Za-z ]{1,24})').firstMatch(normalized);
      if (latinMatch != null) {
        return latinMatch.group(1)?.trim();
      }
    }

    return null;
  }
}

const String _scriptSource = r'''
param(
  [int]$PrepareDelaySeconds = 0,
  [int]$PassCount = 240,
  [int]$PauseMilliseconds = 820
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Windows.Forms

$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
$null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime]

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class RenMaiCaptureNative {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  [DllImport("user32.dll")]
  public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool IsWindowVisible(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool IsIconic(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

  [DllImport("user32.dll")]
  public static extern int GetWindowTextLength(IntPtr hWnd);

  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);

  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

function Await-AsyncOperation([object]$op, [Type]$resultType) {
  $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
    Select-Object -First 1
  $generic = $method.MakeGenericMethod($resultType)
  $task = $generic.Invoke($null, @($op))
  return $task.GetAwaiter().GetResult()
}

function Get-WindowInfo([IntPtr]$handle) {
  if ($handle -eq [IntPtr]::Zero) { return $null }
  if (-not [RenMaiCaptureNative]::IsWindowVisible($handle)) { return $null }
  if ([RenMaiCaptureNative]::IsIconic($handle)) { return $null }

  $rect = New-Object RenMaiCaptureNative+RECT
  if (-not [RenMaiCaptureNative]::GetWindowRect($handle, [ref]$rect)) {
    return $null
  }

  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  if ($width -lt 320 -or $height -lt 260) {
    return $null
  }

  $textLength = [RenMaiCaptureNative]::GetWindowTextLength($handle)
  $titleBuilder = New-Object System.Text.StringBuilder ([Math]::Max($textLength + 1, 2))
  [void][RenMaiCaptureNative]::GetWindowText($handle, $titleBuilder, $titleBuilder.Capacity)

  $classBuilder = New-Object System.Text.StringBuilder 256
  [void][RenMaiCaptureNative]::GetClassName($handle, $classBuilder, $classBuilder.Capacity)

  [uint32]$procId = 0
  [void][RenMaiCaptureNative]::GetWindowThreadProcessId($handle, [ref]$procId)
  $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue

  [pscustomobject]@{
    Handle = $handle
    Left = $rect.Left
    Top = $rect.Top
    Width = $width
    Height = $height
    Title = $titleBuilder.ToString()
    ClassName = $classBuilder.ToString()
    ProcessName = if ($proc) { $proc.ProcessName } else { '' }
  }
}

function Get-VisibleWindows() {
  $script:RenMaiWindowList = New-Object 'System.Collections.Generic.List[object]'
  $callback = [RenMaiCaptureNative+EnumWindowsProc]{
    param([IntPtr]$hWnd, [IntPtr]$lParam)

    $info = Get-WindowInfo $hWnd
    if ($null -ne $info) {
      $title = ([string]$info.Title).Trim()
      $processName = ([string]$info.ProcessName).Trim()
      if (-not [string]::IsNullOrWhiteSpace($processName) -and
          (-not [string]::IsNullOrWhiteSpace($title) -or $processName -match 'QQ|WeChat|Weixin')) {
        $script:RenMaiWindowList.Add($info)
      }
    }

    return $true
  }

  [void][RenMaiCaptureNative]::EnumWindows($callback, [IntPtr]::Zero)
  return @($script:RenMaiWindowList.ToArray())
}

function Get-ProcessMainWindows() {
  $results = New-Object 'System.Collections.Generic.List[object]'
  $processes = Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.MainWindowHandle -ne 0 -and
      $_.ProcessName -match '^(QQ|Weixin|WeChatAppEx)$'
    }

  foreach ($process in $processes) {
    $handle = New-Object System.IntPtr ([int64]$process.MainWindowHandle)
    $info = Get-WindowInfo $handle
    if ($null -ne $info) {
      $results.Add($info)
    }
  }

  return @($results.ToArray())
}

function Test-ChatWindowCandidate([object]$windowInfo) {
  if ($null -eq $windowInfo) { return $false }

  $processName = ([string]$windowInfo.ProcessName).ToLowerInvariant()
  $title = ([string]$windowInfo.Title).Trim()
  $className = ([string]$windowInfo.ClassName).Trim()

  if ($processName -match 'qq|wechat|weixin') { return $true }
  if ($title -match 'QQ|WeChat') { return $true }
  if ($className -match 'TXGuiFoundation|WeChatMainWndForPC|Qt5152QWindowIcon') { return $true }

  return $false
}

function Get-ChatWindowScore([object]$windowInfo, [IntPtr]$foregroundHandle) {
  $title = ([string]$windowInfo.Title).Trim()
  $processName = ([string]$windowInfo.ProcessName).ToLowerInvariant()
  $score = 0

  if ($windowInfo.Handle -eq $foregroundHandle) { $score += 140 }
  if ($processName -match 'qq') { $score += 60 }
  if ($processName -match 'wechat|weixin') { $score += 100 }
  if ($processName -match 'weixin' -and $title -notmatch '^微信$') { $score += 70 }
  if ($processName -match 'wechatappex') { $score += 40 }
  if ($title -match '[\u4e00-\u9fa5]{2,}') { $score += 70 }
  if ($title -match '[A-Za-z0-9]{2,}') { $score += 18 }
  if ($title -match '[\(\)]') { $score += 20 }
  if ($title -and $title -notmatch '^(QQ|WeChat)$') { $score += 40 }

  $area = [Math]::Max($windowInfo.Width * $windowInfo.Height, 0)
  $score += [Math]::Min([int]($area / 45000), 90)

  return $score
}

function Get-PreferredChatWindow([object]$foregroundInfo) {
  $windows = @()
  $windows += @(Get-VisibleWindows)
  $windows += @(Get-ProcessMainWindows)
  $unique = @{}
  foreach ($window in $windows) {
    if ($null -eq $window) { continue }
    $key = ([int64]$window.Handle).ToString()
    if (-not $unique.ContainsKey($key)) {
      $unique[$key] = $window
    }
  }

  $foregroundHandle = if ($foregroundInfo) { $foregroundInfo.Handle } else { [IntPtr]::Zero }
  $candidates = @($unique.Values) | Where-Object { Test-ChatWindowCandidate $_ }
  if ($null -eq $candidates -or $candidates.Count -eq 0) {
    return $null
  }

  $wechatCandidates = @($candidates | Where-Object {
    ([string]$_.ProcessName).ToLowerInvariant() -match 'weixin|wechatappex'
  })
  if ($wechatCandidates.Count -gt 0) {
    $candidates = $wechatCandidates
  }

  return $candidates |
    Sort-Object -Descending -Property @{ Expression = { Get-ChatWindowScore $_ $foregroundHandle } } |
    Select-Object -First 1
}

function Focus-Window([object]$windowInfo) {
  if ($null -eq $windowInfo) { return }

  [void][RenMaiCaptureNative]::ShowWindowAsync($windowInfo.Handle, 9)
  Start-Sleep -Milliseconds 120
  [void][RenMaiCaptureNative]::SetForegroundWindow($windowInfo.Handle)
  Start-Sleep -Milliseconds 240
}

function Capture-RectToFile($x, $y, $width, $height, $filePath) {
  $bitmap = New-Object System.Drawing.Bitmap $width, $height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($x, $y, 0, 0, $bitmap.Size)
    $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function Resize-Image($inputPath, $outputPath, [double]$scale) {
  $image = [System.Drawing.Image]::FromFile($inputPath)
  try {
    $targetWidth = [Math]::Max([int]([Math]::Round($image.Width * $scale)), $image.Width)
    $targetHeight = [Math]::Max([int]([Math]::Round($image.Height * $scale)), $image.Height)
    $bitmap = New-Object System.Drawing.Bitmap $targetWidth, $targetHeight
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.DrawImage($image, 0, 0, $targetWidth, $targetHeight)
      $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  } finally {
    $image.Dispose()
  }
}

function Invoke-Ocr($filePath) {
  $storageFile = Await-AsyncOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($filePath)) ([Windows.Storage.StorageFile])
  $stream = Await-AsyncOperation ($storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await-AsyncOperation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await-AsyncOperation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $ocr = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  $result = Await-AsyncOperation ($ocr.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
  return ($result.Text -replace '\r', '').Trim()
}

function Get-BestOcrText([string]$primary, [string]$secondary) {
  if ([string]::IsNullOrWhiteSpace($primary)) { return $secondary }
  if ([string]::IsNullOrWhiteSpace($secondary)) { return $primary }
  if ($secondary.Length -gt $primary.Length) { return $secondary }
  return $primary
}

function Get-MergedOcrText([string[]]$chunks) {
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $merged = New-Object System.Collections.Generic.List[string]

  foreach ($chunk in $chunks) {
    $text = ([string]$chunk).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { continue }

    $normalized = ($text -replace '\s+', ' ').Trim()
    if ($normalized.Length -lt 2) { continue }

    if ($seen.Add($normalized)) {
      $merged.Add($text)
    }
  }

  return ($merged -join "`n`n").Trim()
}

function Get-WindowCapture([object]$windowInfo, [string]$tag) {
  $width = [int]$windowInfo.Width
  $height = [int]$windowInfo.Height
  $processName = ([string]$windowInfo.ProcessName).ToLowerInvariant()
  if ($width -lt 500 -or $height -lt 400) {
    throw "Chat window is too small or minimized. Restore the QQ or WeChat window and try again."
  }

  $leftRailWidth = if ($processName -match 'weixin|wechatappex') {
    [Math]::Max([int]($width * 0.24), 260)
  } elseif ($processName -match 'qq') {
    [Math]::Max([int]($width * 0.19), 250)
  } else {
    [Math]::Max([int]($width * 0.16), 210)
  }
  $contentX = if ($processName -match 'weixin|wechatappex') {
    $windowInfo.Left + [Math]::Min($leftRailWidth, [Math]::Max([int]($width * 0.25), 280))
  } else {
    $windowInfo.Left + [Math]::Min($leftRailWidth, [Math]::Max([int]($width * 0.24), 240))
  }
  $contentRightPadding = [Math]::Max([int]($width * 0.02), 20)
  $contentWidth = [Math]::Max($width - ($contentX - $windowInfo.Left) - $contentRightPadding, 320)

  $headerX = $contentX
  $headerY = $windowInfo.Top + 12
  $headerWidth = if ($processName -match 'weixin|wechatappex') {
    [Math]::Min([Math]::Max([int]($contentWidth * 0.56), 320), 520)
  } else {
    [Math]::Min([Math]::Max([int]($contentWidth * 0.62), 340), 560)
  }
  $headerHeight = [Math]::Min(108, [Math]::Max(72, [int]($height * 0.11)))

  $chatX = $contentX + 8
  $chatY = $windowInfo.Top + $headerHeight + 10
  $chatWidth = [Math]::Max($contentWidth - 16, 320)
  $chatHeight = [Math]::Max($height - $headerHeight - 154, 260)
  $laneWidth = [Math]::Min([Math]::Max([int]($chatWidth * 0.56), 420), 760)
  $leftLaneX = $chatX + 8
  $rightLaneX = $chatX + [Math]::Max($chatWidth - $laneWidth - 8, 0)

  $headerFile = Join-Path $env:TEMP ("renmai_capture_header_{0}.png" -f $tag)
  $chatFile = Join-Path $env:TEMP ("renmai_capture_chat_{0}.png" -f $tag)
  $chatLeftFile = Join-Path $env:TEMP ("renmai_capture_chat_left_{0}.png" -f $tag)
  $chatRightFile = Join-Path $env:TEMP ("renmai_capture_chat_right_{0}.png" -f $tag)
  $headerScaledFile = Join-Path $env:TEMP ("renmai_capture_header_scaled_{0}.png" -f $tag)
  $chatScaledFile = Join-Path $env:TEMP ("renmai_capture_chat_scaled_{0}.png" -f $tag)
  $chatLeftScaledFile = Join-Path $env:TEMP ("renmai_capture_chat_left_scaled_{0}.png" -f $tag)
  $chatRightScaledFile = Join-Path $env:TEMP ("renmai_capture_chat_right_scaled_{0}.png" -f $tag)

  Capture-RectToFile $headerX $headerY $headerWidth $headerHeight $headerFile
  Capture-RectToFile $chatX $chatY $chatWidth $chatHeight $chatFile
  Capture-RectToFile $leftLaneX $chatY $laneWidth $chatHeight $chatLeftFile
  Capture-RectToFile $rightLaneX $chatY $laneWidth $chatHeight $chatRightFile
  Resize-Image $headerFile $headerScaledFile 2.2
  Resize-Image $chatFile $chatScaledFile 1.8
  Resize-Image $chatLeftFile $chatLeftScaledFile 2.0
  Resize-Image $chatRightFile $chatRightScaledFile 2.0

  $headerText = Get-BestOcrText (Invoke-Ocr $headerFile) (Invoke-Ocr $headerScaledFile)
  $chatText = Get-MergedOcrText @(
    (Get-BestOcrText (Invoke-Ocr $chatFile) (Invoke-Ocr $chatScaledFile)),
    (Get-BestOcrText (Invoke-Ocr $chatLeftFile) (Invoke-Ocr $chatLeftScaledFile)),
    (Get-BestOcrText (Invoke-Ocr $chatRightFile) (Invoke-Ocr $chatRightScaledFile))
  )

  [pscustomobject]@{
    HeaderText = $headerText
    ChatText = $chatText
  }
}

try {
  if ($PrepareDelaySeconds -gt 0) {
    Start-Sleep -Seconds $PrepareDelaySeconds
  }

  $warnings = New-Object System.Collections.Generic.List[string]
  $foregroundInfo = Get-WindowInfo ([RenMaiCaptureNative]::GetForegroundWindow())
  $windowInfo = $foregroundInfo

  if ($null -eq $windowInfo -or
      ([string]$windowInfo.ProcessName).ToLowerInvariant() -match 'renmai' -or
      ([string]$windowInfo.Title).ToLowerInvariant() -match 'renmai' -or
      -not (Test-ChatWindowCandidate $windowInfo)) {
    $preferredWindow = Get-PreferredChatWindow $foregroundInfo
    if ($null -eq $preferredWindow) {
      throw 'No usable QQ or WeChat chat window was found. Open a real chat window that is showing messages and try again.'
    }
    $windowInfo = $preferredWindow
    Focus-Window $windowInfo
    $warnings.Add(("Connected to chat window: {0}" -f ([string]$windowInfo.Title).Trim()))
  }

  if ($null -eq $windowInfo) {
    throw 'No usable QQ or WeChat chat window was found. Open a real chat window that is showing messages and try again.'
  }

  $processName = ([string]$windowInfo.ProcessName).Trim()
  $title = ([string]$windowInfo.Title).Trim()

  if ($processName -match 'renmai' -or $title -match 'renmai') {
    throw 'RenMai is still in front. Open a real chat window and try again.'
  }

  if (-not (Test-ChatWindowCandidate $windowInfo)) {
    throw 'No usable QQ or WeChat chat window was found. Open a real chat window that is showing messages and try again.'
  }

  $captures = New-Object System.Collections.Generic.List[object]
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $duplicatePasses = 0
  $emptyPasses = 0
  $stoppedByRepeat = $false
  $stoppedBySparseText = $false

  for ($i = 0; $i -lt $PassCount; $i++) {
    Focus-Window $windowInfo
    $windowInfo = Get-WindowInfo $windowInfo.Handle
    if ($null -eq $windowInfo) { break }

    $capture = Get-WindowCapture $windowInfo $i
    $captureKey = (($capture.HeaderText + "`n" + $capture.ChatText).Trim() -replace '\s+', ' ')
    $chatLength = (($capture.ChatText ?? '').Trim()).Length
    if ($chatLength -lt 12) {
      $emptyPasses += 1
    } else {
      $emptyPasses = 0
    }

    if ($captureKey.Length -ge 20 -and $seen.Add($captureKey)) {
      $captures.Add($capture)
      $duplicatePasses = 0
    } else {
      $duplicatePasses += 1
    }

    if ($duplicatePasses -ge 4) {
      $stoppedByRepeat = $true
      break
    }
    if ($emptyPasses -ge 3) {
      $stoppedBySparseText = $true
      break
    }

    if ($i -lt ($PassCount - 1)) {
      [System.Windows.Forms.SendKeys]::SendWait('{PGUP}')
      Start-Sleep -Milliseconds $PauseMilliseconds
      [System.Windows.Forms.SendKeys]::SendWait('{PGUP}')
      Start-Sleep -Milliseconds ([Math]::Max([int]($PauseMilliseconds / 2), 220))
    }
  }

  if ($captures.Count -eq 0) {
    throw 'No usable chat text was recognized. Open the conversation area and try again.'
  }

  $ordered = @($captures.ToArray())
  [Array]::Reverse($ordered)

  $headerText = (($ordered | ForEach-Object { $_.HeaderText }) -join "`n").Trim()
  $text = (($ordered | ForEach-Object { $_.ChatText }) -join "`n`n").Trim()

  if ($text.Length -lt 20) {
    throw 'The chat window was found, but too little text was recognized. Scroll to visible messages and try again.'
  }

  if ($stoppedByRepeat) {
    $warnings.Add('已采集到历史尽头。')
  } elseif ($stoppedBySparseText) {
    $warnings.Add('新页文本过少，建议人工复核。')
  } elseif ($captures.Count -ge $PassCount) {
    $warnings.Add('达到安全上限，可继续追加。')
  } else {
    $warnings.Add('已完成多页采集，可根据需要继续追加。')
  }

  @{
    ok = $true
    process_name = $processName
    window_title = $title
    header_text = $headerText
    text = $text
    chunk_count = $captures.Count
    warnings = $warnings
  } | ConvertTo-Json -Depth 4 -Compress
} catch {
  @{
    ok = $false
    error = $_.Exception.Message
    warnings = @()
  } | ConvertTo-Json -Depth 3 -Compress
}
''';
