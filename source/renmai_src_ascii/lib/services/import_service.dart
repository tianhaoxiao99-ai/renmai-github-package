import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/wechat_raw_backup_service.dart';

const _discoveryHints = <String>[
  'wechat',
  'weixin',
  '微信',
  'qq',
  'tencent files',
  'xwechat_files',
  '聊天',
  '记录',
  '导出',
  'export',
  'backup',
  'message',
  'chat',
];

const _conversationHints = <String>[
  '聊天记录',
  '消息记录',
  '聊天',
  '记录',
  'conversation',
  'message',
  'chat',
  '导出',
  'export',
  '微信',
  'qq',
];

const _ignoredDirectoryNames = <String>{
  '.git',
  '.dart_tool',
  'build',
  'cache',
  'caches',
  'code cache',
  'logs',
  'node_modules',
  'tmp',
  'tempfiles',
};

const _technicalNameTokens = <String>{
  'flutter',
  'doctor',
  'repair',
  'config',
  'adminregionconfig',
  'extract',
  'debug',
  'output',
  'schema',
  'build',
  'cache',
  'package',
  'region',
  'temp',
  'tmp',
  'ppt',
  'cached',
  'promo',
  'http',
  'https',
  'www',
  'folders',
  'folder',
  'files',
  'file',
  'documents',
  'document',
  'source',
  'generated',
  'msg',
  'zip',
  'test',
  'data',
  'backup',
  'desktop',
  'downloads',
  'users',
  'administrator',
  'appdata',
  'local',
  'roaming',
  'program',
  'system',
  'windows',
  'xwechat',
  'wxid',
  'main',
  'plugin',
  'module',
  'asset',
  'assets',
  'resource',
  'resources',
  'log',
  'metadata',
  'manifest',
  'index',
  'default',
  'null',
  'undefined',
  'string',
  'object',
};

const _genericPlaceholderNames = <String>{
  'new',
  'untitled',
  'textdocument',
  'person',
  '新建文本文档',
  '文本文档',
  '新建文件夹',
  '未命名',
  '新建联系人',
  '测试联系人',
  '默认联系人',
};

class ImportSessionData {
  final ImportedPackage importedPackage;
  final List<ConversationRecord> records;
  final List<String> warnings;

  const ImportSessionData({
    required this.importedPackage,
    required this.records,
    this.warnings = const [],
  });
}

class AutoImportDiscovery {
  final List<String> importablePaths;
  final List<String> checkedRoots;
  final List<String> warnings;
  final bool foundWeChatLocalBackup;
  final bool foundQqLocalBackup;

  const AutoImportDiscovery({
    required this.importablePaths,
    required this.checkedRoots,
    required this.warnings,
    this.foundWeChatLocalBackup = false,
    this.foundQqLocalBackup = false,
  });

  bool get hasImportablePaths => importablePaths.isNotEmpty;

  String buildFailureMessage() {
    if (foundWeChatLocalBackup) {
      return '检测到微信本地备份目录。你可以手动选择 xwechat_files 或账号目录尝试直读原始数据库；如果微信当前未登录，仍建议优先导入 .txt / .html / .zip 聊天导出文件。';
    }
    if (foundQqLocalBackup) {
      return '检测到 QQ 本地目录，但当前版本只能读取可直接查看的 .txt / .html / .zip 聊天导出文件。';
    }
    return '没有在常见位置找到可导入的聊天记录。请优先选择 .txt / .html / .zip 聊天导出文件。';
  }
}

class _CollectedFilesResult {
  final List<File> files;
  final List<String> warnings;
  final bool foundWeChatLocalBackup;
  final bool foundQqLocalBackup;

  const _CollectedFilesResult({
    required this.files,
    required this.warnings,
    this.foundWeChatLocalBackup = false,
    this.foundQqLocalBackup = false,
  });
}

class _ZipExtractResult {
  final List<File> files;
  final List<String> warnings;

  const _ZipExtractResult({
    required this.files,
    required this.warnings,
  });
}

class _ImportabilityAssessment {
  final bool shouldImport;

  const _ImportabilityAssessment({required this.shouldImport});
}

class _PendingDirectory {
  final Directory directory;
  final int depth;
  final bool hinted;

  const _PendingDirectory({
    required this.directory,
    required this.depth,
    required this.hinted,
  });
}

class _ContactProfile {
  final String contactId;
  final String contactName;
  final Set<String> comparableNames;

  const _ContactProfile({
    required this.contactId,
    required this.contactName,
    required this.comparableNames,
  });
}

class ImportService {
  ImportService({
    WeChatRawBackupService? weChatRawBackupService,
  }) : _weChatRawBackupService =
            weChatRawBackupService ?? WeChatRawBackupService.instance;

  static final ImportService instance = ImportService();

  final WeChatRawBackupService _weChatRawBackupService;

  List<ConversationRecord> sanitizeRecords(
      Iterable<ConversationRecord> source) {
    final grouped = <String, List<ConversationRecord>>{};
    for (final record in source) {
      grouped
          .putIfAbsent(record.contactId, () => <ConversationRecord>[])
          .add(record);
    }

    final results = <ConversationRecord>[];
    for (final group in grouped.values) {
      final resolvedContactName = _resolveContactName(
        group.first.contactName,
        group,
      );
      if (!_looksLikeHumanReadableName(resolvedContactName)) {
        continue;
      }

      final resolvedContactId = _normalizeContactId(resolvedContactName);
      if (resolvedContactId.isEmpty) {
        continue;
      }

      for (final record in group) {
        final normalizedSender = record.isSelf
            ? '我'
            : _normalizeDisplayName(record.senderName).trim().isEmpty
                ? resolvedContactName
                : _extractFriendlyBaseName(
                    _normalizeDisplayName(record.senderName));
        final evidenceSnippet = record.content.length > 60
            ? '${record.content.substring(0, 60)}...'
            : record.content;
        results.add(
          record.copyWith(
            contactId: resolvedContactId,
            contactName: resolvedContactName,
            senderName: normalizedSender,
            isSelf: record.isSelf || _isSelfSender(normalizedSender),
            evidenceSnippet: evidenceSnippet,
          ),
        );
      }
    }

    return _deduplicate(
        results.where((r) => !_isGarbageMessageContent(r.content)).toList());
  }

  /// 识别消息内容是否为垃圾（文件路径、zip 元数据、纯技术标识等）
  bool _isGarbageMessageContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return true;

