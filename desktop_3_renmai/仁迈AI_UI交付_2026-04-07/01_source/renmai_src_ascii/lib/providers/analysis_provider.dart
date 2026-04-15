import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/attachment_ingest_service.dart';
import 'package:renmai/services/api_service.dart';
import 'package:renmai/services/chat_window_capture_service.dart';
import 'package:renmai/services/import_service.dart';
import 'package:renmai/services/local_report_service.dart';
import 'package:renmai/services/storage_service.dart';
import 'package:renmai/services/web_handoff_service.dart';

typedef ImportSessionReview = Future<ImportSessionData?> Function(
  ImportSessionData session,
);

class AnalysisProvider extends ChangeNotifier {
  AnalysisProvider();

  AiProviderConfig _aiConfig = const AiProviderConfig();
  final List<ImportedPackage> _importedPackages = [];
  final List<ConversationRecord> _records = [];
  ComparisonReport? _currentReport;
  String? _selectedContactId;
  String? _clipboardAppendContactId;
  String? _clipboardAppendContactName;
  String? _errorMessage;
  String? _statusMessage;
  bool _isInitialized = false;
  bool _isImporting = false;
  bool _isAnalyzing = false;

  AiProviderConfig get aiConfig => _aiConfig;
  List<ImportedPackage> get importedPackages =>
      List.unmodifiable(_importedPackages);
  List<ConversationRecord> get records => List.unmodifiable(_records);
  ComparisonReport? get currentReport => _currentReport;
  List<ContactInsight> get contactInsights =>
      _currentReport?.contactInsights ?? const [];
  List<RelationshipRankItem> get relationshipRanking =>
      _currentReport?.relationshipRanking ?? const [];
  List<GiftRecommendation> get giftRecommendations =>
      _currentReport?.giftRecommendations ?? const [];
  List<String> get actionSuggestions =>
      _currentReport?.actionSuggestions ?? const [];
  String? get selectedContactId => _selectedContactId;
  String? get clipboardAppendContactId => _clipboardAppendContactId;
  String? get clipboardAppendContactName => _clipboardAppendContactName;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  bool get isInitialized => _isInitialized;
  bool get isImporting => _isImporting;
  bool get isAnalyzing => _isAnalyzing;
  bool get hasData => _records.isNotEmpty;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await StorageService.instance.initialize();

    final baseUrl =
        StorageService.instance.getString(AppConstants.keyAiBaseUrl) ?? '';
    final model =
        StorageService.instance.getString(AppConstants.keyAiModel) ?? '';
    final enabled =
        StorageService.instance.getString(AppConstants.keyAiEnabled) == 'true';
    final apiKey = await StorageService.instance
            .getSecureString(AppConstants.keyAiApiKey) ??
        '';

