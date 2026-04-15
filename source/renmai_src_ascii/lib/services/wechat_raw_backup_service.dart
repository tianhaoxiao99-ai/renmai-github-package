import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/services/api_service.dart';
import 'package:renmai/services/attachment_ingest_service.dart';

typedef WeChatRawProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell,
});

typedef WeChatImageTextExtractor = Future<String> Function(String filePath);
typedef WeChatAudioTranscriber = Future<String> Function(
  AiProviderConfig config,
  String filePath,
);

class WeChatRawBackupImportResult {
  final List<ConversationRecord> records;
  final List<String> warnings;
  final List<String> discoveredFiles;
  final List<String> matchedAccountRoots;

  const WeChatRawBackupImportResult({
    required this.records,
    required this.warnings,
    required this.discoveredFiles,
    required this.matchedAccountRoots,
  });
}

class _WeChatRecordEnrichmentResult {
  final List<ConversationRecord> records;
  final List<String> warnings;

  const _WeChatRecordEnrichmentResult({
    required this.records,
    required this.warnings,
  });
}

class WeChatRawBackupService {
  WeChatRawBackupService({
    WeChatRawProcessRunner? processRunner,
    WeChatImageTextExtractor? imageTextExtractor,
    WeChatAudioTranscriber? audioTranscriber,
  })  : _processRunner = processRunner ?? _defaultProcessRunner,
        _imageTextExtractor = imageTextExtractor ??
            AttachmentIngestService.instance.extractImageText,
        _audioTranscriber = audioTranscriber ??
            ((config, filePath) => ApiService.instance.transcribeAudio(
                  config: config,
                  filePath: filePath,
                ));

  static final WeChatRawBackupService instance = WeChatRawBackupService();

  final WeChatRawProcessRunner _processRunner;
  final WeChatImageTextExtractor _imageTextExtractor;
  final WeChatAudioTranscriber _audioTranscriber;

  static const Set<String> _nonAccountDirectoryNames = {
    'all_users',
    'backup',
    'cache',
    'config',
    'logs',
    'temp',
    'tmp',
  };

  List<String> resolveExplicitBackupSelections(List<String> paths) {
    final roots = <String>{};

    for (final rawPath in paths) {
      final trimmed = rawPath.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final explicitRoot = _findAccountRoot(trimmed);
      if (explicitRoot != null) {
        roots.add(explicitRoot);
        continue;
      }

      final directory = Directory(trimmed);
      if (!directory.existsSync()) {
        continue;
      }

      if (_looksLikeBackupRoot(directory.path)) {
        for (final child in directory.listSync(followLinks: false)) {
          if (child is! Directory) {
            continue;
          }
          if (_isAccountRoot(child.path)) {
            roots.add(p.normalize(child.path));
          }
        }
      }
    }

    return roots.toList()..sort();
  }

  bool looksLikeExplicitBackupSelection(List<String> paths) {
    return resolveExplicitBackupSelections(paths).isNotEmpty;
  }

