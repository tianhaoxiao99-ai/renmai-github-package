import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/web_handoff_service.dart';

void main() {
  group('WebHandoffService', () {
    test('builds a web-compatible desktop bridge payload', () {
      final report = _sampleReport();
      final payload = WebHandoffService.buildBridgePayload(
        importedPackages: [_samplePackage()],
        records: _sampleRecords(),
        report: report,
        selectedContactId: 'dad',
        exportedAt: DateTime(2026, 4, 13, 9, 30),
        exportedFileName: 'renmai_web_bridge_20260413_093000.json',
      );

      expect(payload['format'], WebHandoffService.bridgeFormat);

      final state = Map<String, dynamic>.from(payload['state'] as Map);
      final relationships =
          (state['relationships'] as List).cast<Map<String, dynamic>>();
      final analyses = (state['analyses'] as List).cast<Map<String, dynamic>>();
      final bridge = Map<String, dynamic>.from(state['bridge'] as Map);
      final ui = Map<String, dynamic>.from(state['ui'] as Map);

      expect(relationships, isNotEmpty);
      expect(relationships.first['id'], 'dad');
      expect(relationships.first['type'], 'family');
      expect(analyses.single['summary'], '当前核心关系稳定，适合继续保持节奏。');
      expect(ui['activePage'], 'dashboard');
      expect(ui['selectedRelationshipId'], 'dad');
      expect(bridge['source'], 'desktop');
      expect(bridge['contactCount'], 2);
      expect(bridge['fileName'], 'renmai_web_bridge_20260413_093000.json');
    });

    test('exports the bridge package to a file', () async {
      final tempDir = await Directory.systemTemp.createTemp('renmai_bridge_test');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final outputPath = '${tempDir.path}\\bridge.json';
      final result = await WebHandoffService.exportBridgeFile(
        importedPackages: [_samplePackage()],
        records: _sampleRecords(),
        report: _sampleReport(),
        selectedContactId: 'dad',
        outputPath: outputPath,
        now: DateTime(2026, 4, 13, 10, 0),
      );

      expect(result.file.path, outputPath);
      expect(result.file.existsSync(), isTrue);

      final decoded = jsonDecode(await result.file.readAsString()) as Map<String, dynamic>;
      final state = Map<String, dynamic>.from(decoded['state'] as Map);
      final bridge = Map<String, dynamic>.from(state['bridge'] as Map);

      expect(decoded['format'], WebHandoffService.bridgeFormat);
      expect(bridge['source'], 'desktop');
      expect(bridge['recordCount'], 2);
    });
  });
}

ImportedPackage _samplePackage() {
  return ImportedPackage(
    id: 'pkg-1',
    source: 'wechat_local_backup',
    originPaths: const ['C:\\mock\\xwechat_files'],
    discoveredFiles: const ['message_1.db'],
    importedAt: DateTime(2026, 4, 13, 8, 0),
    status: 'completed',
    contactCount: 2,
    messageCount: 2,
    packageSummary: '已导入 2 位联系人 / 2 条消息',
  );
}

List<ConversationRecord> _sampleRecords() {
  return [
    ConversationRecord(
      id: 'msg-1',
      packageId: 'pkg-1',
      source: 'wechat',
      contactId: 'dad',
      contactName: '爸爸',
      senderName: '爸爸',
      isSelf: false,
      sentAt: DateTime(2026, 4, 12, 18, 0),
      content: '周末回家吃饭。',
      messageType: 'text',
      evidenceSnippet: '周末回家吃饭。',
      sourceFile: 'message_1.db',
    ),
    ConversationRecord(
      id: 'msg-2',
      packageId: 'pkg-1',
      source: 'wechat',
      contactId: 'zheng',
      contactName: '郑成一',
      senderName: '我',
      isSelf: true,
      sentAt: DateTime(2026, 4, 12, 20, 0),
      content: '这周找你打球。',
      messageType: 'text',
      evidenceSnippet: '这周找你打球。',
      sourceFile: 'message_1.db',
    ),
  ];
}

ComparisonReport _sampleReport() {
  const dadGift = GiftRecommendation(
    id: 'gift-1',
    contactId: 'dad',
    contactName: '爸爸',
    giftName: '手作茶礼盒',
    reason: '更适合家人场景，稳妥且不突兀。',
    occasion: '节日',
    budgetRange: '¥220 - ¥460',
    confidence: 0.86,
  );

  return ComparisonReport(
    id: 'report-1',
    generatedAt: DateTime(2026, 4, 13, 8, 20),
    overallSummary: '当前核心关系稳定，适合继续保持节奏。',
    relationshipRanking: const [
      RelationshipRankItem(
        contactId: 'dad',
        contactName: '爸爸',
        score: 92,
        rationale: '家人关系高频互动，最近仍在持续升温。',
        referenceTier: '好',
        relationDetail: '父亲',
      ),
      RelationshipRankItem(
        contactId: 'zheng',
        contactName: '郑成一',
        score: 78,
        rationale: '高频朋友关系，当前互动明显高于一般联系人。',
        referenceTier: '中等',
        relationDetail: '朋友',
      ),
    ],
    contactInsights: const [
      ContactInsight(
        contactId: 'dad',
        contactName: '爸爸',
        relationshipLevel: '稳定升温',
        intimacyScore: 92,
        referenceTier: '好',
        relationType: '家人',
        relationDetail: '父亲',
        referenceReason: '直系家人，即使关系起伏也不应低于普通联系人。',
        activityLevel: '高频互动',
        totalMessages: 36,
        activeDays: 12,
        lastInteractionAt: null,
        positiveSignals: ['会主动邀约', '有现实关心'],
        riskPoints: ['最近表达偏少'],
        suggestions: ['先围绕周末安排继续跟进。'],
        evidenceQuotes: ['周末回家吃饭。'],
        keywords: ['家人', '周末'],
        giftSuggestion: dadGift,
      ),
      ContactInsight(
        contactId: 'zheng',
        contactName: '郑成一',
        relationshipLevel: '高频好友',
        intimacyScore: 78,
        referenceTier: '好',
        relationType: '朋友',
        relationDetail: '朋友',
        referenceReason: '近期高频互动，明显高于普通熟人。',
        activityLevel: '稳定互动',
        totalMessages: 24,
        activeDays: 8,
        lastInteractionAt: null,
        positiveSignals: ['最近互动自然'],
        riskPoints: [],
        suggestions: ['顺着最近的话题继续约一次线下。'],
        evidenceQuotes: ['这周找你打球。'],
        keywords: ['朋友', '打球'],
        giftSuggestion: null,
      ),
    ],
    giftRecommendations: const [dadGift],
    actionSuggestions: const [
      '先给爸爸确认周末时间。',
      '再和郑成一把线下见面敲定。',
    ],
    evidenceQuotes: const [
      '周末回家吃饭。',
      '这周找你打球。',
    ],
    sourcePackageIds: const ['pkg-1'],
    usedAi: false,
    workspaceFingerprint: 'fingerprint-1',
  );
}