    // 整条消息是 Windows/Unix 文件路径
    if (RegExp(r'^[A-Za-z]:\\', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^/(?:Users|home|var|tmp|opt)/', caseSensitive: false)
            .hasMatch(trimmed)) {
      return true;
    }

    // 整条消息是带扩展名的文件名
    if (RegExp(
            r'^[\w\-. ()]+\.(zip|txt|html|htm|csv|json|xml|db|sqlite|exe|dll|log|bak|dat|cfg|ini)$',
            caseSensitive: false)
        .hasMatch(trimmed)) {
      return true;
    }

    // zip 元数据标签开头
    final lowerTrimmed = trimmed.toLowerCase();
    if (lowerTrimmed.startsWith('source test zip') ||
        lowerTrimmed.startsWith('source main zip') ||
        lowerTrimmed.startsWith('generated at') ||
        lowerTrimmed.startsWith('created at') ||
        lowerTrimmed.startsWith('modified at') ||
        lowerTrimmed.startsWith('extracted from')) {
      return true;
    }

    // 内容主体是文件路径（多行中超迀 60% 是路径）
    final lines = trimmed.split('\n');
    if (lines.length >= 2) {
      final pathLines = lines.where((l) {
        final lt = l.trim();
        return RegExp(r'^[A-Za-z]:\\').hasMatch(lt) ||
            RegExp(r'^/(?:Users|home)/').hasMatch(lt) ||
            RegExp(r'\\[\w]+\\[\w]+\\').hasMatch(lt);
      }).length;
      if (pathLines / lines.length > 0.6) {
        return true;
      }
    }

    return false;
  }

  List<ConversationRecord> alignImportedRecordsToWorkspace({
    required List<ConversationRecord> existingRecords,
    required List<ConversationRecord> importedRecords,
    String? preferredContactId,
    String? lockedContactName,
  }) {
    if (existingRecords.isEmpty || importedRecords.isEmpty) {
      return importedRecords;
    }

    final profiles = _buildContactProfiles(existingRecords);
    if (profiles.isEmpty) {
      return importedRecords;
    }

    final grouped = <String, List<ConversationRecord>>{};
    for (final record in importedRecords) {
      grouped
          .putIfAbsent(record.contactId, () => <ConversationRecord>[])
          .add(record);
    }

    final aligned = <ConversationRecord>[];
    for (final group in grouped.values) {
      final target = _matchImportedGroupToExistingContact(
        group: group,
        profiles: profiles,
        preferredContactId: preferredContactId,
        lockedContactName: lockedContactName,
      );
      if (target == null) {
        aligned.addAll(group);
        continue;
      }

      for (final record in group) {
        aligned.add(
          record.copyWith(
            contactId: target.contactId,
            contactName: target.contactName,
          ),
        );
      }
    }

    return aligned;
  }

  Future<ImportSessionData> importPaths(
    List<String> paths, {
    List<String> presetWarnings = const [],
    bool strictContentFilter = false,
    AiProviderConfig aiConfig = const AiProviderConfig(),
  }) async {
    final packageId = 'pkg_${DateTime.now().millisecondsSinceEpoch}';
    final warnings = <String>[...presetWarnings];
    final prefersRawBackup =
        _weChatRawBackupService.looksLikeExplicitBackupSelection(paths);
    final onlyRawBackupSelections =
        prefersRawBackup && _containsOnlyRawBackupSelections(paths);
    String? rawFailureMessage;

    if (prefersRawBackup) {
      try {
        final rawResult = await _weChatRawBackupService.importFromSelections(
          paths,
          packageId: packageId,
          aiConfig: aiConfig,
        );
        if (rawResult != null) {
          final deduped = _deduplicate(rawResult.records);
          if (deduped.isNotEmpty) {
            final contactCount =
                deduped.map((item) => item.contactId).toSet().length;
            return ImportSessionData(
              importedPackage: ImportedPackage(
                id: packageId,
                source: 'wechat',
                originPaths: paths,
                discoveredFiles: rawResult.discoveredFiles,
                importedAt: DateTime.now(),
                status: 'completed',
                contactCount: contactCount,
                messageCount: deduped.length,
                packageSummary:
                    '已从微信本地原始备份识别 $contactCount 位联系人，共 ${deduped.length} 条有效消息。',
              ),
              records: deduped,
              warnings: {
                ...warnings,
                ...rawResult.warnings,
              }.toList(),
            );
          }
        }
      } on FileSystemException catch (error) {
        rawFailureMessage =
            error.message.isEmpty ? '微信原始备份直读失败。' : error.message;
        warnings.add(rawFailureMessage);
      }

      if (rawFailureMessage != null && onlyRawBackupSelections) {
        throw FileSystemException(rawFailureMessage);
      }
    }

    final collected = await _collectSupportedFiles(paths);
    final discoveredFiles = collected.files;
    warnings.addAll(collected.warnings);
    var hasReadableText = false;
    var skippedNonChatFiles = 0;

    if (discoveredFiles.isEmpty) {
      throw FileSystemException(
        _emptyImportMessage(
          foundWeChatLocalBackup: collected.foundWeChatLocalBackup,
          foundQqLocalBackup: collected.foundQqLocalBackup,
          rawAttempted: prefersRawBackup,
          rawFailureMessage: rawFailureMessage,
        ),
      );
    }

    final records = <ConversationRecord>[];
    final sourceTypes = <String>{};

    for (final file in discoveredFiles) {
      final text = await _readNormalizedText(file);
      if (text.trim().isEmpty) {
        continue;
      }
      hasReadableText = true;

      final assessment = _evaluateReadableText(
        sourceFile: file.path,
        text: text,
        strict: strictContentFilter,
      );
      if (!assessment.shouldImport) {
        skippedNonChatFiles += 1;
        continue;
      }

      final source = _detectSource(file.path, text);
      sourceTypes.add(source);
      final parsed = _parseConversationText(
        packageId: packageId,
        source: source,
        sourceFile: file.path,
        text: text,
        allowFallback: !strictContentFilter,
      );
      if (parsed.isEmpty) {
        skippedNonChatFiles += 1;
        continue;
      }

      records.addAll(parsed);
    }

    if (skippedNonChatFiles > 0) {
      warnings.add('已自动跳过 $skippedNonChatFiles 个不像聊天记录的文件。');
    }

    final deduped = _deduplicate(records);
    if (!hasReadableText) {
      throw const FileSystemException('选中的文件里没有可读取的文本内容。');
    }
    if (deduped.isEmpty) {
      throw FileSystemException(
        _emptyImportMessage(
          foundWeChatLocalBackup: collected.foundWeChatLocalBackup,
          foundQqLocalBackup: collected.foundQqLocalBackup,
          noChatLikeText: true,
          rawAttempted: prefersRawBackup,
          rawFailureMessage: rawFailureMessage,
        ),
      );
    }

    final contactCount = deduped.map((item) => item.contactId).toSet().length;
    final sourceLabel = sourceTypes.isEmpty
        ? 'unknown'
        : (sourceTypes.length == 1 ? sourceTypes.first : 'mixed');

    final importedPackage = ImportedPackage(
      id: packageId,
      source: sourceLabel,
      originPaths: paths,
      discoveredFiles: discoveredFiles.map((item) => item.path).toList(),
      importedAt: DateTime.now(),
      status: 'completed',
      contactCount: contactCount,
      messageCount: deduped.length,
      packageSummary:
          '已识别 $contactCount 位联系人，共 ${deduped.length} 条有效消息，来源：${_sourceLabel(sourceLabel)}。',
    );

    return ImportSessionData(
      importedPackage: importedPackage,
      records: deduped,
      warnings: warnings.toSet().toList(),
    );
  }