    _aiConfig = AiProviderConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      enabled: enabled,
    );

    final packageJson =
        StorageService.instance.getJsonList(AppConstants.keyImportedPackages);
    _importedPackages
      ..clear()
      ..addAll(packageJson.map(ImportedPackage.fromJson));

    final recordJson = StorageService.instance
        .getJsonList(AppConstants.keyConversationRecords);
    _records
      ..clear()
      ..addAll(recordJson.map(ConversationRecord.fromJson));

    final sanitizedRecords = ImportService.instance.sanitizeRecords(_records);
    final removedNoiseCount = _records.length - sanitizedRecords.length;
    var clearedStaleWorkspace = false;
    if (removedNoiseCount > 0) {
      _records
        ..clear()
        ..addAll(sanitizedRecords);
      _statusMessage = '已自动清理 $removedNoiseCount 条明显不是聊天记录的旧数据。';
    }

    _refreshImportedPackagesFromRecords();

    final reportJson =
        StorageService.instance.getJson(AppConstants.keyComparisonReport);
    if (reportJson != null && removedNoiseCount == 0 && _records.isNotEmpty) {
      final storedReport = ComparisonReport.fromJson(reportJson);
      if (_reportMatchesRecords(storedReport)) {
        _currentReport = storedReport;
      } else {
        clearedStaleWorkspace = true;
        _currentReport = LocalReportService.instance.buildReport(
          packages: _importedPackages,
          records: _records,
        );
        _statusMessage ??= '已自动清理失效报告，并按当前聊天记录重新生成。';
      }
    } else if (_records.isNotEmpty) {
      _currentReport = LocalReportService.instance.buildReport(
        packages: _importedPackages,
        records: _records,
      );
    } else if (reportJson != null) {
      clearedStaleWorkspace = true;
      _currentReport = null;
      _statusMessage ??= '已自动清理没有对应聊天记录的旧报告。';
    }

    _selectedContactId =
        StorageService.instance.getString(AppConstants.keySelectedContactId);
    _selectedContactId ??=
        _currentReport?.relationshipRanking.isNotEmpty == true
            ? _currentReport!.relationshipRanking.first.contactId
            : null;
    if (_selectedContactId != null &&
        _records.every((item) => item.contactId != _selectedContactId)) {
      _selectedContactId =
          _currentReport?.relationshipRanking.isNotEmpty == true
              ? _currentReport!.relationshipRanking.first.contactId
              : null;
    }

    if (_currentReport != null && !_reportMatchesRecords(_currentReport!)) {
      clearedStaleWorkspace = true;
      _currentReport = _records.isEmpty
          ? null
          : LocalReportService.instance.buildReport(
              packages: _importedPackages,
              records: _records,
            );
      _selectedContactId =
          _currentReport?.relationshipRanking.isNotEmpty == true
              ? _currentReport!.relationshipRanking.first.contactId
              : null;
    }

    if (removedNoiseCount > 0 || clearedStaleWorkspace) {
      await _persistWorkspace();
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> importPaths(List<String> paths) async {
    await _runImportWorkflow(
      preparationStatus: '正在解析你选择的聊天记录，请稍候...',
      loader: () => ImportService.instance.importPaths(
        paths,
        aiConfig: _aiConfig,
      ),
    );
  }

  Future<void> importClipboardText(String text) async {
    await _runImportWorkflow(
      preparationStatus: '正在解析剪贴板里的聊天内容，请稍候...',
      updateClipboardAppendTarget: true,
      loader: () => ImportService.instance.importPlainText(
        text,
        sourceFile: 'clipboard_import.txt',
      ),
    );
  }

  Future<void> appendClipboardText(String text) async {
    await _runImportWorkflow(
      preparationStatus: _clipboardAppendContactName == null
          ? '正在连续导入剪贴板里的聊天内容，请稍候...'
          : '正在追加 ${_clipboardAppendContactName!} 的聊天记录，请稍候...',
      preferredContactId: _clipboardAppendContactId ?? _selectedContactId,
      lockedContactName: _clipboardAppendContactName,
      updateClipboardAppendTarget: true,
      loader: () => ImportService.instance.importPlainText(
        text,
        sourceFile: _clipboardAppendContactName == null
            ? 'clipboard_append.txt'
            : '${_clipboardAppendContactName!}_clipboard_append.txt',
        lockedContactName: _clipboardAppendContactName,
      ),
    );
  }

  Future<void> smartImportFromDevice() async {
    await _runImportWorkflow(
      preparationStatus: '正在扫描本机常见的微信 / QQ 导出目录...',
      loader: () async {
        final discovery =
            await ImportService.instance.discoverAutoImportPaths();
        if (!discovery.hasImportablePaths) {
          throw FileSystemException(discovery.buildFailureMessage());
        }

        _statusMessage =
            '已自动找到 ${discovery.importablePaths.length} 份高置信度聊天记录，正在生成报告...';
        notifyListeners();

        return ImportService.instance.importPaths(
          discovery.importablePaths,
          presetWarnings: discovery.warnings,
          strictContentFilter: true,
          aiConfig: _aiConfig,
        );
      },
    );
  }

  Future<void> importWeChatLocalBackup({
    List<String>? accountRoots,
    ImportSessionReview? reviewSession,
  }) async {
    await _runImportWorkflow(
      preparationStatus: '正在直读微信本地数据库，请先打开电脑版微信并保持登录...',
      timeout: const Duration(minutes: 6),
      timeoutMessage: '直读微信本地数据库在 6 分钟内还没有完成。请保持微信登录后重试，或改用聊天导出文件导入。',
      reviewSession: reviewSession,
      loader: () {
        final resolvedRoots = accountRoots ??
            ImportService.instance.discoverWeChatBackupAccountRoots();
        if (resolvedRoots.isEmpty) {
          throw const FileSystemException(
            '没有找到可直读的微信目录。请先确认本机存在 xwechat_files，或在导入页手动选择具体账号目录，并确保电脑版微信已经打开且保持登录。',
          );
        }
        return ImportService.instance.importPaths(
          resolvedRoots,
          aiConfig: _aiConfig,
        );
      },
    );
  }

  Future<void> scanExportRecords() async {
    await smartImportFromDevice();
  }

  Future<void> captureFromChatWindow() async {
    await _runChatWindowCapture(
      append: false,
      preparationStatus: '请在 4 秒内切到 QQ 或微信聊天窗口。仁迈会自动截图、识别并向上翻页采集聊天内容。',
    );
  }

  Future<void> appendFromChatWindow() async {
    await _runChatWindowCapture(
      append: true,
      preparationStatus: _clipboardAppendContactName == null
          ? '请在 4 秒内切到同一个聊天窗口，仁迈会继续向上采集更多历史消息。'
          : '请在 4 秒内切到 ${_clipboardAppendContactName!} 的聊天窗口，仁迈会继续采集并自动合并。',
    );
  }

  Future<void> importAttachmentFiles(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }

    final targetContactId = _clipboardAppendContactId ?? _selectedContactId;
    final targetContactName = _clipboardAppendContactName ??
        (targetContactId == null
            ? null
            : findInsightByContactId(targetContactId)?.contactName);

    if (targetContactId == null ||
        targetContactName == null ||
        targetContactName.trim().isEmpty) {
      _errorMessage = '请先导入或采集一位联系人，再补充图片、文件或语音附件。';
      notifyListeners();
      return;
    }

    await _runImportWorkflow(
      preparationStatus: '正在读取附件内容，并并入 $targetContactName 的分析...',
      preferredContactId: targetContactId,
      lockedContactName: targetContactName,
      updateClipboardAppendTarget: true,
      loader: () async {
        final session = await AttachmentIngestService.instance.importForContact(
          paths: paths,
          contactId: targetContactId,
          contactName: targetContactName,
          aiConfig: _aiConfig,
        );
        return ImportSessionData(
          importedPackage: session.importedPackage,
          records: session.records,
          warnings: session.warnings,
        );
      },
    );
  }

  Future<void> rebuildLocalReport({String? statusMessage}) async {
    _currentReport = LocalReportService.instance.buildReport(
      packages: _importedPackages,
      records: _records,
    );
    _syncSelectedContactId();
    _statusMessage = statusMessage ?? '已根据最新导入内容刷新本地报告。';
    _syncClipboardAppendTarget();
    await _persistWorkspace();
    notifyListeners();
  }

  Future<void> runAiAnalysis() async {
    if (_isAnalyzing) {
      return;
    }
    if (_currentReport == null || _records.isEmpty) {
      _errorMessage = '请先导入聊天记录，再发起 AI 分析。';
      notifyListeners();
      return;
    }
    if (!_aiConfig.enabled) {
      _errorMessage = '请先在 AI 设置页开启“启用 AI 增强”，再发起 AI 分析。';
      notifyListeners();
      return;
    }
    if (!_aiConfig.isReady) {
      _errorMessage = '请先在设置页填写可用的 AI 地址、API Key 和模型名称。';
      notifyListeners();
      return;
    }

    _isAnalyzing = true;
    _errorMessage = null;
    _statusMessage = '正在调用 AI 生成结构化关系报告...';
    notifyListeners();

    try {
      _currentReport = await ApiService.instance.generateComparisonReport(
        config: _aiConfig,
        seedReport: _currentReport!,
        records: _records,
      );
      _selectedContactId ??=
          _currentReport?.relationshipRanking.isNotEmpty == true
              ? _currentReport!.relationshipRanking.first.contactId
              : null;
      _statusMessage = 'AI 增强报告已生成，关系排序与送礼建议已更新。';
      await _persistWorkspace();
    } catch (error) {
      _errorMessage = 'AI 分析失败：$error';
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> saveAiConfig(AiProviderConfig config) async {
    _aiConfig = config;
    await StorageService.instance
        .setString(AppConstants.keyAiBaseUrl, config.baseUrl);
    await StorageService.instance
        .setString(AppConstants.keyAiModel, config.model);
    await StorageService.instance.setString(
      AppConstants.keyAiEnabled,
      config.enabled ? 'true' : 'false',
    );
    await StorageService.instance
        .setSecureString(AppConstants.keyAiApiKey, config.apiKey);
    _statusMessage = 'AI 配置已保存。';
    notifyListeners();
  }

  void selectContact(String? contactId) {
    _selectedContactId = contactId;
    if (contactId != null && contactId.isNotEmpty) {
      StorageService.instance
          .setString(AppConstants.keySelectedContactId, contactId);
    }
    notifyListeners();
  }

  ContactInsight? findInsightByContactId(String contactId) {
    for (final insight in contactInsights) {
      if (insight.contactId == contactId) {
        return insight;
      }
    }
    return null;
  }

  List<ConversationRecord> recordsForContact(String contactId) {
    final matched = _records
        .where((item) => item.contactId == contactId)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return matched;
  }

  List<ConversationRecord> recordsForPackage(String packageId) {
    final matched = _records
        .where((item) => item.packageId == packageId)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return matched;
  }

  Future<void> updateConversationRecord(
      ConversationRecord updatedRecord) async {
    final index = _records.indexWhere((item) => item.id == updatedRecord.id);
    if (index == -1) {
      _errorMessage = '未找到要更新的聊天记录。';
      notifyListeners();
      return;
    }

    final existing = _records[index];
    final normalizedContent = updatedRecord.content.trim();
    if (normalizedContent.isEmpty) {
      _errorMessage = '聊天内容不能为空。';
      notifyListeners();
      return;
    }

    final normalizedSender = updatedRecord.isSelf
        ? '我'
        : (updatedRecord.senderName.trim().isEmpty
            ? existing.senderName
            : updatedRecord.senderName.trim());

    _records[index] = updatedRecord.copyWith(
      senderName: normalizedSender,
      content: normalizedContent,
      evidenceSnippet: _buildEvidenceSnippet(normalizedContent),
    );
    final sanitized = ImportService.instance.sanitizeRecords(
      _deduplicateRecords(_records),
    );
    _records
      ..clear()
      ..addAll(sanitized);
    _refreshImportedPackagesFromRecords();

    await rebuildLocalReport(
      statusMessage: '已更新聊天记录并重建本地报告。如需 AI 增强，请重新分析。',
    );
  }

  Future<void> deleteConversationRecord(String recordId) async {
    final index = _records.indexWhere((item) => item.id == recordId);
    if (index == -1) {
      _errorMessage = '未找到要删除的聊天记录。';
      notifyListeners();
      return;
    }
    _records.removeAt(index);
    _refreshImportedPackagesFromRecords();

    await rebuildLocalReport(
      statusMessage: '已删除聊天记录并重建本地报告。如需 AI 增强，请重新分析。',
    );
  }

  Future<void> deleteContact(String contactId) async {
    final matchedRecords = _records
        .where((item) => item.contactId == contactId)
        .toList(growable: false);
    if (matchedRecords.isEmpty) {
      _errorMessage = '未找到要删除的联系人。';
      notifyListeners();
      return;
    }

    final contactName = findInsightByContactId(contactId)?.contactName ??
        matchedRecords.first.contactName;
    _records.removeWhere((item) => item.contactId == contactId);
    _refreshImportedPackagesFromRecords();
    _syncTransientSelectionsToWorkspace();

    await rebuildLocalReport(
      statusMessage: '已删除 $contactName 的全部聊天记录，并重新生成本地关系结果。如需 AI 增强请重新分析。',
    );
  }

  Future<void> deleteImportedContacts({
    required String packageId,
    required List<String> contactIds,
  }) async {
    final normalizedPackageId = packageId.trim();
    final selectedIds = contactIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    if (normalizedPackageId.isEmpty || selectedIds.isEmpty) {
      _errorMessage = '请先选择要删除的导入内容。';
      notifyListeners();
      return;
    }

    final matchedRecords = _records
        .where(
          (item) =>
              item.packageId == normalizedPackageId &&
              selectedIds.contains(item.contactId),
        )
        .toList(growable: false);
    if (matchedRecords.isEmpty) {
      _errorMessage = '未找到要删除的导入内容。';
      notifyListeners();
      return;
    }

    final removedContactCount =
        matchedRecords.map((item) => item.contactId).toSet().length;
    final removedMessageCount = matchedRecords.length;

    _records.removeWhere(
      (item) =>
          item.packageId == normalizedPackageId &&
          selectedIds.contains(item.contactId),
    );
    _refreshImportedPackagesFromRecords();
    _syncTransientSelectionsToWorkspace();

    await rebuildLocalReport(
      statusMessage:
          '已从这次导入中删除 $removedContactCount 位联系人，共 $removedMessageCount 条消息。',
    );
  }

  Future<void> clearWorkspace() async {
    _importedPackages.clear();
    _records.clear();
    _currentReport = null;
    _selectedContactId = null;
    _clipboardAppendContactId = null;
    _clipboardAppendContactName = null;
    _errorMessage = null;
    _statusMessage = '本地工作区已清空。';
    await StorageService.instance.remove(AppConstants.keyImportedPackages);
    await StorageService.instance.remove(AppConstants.keyConversationRecords);
    await StorageService.instance.remove(AppConstants.keyComparisonReport);
    await StorageService.instance.remove(AppConstants.keySelectedContactId);
    notifyListeners();
  }

  Future<File> exportWebBridgePackage({String? outputPath}) async {
    if (_records.isEmpty) {
      throw const FileSystemException('请先导入聊天记录，再导出给网页版。');
    }

    final report = _currentReport ??
        LocalReportService.instance.buildReport(
          packages: _importedPackages,
          records: _records,
        );

    final exportResult = await WebHandoffService.exportBridgeFile(
      importedPackages: _importedPackages,
      records: _records,
      report: report,
      selectedContactId: _selectedContactId,
      outputPath: outputPath,
    );

    _statusMessage = '已导出网页版交接包：${exportResult.file.path}';
    _errorMessage = null;
    notifyListeners();
    return exportResult.file;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearClipboardAppendTarget() {
    _clipboardAppendContactId = null;
    _clipboardAppendContactName = null;
    _statusMessage = '已结束连续导入模式。';
    notifyListeners();
  }

  Future<void> _runChatWindowCapture({
    required bool append,
    required String preparationStatus,
  }) async {
    await _runImportWorkflow(
      preparationStatus: preparationStatus,
      timeout: const Duration(minutes: 5),
      timeoutMessage: '聊天窗口采集超时。请确认聊天窗口保持在前台后重试，或改用导出文件导入。',
      preferredContactId:
          append ? (_clipboardAppendContactId ?? _selectedContactId) : null,
      lockedContactName: append ? _clipboardAppendContactName : null,
      updateClipboardAppendTarget: true,
      loader: () async {
        final capture = await ChatWindowCaptureService.instance
            .captureForegroundConversation(
          prepareDelaySeconds: 0,
          passCount: 240,
          pauseMilliseconds: 820,
        );

        final lockedContactName =
            append ? _clipboardAppendContactName : capture.suggestedContactName;
        final baseName =
            lockedContactName ?? capture.suggestedContactName ?? '窗口采集';
        final fileName = '${_sanitizeSourceName(baseName)}_window_capture.txt';
        final seededText = [
          if ((capture.suggestedContactName ?? '').trim().isNotEmpty)
            '聊天记录：${capture.suggestedContactName}',
          if (capture.headerText.trim().isNotEmpty) capture.headerText.trim(),
          capture.text,
        ].join('\n');

        final imported = await ImportService.instance.importPlainText(
          seededText,
          sourceFile: fileName,
          lockedContactName: lockedContactName,
        );

        return ImportSessionData(
          importedPackage: imported.importedPackage,
          records: imported.records,
          warnings: [
            ...capture.warnings,
            ...imported.warnings,
          ],
        );
      },
    );
  }

  Future<void> _runImportWorkflow({
    required String preparationStatus,
    required Future<ImportSessionData> Function() loader,
    String? preferredContactId,
    String? lockedContactName,
    bool updateClipboardAppendTarget = false,
    ImportSessionReview? reviewSession,
    Duration timeout = const Duration(minutes: 2),
    String? timeoutMessage,
  }) async {
    if (_isImporting) {
      return;
    }

    _isImporting = true;
    _errorMessage = null;
    _statusMessage = preparationStatus;
    notifyListeners();

    try {
      var session = await loader().timeout(
        timeout,
        onTimeout: () => throw FileSystemException(
          timeoutMessage ?? '导入超时，请重试。',
        ),
      );
      if (reviewSession != null) {
        final reviewedSession = await reviewSession(session);
        if (reviewedSession == null) {
          _statusMessage = '已取消这次导入。';
          return;
        }
        session = reviewedSession;
      }
      _statusMessage =
          '已读取 ${session.importedPackage.messageCount} 条消息，正在整理联系人并生成报告...';
      notifyListeners();
      await _applyImportSession(
        session,
        preferredContactId: preferredContactId,
        lockedContactName: lockedContactName,
        updateClipboardAppendTarget: updateClipboardAppendTarget,
      );
    } catch (error) {
      if (error is FileSystemException) {
        _errorMessage = error.message;
      } else {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> _applyImportSession(
    ImportSessionData session, {
    String? preferredContactId,
    String? lockedContactName,
    bool updateClipboardAppendTarget = false,
  }) async {
    _importedPackages.insert(0, session.importedPackage);
    final alignedSessionRecords =
        ImportService.instance.alignImportedRecordsToWorkspace(
      existingRecords: _records,
      importedRecords: session.records,
      preferredContactId: preferredContactId,
      lockedContactName: lockedContactName,
    );
    final mergedRecords = ImportService.instance.sanitizeRecords(
      _deduplicateRecords([..._records, ...alignedSessionRecords]),
    );
    _records
      ..clear()
      ..addAll(mergedRecords);

    if (updateClipboardAppendTarget) {
      _updateClipboardAppendTarget(
        importedRecords: alignedSessionRecords,
        preferredContactId: preferredContactId,
      );
    }
    await _persistWorkspace();

    final warningText =
        session.warnings.isEmpty ? '' : ' ${session.warnings.join(' ')}';
    await rebuildLocalReport(
      statusMessage: '${session.importedPackage.packageSummary}$warningText',
    );
  }

  void _updateClipboardAppendTarget({
    required List<ConversationRecord> importedRecords,
    String? preferredContactId,
  }) {
    if (preferredContactId != null) {
      for (final record in importedRecords) {
        if (record.contactId == preferredContactId) {
          _clipboardAppendContactId = record.contactId;
          _clipboardAppendContactName = record.contactName;
          return;
        }
      }
    }

    if (importedRecords.isEmpty) {
      return;
    }

    final counts = <String, int>{};
    final names = <String, String>{};
    for (final record in importedRecords) {
      counts[record.contactId] = (counts[record.contactId] ?? 0) + 1;
      names.putIfAbsent(record.contactId, () => record.contactName);
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    _clipboardAppendContactId = best.key;
    _clipboardAppendContactName = names[best.key];
  }

  Future<void> _persistWorkspace() async {
    await StorageService.instance.setJsonList(
      AppConstants.keyImportedPackages,
      _importedPackages.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJsonList(
      AppConstants.keyConversationRecords,
      _records.map((item) => item.toJson()).toList(),
    );
    if (_currentReport != null) {
      await StorageService.instance.setJson(
        AppConstants.keyComparisonReport,
        _currentReport!.toJson(),
      );
    } else {
      await StorageService.instance.remove(AppConstants.keyComparisonReport);
    }

    if (_selectedContactId != null && _selectedContactId!.isNotEmpty) {
      await StorageService.instance.setString(
        AppConstants.keySelectedContactId,
        _selectedContactId!,
      );
    } else {
      await StorageService.instance.remove(AppConstants.keySelectedContactId);
    }
  }

  bool _reportMatchesRecords(ComparisonReport report) {
    if (_records.isEmpty) {
      return false;
    }
    if (report.workspaceFingerprint.trim().isEmpty) {
      return false;
    }
    return report.workspaceFingerprint == _currentWorkspaceFingerprint();
  }

  List<ConversationRecord> _deduplicateRecords(
      List<ConversationRecord> source) {
    final seen = <String>{};
    final results = <ConversationRecord>[];

    for (final item in source) {
      final key =
          '${item.contactId}|${item.senderName}|${item.sentAt.toIso8601String()}|${item.content}';
      if (seen.add(key)) {
        results.add(item);
      }
    }

    results.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return results;
  }

  String _sanitizeSourceName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'window_capture';
    }
    return normalized.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
  }

  void _syncSelectedContactId() {
    if (_selectedContactId != null &&
        _records.any((item) => item.contactId == _selectedContactId)) {
      return;
    }
    _selectedContactId = _currentReport?.relationshipRanking.isNotEmpty == true
        ? _currentReport!.relationshipRanking.first.contactId
        : null;
  }

  void _syncClipboardAppendTarget() {
    if (_clipboardAppendContactId == null ||
        _clipboardAppendContactId!.trim().isEmpty) {
      return;
    }

    for (final record in _records) {
      if (record.contactId == _clipboardAppendContactId) {
        _clipboardAppendContactName = record.contactName;
        return;
      }
    }

    _clipboardAppendContactId = null;
    _clipboardAppendContactName = null;
  }

  void _syncTransientSelectionsToWorkspace() {
    if (_selectedContactId != null &&
        !_records.any((item) => item.contactId == _selectedContactId)) {
      _selectedContactId = null;
    }
    _syncSelectedContactId();
    _syncClipboardAppendTarget();
  }

  void _refreshImportedPackagesFromRecords() {
    if (_importedPackages.isEmpty) {
      return;
    }

    final recordsByPackageId = <String, List<ConversationRecord>>{};
    for (final record in _records) {
      recordsByPackageId
          .putIfAbsent(record.packageId, () => <ConversationRecord>[])
          .add(record);
    }

    final refreshedPackages = <ImportedPackage>[];
    for (final package in _importedPackages) {
      final packageRecords = recordsByPackageId[package.id];
      if (packageRecords == null || packageRecords.isEmpty) {
        continue;
      }

      final contactCount =
          packageRecords.map((item) => item.contactId).toSet().length;
      final messageCount = packageRecords.length;
      refreshedPackages.add(
        package.copyWith(
          contactCount: contactCount,
          messageCount: messageCount,
          packageSummary: _buildPackageSummary(
            package: package,
            contactCount: contactCount,
            messageCount: messageCount,
          ),
        ),
      );
    }

    _importedPackages
      ..clear()
      ..addAll(refreshedPackages);
  }

  String _buildPackageSummary({
    required ImportedPackage package,
    required int contactCount,
    required int messageCount,
  }) {
    return '当前工作区保留 $contactCount 位联系人，共 $messageCount 条消息，来源：${_sourceLabel(package.source)}。';
  }

  String _sourceLabel(String source) {
    switch (source.trim().toLowerCase()) {
      case 'wechat':
        return '微信';
      case 'qq':
        return 'QQ';
      case 'chat_window':
      case 'window_capture':
        return '聊天窗口采集';
      case 'clipboard':
        return '剪贴板';
      case 'attachment':
        return '附件补录';
      default:
        return source.trim().isEmpty ? '未知来源' : source;
    }
  }

  String _currentWorkspaceFingerprint() {
    return LocalReportService.instance.buildWorkspaceFingerprint(
      packages: _importedPackages,
      records: _records,
    );
  }

  String _buildEvidenceSnippet(String content) {
    final normalized = content.trim();
    if (normalized.length <= 60) {
      return normalized;
    }
    return '${normalized.substring(0, 60)}...';
  }
}
