import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/services/local_report_service.dart';
import 'package:renmai/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.initialize();
  });

  setUp(() async {
    await StorageService.instance.clear();
  });

  test('rebuilds a stored report when workspace fingerprint is missing',
      () async {
    final packages = [_package('pkg_legacy')];
    final records = [
      _record(
        id: '1',
        packageId: 'pkg_legacy',
        contactId: 'alice',
        contactName: 'Alice',
        senderName: 'Alice',
        isSelf: false,
        sentAt: DateTime(2026, 3, 20, 10, 0),
        content: 'Remember the birthday gift.',
      ),
      _record(
        id: '2',
        packageId: 'pkg_legacy',
        contactId: 'alice',
        contactName: 'Alice',
        senderName: 'Me',
        isSelf: true,
        sentAt: DateTime(2026, 3, 20, 10, 5),
        content: 'I will prepare something thoughtful.',
      ),
    ];

    final legacyReport = LocalReportService.instance
        .buildReport(packages: packages, records: records, usedAi: true)
        .toJson()
      ..remove('workspace_fingerprint');

    await StorageService.instance.setJsonList(
      AppConstants.keyImportedPackages,
      packages.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJsonList(
      AppConstants.keyConversationRecords,
      records.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJson(
      AppConstants.keyComparisonReport,
      legacyReport,
    );

    final provider = AnalysisProvider();
    await provider.initialize();

    expect(provider.currentReport, isNotNull);
    expect(provider.currentReport!.workspaceFingerprint, isNotEmpty);
    expect(provider.currentReport!.usedAi, isFalse);
  });

  test('updates and deletes conversation records while rebuilding the report',
      () async {
    final packages = [_package('pkg_edit')];
    final records = [
      _record(
        id: '1',
        packageId: 'pkg_edit',
        contactId: 'bob',
        contactName: 'Bob',
        senderName: 'Bob',
        isSelf: false,
        sentAt: DateTime(2026, 3, 21, 9, 0),
        content: 'Let us meet this weekend.',
      ),
      _record(
        id: '2',
        packageId: 'pkg_edit',
        contactId: 'bob',
        contactName: 'Bob',
        senderName: 'Me',
        isSelf: true,
        sentAt: DateTime(2026, 3, 21, 9, 5),
        content: 'Sure, I will also bring a gift.',
      ),
    ];

    await StorageService.instance.setJsonList(
      AppConstants.keyImportedPackages,
      packages.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJsonList(
      AppConstants.keyConversationRecords,
      records.map((item) => item.toJson()).toList(),
    );

    final provider = AnalysisProvider();
    await provider.initialize();

    final firstFingerprint = provider.currentReport!.workspaceFingerprint;
    await provider.updateConversationRecord(
      provider.records.first.copyWith(
        content: 'Let us meet this weekend and celebrate your birthday.',
      ),
    );

    expect(
      provider.records.any(
        (item) => item.content.contains('celebrate your birthday'),
      ),
      isTrue,
    );
    expect(
      provider.currentReport!.workspaceFingerprint,
      isNot(firstFingerprint),
    );
    expect(provider.currentReport!.usedAi, isFalse);

    final secondFingerprint = provider.currentReport!.workspaceFingerprint;
    await provider.deleteConversationRecord('2');

    expect(provider.records.length, 1);
    expect(
      provider.currentReport!.workspaceFingerprint,
      isNot(secondFingerprint),
    );
    expect(provider.currentReport!.contactInsights.single.totalMessages, 1);
    expect(provider.importedPackages.single.messageCount, 1);
    expect(provider.importedPackages.single.contactCount, 1);
  });

  test('deletes irrelevant contacts and refreshes package statistics',
      () async {
    final packages = [
      _package('pkg_a', contactCount: 2, messageCount: 3),
      _package('pkg_b', contactCount: 1, messageCount: 1),
    ];
    final records = [
      _record(
        id: '1',
        packageId: 'pkg_a',
        contactId: 'alice',
        contactName: 'Alice',
        senderName: 'Alice',
        isSelf: false,
        sentAt: DateTime(2026, 3, 22, 8, 0),
        content: 'Let us confirm tomorrow.',
      ),
      _record(
        id: '2',
        packageId: 'pkg_a',
        contactId: 'bob',
        contactName: 'Bob',
        senderName: 'Bob',
        isSelf: false,
        sentAt: DateTime(2026, 3, 22, 8, 10),
        content: 'This is unrelated noise.',
      ),
      _record(
        id: '3',
        packageId: 'pkg_a',
        contactId: 'bob',
        contactName: 'Bob',
        senderName: 'Me',
        isSelf: true,
        sentAt: DateTime(2026, 3, 22, 8, 11),
        content: 'Acknowledged.',
      ),
      _record(
        id: '4',
        packageId: 'pkg_b',
        contactId: 'carol',
        contactName: 'Carol',
        senderName: 'Carol',
        isSelf: false,
        sentAt: DateTime(2026, 3, 22, 9, 0),
        content: 'Birthday gift reminder.',
      ),
    ];

    await StorageService.instance.setJsonList(
      AppConstants.keyImportedPackages,
      packages.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJsonList(
      AppConstants.keyConversationRecords,
      records.map((item) => item.toJson()).toList(),
    );

    final provider = AnalysisProvider();
    await provider.initialize();

    final firstFingerprint = provider.currentReport!.workspaceFingerprint;
    await provider.deleteContact('bob');

    expect(provider.records.where((item) => item.contactId == 'bob'), isEmpty);
    expect(
      provider.contactInsights.map((item) => item.contactId),
      isNot(contains('bob')),
    );
    expect(
      provider.currentReport!.workspaceFingerprint,
      isNot(firstFingerprint),
    );
    expect(provider.importedPackages.length, 2);
    expect(
      provider.importedPackages
          .firstWhere((item) => item.id == 'pkg_a')
          .messageCount,
      1,
    );
    expect(
      provider.importedPackages
          .firstWhere((item) => item.id == 'pkg_a')
          .contactCount,
      1,
    );
    expect(
      provider.importedPackages
          .firstWhere((item) => item.id == 'pkg_b')
          .messageCount,
      1,
    );
  });

  test('clearWorkspace clears imported data but keeps AI configuration',
      () async {
    final packages = [_package('pkg_reset')];
    final records = [
      _record(
        id: '1',
        packageId: 'pkg_reset',
        contactId: 'alice',
        contactName: 'Alice',
        senderName: 'Alice',
        isSelf: false,
        sentAt: DateTime(2026, 3, 23, 10, 0),
        content: 'Birthday gift reminder.',
      ),
      _record(
        id: '2',
        packageId: 'pkg_reset',
        contactId: 'alice',
        contactName: 'Alice',
        senderName: 'Me',
        isSelf: true,
        sentAt: DateTime(2026, 3, 23, 10, 5),
        content: 'I will handle it.',
      ),
    ];
    final report = LocalReportService.instance.buildReport(
      packages: packages,
      records: records,
    );

    await StorageService.instance.setString(
      AppConstants.keyAiBaseUrl,
      'https://example.test/v1',
    );
    await StorageService.instance.setString(
      AppConstants.keyAiModel,
      'gpt-test',
    );
    await StorageService.instance.setString(
      AppConstants.keyAiEnabled,
      'true',
    );
    await StorageService.instance.setJsonList(
      AppConstants.keyImportedPackages,
      packages.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJsonList(
      AppConstants.keyConversationRecords,
      records.map((item) => item.toJson()).toList(),
    );
    await StorageService.instance.setJson(
      AppConstants.keyComparisonReport,
      report.toJson(),
    );
    await StorageService.instance.setString(
      AppConstants.keySelectedContactId,
      'alice',
    );

    final provider = AnalysisProvider();
    await provider.initialize();

    expect(provider.hasData, isTrue);
    expect(provider.currentReport, isNotNull);
    expect(provider.selectedContactId, 'alice');

    await provider.clearWorkspace();

    expect(provider.records, isEmpty);
    expect(provider.importedPackages, isEmpty);
    expect(provider.currentReport, isNull);
    expect(provider.selectedContactId, isNull);
    expect(provider.statusMessage, '本地工作区已清空。');
    expect(provider.aiConfig.baseUrl, 'https://example.test/v1');
    expect(provider.aiConfig.model, 'gpt-test');
    expect(StorageService.instance.getJsonList(AppConstants.keyImportedPackages),
        isEmpty);
    expect(
      StorageService.instance.getJsonList(AppConstants.keyConversationRecords),
      isEmpty,
    );
    expect(
      StorageService.instance.getJson(AppConstants.keyComparisonReport),
      isNull,
    );
    expect(
      StorageService.instance.getString(AppConstants.keySelectedContactId),
      isNull,
    );
  });
}

ConversationRecord _record({
  required String id,
  required String packageId,
  required String contactId,
  required String contactName,
  required String senderName,
  required bool isSelf,
  required DateTime sentAt,
  required String content,
}) {
  return ConversationRecord(
    id: id,
    packageId: packageId,
    source: 'wechat',
    contactId: contactId,
    contactName: contactName,
    senderName: senderName,
    isSelf: isSelf,
    sentAt: sentAt,
    content: content,
    messageType: 'text',
    evidenceSnippet: content,
    sourceFile: 'memory',
  );
}

ImportedPackage _package(
  String id, {
  int contactCount = 1,
  int messageCount = 2,
}) {
  return ImportedPackage(
    id: id,
    source: 'wechat',
    originPaths: const ['memory'],
    discoveredFiles: const ['memory'],
    importedAt: DateTime.now(),
    status: 'completed',
    contactCount: contactCount,
    messageCount: messageCount,
    packageSummary: 'test package',
  );
}