  Future<ImportSessionData> importPlainText(
    String text, {
    String sourceFile = 'clipboard_import.txt',
    String? lockedContactName,
    List<String> presetWarnings = const [],
  }) async {
    final packageId = 'pkg_${DateTime.now().millisecondsSinceEpoch}';
    final normalizedText =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalizedText.isEmpty) {
      throw const FileSystemException('剪贴板里还没有可导入的聊天文本。');
    }

    final assessment = _evaluateReadableText(
      sourceFile: sourceFile,
      text: normalizedText,
      strict: false,
    );
    final hasLockedContactName = (lockedContactName ?? '').trim().isNotEmpty;
    final looksLikeWindowCapture =
        sourceFile.toLowerCase().contains('window_capture') ||
            normalizedText.contains('聊天记录：') ||
            normalizedText.contains('聊天记录:');
    if (!assessment.shouldImport &&
        !hasLockedContactName &&
        !looksLikeWindowCapture) {
      throw const FileSystemException('剪贴板内容不像聊天记录，请先复制聊天文本。');
    }

    final source = _detectSource(sourceFile, normalizedText);
    final parsed = _parseConversationText(
      packageId: packageId,
      source: source,
      sourceFile: sourceFile,
      text: normalizedText,
      lockedContactName: lockedContactName,
    );
    final deduped = _deduplicate(parsed);
    if (deduped.isEmpty) {
      throw const FileSystemException('聊天文本已读取，但还没有识别出可用的聊天记录。');
    }

    final importedPackage = ImportedPackage(
      id: packageId,
      source: source,
      originPaths: const ['clipboard://text'],
      discoveredFiles: const ['clipboard://text'],
      importedAt: DateTime.now(),
      status: 'completed',
      contactCount: deduped.map((item) => item.contactId).toSet().length,
      messageCount: deduped.length,
      packageSummary:
          '已从剪贴板识别出 ${deduped.map((item) => item.contactId).toSet().length} 位联系人，共 ${deduped.length} 条有效消息。',
    );

