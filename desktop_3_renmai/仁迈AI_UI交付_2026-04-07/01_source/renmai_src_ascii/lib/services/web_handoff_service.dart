import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';

class WebHandoffExportResult {
  final File file;
  final int contactCount;
  final int recordCount;

  const WebHandoffExportResult({
    required this.file,
    required this.contactCount,
    required this.recordCount,
  });
}

class WebHandoffService {
  WebHandoffService._();

  static const String bridgeFormat = 'renmai-web-bridge-v1';

  static Future<WebHandoffExportResult> exportBridgeFile({
    required List<ImportedPackage> importedPackages,
    required List<ConversationRecord> records,
    required ComparisonReport report,
    String? selectedContactId,
    String? outputPath,
    DateTime? now,
  }) async {
    final exportTime = now ?? DateTime.now();
    final resolvedOutputPath = outputPath ?? defaultBridgePath(exportTime);
    final outputFile = File(resolvedOutputPath);
    if (!outputFile.parent.existsSync()) {
      await outputFile.parent.create(recursive: true);
    }

    final payload = buildBridgePayload(
      importedPackages: importedPackages,
      records: records,
      report: report,
      selectedContactId: selectedContactId,
      exportedAt: exportTime,
      exportedFileName: p.basename(resolvedOutputPath),
    );

    const encoder = JsonEncoder.withIndent('  ');
    await outputFile.writeAsString(encoder.convert(payload));

    return WebHandoffExportResult(
      file: outputFile,
      contactCount: report.contactInsights.length,
      recordCount: records.length,
    );
  }

  static String defaultBridgePath([DateTime? now]) {
    final exportTime = now ?? DateTime.now();
    final userProfile = Platform.environment['USERPROFILE'];
    final desktopPath = userProfile == null || userProfile.trim().isEmpty
        ? Directory.current.path
        : p.join(userProfile, 'Desktop');
    return p.join(desktopPath, defaultBridgeFileName(exportTime));
  }

  static String defaultBridgeFileName([DateTime? now]) {
    final exportTime = now ?? DateTime.now();
    final compactTime = _compactTime(exportTime);
    return 'renmai_web_bridge_$compactTime.json';
  }

  static Map<String, dynamic> buildBridgePayload({
    required List<ImportedPackage> importedPackages,
    required List<ConversationRecord> records,
    required ComparisonReport report,
    String? selectedContactId,
    DateTime? exportedAt,
    String? exportedFileName,
  }) {
    final exportTime = exportedAt ?? DateTime.now();
    final relationships = _buildRelationships(report);
    final selectedId = _resolveSelectedRelationshipId(
      relationships: relationships,
      report: report,
      selectedContactId: selectedContactId,
    );
    final matchedRelationships =
        relationships.where((item) => item['id'] == selectedId).toList();
    final primaryRelationship = matchedRelationships.isNotEmpty
        ? matchedRelationships.first
        : (relationships.isNotEmpty
            ? relationships.first
            : <String, dynamic>{});
    final primaryRelationshipId = primaryRelationship['id']?.toString();
    final primaryRelationType = primaryRelationship['type']?.toString() ?? 'friend';
    final analysisId = 'desktop-sync-${report.id}';
    final bridgeState = <String, dynamic>{
      'profile': {
        'name': '仁迈桌面交接',
        'title': '桌面直读结果已同步到网页端',
        'city': '',
        'phone': '',
        'bio':
            '这份在线工作台来自桌面端导出。适合继续查看联系人、报告、消息建议和礼物方向；真正要直读微信本地数据库时，请继续使用桌面版。',
      },
      'relationships': relationships,
      'analyses': [
        {
          'id': analysisId,
          'title': report.usedAi ? '桌面端 AI 增强报告' : '桌面端本地报告',
          'targetId': 'all',
          'score': _buildReportScore(report),
          'summary': report.overallSummary,
          'insights': _buildInsightBullets(report),
          'suggestions': _buildSuggestionBullets(report),
          'createdAt': _friendlyDate(exportTime),
        },
      ],
      'assistantHistory': _buildAssistantHistory(report, exportTime),
      'manualMessages': _buildManualMessages(report, exportTime),
      'messageDrafts': <String, dynamic>{},
      'favorites': const <String>[],
      'settings': {
        'weeklyDigest': true,
        'birthdayReminder': true,
        'privacyMode': false,
        'aiProvider': 'cloudflare-workers-ai',
        'aiModel': '@cf/meta/llama-3.1-8b-instruct-fast',
        'webTheme': 'warm',
        'webDensity': 'comfortable',
        'webGuideDismissed': false,
        'journeyGuideDismissed': false,
        'relationshipGuideDismissed': false,
        'analysisGuideDismissed': false,
        'messageGuideDismissed': false,
        'giftGuideDismissed': false,
      },
      'ui': {
        'activePage': 'dashboard',
        'relationView': 'list',
        'relationFilter': 'all',
        'relationSearch': '',
        'selectedRelationshipId': primaryRelationshipId,
        'selectedMessageRelationshipId': primaryRelationshipId,
        'selectedAnalysisId': analysisId,
        'selectedGiftRelationshipId': primaryRelationshipId,
        'giftRelation': primaryRelationType,
        'giftOccasion': '生日',
        'giftBudget': _buildGiftBudget(primaryRelationship),
        'assistantTargetId': primaryRelationshipId,
        'assistantIntent': '跟进',
        'assistantScenario': '我想先看清关系结果，再决定怎么继续回复。',
      },
      'bridge': {
        'source': 'desktop',
        'mode': 'desktop-to-web',
        'importedAt': exportTime.toIso8601String(),
        'fileName': exportedFileName ?? defaultBridgeFileName(exportTime),
        'contactCount': report.contactInsights.length,
        'recordCount': records.length,
        'packageCount': importedPackages.length,
        'reportTitle': report.usedAi ? '桌面端 AI 增强报告' : '桌面端本地报告',
        'reportUsedAi': report.usedAi,
      },
    };

    return {
      'format': bridgeFormat,
      'exported_at': exportTime.toIso8601String(),
      'source': 'renmai-desktop',
      'state': bridgeState,
    };
  }

