import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/screens/import/import_screen.dart';
import 'package:renmai/services/import_service.dart';

void main() {
  testWidgets('wechat raw import asks the user to choose contacts first',
      (WidgetTester tester) async {
    final provider = _ReviewingAnalysisProvider();
    const accountRoot =
        r'C:\Users\Administrator\Documents\xwechat_files\wxid_alpha';

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AnalysisProvider>.value(
        value: provider,
        child: MaterialApp(
          home: ImportScreen(
            discoverWeChatAccountRoots: () => const [accountRoot],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('直读微信本地数据库'));
    await tester.pumpAndSettle();

    expect(find.text('选择要导入的联系人'), findsOneWidget);
    expect(find.text('好友A'), findsOneWidget);
    expect(find.text('同事B'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, '同事B'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('导入已选'));
    await tester.pumpAndSettle();

    expect(provider.reviewedSession, isNotNull);
    expect(
      provider.reviewedSession!.records.map((item) => item.contactId).toSet(),
      {'contact_a'},
    );
    expect(provider.reviewedSession!.importedPackage.contactCount, 1);
  });

  testWidgets('import management can delete selected contacts from one session',
      (WidgetTester tester) async {
    final provider = _ManagingAnalysisProvider();

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AnalysisProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: ImportScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('管理已导入内容'), findsOneWidget);

    await tester.tap(find.text('管理已导入内容'));
    await tester.pumpAndSettle();

    expect(find.text('删除这次导入的内容'), findsOneWidget);
    expect(find.text('好友A'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '好友A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除已选内容'));
    await tester.pumpAndSettle();

    expect(provider.deleteCalls, hasLength(1));
    expect(provider.deleteCalls.single.packageId, 'pkg_one');
    expect(provider.deleteCalls.single.contactIds, {'contact_a'});
  });

  testWidgets('import management can delete an entire imported session',
      (WidgetTester tester) async {
    final provider = _ManagingAnalysisProvider();

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AnalysisProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: ImportScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('管理已导入内容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除本次全部内容'));
    await tester.pumpAndSettle();

    expect(provider.deleteCalls, hasLength(1));
    expect(provider.deleteCalls.single.packageId, 'pkg_one');
    expect(provider.deleteCalls.single.contactIds, {'contact_a', 'contact_b'});
  });

  testWidgets('busy import state uses neutral processing label',
      (WidgetTester tester) async {
    final provider = _BusyAnalysisProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AnalysisProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: ImportScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('处理中...'), findsOneWidget);
    expect(find.text('准备采集中...'), findsNothing);
    expect(
      find.text('正在直读微信本地数据库，请先打开电脑端微信并保持登录...'),
      findsOneWidget,
    );
  });
}

ConversationRecord _record({
  required String packageId,
  required String contactId,
  required String contactName,
  required String senderName,
  required String content,
}) {
  return ConversationRecord(
    id: '$packageId-$contactId-${content.hashCode}',
    packageId: packageId,
    source: 'wechat',
    contactId: contactId,
    contactName: contactName,
    senderName: senderName,
    isSelf: false,
    sentAt: DateTime(2026, 4, 11, 10, 0),
    content: content,
    messageType: 'text',
    evidenceSnippet: content,
    sourceFile: 'db',
  );
}

class _ReviewingAnalysisProvider extends AnalysisProvider {
  ImportSessionData? reviewedSession;

  @override
  List<ImportedPackage> get importedPackages => const [];

  @override
  List<ConversationRecord> get records => const [];

  @override
  bool get isImporting => false;

  @override
  String? get statusMessage => '就绪';

  @override
  String? get errorMessage => null;

  @override
  Future<void> importWeChatLocalBackup({
    List<String>? accountRoots,
    ImportSessionReview? reviewSession,
  }) async {
    final session = ImportSessionData(
      importedPackage: ImportedPackage(
        id: 'pkg_review',
        source: 'wechat',
        originPaths: accountRoots ?? const [],
        discoveredFiles: const ['db'],
        importedAt: DateTime(2026, 4, 11, 10, 0),
        status: 'completed',
        contactCount: 2,
        messageCount: 3,
        packageSummary: '已识别 2 位联系人，共 3 条有效消息，来源：微信。',
      ),
      records: [
        _record(
          packageId: 'pkg_review',
          contactId: 'contact_a',
          contactName: '好友A',
          senderName: '好友A',
          content: '早上好',
        ),
        _record(
          packageId: 'pkg_review',
          contactId: 'contact_b',
          contactName: '同事B',
          senderName: '同事B',
          content: '今晚开会吗',
        ),
        _record(
          packageId: 'pkg_review',
          contactId: 'contact_b',
          contactName: '同事B',
          senderName: '同事B',
          content: '我先整理一下材料',
        ),
      ],
      warnings: const [],
    );

    reviewedSession =
        reviewSession == null ? session : await reviewSession(session);
  }
}

class _DeleteCall {
  final String packageId;
  final Set<String> contactIds;

  const _DeleteCall({
    required this.packageId,
    required this.contactIds,
  });
}

class _ManagingAnalysisProvider extends AnalysisProvider {
  final List<_DeleteCall> deleteCalls = [];

  final ImportedPackage _package = ImportedPackage(
    id: 'pkg_one',
    source: 'wechat',
    originPaths: const [r'C:\backup\pkg_one'],
    discoveredFiles: const [r'C:\backup\pkg_one\chat.txt'],
    importedAt: DateTime(2026, 4, 11, 9, 0),
    status: 'completed',
    contactCount: 2,
    messageCount: 3,
    packageSummary: '已识别 2 位联系人，共 3 条有效消息，来源：微信。',
  );

  final List<ConversationRecord> _records = [
    _record(
      packageId: 'pkg_one',
      contactId: 'contact_a',
      contactName: '好友A',
      senderName: '好友A',
      content: '今天见面吗',
    ),
    _record(
      packageId: 'pkg_one',
      contactId: 'contact_b',
      contactName: '同事B',
      senderName: '同事B',
      content: '方案我发你了',
    ),
    _record(
      packageId: 'pkg_one',
      contactId: 'contact_b',
      contactName: '同事B',
      senderName: '同事B',
      content: '晚上再确认一个',
    ),
  ];

  @override
  List<ImportedPackage> get importedPackages => [_package];

  @override
  List<ConversationRecord> get records => List.unmodifiable(_records);

  @override
  bool get isImporting => false;

  @override
  String? get statusMessage => '就绪';

  @override
  String? get errorMessage => null;

  @override
  List<ConversationRecord> recordsForPackage(String packageId) {
    return _records.where((item) => item.packageId == packageId).toList();
  }

  @override
  Future<void> deleteImportedContacts({
    required String packageId,
    required List<String> contactIds,
  }) async {
    deleteCalls.add(
      _DeleteCall(
        packageId: packageId,
        contactIds: contactIds.toSet(),
      ),
    );
  }
}

class _BusyAnalysisProvider extends AnalysisProvider {
  @override
  bool get isImporting => true;

  @override
  String? get statusMessage => '正在直读微信本地数据库，请先打开电脑端微信并保持登录...';
}