    return ImportSessionData(
      importedPackage: importedPackage,
      records: deduped,
      warnings: presetWarnings.toSet().toList(),
    );
  }

  Future<AutoImportDiscovery> discoverAutoImportPaths({
    String? userHomeOverride,
  }) async {
    final roots = _buildDiscoveryRoots(userHomeOverride: userHomeOverride);
    final importablePaths = <String>{};
    final warnings = <String>[];
    final checkedRoots = <String>[];
    var foundWeChatLocalBackup = false;
    var foundQqLocalBackup = false;

    for (final root in roots) {
      if (!root.existsSync()) {
        continue;
      }

      checkedRoots.add(root.path);
      if (_looksLikeWeChatBackupPath(root.path)) {
        foundWeChatLocalBackup = true;
      }
      if (_looksLikeQqBackupPath(root.path)) {
        foundQqLocalBackup = true;
      }

      final queue = <_PendingDirectory>[
        _PendingDirectory(
          directory: root,
          depth: 0,
          hinted: _pathHasDiscoveryHint(root.path),
        ),
      ];
      final visited = <String>{};

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final normalizedPath = current.directory.path.toLowerCase();
        if (!visited.add(normalizedPath)) {
          continue;
        }

        List<FileSystemEntity> children;
        try {
          children = current.directory.listSync(followLinks: false);
        } catch (_) {
          continue;
        }

        for (final child in children) {
          if (child is Directory) {
            final nextDepth = current.depth + 1;
            final nextHinted =
                current.hinted || _pathHasDiscoveryHint(child.path);
            if (_shouldEnterDirectory(
              path: child.path,
              depth: nextDepth,
              hinted: nextHinted,
            )) {
              queue.add(
                _PendingDirectory(
                  directory: child,
                  depth: nextDepth,
                  hinted: nextHinted,
                ),
              );
            }
            continue;
          }

          if (child is! File) {
            continue;
          }

          final ext = p.extension(child.path).toLowerCase();
          if (!AppConstants.supportedImportExtensions.contains(ext)) {
            continue;
          }
          if (!_shouldInspectDiscoveryFile(
              path: child.path, hinted: current.hinted)) {
            continue;
          }

          final assessment = await _evaluateDiscoveryCandidate(
            child,
            hinted: current.hinted,
          );
          if (assessment.shouldImport) {
            importablePaths.add(child.path);
          }
        }
      }
    }

    if (foundWeChatLocalBackup) {
      warnings.add(
          '检测到微信本地备份目录。自动扫描仍优先导入可直接读取的导出文件；如需直读原始数据库，请手动选择 xwechat_files 或具体账号目录。');
    }
    if (foundQqLocalBackup) {
      warnings.add('检测到 QQ 本地目录，但系统只会自动导入可直接读取的聊天导出文件。');
    }

    return AutoImportDiscovery(
      importablePaths: importablePaths.toList()..sort(),
      checkedRoots: checkedRoots,
      warnings: warnings.toSet().toList(),
      foundWeChatLocalBackup: foundWeChatLocalBackup,
      foundQqLocalBackup: foundQqLocalBackup,
    );
  }

  List<String> discoverWeChatBackupAccountRoots({
    String? userHomeOverride,
  }) {
    final userHome = userHomeOverride ??
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (userHome.isEmpty) {
      return const [];
    }

    final candidates = <String>{
      p.join(userHome, 'Documents', 'xwechat_files'),
      p.join(userHome, 'Documents', 'WeChat Files'),
    };

    final roots = <String>{};
    for (final candidate in candidates) {
      roots.addAll(
        _weChatRawBackupService.resolveExplicitBackupSelections([candidate]),
      );
    }

    return roots.toList()..sort();
  }

  List<Directory> _buildDiscoveryRoots({String? userHomeOverride}) {
    final userHome = userHomeOverride ??
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (userHome.isEmpty) {
      return const [];
    }

    final rawPaths = <String>{
      p.join(userHome, 'Desktop'),
      p.join(userHome, 'Downloads'),
      p.join(userHome, 'Documents'),
      p.join(userHome, 'Documents', 'WeChat Files'),
      p.join(userHome, 'Documents', 'Tencent Files'),
      p.join(userHome, 'Documents', 'xwechat_files'),
      p.join(userHome, 'Documents', 'QQ'),
    };

    return rawPaths.map(Directory.new).toList();
  }

  bool _shouldEnterDirectory({
    required String path,
    required int depth,
    required bool hinted,
  }) {
    final lowerName = p.basename(path).toLowerCase();
    if (_ignoredDirectoryNames.contains(lowerName)) {
      return false;
    }
    if (depth <= 1) {
      return true;
    }
    if (depth == 2) {
      return hinted || _pathHasDiscoveryHint(path);
    }
    if (depth > 4) {
      return false;
    }
    return hinted || _pathHasDiscoveryHint(path);
  }

  bool _looksLikeWeChatBackupPath(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.contains('xwechat_files') ||
        lowerPath.contains('${p.separator}db_storage${p.separator}') ||
        lowerPath.endsWith('${p.separator}db_storage') ||
        lowerPath.contains('wechat files');
  }

  bool _containsOnlyRawBackupSelections(List<String> paths) {
    var foundAny = false;
    for (final rawPath in paths) {
      final trimmed = rawPath.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      foundAny = true;
      final resolved =
          _weChatRawBackupService.resolveExplicitBackupSelections([trimmed]);
      if (resolved.isNotEmpty) {
        continue;
      }
      if (_looksLikeWeChatBackupPath(trimmed)) {
        continue;
      }
      return false;
    }
    return foundAny;
  }

  bool _looksLikeQqBackupPath(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.contains('tencent files') ||
        lowerPath.contains('${p.separator}qq${p.separator}') ||
        lowerPath.endsWith('${p.separator}qq');
  }

  bool _pathHasDiscoveryHint(String path) {
    final lowerPath = path.toLowerCase();
    return _discoveryHints.any(
      (hint) => lowerPath.contains(hint.toLowerCase()) || path.contains(hint),
    );
  }

  bool _pathHasConversationHint(String path) {
    final segments = p.split(path);
    final relevant =
        segments.length > 4 ? segments.sublist(segments.length - 4) : segments;
    final joined = relevant.join(' ').toLowerCase();
    return _conversationHints.any(
      (hint) => joined.contains(hint.toLowerCase()) || path.contains(hint),
    );
  }

  bool _textHasConversationHint(String text) {
    final lowerText = text.toLowerCase();
    return _conversationHints.any(
      (hint) => lowerText.contains(hint.toLowerCase()) || text.contains(hint),
    );
  }

  bool _shouldInspectDiscoveryFile({
    required String path,
    required bool hinted,
  }) {
    if (hinted) {
      return true;
    }
    return _pathHasConversationHint(path);
  }

  Future<_CollectedFilesResult> _collectSupportedFiles(
      List<String> paths) async {
    final results = <File>[];
    final warnings = <String>[];
    var foundWeChatLocalBackup = false;
    var foundQqLocalBackup = false;

    for (final rawPath in paths) {
      if (rawPath.trim().isEmpty) {
        continue;
      }

      if (_looksLikeWeChatBackupPath(rawPath)) {
        foundWeChatLocalBackup = true;
      }
      if (_looksLikeQqBackupPath(rawPath)) {
        foundQqLocalBackup = true;
      }

      final entityType = FileSystemEntity.typeSync(rawPath);
      if (entityType == FileSystemEntityType.notFound) {
        continue;
      }

      if (entityType == FileSystemEntityType.directory) {
        final directory = Directory(rawPath);
        if (_looksLikeWeChatBackupPath(directory.path)) {
          warnings.add(
            '已跳过微信原始数据库目录 ${p.basename(directory.path)} 的普通深度扫描；如需读取多年历史，请使用“直读微信本地数据库”。',
          );
          continue;
        }
        List<FileSystemEntity> entities;
        try {
          entities = directory.listSync(recursive: true, followLinks: false);
        } catch (_) {
          continue;
        }

        for (final entity in entities.whereType<File>()) {
          if (_looksLikeWeChatBackupPath(entity.path)) {
            foundWeChatLocalBackup = true;
          }
          if (_looksLikeQqBackupPath(entity.path)) {
            foundQqLocalBackup = true;
          }

          final ext = p.extension(entity.path).toLowerCase();
          if (!AppConstants.supportedImportExtensions.contains(ext)) {
            continue;
          }

          if (ext == '.zip') {
            final zipResult =
                await _extractZip(entity, failOnInvalidZip: false);
            results.addAll(zipResult.files);
            warnings.addAll(zipResult.warnings);
          } else {
            results.add(entity);
          }
        }
        continue;
      }

      if (entityType == FileSystemEntityType.file) {
        final file = File(rawPath);
        final ext = p.extension(file.path).toLowerCase();
        if (!AppConstants.supportedImportExtensions.contains(ext)) {
          continue;
        }

        if (ext == '.zip') {
          final zipResult = await _extractZip(file, failOnInvalidZip: true);
          results.addAll(zipResult.files);
          warnings.addAll(zipResult.warnings);
        } else {
          results.add(file);
        }
      }
    }

    return _CollectedFilesResult(
      files: results,
      warnings: warnings.toSet().toList(),
      foundWeChatLocalBackup: foundWeChatLocalBackup,
      foundQqLocalBackup: foundQqLocalBackup,
    );
  }

  Future<_ImportabilityAssessment> _evaluateDiscoveryCandidate(
    File file, {
    required bool hinted,
  }) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.zip') {
      if (!hinted && !_pathHasConversationHint(file.path)) {
        return const _ImportabilityAssessment(shouldImport: false);
      }

      final zipResult = await _extractZip(file, failOnInvalidZip: false);
      for (final extracted in zipResult.files) {
        final text = await _readNormalizedText(extracted);
        if (text.trim().isEmpty) {
          continue;
        }
        final assessment = _evaluateReadableText(
          sourceFile: extracted.path,
          text: text,
          strict: true,
        );
        if (assessment.shouldImport) {
          return const _ImportabilityAssessment(shouldImport: true);
        }
      }
      return const _ImportabilityAssessment(shouldImport: false);
    }

    if (!hinted && !_pathHasConversationHint(file.path)) {
      return const _ImportabilityAssessment(shouldImport: false);
    }

    final text = await _readNormalizedText(file);
    if (text.trim().isEmpty) {
      return const _ImportabilityAssessment(shouldImport: false);
    }

    return _evaluateReadableText(
      sourceFile: file.path,
      text: text,
      strict: true,
    );
  }

  Future<_ZipExtractResult> _extractZip(
    File zipFile, {
    required bool failOnInvalidZip,
  }) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final tempDir = await Directory.systemTemp.createTemp('renmai_import_');
      final extracted = <File>[];

      for (final entry in archive) {
        if (!entry.isFile) {
          continue;
        }

        final ext = p.extension(entry.name).toLowerCase();
        if (!AppConstants.supportedImportExtensions.contains(ext) ||
            ext == '.zip') {
          continue;
        }

        final outputPath = p.join(tempDir.path, entry.name);
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(entry.content as List<int>, flush: true);
        extracted.add(outputFile);
      }

      return _ZipExtractResult(files: extracted, warnings: const []);
    } catch (_) {
      final warning = '已跳过无效压缩包：${p.basename(zipFile.path)}。';
      if (failOnInvalidZip) {
        throw FileSystemException(warning, zipFile.path);
      }
      return _ZipExtractResult(files: const [], warnings: [warning]);
    }
  }

  Future<String> _readNormalizedText(File file) async {
    final bytes = await file.readAsBytes();
    final ext = p.extension(file.path).toLowerCase();
    final decoded = _decodeBytes(bytes);

    if (ext == '.html' || ext == '.htm') {
      return _htmlToText(decoded);
    }
    return decoded.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  String _decodeBytes(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(codeUnits);
  }

  String _htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|tr|h\d)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  _ImportabilityAssessment _evaluateReadableText({
    required String sourceFile,
    required String text,
    required bool strict,
  }) {
    final normalized =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) {
      return const _ImportabilityAssessment(shouldImport: false);
    }

    final timestampMatches = _timestampRegExp().allMatches(normalized).length;
    final speakerMatches = _countMeaningfulSpeakerMatches(normalized);
    final urlMatches = RegExp(r'https?://').allMatches(normalized).length;
    final lineCount = '\n'.allMatches(normalized).length + 1;
    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(normalized);
    final hasConversationHint = _pathHasConversationHint(sourceFile) ||
        _textHasConversationHint(normalized);
    final looksStructured = timestampMatches >= 2 ||
        (timestampMatches >= 1 && speakerMatches >= 1) ||
        speakerMatches >= 3;
    final looksLikeMarketing =
        urlMatches >= 2 && timestampMatches == 0 && speakerMatches == 0;
    final longEnough = normalized.length >= 24 || lineCount >= 3;

    if (!longEnough || looksLikeMarketing) {
      return const _ImportabilityAssessment(shouldImport: false);
    }

    if (strict) {
      final looksPlausibleConversation =
          _looksLikePlausibleConversation(sourceFile, normalized);
      if (!looksPlausibleConversation) {
        return const _ImportabilityAssessment(shouldImport: false);
      }
      return _ImportabilityAssessment(shouldImport: looksStructured);
    }

    // 非严格模式：只要内容有中文且足够长就尝试导入
    if (hasChinese && normalized.length >= 50) {
      return const _ImportabilityAssessment(shouldImport: true);
    }
    if (looksStructured) {
      return const _ImportabilityAssessment(shouldImport: true);
    }
    if (hasConversationHint && (timestampMatches >= 1 || speakerMatches >= 1)) {
      return const _ImportabilityAssessment(shouldImport: true);
    }
    if (hasChinese && lineCount >= 5) {
      return const _ImportabilityAssessment(shouldImport: true);
    }
    return const _ImportabilityAssessment(shouldImport: false);
  }

  bool _looksLikePlausibleConversation(String sourceFile, String text) {
    final contactName =
        _normalizeDisplayName(_deriveContactName(sourceFile, text));
    final speakers = _extractSpeakerCandidates(text)
        .map(_normalizeDisplayName)
        .map(_extractFriendlyBaseName)
        .where(_looksLikeHumanReadableName)
        .toSet();

    if (_looksLikeHumanReadableName(contactName)) {
      return true;
    }
    if (_inferDominantSpeakerName(text) != null) {
      return true;
    }
    if (speakers.length >= 2) {
      return true;
    }
    return false;
  }

  String _detectSource(String path, String text) {
    final lowerPath = path.toLowerCase();
    final lowerText = text.toLowerCase();

    if (lowerPath.contains('wechat') ||
        lowerPath.contains('weixin') ||
        path.contains('微信') ||
        lowerText.contains('微信聊天记录')) {
      return 'wechat';
    }
    if (lowerPath.contains('qq') ||
        path.contains('QQ') ||
        lowerText.contains('qq消息记录')) {
      return 'qq';
    }
    return 'unknown';
  }

  List<ConversationRecord> _parseConversationText({
    required String packageId,
    required String source,
    required String sourceFile,
    required String text,
    String? lockedContactName,
    bool allowFallback = true,
  }) {
    final provisionalContactName = _normalizeDisplayName(
      _deriveContactName(
        sourceFile,
        text,
        lockedContactName: lockedContactName,
      ),
    );
    final provisionalContactId = _normalizeContactId(provisionalContactName);
    final lines = text.split('\n');
    final messages = <ConversationRecord>[];
    final timestampPattern = _timestampRegexSource();
    final syntheticBaseTime = _resolveSyntheticBaseTime(sourceFile);

    final inlinePattern = RegExp(
      '^\\[?($timestampPattern)\\]?\\s*([^:\\uFF1A]{1,30})[:\\uFF1A]\\s*(.+)\$',
    );
    final headerPatternA = RegExp('^(.+?)\\s+($timestampPattern)\$');
    final headerPatternB = RegExp('^($timestampPattern)\\s+(.+)\$');
    final speakerOnlyPattern = _speakerLineRegExp();

    String? currentSender;
    DateTime? currentSentAt;
    final buffer = <String>[];

    void flushCurrent() {
      if (currentSender == null || currentSentAt == null || buffer.isEmpty) {
        return;
      }

      final senderName = currentSender;
      final sentAt = currentSentAt;
      final content = buffer.join('\n').trim();
      if (content.isEmpty) {
        buffer.clear();
        return;
      }

      messages.add(
        ConversationRecord(
          id: '${packageId}_${messages.length + 1}',
          packageId: packageId,
          source: source,
          contactId: provisionalContactId,
          contactName: provisionalContactName,
          senderName: _normalizeDisplayName(senderName),
          isSelf: _isSelfSender(senderName),
          sentAt: sentAt,
          content: content,
          messageType: _detectMessageType(content),
          evidenceSnippet:
              content.length > 60 ? '${content.substring(0, 60)}...' : content,
          sourceFile: sourceFile,
        ),
      );

      buffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (buffer.isNotEmpty) {
          buffer.add('');
        }
        continue;
      }
      if (_isConversationMetaLine(line)) {
        continue;
      }

      final inlineMatch = inlinePattern.firstMatch(line);
      if (inlineMatch != null) {
        final candidateSender = _normalizeDisplayName(inlineMatch.group(2)!);
        if (!(_isSelfSender(candidateSender) ||
            _looksLikeSpeakerName(candidateSender))) {
          buffer.add(line);
          continue;
        }
        flushCurrent();
        currentSentAt = _parseFlexibleDate(inlineMatch.group(1)!);
        currentSender = candidateSender;
        buffer
          ..clear()
          ..add(inlineMatch.group(3)!.trim());
        continue;
      }

      final headerAMatch = headerPatternA.firstMatch(line);
      if (headerAMatch != null && !_looksLikeContentLine(line)) {
        final candidateSender = _normalizeDisplayName(headerAMatch.group(1)!);
        if (!(_isSelfSender(candidateSender) ||
            _looksLikeSpeakerName(candidateSender))) {
          buffer.add(line);
          continue;
        }
        flushCurrent();
        currentSender = candidateSender;
        currentSentAt = _parseFlexibleDate(headerAMatch.group(2)!);
        continue;
      }

      final headerBMatch = headerPatternB.firstMatch(line);
      if (headerBMatch != null && !_looksLikeContentLine(line)) {
        final candidateSender = _normalizeDisplayName(headerBMatch.group(2)!);
        if (!(_isSelfSender(candidateSender) ||
            _looksLikeSpeakerName(candidateSender))) {
          buffer.add(line);
          continue;
        }
        flushCurrent();
        currentSentAt = _parseFlexibleDate(headerBMatch.group(1)!);
        currentSender = candidateSender;
        continue;
      }

      final speakerOnlyMatch = speakerOnlyPattern.firstMatch(line);
      if (speakerOnlyMatch != null) {
        final candidateSender =
            _normalizeDisplayName(speakerOnlyMatch.group(2)!);
        if (_isSelfSender(candidateSender) ||
            _looksLikeSpeakerName(candidateSender)) {
          flushCurrent();
          currentSender = candidateSender;
          currentSentAt =
              syntheticBaseTime.add(Duration(minutes: messages.length));
          buffer
            ..clear()
            ..add(speakerOnlyMatch.group(3)!.trim());
          continue;
        }
      }

      buffer.add(line);
    }

    flushCurrent();

    if (messages.isNotEmpty) {
      final resolvedContactName = _resolveContactName(
        lockedContactName ?? provisionalContactName,
        messages,
      );
      if (!_looksLikeHumanReadableName(resolvedContactName)) {
        return const [];
      }

      final resolvedContactId = _normalizeContactId(resolvedContactName);
      return messages
          .map(
            (item) => item.copyWith(
              contactId: resolvedContactId,
              contactName: resolvedContactName,
              senderName: item.isSelf
                  ? '我'
                  : _extractFriendlyBaseName(
                      _normalizeDisplayName(item.senderName)),
            ),
          )
          .toList();
    }

    if (!allowFallback) {
      return const [];
    }

    return _buildFallbackMessages(
      packageId: packageId,
      source: source,
      sourceFile: sourceFile,
      contactId: provisionalContactId,
      contactName: lockedContactName ?? provisionalContactName,
      text: text,
    );
  }

  List<ConversationRecord> _buildFallbackMessages({
    required String packageId,
    required String source,
    required String sourceFile,
    required String contactId,
    required String contactName,
    required String text,
  }) {
    if (!_looksLikeHumanReadableName(contactName) &&
        !(_pathHasConversationHint(sourceFile) ||
            _textHasConversationHint(text))) {
      return const [];
    }

    final chunks = text
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final baseTime = _resolveSyntheticBaseTime(sourceFile);

    return chunks.asMap().entries.map((entry) {
      final offsetMinutes = entry.key;
      final content = entry.value;
      return ConversationRecord(
        id: '${packageId}_fallback_${entry.key}',
        packageId: packageId,
        source: source,
        contactId: contactId,
        contactName: contactName,
        senderName: contactName,
        isSelf: false,
        sentAt: baseTime.add(Duration(minutes: offsetMinutes)),
        content: content,
        messageType: _detectMessageType(content),
        evidenceSnippet:
            content.length > 60 ? '${content.substring(0, 60)}...' : content,
        sourceFile: sourceFile,
      );
    }).toList();
  }

  bool _looksLikeContentLine(String line) {
    return line.contains('http://') ||
        line.contains('https://') ||
        line.length > 48;
  }

  DateTime _parseFlexibleDate(String raw) {
    final match = RegExp(
      r'(\d{4})[\u5e74/\-.](\d{1,2})[\u6708/\-.](\d{1,2})\u65e5?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(raw.trim());
    if (match == null) {
      return DateTime.now();
    }

    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '') ?? 0,
    );
  }

  String _deriveContactName(
    String sourceFile,
    String text, {
    String? lockedContactName,
  }) {
    final locked = _normalizeDisplayName(lockedContactName ?? '');
    if (locked.isNotEmpty && _looksLikeHumanReadableName(locked)) {
      return locked;
    }

    final contentPatterns = <RegExp>[
      RegExp(r'(?:和|与)\s*([^\n]{1,30}?)\s*的聊天记录'),
      RegExp(r'(?:聊天记录|消息记录)[:：\s-]+([^\n]{1,30})'),
    ];

    for (final pattern in contentPatterns) {
      final match = pattern.firstMatch(text);
      final name = _normalizeDisplayName(match?.group(1) ?? '');
      final friendly = _extractFriendlyBaseName(name);
      if (friendly.isNotEmpty && _looksLikeHumanReadableName(friendly)) {
        return friendly;
      }
    }

    final dominantSpeaker = _inferDominantSpeakerName(text);
    if (dominantSpeaker != null) {
      return dominantSpeaker;
    }

    final fileName = p.basenameWithoutExtension(sourceFile);
    final normalized = fileName
        .replaceAll('聊天记录', '')
        .replaceAll('消息记录', '')
        .replaceAll('message', '')
        .replaceAll('messages', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    final cleaned = _extractFriendlyBaseName(_normalizeDisplayName(normalized));
    if (cleaned.isEmpty ||
        _looksLikeWeakContactName(cleaned) ||
        !_looksLikeHumanReadableName(cleaned)) {
      return '未命名联系人';
    }
    return cleaned;
  }

  String _normalizeContactId(String contactName) {
    final sanitized = contactName.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'),
          '_',
        );
    return sanitized
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  bool _isSelfSender(String senderName) {
    const selfAliases = {'我', 'me', 'Me', '本人', '自己', 'you', 'You'};
    return selfAliases.contains(_normalizeDisplayName(senderName));
  }

  String _detectMessageType(String content) {
    if (content.contains('[图片]') || content.contains('图片')) {
      return 'image';
    }
    if (content.contains('[文件]') || content.contains('文件')) {
      return 'file';
    }
    if (content.contains('[语音]') || content.contains('语音')) {
      return 'voice';
    }
    return 'text';
  }

  int _countMeaningfulSpeakerMatches(String text) {
    var count = 0;
    for (final match in _speakerLineRegExp(multiLine: true).allMatches(text)) {
      final candidate = _normalizeDisplayName(match.group(2) ?? '');
      if (_looksLikeSpeakerName(candidate)) {
        count++;
      }
    }
    return count;
  }

  bool _looksLikeSpeakerName(String value) {
    final normalized = _extractFriendlyBaseName(_normalizeDisplayName(value));
    if (normalized.isEmpty) {
      return false;
    }
    if (_isSelfSender(normalized)) {
      return true;
    }
    if (_looksLikeUrlFragment(normalized)) {
      return false;
    }

    final compact = _nameForComparison(normalized);
    if (compact.isEmpty) {
      return false;
    }
    if (_technicalNameTokens.any((token) => compact.contains(token))) {
      return false;
    }

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (!RegExp(r'[\u4e00-\u9fa5]').hasMatch(normalized) && words.length > 3) {
      return false;
    }

    return _looksLikeHumanReadableName(normalized);
  }

  bool _looksLikeUrlFragment(String value) {
    final lower = value.toLowerCase();
    return lower.contains('http') ||
        lower.contains('www.') ||
        lower.contains('://') ||
        lower.contains('.com') ||
        lower.contains('.cn') ||
        lower.contains('.net') ||
        lower.contains('/') ||
        lower.contains('\\');
  }

  List<ConversationRecord> _deduplicate(List<ConversationRecord> source) {
    final seen = <String>{};
    final results = <ConversationRecord>[];

    for (final record in source) {
      final key =
          '${record.contactId}|${record.senderName}|${record.sentAt.toIso8601String()}|${record.content}';
      if (seen.add(key)) {
        results.add(record);
      }
    }

    results.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return results;
  }

  List<String> _extractSpeakerCandidates(String text) {
    final timestampPattern = _timestampRegexSource();
    final inlinePattern = RegExp(
      '^\\[?($timestampPattern)\\]?\\s*([^:\\uFF1A]{1,30})[:\\uFF1A]\\s*(.+)\$',
      multiLine: true,
    );
    final headerPatternA =
        RegExp('^(.+?)\\s+($timestampPattern)\$', multiLine: true);
    final headerPatternB =
        RegExp('^($timestampPattern)\\s+(.+)\$', multiLine: true);
    final speakerOnlyPattern = _speakerLineRegExp(multiLine: true);
    final candidates = <String>[];

    for (final match in inlinePattern.allMatches(text)) {
      final candidate = match.group(2) ?? '';
      if (_looksLikeSpeakerName(candidate) || _isSelfSender(candidate)) {
        candidates.add(candidate);
      }
    }
    for (final match in speakerOnlyPattern.allMatches(text)) {
      final candidate = match.group(2) ?? '';
      if (_looksLikeSpeakerName(candidate) || _isSelfSender(candidate)) {
        candidates.add(candidate);
      }
    }
    for (final match in headerPatternA.allMatches(text)) {
      final candidate = match.group(1) ?? '';
      if (_looksLikeSpeakerName(candidate) || _isSelfSender(candidate)) {
        candidates.add(candidate);
      }
    }
    for (final match in headerPatternB.allMatches(text)) {
      final candidate = match.group(2) ?? '';
      if (_looksLikeSpeakerName(candidate) || _isSelfSender(candidate)) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  String? _inferDominantSpeakerName(String text) {
    final counts = <String, int>{};
    final firstSeen = <String, int>{};
    var order = 0;

    for (final candidate in _extractSpeakerCandidates(text)) {
      final normalized = _extractFriendlyBaseName(candidate);
      if (normalized.isEmpty ||
          _isSelfSender(normalized) ||
          !_looksLikeHumanReadableName(normalized)) {
        continue;
      }

      counts[normalized] = (counts[normalized] ?? 0) + 1;
      firstSeen.putIfAbsent(normalized, () => order++);
    }

    if (counts.isEmpty) {
      return null;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }

        final byLength = a.key.length.compareTo(b.key.length);
        if (byLength != 0) {
          return byLength;
        }

        return (firstSeen[a.key] ?? 0).compareTo(firstSeen[b.key] ?? 0);
      });

    return sorted.first.key;
  }

  String _resolveContactName(
      String currentName, List<ConversationRecord> messages) {
    final normalizedCurrent =
        _extractFriendlyBaseName(_normalizeDisplayName(currentName));
    final speakerCounts = <String, int>{};

    for (final message in messages) {
      final sender =
          _extractFriendlyBaseName(_normalizeDisplayName(message.senderName));
      if (sender.isEmpty ||
          _isSelfSender(sender) ||
          !_looksLikeHumanReadableName(sender)) {
        continue;
      }
      speakerCounts[sender] = (speakerCounts[sender] ?? 0) + 1;
    }

    final sortedSpeakers = speakerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSpeaker = sortedSpeakers.isEmpty ? null : sortedSpeakers.first.key;

    if (!_looksLikeHumanReadableName(normalizedCurrent)) {
      return topSpeaker ?? normalizedCurrent;
    }
    if (topSpeaker == null) {
      return normalizedCurrent;
    }
    if (_looksLikeWeakContactName(normalizedCurrent)) {
      return topSpeaker;
    }

    final compactCurrent = _nameForComparison(normalizedCurrent);
    final compactSpeaker = _nameForComparison(topSpeaker);
    if (compactCurrent.isNotEmpty &&
        compactSpeaker.isNotEmpty &&
        (compactCurrent.contains(compactSpeaker) ||
            compactSpeaker.contains(compactCurrent))) {
      return topSpeaker;
    }

    return normalizedCurrent;
  }

  bool _isConversationMetaLine(String line) {
    final normalized = _normalizeDisplayName(line).replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized == '聊天记录' ||
        normalized == '微信聊天记录' ||
        normalized == 'QQ聊天记录' ||
        normalized == '消息记录') {
      return true;
    }
    if (RegExp(r'^.{1,40}(?:和|与).{1,40}的聊天记录$').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'^共\d+(?:条)?(?:聊天记录|消息)$').hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  String _normalizeDisplayName(String raw) {
    return raw
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'^[\s\-\._|｜:：]+'), '')
        .replaceAll(RegExp(r'[\s\-\._|｜:：]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _extractFriendlyBaseName(String raw) {
    final normalized = _normalizeDisplayName(raw);
    if (normalized.isEmpty) {
      return normalized;
    }

    final chineseMatch = RegExp(
      r'^([\u4e00-\u9fa5]{1,8})(?:[\uFF08(].+[)\uFF09])+$',
    ).firstMatch(normalized);
    if (chineseMatch != null) {
      return chineseMatch.group(1) ?? normalized;
    }

    final latinMatch = RegExp(
      r'^([A-Za-z][A-Za-z ]{1,24})(?:[\uFF08(].+[)\uFF09])+$',
    ).firstMatch(normalized);
    if (latinMatch != null) {
      return (latinMatch.group(1) ?? normalized).trim();
    }

    return normalized;
  }

  String _nameForComparison(String value) {
    return _normalizeDisplayName(value)
        .toLowerCase()
        .replaceAll('聊天记录', '')
        .replaceAll('消息记录', '')
        .replaceAll('chat', '')
        .replaceAll('message', '')
        .replaceAll('messages', '')
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '');
  }

  bool _looksLikeWeakContactName(String value) {
    final normalized = _normalizeDisplayName(value);
    if (_looksLikeUrlFragment(normalized)) {
      return false;
    }

    final comparison = _nameForComparison(normalized);
    if (comparison.isEmpty) {
      return true;
    }
    if (_genericPlaceholderNames.contains(comparison)) {
      return true;
    }
    // 只有完全等于占位词时才拒绝，带有其它中文词的名称保留
    if (normalized == '新建' || normalized == '未命名') {
      return true;
    }
    return false;
  }

  bool _looksLikeHumanReadableName(String value) {
    final normalized = _normalizeDisplayName(value);
    if (normalized.isEmpty || normalized == '未命名联系人') {
      return false;
    }

    final comparison = _nameForComparison(normalized);
    if (comparison.isEmpty) {
      return false;
    }
    if (RegExp(r'^[a-f0-9]{16,}$', caseSensitive: false).hasMatch(comparison)) {
      return false;
    }
    if (_technicalNameTokens.any((token) => comparison.contains(token))) {
      return false;
    }
    if (_looksLikeWeakContactName(normalized)) {
      return false;
    }

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (!RegExp(r'[\u4e00-\u9fa5]').hasMatch(normalized) && words.length > 3) {
      return false;
    }

    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'^[A-Za-z][A-Za-z .·]{0,24}$').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'^[A-Za-z0-9][A-Za-z0-9 .·]{1,18}$').hasMatch(normalized) &&
        RegExp(r'[A-Za-z]').hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  String _timestampRegexSource() {
    return r'\d{4}(?:[-/.\u5e74]\d{1,2})(?:[-/.\u6708]\d{1,2})\u65e5?\s+\d{1,2}:\d{2}(?::\d{2})?';
  }

  RegExp _timestampRegExp({bool multiLine = false}) {
    return RegExp(_timestampRegexSource(), multiLine: multiLine);
  }

  RegExp _speakerLineRegExp({bool multiLine = false}) {
    return RegExp(
      r'(^|\n)\s*(?!https?)(?!www\.)([A-Za-z0-9_\-\u4e00-\u9fa5\uFF08\uFF09()\u00B7\u00B0\u2103\s]{1,24})[:\uFF1A]\s*(\S.+)$',
      multiLine: multiLine,
    );
  }

  DateTime _resolveSyntheticBaseTime(String sourceFile) {
    final file = File(sourceFile);
    if (file.existsSync()) {
      try {
        return file.lastModifiedSync();
      } catch (_) {}
    }
    return DateTime.now().subtract(const Duration(minutes: 5));
  }

  List<_ContactProfile> _buildContactProfiles(
      List<ConversationRecord> records) {
    final grouped = <String, List<ConversationRecord>>{};
    for (final record in records) {
      grouped
          .putIfAbsent(record.contactId, () => <ConversationRecord>[])
          .add(record);
    }

    final profiles = <_ContactProfile>[];
    for (final entry in grouped.entries) {
      final comparableNames = <String>{};
      final resolvedName = _normalizeDisplayName(entry.value.first.contactName);
      if (resolvedName.isNotEmpty) {
        comparableNames.add(_nameForComparison(resolvedName));
        comparableNames
            .add(_nameForComparison(_extractFriendlyBaseName(resolvedName)));
      }

      for (final message in entry.value) {
        final sender = _normalizeDisplayName(message.senderName);
        if (sender.isEmpty || _isSelfSender(sender)) {
          continue;
        }
        comparableNames.add(_nameForComparison(sender));
        comparableNames
            .add(_nameForComparison(_extractFriendlyBaseName(sender)));
      }

      comparableNames.removeWhere((item) => item.trim().isEmpty);
      if (comparableNames.isEmpty) {
        continue;
      }

      profiles.add(
        _ContactProfile(
          contactId: entry.key,
          contactName: resolvedName,
          comparableNames: comparableNames,
        ),
      );
    }

    return profiles;
  }

  _ContactProfile? _matchImportedGroupToExistingContact({
    required List<ConversationRecord> group,
    required List<_ContactProfile> profiles,
    String? preferredContactId,
    String? lockedContactName,
  }) {
    if (group.isEmpty || profiles.isEmpty) {
      return null;
    }

    final importedNames = <String>{
      _nameForComparison(group.first.contactName),
      _nameForComparison(_extractFriendlyBaseName(group.first.contactName)),
      if (lockedContactName != null) _nameForComparison(lockedContactName),
    }..removeWhere((item) => item.trim().isEmpty);

    final speakerNames = <String>{};
    for (final record in group) {
      final sender = _normalizeDisplayName(record.senderName);
      if (sender.isEmpty || _isSelfSender(sender)) {
        continue;
      }
      speakerNames.add(_nameForComparison(sender));
      speakerNames.add(_nameForComparison(_extractFriendlyBaseName(sender)));
    }
    speakerNames.removeWhere((item) => item.trim().isEmpty);

    _ContactProfile? bestProfile;
    var bestScore = 0;

    for (final profile in profiles) {
      var score = 0;
      if (preferredContactId != null &&
          profile.contactId == preferredContactId) {
        score += 8;
      }

      for (final importedName in importedNames) {
        for (final candidate in profile.comparableNames) {
          if (importedName == candidate) {
            score += 12;
          } else if (importedName.isNotEmpty &&
              candidate.isNotEmpty &&
              (importedName.contains(candidate) ||
                  candidate.contains(importedName))) {
            score += 7;
          }
        }
      }

      for (final speakerName in speakerNames) {
        for (final candidate in profile.comparableNames) {
          if (speakerName == candidate) {
            score += 14;
          } else if (speakerName.isNotEmpty &&
              candidate.isNotEmpty &&
              (speakerName.contains(candidate) ||
                  candidate.contains(speakerName))) {
            score += 8;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestProfile = profile;
      }
    }

    if (bestScore < 8) {
      return null;
    }
    return bestProfile;
  }

  String _sourceLabel(String value) {
    switch (value) {
      case 'wechat':
        return '微信';
      case 'qq':
        return 'QQ';
      case 'mixed':
        return '微信 + QQ';
      default:
        return '未识别来源';
    }
  }

  String _emptyImportMessage({
    required bool foundWeChatLocalBackup,
    required bool foundQqLocalBackup,
    bool noChatLikeText = false,
    bool rawAttempted = false,
    String? rawFailureMessage,
  }) {
    if (foundWeChatLocalBackup) {
      if (rawAttempted && (rawFailureMessage ?? '').trim().isNotEmpty) {
        return rawFailureMessage!;
      }
      return noChatLikeText
          ? '检测到微信本地备份目录，但暂时没有解析出可用聊天记录。请保持微信登录后重试直读，或优先导入可直接查看的 .txt / .html / .zip 聊天记录。'
          : '没有找到可导入的聊天记录文件。你可以手动选择 xwechat_files 或具体账号目录尝试直读原始数据库，也可以优先导入 .txt / .html / .zip 聊天导出文件。';
    }

    if (foundQqLocalBackup) {
      return noChatLikeText
          ? '检测到 QQ 本地目录，但没有识别出可读聊天记录。请优先导出为 .txt / .html / .zip 后再导入。'
          : '没有找到可导入的 QQ 聊天记录文件。请优先选择已经导出的 .txt / .html / .zip 文件或导出目录。';
    }

    if (noChatLikeText) {
      return '扫描到了文件，但没有识别出聊天记录结构。请优先选择带有时间、发言人和正文的 .txt / .html / .zip 文件。';
    }

    return '没有找到可导入的聊天记录文件。请优先选择 .txt / .html / .zip 聊天导出文件，而不是整个 Documents 或缓存目录。';
  }
}