  static List<Map<String, dynamic>> _buildRelationships(ComparisonReport report) {
    final rankingIndex = <String, int>{};
    for (var index = 0; index < report.relationshipRanking.length; index++) {
      rankingIndex[report.relationshipRanking[index].contactId] = index;
    }

    return report.contactInsights.map((insight) {
      final index = rankingIndex[insight.contactId] ?? 999;
      final type = _mapRelationType(insight);
      final noteParts = <String>[
        if (insight.referenceReason.trim().isNotEmpty) insight.referenceReason.trim(),
        if (insight.relationDetail.trim().isNotEmpty) insight.relationDetail.trim(),
        if (insight.suggestions.isNotEmpty) insight.suggestions.first.trim(),
      ].where((item) => item.isNotEmpty).take(3).toList();

      final tagPool = <String>[
        insight.referenceTier.trim(),
        insight.relationshipLevel.trim(),
        insight.activityLevel.trim(),
        ...insight.keywords.take(2).map((item) => item.trim()),
      ].where((item) => item.isNotEmpty).toSet().toList();

      final important = index < 5 || insight.intimacyScore >= 72;
      return {
        'id': insight.contactId,
        'name': insight.contactName,
        'type': type,
        'city': '',
        'birthday': '',
        'weeklyFrequency': _estimateWeeklyFrequency(insight),
        'monthlyDepth': _estimateMonthlyDepth(insight),
        'importanceTier': important ? 'important' : 'regular',
        'importanceRank': important ? (index + 1).clamp(1, 5) : 0,
        'lastContact': insight.lastInteractionAt == null
            ? ''
            : _friendlyDate(insight.lastInteractionAt!),
        'note': noteParts.isEmpty
            ? '这份联系人来自桌面端同步，适合先看关系判断，再决定下一步。'
            : noteParts.join(' · '),
        'tags': tagPool,
      };
    }).toList()
      ..sort((a, b) {
        final leftImportant = a['importanceTier'] == 'important' ? 0 : 1;
        final rightImportant = b['importanceTier'] == 'important' ? 0 : 1;
        if (leftImportant != rightImportant) {
          return leftImportant.compareTo(rightImportant);
        }
        return (a['importanceRank'] as int).compareTo(b['importanceRank'] as int);
      });
  }

  static String _resolveSelectedRelationshipId({
    required List<Map<String, dynamic>> relationships,
    required ComparisonReport report,
    String? selectedContactId,
  }) {
    if (selectedContactId != null &&
        relationships.any((item) => item['id'] == selectedContactId)) {
      return selectedContactId;
    }
    if (report.relationshipRanking.isNotEmpty) {
      return report.relationshipRanking.first.contactId;
    }
    return relationships.isNotEmpty ? relationships.first['id'].toString() : 'desktop-sync';
  }

  static List<String> _buildInsightBullets(ComparisonReport report) {
    final bullets = <String>[
      ...report.relationshipRanking
          .take(3)
          .map((item) => '${item.contactName}：${item.rationale.trim()}')
          .where((item) => item.isNotEmpty),
      ...report.evidenceQuotes.take(2),
    ];
    return bullets.where((item) => item.trim().isNotEmpty).take(5).toList();
  }

  static List<String> _buildSuggestionBullets(ComparisonReport report) {
    final suggestions = report.actionSuggestions
        .where((item) => item.trim().isNotEmpty)
        .take(5)
        .toList();
    if (suggestions.isNotEmpty) {
      return suggestions;
    }
    return report.contactInsights
        .expand((item) => item.suggestions)
        .where((item) => item.trim().isNotEmpty)
        .take(5)
        .toList();
  }

