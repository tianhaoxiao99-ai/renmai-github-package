import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/relationship_provider.dart';
import 'package:renmai/screens/contacts/contact_detail_screen.dart';
import 'package:renmai/screens/contacts/contacts_screen.dart';
import 'package:renmai/screens/report/report_screen.dart';

class _FakeAnalysisProvider extends AnalysisProvider {
  _FakeAnalysisProvider({
    required this.report,
    required this.contactRecords,
  });

  final ComparisonReport report;
  final Map<String, List<ConversationRecord>> contactRecords;

  @override
  Future<void> initialize() async {}

  @override
  ComparisonReport? get currentReport => report;

  @override
  List<ContactInsight> get contactInsights => report.contactInsights;

  @override
  List<RelationshipRankItem> get relationshipRanking => report.relationshipRanking;

  @override
  List<ConversationRecord> get records =>
      contactRecords.values.expand((items) => items).toList();

  @override
  bool get hasData => records.isNotEmpty;

  @override
  ContactInsight? findInsightByContactId(String contactId) {
    for (final insight in contactInsights) {
      if (insight.contactId == contactId) {
        return insight;
      }
    }
    return null;
  }

  @override
  List<ConversationRecord> recordsForContact(String contactId) {
    final records = List<ConversationRecord>.from(
      contactRecords[contactId] ?? const <ConversationRecord>[],
    )..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return records;
  }
}

