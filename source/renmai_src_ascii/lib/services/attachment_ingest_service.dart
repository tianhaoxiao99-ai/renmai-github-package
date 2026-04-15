import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/api_service.dart';

class AttachmentIngestResult {
  final ImportedPackage importedPackage;
  final List<ConversationRecord> records;
  final List<String> warnings;

  const AttachmentIngestResult({
    required this.importedPackage,
    required this.records,
    required this.warnings,
  });
}

class AttachmentIngestService {
  AttachmentIngestService._();

  static final AttachmentIngestService instance = AttachmentIngestService._();

  static const _textExtensions = {
    '.txt',
    '.md',
    '.markdown',
    '.csv',
    '.json',
    '.log',
  };

  static const _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.bmp',
    '.webp',
  };

  static const _audioExtensions = {
    '.mp3',
    '.wav',
    '.m4a',
    '.aac',
    '.opus',
    '.amr',
    '.ogg',
  };

  Future<AttachmentIngestResult> importForContact({
    required List<String> paths,
    required String contactId,
    required String contactName,
    required AiProviderConfig aiConfig,
  }) async {
    final warnings = <String>[];
    final records = <ConversationRecord>[];
    final packageId = 'attachment_${DateTime.now().millisecondsSinceEpoch}';
    var offset = 0;

    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) {
        warnings.add('已跳过不存在的附件：${p.basename(path)}');
        continue;
      }

      final ext = p.extension(path).toLowerCase();
      final basename = p.basename(path);
      try {
        if (_textExtensions.contains(ext)) {
          final content = await _readTextFile(file);
          if (content.trim().isEmpty) {
            warnings.add('已跳过空文本附件：$basename');
            continue;
          }
          records.add(
            _buildRecord(
              id: '${packageId}_$offset',
              packageId: packageId,
              contactId: contactId,
              contactName: contactName,
              sourceFile: file.path,
              messageType: 'file',
              content: '【文件摘录：$basename】\n${_clip(content, 2400)}',
              sentAt: DateTime.now().add(Duration(seconds: offset)),
            ),
          );
          offset++;
          continue;
        }

        if (_imageExtensions.contains(ext)) {
          final ocrText = await _extractImageText(file.path);
          final content = ocrText.trim().isEmpty
              ? '【图片：$basename】\n当前图片没有识别到明显文字。'
              : '【图片文字：$basename】\n${_clip(ocrText, 1800)}';
          if (ocrText.trim().isEmpty) {
            warnings.add('图片 $basename 没有识别到明显文字，已按图片记录导入。');
          }
          records.add(
            _buildRecord(
              id: '${packageId}_$offset',
              packageId: packageId,
              contactId: contactId,
              contactName: contactName,
              sourceFile: file.path,
              messageType: 'image',
              content: content,
              sentAt: DateTime.now().add(Duration(seconds: offset)),
            ),
          );
          offset++;
          continue;
        }

        if (_audioExtensions.contains(ext)) {
          if (!aiConfig.isReady) {
            warnings.add('语音 $basename 需要先在 AI 设置里配置可用接口，当前先跳过。');
            continue;
          }
          final transcript = await ApiService.instance.transcribeAudio(
            config: aiConfig,
            filePath: file.path,
          );
          records.add(
            _buildRecord(
              id: '${packageId}_$offset',
              packageId: packageId,
              contactId: contactId,
              contactName: contactName,
              sourceFile: file.path,
              messageType: 'voice',
              content: '【语音转写：$basename】\n${_clip(transcript, 2400)}',
              sentAt: DateTime.now().add(Duration(seconds: offset)),
            ),
          );
          offset++;
          continue;
        }

        warnings.add('暂不支持直接读取附件 $basename，当前支持文本、图片和常见语音格式。');
      } catch (error) {
        warnings.add('附件 $basename 读取失败：$error');
      }
    }

    if (records.isEmpty) {
      throw const FileSystemException('没有从附件里读取到可并入分析的内容。');
    }

    final package = ImportedPackage(
      id: packageId,
      source: 'attachment',
      originPaths: paths,
      discoveredFiles: paths,
      importedAt: DateTime.now(),
      status: 'completed',
      contactCount: 1,
      messageCount: records.length,
      packageSummary: '已补充 ${records.length} 条附件内容到 $contactName',
    );

    return AttachmentIngestResult(
      importedPackage: package,
      records: records,
      warnings: warnings,
    );
  }

  Future<String> extractImageText(String filePath) {
    return _extractImageText(filePath);
  }

  String clipText(String text, int maxLength) {
    return _clip(text, maxLength);
  }

  ConversationRecord _buildRecord({
    required String id,
    required String packageId,
    required String contactId,
    required String contactName,
    required String sourceFile,
    required String messageType,
    required String content,
    required DateTime sentAt,
  }) {
    final snippet =
        content.length > 80 ? '${content.substring(0, 80)}...' : content;
    return ConversationRecord(
      id: id,
      packageId: packageId,
      source: 'attachment',
      contactId: contactId,
      contactName: contactName,
      senderName: contactName,
      isSelf: false,
      sentAt: sentAt,
      content: content,
      messageType: messageType,
      evidenceSnippet: snippet,
      sourceFile: sourceFile,
    );
  }

  Future<String> _readTextFile(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  Future<String> _extractImageText(String filePath) async {
    if (!Platform.isWindows) {
      return '';
    }

    final scriptFile = await _ensureImageScriptFile();
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-ImagePath',
        filePath,
      ],
      runInShell: true,
    );

    final stdoutText = (result.stdout ?? '').toString().trim();
    if (result.exitCode != 0) {
      return '';
    }
    return stdoutText;
  }

  Future<File> _ensureImageScriptFile() async {
    final directory =
        Directory('${Directory.systemTemp.path}\\renmai_attachment_service');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}\\ocr_image.ps1');
    await file.writeAsString(_imageOcrScript, flush: true);
    return file;
  }

  String _clip(String text, int maxLength) {
    final normalized = text.trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...';
  }
}

const String _imageOcrScript = r'''
param(
  [Parameter(Mandatory = $true)]
  [string]$ImagePath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
$null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime]

function Await-AsyncOperation([object]$op, [Type]$resultType) {
  $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
    Select-Object -First 1
  $generic = $method.MakeGenericMethod($resultType)
  $task = $generic.Invoke($null, @($op))
  return $task.GetAwaiter().GetResult()
}

try {
  $storageFile = Await-AsyncOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)) ([Windows.Storage.StorageFile])
  $stream = Await-AsyncOperation ($storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await-AsyncOperation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await-AsyncOperation ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $ocr = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  $result = Await-AsyncOperation ($ocr.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
  $result.Text
} catch {
  ''
}
''';