  static List<Map<String, dynamic>> _buildAssistantHistory(
    ComparisonReport report,
    DateTime exportTime,
  ) {
    return report.contactInsights.take(3).map((insight) {
      final giftSuggestion = insight.giftSuggestion;
      final reply = insight.suggestions.isNotEmpty
          ? insight.suggestions.first
          : '先围绕最近一次话题继续推进，不要一下子把目标说太满。';
      return {
        'id': 'assistant-${insight.contactId}',
        'targetId': insight.contactId,
        'intent': '跟进',
        'summary': insight.referenceReason.trim().isNotEmpty
            ? insight.referenceReason.trim()
            : '${insight.contactName} 当前更适合先稳住节奏，再往下推进。',
        'reply': reply,
        'giftAdvice': giftSuggestion == null
            ? ''
            : '${giftSuggestion.giftName} · ${giftSuggestion.reason}',
        'budgetText': giftSuggestion?.budgetRange ?? '先看报告里的预算提示',
        'needs': [
          ...insight.positiveSignals.take(2),
          ...insight.riskPoints.take(1),
        ].where((item) => item.trim().isNotEmpty).toList(),
        'source': report.usedAi ? 'model' : 'local',
        'createdAt': _friendlyDate(exportTime),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _buildManualMessages(
    ComparisonReport report,
    DateTime exportTime,
  ) {
    return report.contactInsights
        .expand((insight) => insight.evidenceQuotes.take(1).map((quote) {
              return {
                'id': 'bridge-msg-${insight.contactId}',
                'relationshipId': insight.contactId,
                'role': 'other',
                'text': quote,
                'meta': '来自桌面端摘要',
                'createdAt': _friendlyDate(exportTime),
              };
            }))
        .toList();
  }

  static int _buildReportScore(ComparisonReport report) {
    if (report.relationshipRanking.isEmpty) {
      return 0;
    }
    final total = report.relationshipRanking
        .fold<double>(0, (sum, item) => sum + item.score);
    return (total / report.relationshipRanking.length).round();
  }

  static int _buildGiftBudget(Map<String, dynamic> relationship) {
    final type = relationship['type']?.toString() ?? 'friend';
    switch (type) {
      case 'family':
        return 460;
      case 'partner':
        return 880;
      case 'mentor':
        return 320;
      case 'colleague':
        return 260;
      case 'classmate':
        return 220;
      default:
        return 300;
    }
  }

  static int _estimateWeeklyFrequency(ContactInsight insight) {
    final score = insight.intimacyScore;
    if (score >= 92) return 7;
    if (score >= 84) return 5;
    if (score >= 76) return 4;
    if (score >= 64) return 3;
    if (score >= 52) return 2;
    if (score >= 40) return 1;
    return 0;
  }

  static int _estimateMonthlyDepth(ContactInsight insight) {
    final signalWeight = insight.positiveSignals.length + insight.suggestions.length;
    if (insight.intimacyScore >= 88) return 6;
    if (insight.intimacyScore >= 78) return 4 + (signalWeight > 2 ? 1 : 0);
    if (insight.intimacyScore >= 62) return 3;
    if (insight.intimacyScore >= 48) return 2;
    return 1;
  }

  static String _mapRelationType(ContactInsight insight) {
    final hint = [
      insight.relationType,
      insight.relationDetail,
      insight.referenceReason,
      insight.contactName,
    ].join(' ');
    if (_containsAny(hint, const ['伴侣', '对象', '男友', '女友', '老婆', '老公'])) {
      return 'partner';
    }
    if (_containsAny(hint, const ['导师', '老师', 'mentor'])) {
      return 'mentor';
    }
    if (_containsAny(hint, const ['同事', '客户', '合作', '工作'])) {
      return 'colleague';
    }
    if (_containsAny(hint, const ['同学', '校友', '同窗'])) {
      return 'classmate';
    }
    if (_containsAny(hint, const ['爸爸', '妈妈', '父亲', '母亲', '家人', '亲人', '姑', '舅', '姨', '叔', '伯', '哥', '姐', '弟', '妹'])) {
      return 'family';
    }
    return 'friend';
  }

  static bool _containsAny(String source, List<String> needles) {
    return needles.any((item) => source.contains(item));
  }

  static String _friendlyDate(DateTime value) {
    final normalized = value.toLocal();
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static String _compactTime(DateTime value) {
    final normalized = value.toLocal();
    final month = normalized.month.toString().padLeft(2, '0');
    final hour = normalized.hour.toString().padLeft(2, '0');
    final minute = normalized.minute.toString().padLeft(2, '0');
    final second = normalized.second.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}$month${day}_$hour$minute$second';
  }
}