void main() {
  testWidgets('report screen renders reference tier explanation',
      (WidgetTester tester) async {
    final report = _buildReport();
    final provider = _FakeAnalysisProvider(
      report: report,
      contactRecords: _buildRecords(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AnalysisProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme(preset: AppThemePreset.warmApricot),
          home: const ReportScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('评分依据'), findsOneWidget);
    expect(find.text('好（仅供参考）'), findsWidgets);
    expect(find.text('父母'), findsWidgets);
    expect(find.text('关系类型基线'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contacts and detail screens show relation reason',
      (WidgetTester tester) async {
    final report = _buildReport();
    final analysisProvider = _FakeAnalysisProvider(
      report: report,
      contactRecords: _buildRecords(),
    );
    final relationshipProvider = RelationshipProvider()
      ..syncFromAnalysis(analysisProvider);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AnalysisProvider>.value(value: analysisProvider),
          ChangeNotifierProvider<RelationshipProvider>.value(
            value: relationshipProvider,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(preset: AppThemePreset.warmApricot),
          routes: {
            '/': (_) => const ContactsScreen(),
            '/detail': (_) => const ContactDetailScreen(contactId: 'father'),
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('好（仅供参考）'), findsWidgets);
    expect(find.text('父母'), findsWidgets);
    expect(find.textContaining('父母属于直系家人'), findsOneWidget);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AnalysisProvider>.value(value: analysisProvider),
          ChangeNotifierProvider<RelationshipProvider>.value(
            value: relationshipProvider,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(preset: AppThemePreset.warmApricot),
          home: const ContactDetailScreen(contactId: 'father'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('父母属于直系家人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ComparisonReport _buildReport() {
  final fatherInsight = ContactInsight(
    contactId: 'father',
    contactName: '爸爸',
    relationshipLevel: '保持联系',
    intimacyScore: 84.6,
    referenceTier: '好',
    relationType: 'family',
    relationDetail: '父母',
    referenceReason: '父母属于直系家人，会优先保留较高的关系参考基线。最近互动很近，不是只靠旧记录撑起来。',
    activityLevel: '持续互动',
    totalMessages: 2,
    activeDays: 2,
    lastInteractionAt: DateTime(2026, 4, 12, 10, 0),
    positiveSignals: ['近 7 天仍有新的互动。'],
    riskPoints: [],
    suggestions: ['保持当前联系节奏。'],
    evidenceQuotes: ['爸爸：记得吃饭，周末回家'],
    keywords: ['回家'],
    giftSuggestion: null,
  );

  final friendInsight = ContactInsight(
    contactId: 'friend',
    contactName: '陆军',
    relationshipLevel: '稳定升温',
    intimacyScore: 81.2,
    referenceTier: '好',
    relationType: 'friend',
    relationDetail: '朋友',
    referenceReason: '朋友档主要看最近互动、双向回应和具体关心内容。最近互动很近，不是只靠旧记录撑起来。',
    activityLevel: '高频互动',
    totalMessages: 3,
    activeDays: 2,
    lastInteractionAt: DateTime(2026, 4, 12, 21, 0),
    positiveSignals: ['双方都有主动发言，交流并非单向输出。'],
    riskPoints: [],
    suggestions: ['继续围绕最近话题推进具体互动。'],
    evidenceQuotes: ['陆军：周末一起吃饭吧，我请你'],
    keywords: ['吃饭'],
    giftSuggestion: null,
  );

  return ComparisonReport(
    id: 'report_ui',
    generatedAt: DateTime(2026, 4, 13, 9, 0),
    overallSummary: '当前最值得优先处理的关系集中在爸爸和陆军。',
    relationshipRanking: [
      const RelationshipRankItem(
        contactId: 'father',
        contactName: '爸爸',
        score: 84.6,
        rationale: '父母 · 好（仅供参考） · 最近 1 天有互动 · 2 条消息 · 持续互动',
        referenceTier: '好',
        relationDetail: '父母',
      ),
      const RelationshipRankItem(
        contactId: 'friend',
        contactName: '陆军',
        score: 81.2,
        rationale: '朋友 · 好（仅供参考） · 最近 1 天有互动 · 3 条消息 · 高频互动',
        referenceTier: '好',
        relationDetail: '朋友',
      ),
    ],
    contactInsights: [fatherInsight, friendInsight],
    giftRecommendations: [],
    actionSuggestions: ['先联系爸爸，再约陆军见面。'],
    evidenceQuotes: ['爸爸：记得吃饭，周末回家'],
    sourcePackageIds: ['pkg_ui'],
    usedAi: false,
    workspaceFingerprint: 'ui',
  );
}

Map<String, List<ConversationRecord>> _buildRecords() {
  return {
    'father': [
      ConversationRecord(
        id: '1',
        packageId: 'pkg_ui',
        source: 'wechat',
        contactId: 'father',
        contactName: '爸爸',
        senderName: '爸爸',
        isSelf: false,
        sentAt: DateTime(2026, 4, 12, 9, 0),
        content: '记得吃饭，周末回家',
        messageType: 'text',
        evidenceSnippet: '记得吃饭，周末回家',
        sourceFile: 'memory',
      ),
      ConversationRecord(
        id: '2',
        packageId: 'pkg_ui',
        source: 'wechat',
        contactId: 'father',
        contactName: '爸爸',
        senderName: '我',
        isSelf: true,
        sentAt: DateTime(2026, 4, 12, 10, 0),
        content: '好，晚上给你回电话',
        messageType: 'text',
        evidenceSnippet: '好，晚上给你回电话',
        sourceFile: 'memory',
      ),
    ],
    'friend': [
      ConversationRecord(
        id: '3',
        packageId: 'pkg_ui',
        source: 'wechat',
        contactId: 'friend',
        contactName: '陆军',
        senderName: '陆军',
        isSelf: false,
        sentAt: DateTime(2026, 4, 12, 20, 0),
        content: '周末一起吃饭吧，我请你',
        messageType: 'text',
        evidenceSnippet: '周末一起吃饭吧，我请你',
        sourceFile: 'memory',
      ),
      ConversationRecord(
        id: '4',
        packageId: 'pkg_ui',
        source: 'wechat',
        contactId: 'friend',
        contactName: '陆军',
        senderName: '我',
        isSelf: true,
        sentAt: DateTime(2026, 4, 12, 20, 10),
        content: '好，我给你带礼物',
        messageType: 'text',
        evidenceSnippet: '好，我给你带礼物',
        sourceFile: 'memory',
      ),
    ],
  };
}