  Future<WeChatRawBackupImportResult?> importFromSelections(
    List<String> paths, {
    required String packageId,
    AiProviderConfig aiConfig = const AiProviderConfig(),
    bool enrichAttachments = false,
  }) async {
    final accountRoots = resolveExplicitBackupSelections(paths);
    if (accountRoots.isEmpty) {
      return null;
    }

    final scriptFile = _locateHelperScript();
    if (scriptFile == null) {
      throw FileSystemException(
        _describeImportFailure('缺少微信原始备份解析脚本，无法直接读取 xwechat_files 目录。'),
      );
      // ignore: dead_code
      throw FileSystemException(
        _describeImportFailure('缺少微信原始备份解析脚本，无法直接读取 xwechat_files 目录。'),
      );
    }

    final payloadDirectory =
        await Directory.systemTemp.createTemp('renmai-wechat-raw-');
    final outputFile = File(p.join(payloadDirectory.path, '$packageId.json'));
    final mediaOutputDir = enrichAttachments
        ? Directory(p.join(payloadDirectory.path, 'media'))
        : null;

    final arguments = <String>[
      scriptFile.path,
      '--package-id',
      packageId,
      '--output-file',
      outputFile.path,
      '--quiet',
      ...accountRoots.expand((item) => ['--account-root', item]),
    ];
    if (mediaOutputDir != null) {
      arguments.insertAll(
        5,
        [
          '--media-output-dir',
          mediaOutputDir.path,
        ],
      );
    }

    try {
      Map<String, dynamic>? payload;
      var stdoutText = '';
      var stderrText = '';

      final result = await _runPython(arguments);
      stdoutText = (result.stdout ?? '').toString().trim();
      stderrText = (result.stderr ?? '').toString().trim();
      payload = await _loadPayload(
        outputFile: outputFile,
        stdoutText: stdoutText,
      );

      // ignore: unnecessary_null_comparison
      if (payload == null) {
        final detail = stderrText.isNotEmpty ? stderrText : stdoutText;
        throw FileSystemException(
          _describeImportFailure(
            detail.isEmpty
                ? '读取微信原始备份失败，辅助解析脚本没有返回可识别结果。'
                : '读取微信原始备份失败：$detail',
          ),
        );
      }

      if (payload['ok'] != true) {
        final error = (payload['error'] ?? '').toString().trim();
        if (error.isNotEmpty) {
          throw FileSystemException(_describeImportFailure(error));
        }
        throw FileSystemException(
          _describeImportFailure('读取微信原始备份失败，未能提取出可用聊天记录。'),
        );
      }

      // ignore: unnecessary_null_comparison
      if (payload == null) {
        final detail = stderrText.isNotEmpty ? stderrText : stdoutText;
        throw FileSystemException(
          _describeImportFailure(
            detail.isEmpty
                ? '读取微信原始备份失败，辅助解析脚本没有返回可识别结果。'
                : '读取微信原始备份失败：$detail',
          ),
        );
      }

      if (payload['ok'] != true) {
        final error = (payload['error'] ?? '').toString().trim();
        if (error.isNotEmpty) {
          throw FileSystemException(_describeImportFailure(error));
        }
        throw FileSystemException(
          _describeImportFailure('读取微信原始备份失败，未能提取出可用聊天记录。'),
        );
      }

      final recordsJson = (payload['records'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final parsedRecords =
          recordsJson.map(ConversationRecord.fromJson).toList();
      final warnings = (payload['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
      final discoveredFiles =
          (payload['discovered_files'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
      final matchedAccountRoots =
          (payload['matched_account_roots'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList();
      final shouldEnrichAttachments =
          enrichAttachments && _hasAttachmentCandidates(parsedRecords);
      final enrichment = shouldEnrichAttachments
          ? await _enrichRecords(
              parsedRecords,
              aiConfig: aiConfig,
            )
          : _WeChatRecordEnrichmentResult(
              records: parsedRecords,
              warnings: _buildDeferredEnrichmentWarnings(parsedRecords),
            );

      return WeChatRawBackupImportResult(
        records: enrichment.records,
        warnings: {
          ...warnings,
          ...enrichment.warnings,
        }.toList(),
        discoveredFiles: discoveredFiles,
        matchedAccountRoots: matchedAccountRoots,
      );
    } finally {
      if (payloadDirectory.existsSync()) {
        try {
          await payloadDirectory.delete(recursive: true);
        } catch (_) {
          // Best-effort temp cleanup: do not fail a completed import flow.
        }
      }
    }
  }

  bool _hasAttachmentCandidates(List<ConversationRecord> records) {
    for (final record in records) {
      if (record.attachmentPath.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<String> _buildDeferredEnrichmentWarnings(
    List<ConversationRecord> records,
  ) {
    var hasImageLike = false;
    var hasVoice = false;

    for (final record in records) {
      if (record.messageType == 'image' || record.messageType == 'emoji') {
        hasImageLike = true;
      } else if (record.messageType == 'voice') {
        hasVoice = true;
      }

      if (hasImageLike && hasVoice) {
        break;
      }
    }

    if (!hasImageLike && !hasVoice) {
      return const [];
    }

    final parts = <String>[];
    if (hasImageLike) {
      parts.add('图片文字识别');
    }
    if (hasVoice) {
      parts.add('语音转写');
    }

    return [
      '本次直读已优先完成聊天文本导入，${parts.join('和')}暂未在导入阶段同步执行；如需补充，可在导入完成后按需使用附件补充入口。',
    ];
  }

  Future<_WeChatRecordEnrichmentResult> _enrichRecords(
    List<ConversationRecord> records, {
    required AiProviderConfig aiConfig,
  }) async {
    final warnings = <String>[];
    final enriched = <ConversationRecord>[];
    var warnedMissingAiForVoice = false;

    for (final record in records) {
      final attachmentPath = record.attachmentPath.trim();
      if (attachmentPath.isEmpty) {
        enriched.add(record.copyWith(attachmentPath: ''));
        continue;
      }

      final file = File(attachmentPath);
      if (!file.existsSync()) {
        enriched.add(record.copyWith(attachmentPath: ''));
        continue;
      }

      var content = record.content.trim();
      try {
        if (record.messageType == 'image' || record.messageType == 'emoji') {
          final extractedText = (await _imageTextExtractor(file.path)).trim();
          if (extractedText.isNotEmpty) {
            content = _appendExtractedText(
              content,
              record.messageType == 'emoji' ? '表情内容识别' : '图片文字识别',
              extractedText,
              maxLength: 1800,
            );
          }
        } else if (record.messageType == 'voice') {
          if (!aiConfig.isReady) {
            if (!warnedMissingAiForVoice) {
              warnings.add(
                '检测到语音消息，但当前还没有配置可用的 AI 转写接口，因此先保留语音占位内容。',
              );
              warnedMissingAiForVoice = true;
            }
          } else {
            final transcript =
                (await _audioTranscriber(aiConfig, file.path)).trim();
            if (transcript.isNotEmpty) {
              content = _appendExtractedText(
                content,
                '语音转写',
                transcript,
                maxLength: 2400,
              );
            }
          }
        }
      } catch (error) {
        warnings.add('${p.basename(file.path)} 读取失败：$error');
      }

      enriched.add(
        record.copyWith(
          content: content,
          evidenceSnippet: _clip(content, 96),
          attachmentPath: '',
        ),
      );
    }

    return _WeChatRecordEnrichmentResult(
      records: enriched,
      warnings: warnings,
    );
  }

  String _appendExtractedText(
    String baseContent,
    String label,
    String extractedText, {
    required int maxLength,
  }) {
    final trimmedBase = baseContent.trim();
    final trimmedExtracted = _clip(extractedText.trim(), maxLength);
    if (trimmedExtracted.isEmpty) {
      return trimmedBase;
    }
    if (trimmedBase.isEmpty) {
      return '【$label】\n$trimmedExtracted';
    }
    if (trimmedBase.contains(trimmedExtracted)) {
      return trimmedBase;
    }
    return '$trimmedBase\n\n【$label】\n$trimmedExtracted';
  }

  String _clip(String text, int maxLength) {
    return AttachmentIngestService.instance.clipText(text, maxLength);
  }

  Future<Map<String, dynamic>?> _loadPayload({
    required File outputFile,
    required String stdoutText,
  }) async {
    if (outputFile.existsSync()) {
      final fileText = await outputFile.readAsString();
      final decoded = await _tryDecodeJsonMap(fileText);
      if (decoded != null) {
        return decoded;
      }
    }

    if (stdoutText.isEmpty) {
      return null;
    }

    return _tryDecodeJsonMap(stdoutText);
  }

  Future<Map<String, dynamic>?> _tryDecodeJsonMap(String source) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return await Isolate.run(
        () => jsonDecode(trimmed) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  String? _findAccountRoot(String rawPath) {
    final normalized = p.normalize(rawPath);
    final entityType = FileSystemEntity.typeSync(normalized);
    if (entityType == FileSystemEntityType.notFound) {
      return null;
    }

    var current = entityType == FileSystemEntityType.directory
        ? normalized
        : p.dirname(normalized);
    for (var depth = 0; depth < 8; depth++) {
      if (_isAccountRoot(current)) {
        return p.normalize(current);
      }
      final parent = p.dirname(current);
      if (parent == current) {
        break;
      }
      current = parent;
    }
    return null;
  }

  bool _isAccountRoot(String path) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return false;
    }
    final basename = p.basename(path).toLowerCase();
    if (_nonAccountDirectoryNames.contains(basename)) {
      return false;
    }
    return Directory(p.join(path, 'db_storage')).existsSync();
  }

  bool _looksLikeBackupRoot(String path) {
    final normalized = p.normalize(path).toLowerCase();
    return normalized.endsWith('${p.separator}xwechat_files') ||
        normalized.endsWith('${p.separator}wechat files');
  }

  File? _locateHelperScript() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final roots = <String>{
      Directory.current.path,
      executableDir.path,
      p.dirname(executableDir.path),
      p.dirname(p.dirname(executableDir.path)),
      p.dirname(p.dirname(p.dirname(executableDir.path))),
      p.dirname(p.dirname(p.dirname(p.dirname(executableDir.path)))),
      p.dirname(
        p.dirname(p.dirname(p.dirname(p.dirname(executableDir.path)))),
      ),
    };

    for (final root in roots) {
      final candidate = File(p.join(root, 'scripts', 'wechat_raw_import.py'));
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Future<ProcessResult> _runPython(List<String> arguments) async {
    final attempts = <({
      String executable,
      List<String> args,
      String? workingDirectory,
      bool runInShell
    })>[
      ..._bundledPythonAttempts(arguments),
      (
        executable: 'python',
        args: arguments,
        workingDirectory: null,
        runInShell: true,
      ),
      (
        executable: 'py',
        args: ['-3', ...arguments],
        workingDirectory: null,
        runInShell: true,
      ),
    ];

    ProcessResult? lastResult;
    Object? lastError;

    for (final attempt in attempts) {
      try {
        final result = await _processRunner(
          attempt.executable,
          attempt.args,
          workingDirectory: attempt.workingDirectory,
          runInShell: attempt.runInShell,
        );
        final stdoutText = (result.stdout ?? '').toString().trim();
        if (result.exitCode == 0 || _looksLikeJsonPayload(stdoutText)) {
          return result;
        }
        lastResult = result;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastResult != null) {
      return lastResult;
    }
    throw FileSystemException(
      _describeImportFailure(
        lastError == null
            ? '系统没有可用的 Python 运行环境，无法读取微信原始备份。'
            : '系统没有可用的 Python 运行环境，无法读取微信原始备份：$lastError',
      ),
    );
    // ignore: dead_code
    throw FileSystemException(
      _describeImportFailure(
        lastError == null
            ? '系统没有可用的 Python 运行环境，无法读取微信原始备份。'
            : '系统没有可用的 Python 运行环境，无法读取微信原始备份：$lastError',
      ),
    );
  }

  bool _looksLikeJsonPayload(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('{') && trimmed.endsWith('}');
  }

  String _describeImportFailure(String rawMessage) {
    final message = rawMessage.trim();
    final lower = message.toLowerCase();
    if (message.contains('缺少微信原始备份解析脚本')) {
      return '当前这个运行包没有带“直读微信本地数据库”组件，所以暂时不能直接读取 xwechat_files。普通用户不用自己改文件，直接改用“扫描导出记录”或“选择记录文件”即可；如果一定要直读 xwechat_files，请换带完整直读组件的安装包。';
    }
    if (message.contains('缺少 Python 依赖 Cryptodome') ||
        lower.contains("no module named 'cryptodome'") ||
        lower.contains('cryptodome')) {
      return '当前电脑缺少“直读微信本地数据库”所需组件，所以这次无法直接读取 xwechat_files。普通用户不用自己安装 Python 环境，建议直接改用“扫描导出记录”或“选择记录文件”；如果你必须直读本地数据库，请换带完整运行环境的安装包。';
    }
    if (message.contains('message_') &&
        (message.contains('解密 key') || lower.contains('key'))) {
      return '这份微信备份里的消息库没有拿到完整解密 key。通常是因为当前登录微信账号与所选备份不一致，或者微信没有保持登录。请确认选中的是当前账号对应的 xwechat_files，并在电脑微信保持登录时重试。';
    }
    if (message.contains('解密校验失败') ||
        message.contains('数据库解密校验失败')) {
      return '微信数据库解密校验失败，当前拿到的 key 与这份备份不匹配。请确认账号目录正确，并在电脑微信保持登录后重试。';
    }
    if (message.startsWith('读取微信原始备份失败：Traceback')) {
      return '读取微信原始备份失败。底层脚本抛出了未收口异常，请换新的发布包后重试。';
    }

    if (message.contains('缺少微信原始备份解析脚本')) {
      return '当前这个运行版没有带“直读微信本地数据库”组件，所以暂时不能直接读取 xwechat_files。普通用户不用自己改文件，直接改用“扫描导出记录”或“选择记录文件”即可；如果一定要直读 xwechat_files，请换带完整直读组件的安装包。';
    }

    if (message.contains('缺少 Python 依赖 Cryptodome') ||
        lower.contains("no module named 'cryptodome'") ||
        lower.contains('cryptodome')) {
      return '当前电脑缺少“直读微信本地数据库”所需组件，所以这次无法直接读取 xwechat_files。普通用户不用自己安装 Python 环境，建议直接改用“扫描导出记录”或“选择记录文件”；如果你必须直读本地数据库，请换带完整运行环境的安装包。';
    }

    if (lower.contains('python') &&
        (message.contains('没有可用的 Python 运行环境') ||
            lower.contains('python was not found') ||
            lower.contains('not recognized') ||
            lower.contains('no module named'))) {
      return '当前电脑缺少“直读微信本地数据库”所需运行环境，所以这次无法直接读取 xwechat_files。普通用户不用自己手动配置环境，建议直接改用“扫描导出记录”或“选择记录文件”；如果你必须直读本地数据库，请换带完整运行环境的安装包。';
    }

    return message;
  }

  List<
      ({
        String executable,
        List<String> args,
        String? workingDirectory,
        bool runInShell
      })> _bundledPythonAttempts(List<String> arguments) {
    final attempts = <({
      String executable,
      List<String> args,
      String? workingDirectory,
      bool runInShell
    })>[];
    final searchRoots = _resolveRuntimeRoots();
    final seen = <String>{};

    for (final root in searchRoots) {
      for (final candidate in <String>[
        p.join(root, 'python.cmd'),
        p.join(root, 'python.bat'),
        p.join(root, 'py.cmd'),
        p.join(root, 'py.bat'),
      ]) {
        final normalized = p.normalize(candidate);
        if (!File(normalized).existsSync() || !seen.add(normalized)) {
          continue;
        }
        final basename = p.basename(normalized).toLowerCase();
        attempts.add((
          executable: normalized,
          args: basename.startsWith('py.') ? ['-3', ...arguments] : arguments,
          workingDirectory: root,
          runInShell: true,
        ));
      }
    }

    return attempts;
  }

  List<String> _resolveRuntimeRoots() {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final roots = <String>{
      Directory.current.path,
      executableDir,
      p.dirname(executableDir),
      p.dirname(p.dirname(executableDir)),
      p.dirname(p.dirname(p.dirname(executableDir))),
      p.dirname(p.dirname(p.dirname(p.dirname(executableDir)))),
      p.dirname(p.dirname(p.dirname(p.dirname(p.dirname(executableDir))))),
    };

    return roots.map(p.normalize).toList();
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      environment: const {
        'PYTHONIOENCODING': 'utf-8',
        'PYTHONUTF8': '1',
      },
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }
}
