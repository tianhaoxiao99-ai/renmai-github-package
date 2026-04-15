import 'dart:math' as math;

import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';

class LocalReportService {
  LocalReportService._();

  static final LocalReportService instance = LocalReportService._();

  static const List<String> _positiveKeywords = [
    '谢谢',
    '辛苦',
    '想你',
    '喜欢',
    '开心',
    '哈哈',
    '见面',
    '一起',
    '生日',
    '礼物',
    '加油',
    '想吃',
    '周末',
    '回家',
    '抱抱',
    '放心',
    '记得',
    '陪你',
    '想见',
    '照顾',
  ];

  static const List<String> _negativeKeywords = [
    '算了',
    '生气',
    '忙',
    '改天',
    '下次',
    '再说',
    '累',
    '尴尬',
    '别',
    '不行',
    '不用',
    '没空',
    '冷静',
    '取消',
  ];

  static const List<String> _relationshipKeywords = [
    '谢谢',
    '辛苦了',
    '加油',
    '想你',
    '喜欢',
    '礼物',
    '生日',
    '纪念日',
    '一起',
    '见面',
    '吃饭',
    '看电影',
    '回家',
    '陪你',
    '照顾',
    '别担心',
    '放心',
    '抱抱',
    '晚安',
    '早安',
    '想见你',
    '周末',
    '记得',
    '给你带',
  ];

  static const List<String> _giftCatalog = [
    '精致茶具礼盒|拜访 / 节日|¥200-500|稳重体面，适合表达认真关心，尤其适合家人或偏正式关系。',
    '无线耳机|生日 / 奖励|¥300-800|实用又不失惊喜，适合高频互动的朋友、同事和熟人。',
    '永生花礼盒|纪念日 / 生日|¥150-300|更偏情绪表达，适合正在升温或需要仪式感的关系。',
    '按摩仪|节日 / 生日|¥400-900|照顾意味明显，适合家人或你想表达体贴的对象。',
    '手账礼盒|日常惊喜|¥80-200|轻量、低压，适合关系还在试探或修复阶段。',
    '香水小样套装|生日 / 纪念日|¥200-600|更有审美和心意，适合熟悉度较高的对象。',
    '咖啡豆礼盒|工作日 / 日常感谢|¥120-260|不冒犯也不敷衍，适合同事、合作方和经常见面的朋友。',
    '电影兑换券|周末 / 轻邀约|¥80-180|适合把线上聊天自然过渡到一次轻松见面。',
    '零食小礼箱|日常关心|¥60-160|门槛低、接受度高，适合熟人和还在建立节奏的关系。',
    '护颈靠枕|通勤 / 关心|¥100-220|偏实用照顾，适合同事、同学和高频见面对象。',
    '鲜花餐厅双人券|纪念日 / 见面|¥300-700|更适合明确升温或伴侣关系，强调仪式感和陪伴感。',
    '运动水杯|日常陪伴|¥90-180|轻负担、常使用，适合朋友、同学和运动型对象。',
    '书店礼卡|生日 / 日常激励|¥100-300|安全而有分寸，适合知识型、审美型和不宜送太重礼的人。',
    '家居香薰|乔迁 / 日常|¥150-320|氛围感强，适合熟悉度较高但还不想送太私人礼物的关系。',
    '营养礼盒|探望 / 节日|¥180-420|更适合父母长辈或需要表达照顾意味的对象。',
    '桌面文具套装|工作日 / 感谢|¥80-220|对办公场景友好，适合同事、合作方和老师。',
  ];

  static const List<String> _parentTokens = [
    '爸爸',
    '妈妈',
    '父亲',
    '母亲',
    '老爸',
    '老妈',
    '爸',
    '妈',
    '爹',
    '娘',
  ];

  static const List<String> _closeFamilyTokens = [
    '哥哥',
    '姐姐',
    '弟弟',
    '妹妹',
    '爷爷',
    '奶奶',
    '外公',
    '外婆',
    '姥爷',
    '姥姥',
  ];

  static const List<String> _extendedFamilyTokens = [
    '姑姑',
    '姑妈',
    '姑父',
    '舅舅',
    '舅妈',
    '阿姨',
    '姨妈',
    '姨父',
    '叔叔',
    '婶婶',
    '伯伯',
    '伯母',
    '姑',
    '舅',
    '姨',
    '叔',
    '伯',
    '表哥',
    '表姐',
    '表弟',
    '表妹',
    '堂哥',
    '堂姐',
    '堂弟',
    '堂妹',
  ];

  static const List<String> _partnerTokens = [
    '老公',
    '老婆',
    '媳妇',
    '爱人',
    '对象',
    '男朋友',
    '女朋友',
    '宝宝',
    '宝贝',
    '亲爱的',
  ];

  static const List<String> _classmateTokens = [
    '同学',
    '室友',
    '学长',
    '学姐',
    '学弟',
    '学妹',
  ];

  String buildWorkspaceFingerprint({
    required List<ImportedPackage> packages,
    required List<ConversationRecord> records,
  }) {
    final packageIds = packages.map((item) => item.id).toList()..sort();
    final sortedRecords = [...records]..sort((a, b) {
        final sentAtCompare = a.sentAt.compareTo(b.sentAt);
        if (sentAtCompare != 0) {
          return sentAtCompare;
        }
        final contactCompare = a.contactId.compareTo(b.contactId);
        if (contactCompare != 0) {
          return contactCompare;
        }
        final senderCompare = a.senderName.compareTo(b.senderName);
        if (senderCompare != 0) {
          return senderCompare;
        }
        return a.content.compareTo(b.content);
      });

    final buffer = StringBuffer()
      ..write('packages:${packageIds.join(",")}|')
      ..write('count:${sortedRecords.length}|');
    for (final record in sortedRecords) {
      buffer
        ..write(record.packageId)
        ..write('|')
        ..write(record.contactId)
        ..write('|')
        ..write(record.senderName)
        ..write('|')
        ..write(record.isSelf ? '1' : '0')
        ..write('|')
        ..write(record.sentAt.toIso8601String())
        ..write('|')
        ..write(record.messageType)
        ..write('|')
        ..write(record.content)
        ..write('\n');
    }

    return '${sortedRecords.length}_${packageIds.length}_${_hashString(buffer.toString())}';
  }

  ComparisonReport buildReport({
    required List<ImportedPackage> packages,
    required List<ConversationRecord> records,
    bool usedAi = false,
  }) {
    final workspaceFingerprint = buildWorkspaceFingerprint(
      packages: packages,
      records: records,
    );
    if (records.isEmpty) {
      return ComparisonReport(
        id: 'report_empty',
        generatedAt: DateTime.now(),
        overallSummary: '当前还没有可分析的聊天记录，先导入微信或 QQ 的聊天导出文件。',
        relationshipRanking: const [],
        contactInsights: const [],
        giftRecommendations: const [],
        actionSuggestions: const [
          '先导入至少一位联系人的聊天记录。',
          '建议优先导入最近互动较多、你最在意的联系人。',
          '确认本地报告方向正确后，再决定要不要启用 AI 增强。',
        ],
        evidenceQuotes: const [],
        sourcePackageIds: packages.map((item) => item.id).toList(),
        usedAi: usedAi,
        workspaceFingerprint: workspaceFingerprint,
      );
    }

    final grouped = <String, List<ConversationRecord>>{};
    for (final record in records) {
      grouped
          .putIfAbsent(record.contactId, () => <ConversationRecord>[])
          .add(record);
    }

    final insights = grouped.entries.map((entry) {
      final messages = [...entry.value]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return _buildInsight(messages);
    }).toList()
      ..sort(_compareInsights);

    final ranking = insights
        .map(
          (item) => RelationshipRankItem(
            contactId: item.contactId,
            contactName: item.contactName,
            score: item.intimacyScore,
            rationale: _buildRankingRationale(item),
            referenceTier: item.referenceTier,
            relationDetail: item.relationDetail,
          ),
        )
        .toList();

    final giftRecommendations = insights
        .map((item) => item.giftSuggestion)
        .whereType<GiftRecommendation>()
        .toList();

    final actionSuggestions = insights
        .expand((item) => item.suggestions.take(1))
        .toSet()
        .take(AppConstants.maxActionSuggestions)
        .toList();

    final evidenceQuotes = insights
        .expand((item) => item.evidenceQuotes.take(1))
        .where((item) => item.trim().isNotEmpty)
        .take(AppConstants.maxEvidenceQuotes)
        .toList();

    final topContacts = ranking
        .take(math.min(3, ranking.length))
        .map((item) => item.contactName)
        .toList();
    final summary = topContacts.isEmpty
        ? '已完成基础关系分析。'
        : '当前最值得优先经营的关系集中在 ${topContacts.join('、')}。建议先围绕高频、双向、带有积极回应的关系安排下一步互动。';

    return ComparisonReport(
      id: 'report_${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      overallSummary: summary,
      relationshipRanking: ranking,
      contactInsights: insights,
      giftRecommendations: giftRecommendations,
      actionSuggestions: actionSuggestions,
      evidenceQuotes: evidenceQuotes,
      sourcePackageIds: packages.map((item) => item.id).toList(),
      usedAi: usedAi,
      workspaceFingerprint: workspaceFingerprint,
    );
  }

  String _hashString(String value) {
    const mask = 0x1fffffffffffff;
    var hash = 1469598103934665603;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 1099511628211) & mask;
    }
    return hash.toRadixString(16);
  }

  ContactInsight _buildInsight(List<ConversationRecord> messages) {
    final contactId = messages.first.contactId;
    final contactName = messages.first.contactName;
    final totalMessages = messages.length;
    final activeDays = messages
        .map((item) =>
            '${item.sentAt.year}-${item.sentAt.month}-${item.sentAt.day}')
        .toSet()
        .length;
    final lastInteractionAt = messages.last.sentAt;
    final daysSinceLast = DateTime.now().difference(lastInteractionAt).inDays;
    final selfCount = messages.where((item) => item.isSelf).length;
    final otherCount = totalMessages - selfCount;
    final lastMessage = messages.last;
    final lastMessageFromSelf = lastMessage.isSelf;
    final trailingSelfMessages = _countTrailingSelfMessages(messages);
    final positiveHits = _countHits(messages, _positiveKeywords);
    final negativeHits = _countHits(messages, _negativeKeywords);
    final keywords = _extractKeywords(messages);
    final evidenceSegments = _selectRelationshipEvidence(messages);
    final hasPlanSignals = _containsAnyKeyword(
      keywords,
      const ['见面', '吃饭', '电影', '周末', '旅行'],
    );
    final hasMilestoneSignals = _containsAnyKeyword(
      keywords,
      const ['生日', '纪念日', '节日'],
    );
    final hasWorkSignals = _containsAnyKeyword(
      keywords,
      const ['项目', '合作', '工作'],
    );

    final hasServiceSignals = messages.any(
      (item) =>
          item.content.contains('课程') ||
          item.content.contains('课表') ||
          item.content.contains('老师') ||
          item.content.contains('地址'),
    );

    final relationProfile = _buildRelationProfile(
      contactName: contactName,
      keywords: keywords,
      hasWorkSignals: hasWorkSignals,
      hasServiceSignals: hasServiceSignals,
      hasPlanSignals: hasPlanSignals,
      hasMilestoneSignals: hasMilestoneSignals,
      positiveHits: positiveHits,
      activeDays: activeDays,
    );

    final reciprocalPairs = _countReciprocalPairs(messages);
    final signalScore = math.min(
      positiveHits * 4.0 +
          evidenceSegments.length * 9.0 +
          (hasPlanSignals ? 6.0 : 0.0) +
          (hasMilestoneSignals ? 6.0 : 0.0),
      40.0,
    );
    final reciprocityScore = math.min(
      reciprocalPairs * 2.8 +
          (otherCount > 0 && selfCount > 0
              ? math.max(
                  0.0,
                  10 - ((selfCount - otherCount).abs() / totalMessages) * 10,
                )
              : 0.0),
      24.0,
    );
    final continuityScore = math.min(activeDays * 1.8, 10.0);
    final familiarityScore = math.min(totalMessages / 10.0, 8.0);
    final recencyScore = math.max(
      0.0,
      12.0 - math.min(daysSinceLast.toDouble(), 24.0) / 2.0,
    );
    final negativePenalty = math.min(
      negativeHits * 4.0 +
          (trailingSelfMessages >= 2 ? 4.0 : 0.0) +
          (lastMessageFromSelf && daysSinceLast >= 3 ? 4.0 : 0.0),
      18.0,
    );
    var intimacyScore = signalScore +
        reciprocityScore +
        continuityScore +
        familiarityScore +
        recencyScore -
        negativePenalty;
    if (totalMessages < 10) {
      intimacyScore -= 6;
    }
    if (evidenceSegments.isEmpty && positiveHits == 0) {
      intimacyScore -= 12;
    }
    if ((hasWorkSignals || hasServiceSignals) &&
        !hasPlanSignals &&
        !hasMilestoneSignals) {
      intimacyScore -= 8;
    }
    intimacyScore += relationProfile.scoreBonus;
    intimacyScore = math.max(intimacyScore, relationProfile.floorScore);
    intimacyScore = intimacyScore.clamp(18.0, 96.0);
    intimacyScore = (intimacyScore * 100).roundToDouble() / 100;
    final hasStrongRelationshipSignals = evidenceSegments.length >= 2 ||
        positiveHits >= 3 ||
        hasPlanSignals ||
        hasMilestoneSignals;
    final hasModerateRelationshipSignals = evidenceSegments.isNotEmpty ||
        positiveHits >= 2 ||
        reciprocalPairs >= 3;

    final relationshipLevel = intimacyScore >= 85
        ? '重点经营'
        : intimacyScore >= 70
            ? '稳定升温'
            : intimacyScore >= 55
                ? '保持联系'
                : '有待修复';

    final activityLevel = daysSinceLast <= 3
        ? '高频互动'
        : daysSinceLast <= 14
            ? '持续互动'
            : daysSinceLast <= 30
                ? '轻度活跃'
                : '沉寂待激活';

    var effectiveRelationshipLevel = relationshipLevel;
    effectiveRelationshipLevel =
        intimacyScore >= 78 && hasStrongRelationshipSignals
            ? '重点经营'
            : intimacyScore >= 55 && hasModerateRelationshipSignals
                ? '稳定升温'
                : intimacyScore >= 42
                    ? '保持联系'
                    : '有待修复';
    if ((hasWorkSignals || hasServiceSignals) &&
        !hasPlanSignals &&
        !hasMilestoneSignals) {
      if (effectiveRelationshipLevel == '重点经营' ||
          effectiveRelationshipLevel == '稳定升温') {
        effectiveRelationshipLevel = '保持联系';
      } else if (effectiveRelationshipLevel == '有待修复' &&
          otherCount > 0 &&
          selfCount > 0) {
        effectiveRelationshipLevel = '保持联系';
      }
    }

    final positiveSignals = <String>[];
    if (daysSinceLast <= 7 && !lastMessageFromSelf) {
      positiveSignals.add('近 7 天仍有新的互动。');
    }
    if (activeDays >= 4) {
      positiveSignals.add('互动分布在多个日期，不是一次性对话。');
    }
    if (selfCount > 0 && otherCount > 0) {
      positiveSignals.add('双方都有主动发言，交流并非单向输出。');
    }
    if (evidenceSegments.isNotEmpty) {
      positiveSignals.add('聊天中出现了明确的关心、邀约或正向回应。');
    } else if (positiveHits > negativeHits) {
      positiveSignals.add('近期消息里的积极表达多于负面表达。');
    }

    final riskPoints = <String>[];
    if (daysSinceLast > 21) {
      riskPoints.add('最近 $daysSinceLast 天没有新互动，关系有降温风险。');
    }
    if (lastMessageFromSelf && daysSinceLast >= 3) {
      riskPoints.add('最近一次消息由你发出，已等待 $daysSinceLast 天仍未见明确回应。');
    }
    if (totalMessages < 12) {
      riskPoints.add('样本量偏少，当前判断更适合作为辅助参考。');
    }
    if (selfCount > otherCount * 2 && otherCount > 0) {
      riskPoints.add('你的主动输出明显更多，建议观察对方真实回应意愿。');
    }
    if (trailingSelfMessages >= 2 && otherCount > 0) {
      riskPoints.add('最近连续多条消息都由你主动发出，建议先暂停连续追发。');
    }
    if (negativeHits >= positiveHits + 2) {
      riskPoints.add('近期聊天中出现较多推迟、忙碌或负向措辞。');
    }

    final referenceTier = _referenceTierForScore(intimacyScore);
    final referenceReason = _buildReferenceReason(
      profile: relationProfile,
      referenceTier: referenceTier,
      positiveSignals: positiveSignals,
      riskPoints: riskPoints,
      daysSinceLast: daysSinceLast,
      hasStrongRelationshipSignals: hasStrongRelationshipSignals,
      hasModerateRelationshipSignals: hasModerateRelationshipSignals,
    );

    final suggestions = <String>[];
    if (lastMessageFromSelf && daysSinceLast >= 3) {
      suggestions.add('先不要连续追发，等 2 到 3 天后用一个低压力、可直接回答的问题重新触达。');
    } else if (daysSinceLast > 14) {
      suggestions.add('先发起一次低打扰问候，再观察对方回复质量。');
    } else {
      suggestions.add('保持当前联系节奏，优先围绕最近话题推进具体互动。');
    }

    if (effectiveRelationshipLevel == '重点经营' ||
        effectiveRelationshipLevel == '稳定升温') {
      if (hasPlanSignals) {
        suggestions.add('把聊天里提到的见面事项落到具体时间和地点，避免停留在“改天约”。');
      } else {
        suggestions.add('可以围绕最近提到的话题，准备更有针对性的礼物或见面安排。');
      }
    } else {
      suggestions.add('先做轻量联系，不建议一开始就安排高投入礼物。');
    }

    if (hasWorkSignals || hasServiceSignals) {
      suggestions.add('下次联系尽量带上明确事项、时间点或可执行结果，避免只停留在寒暄。');
    }
    if (hasMilestoneSignals) {
      suggestions.add('围绕重要节点提前准备，会比临时起意更有效。');
    }
    if (negativeHits >= positiveHits + 2) {
      suggestions.add('近期先减少高强度表达，优先用确认近况和提供帮助的方式恢复舒适感。');
    }

    final giftSuggestion = _pickGift(
      contactId: contactId,
      contactName: contactName,
      relationType: relationProfile.relationType,
      relationDetail: relationProfile.relationDetail,
      relationshipLevel: effectiveRelationshipLevel,
      keywords: keywords,
      intimacyScore: intimacyScore,
      totalMessages: totalMessages,
      activeDays: activeDays,
      positiveHits: positiveHits,
      hasPlanSignals: hasPlanSignals,
      hasMilestoneSignals: hasMilestoneSignals,
    );

    return ContactInsight(
      contactId: contactId,
      contactName: contactName,
      relationshipLevel: effectiveRelationshipLevel,
      intimacyScore: intimacyScore,
      referenceTier: referenceTier,
      relationType: relationProfile.relationType,
      relationDetail: relationProfile.relationDetail,
      referenceReason: referenceReason,
      activityLevel: activityLevel,
      totalMessages: totalMessages,
      activeDays: activeDays,
      lastInteractionAt: lastInteractionAt,
      positiveSignals: positiveSignals,
      riskPoints: riskPoints,
      suggestions: suggestions,
      evidenceQuotes: evidenceSegments,
      keywords: keywords,
      giftSuggestion: giftSuggestion,
    );
  }

  int _compareInsights(ContactInsight a, ContactInsight b) {
    final scoreCompare = b.intimacyScore.compareTo(a.intimacyScore);
    if (scoreCompare != 0) {
      return scoreCompare;
    }

    final lastInteractionCompare =
        (b.lastInteractionAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
              a.lastInteractionAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
    if (lastInteractionCompare != 0) {
      return lastInteractionCompare;
    }

    final activeDaysCompare = b.activeDays.compareTo(a.activeDays);
    if (activeDaysCompare != 0) {
      return activeDaysCompare;
    }

    final totalMessagesCompare = b.totalMessages.compareTo(a.totalMessages);
    if (totalMessagesCompare != 0) {
      return totalMessagesCompare;
    }

    final positiveSignalsCompare =
        b.positiveSignals.length.compareTo(a.positiveSignals.length);
    if (positiveSignalsCompare != 0) {
      return positiveSignalsCompare;
    }

    final riskPointsCompare = a.riskPoints.length.compareTo(b.riskPoints.length);
    if (riskPointsCompare != 0) {
      return riskPointsCompare;
    }

    final contactNameCompare = a.contactName.compareTo(b.contactName);
    if (contactNameCompare != 0) {
      return contactNameCompare;
    }

    return a.contactId.compareTo(b.contactId);
  }

  String _buildRankingRationale(ContactInsight insight) {
    final parts = <String>[];
    if (insight.relationDetail.isNotEmpty) {
      parts.add(insight.relationDetail);
    }
    if (insight.referenceTier.isNotEmpty) {
      parts.add(AppConstants.displayReferenceTier(insight.referenceTier));
    }
    if (insight.lastInteractionAt != null) {
      final days = DateTime.now().difference(insight.lastInteractionAt!).inDays;
      parts.add(days <= 0 ? '今天还有互动' : '最近 $days 天有互动');
    }
    parts.add('${insight.totalMessages} 条消息');
    parts.add('${insight.activeDays} 天有互动');
    parts.add(insight.activityLevel);
    if (insight.positiveSignals.isNotEmpty) {
      parts.add(insight.positiveSignals.first);
    } else if (insight.riskPoints.isNotEmpty) {
      parts.add(insight.riskPoints.first);
    }
    return parts.join(' · ');
  }

  String _referenceTierForScore(double score) {
    if (score >= 78) {
      return '好';
    }
    if (score >= 56) {
      return '中等';
    }
    return '不好';
  }

  String _buildReferenceReason({
    required _RelationProfile profile,
    required String referenceTier,
    required List<String> positiveSignals,
    required List<String> riskPoints,
    required int daysSinceLast,
    required bool hasStrongRelationshipSignals,
    required bool hasModerateRelationshipSignals,
  }) {
    final parts = <String>[profile.baselineReason];
    if (daysSinceLast <= 3) {
      parts.add('最近互动很近，不是只靠旧记录撑起来。');
    } else if (daysSinceLast <= 14) {
      parts.add('最近两周内仍有互动，关系还在持续。');
    } else if (daysSinceLast > 30) {
      parts.add('最近互动偏少，所以这档判断更偏关系基线，不代表当前节奏很好。');
    }

    if (positiveSignals.isNotEmpty) {
      parts.add(positiveSignals.first);
    } else if (hasStrongRelationshipSignals) {
      parts.add('聊天里出现了比较明确的关心、邀约或重要节点。');
    } else if (hasModerateRelationshipSignals) {
      parts.add('虽然强信号不算多，但至少能看到持续往来。');
    }

    if (riskPoints.isNotEmpty) {
      parts.add(riskPoints.first);
    }

    if (profile.needsAiRefinement) {
      parts.add('如果后面接入 AI，可继续结合备注、称呼和更长聊天，把关系类型细分得更准。');
    } else if (referenceTier == '中等' && profile.isFamily) {
      parts.add('家人即使近期互动偏弱，也不会按普通陌生联系人处理。');
    }

    return parts.join(' ');
  }

  bool _containsAnyKeyword(List<String> source, List<String> candidates) {
    for (final item in source) {
      if (candidates.contains(item)) {
        return true;
      }
    }
    return false;
  }

  int _countHits(List<ConversationRecord> messages, List<String> keywords) {
    var count = 0;
    for (final item in messages) {
      for (final keyword in keywords) {
        if (item.content.contains(keyword)) {
          count++;
        }
      }
    }
    return count;
  }

  List<String> _extractKeywords(List<ConversationRecord> messages) {
    const candidates = [
      '生日',
      '纪念日',
      '节日',
      '礼物',
      '吃饭',
      '见面',
      '项目',
      '合作',
      '工作',
      '回家',
      '家里',
      '旅行',
      '电影',
      '周末',
      '休息',
      '加班',
      '照顾',
      '陪你',
    ];

    final hits = <String, int>{};
    for (final message in messages) {
      for (final keyword in candidates) {
        if (message.content.contains(keyword)) {
          hits[keyword] = (hits[keyword] ?? 0) + 1;
        }
      }
    }

    final sorted = hits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((item) => item.key).toList();
  }

  List<String> _selectRelationshipEvidence(List<ConversationRecord> messages) {
    final candidates = <_EvidenceCandidate>[];

    for (var i = 0; i < messages.length; i++) {
      final current = messages[i];
      final score = _scoreRelationshipMessage(current);
      if (score <= 0) {
        continue;
      }

      final lines = <String>[
        '${current.senderName}：${current.content.trim()}',
      ];
      var totalScore = score.toDouble();

      if (i + 1 < messages.length) {
        final next = messages[i + 1];
        final nextScore = _scoreRelationshipMessage(next);
        final gap = next.sentAt.difference(current.sentAt).inHours.abs();
        if (next.senderName != current.senderName &&
            gap <= 36 &&
            nextScore >= 2) {
          lines.add('${next.senderName}：${next.content.trim()}');
          totalScore += nextScore * 0.8;
        }
      }

      final segment = lines.join('\n');
      if (_looksLikeEvidenceSegment(segment)) {
        candidates.add(_EvidenceCandidate(score: totalScore, text: segment));
      }
    }

    if (candidates.isEmpty) {
      return _fallbackEvidence(messages);
    }

    final seen = <String>{};
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates
        .where((item) => seen.add(item.text))
        .take(AppConstants.maxContactQuotes)
        .map((item) => item.text)
        .toList();
  }

  bool _looksLikeEvidenceSegment(String text) {
    final compact = text.trim();
    if (compact.isEmpty) {
      return false;
    }
    if (compact.length > 180) {
      return false;
    }
    return _relationshipKeywords.any(compact.contains);
  }

  List<String> _fallbackEvidence(List<ConversationRecord> messages) {
    final results = <String>[];
    for (final item in messages.reversed) {
      final content = item.content.trim();
      if (content.isEmpty || content.length > 90) {
        continue;
      }
      results.add('${item.senderName}：$content');
      if (results.length >= math.min(2, AppConstants.maxContactQuotes)) {
        break;
      }
    }
    return results;
  }

  int _scoreRelationshipMessage(ConversationRecord record) {
    final content = record.content.trim();
    if (content.isEmpty || content.length < 2) {
      return 0;
    }

    var score = 0;
    for (final keyword in _relationshipKeywords) {
      if (content.contains(keyword)) {
        score += 3;
      }
    }
    for (final keyword in _positiveKeywords) {
      if (content.contains(keyword)) {
        score += 2;
      }
    }
    for (final keyword in _negativeKeywords) {
      if (content.contains(keyword)) {
        score -= 2;
      }
    }
    if (content.contains('？') || content.contains('?')) {
      score += 1;
    }
    if (content.contains('见面') ||
        content.contains('一起') ||
        content.contains('吃饭')) {
      score += 2;
    }
    if (content.contains('谢谢') ||
        content.contains('辛苦') ||
        content.contains('加油')) {
      score += 2;
    }
    if (content.contains('礼物') ||
        content.contains('生日') ||
        content.contains('纪念日')) {
      score += 2;
    }

    return score;
  }

  GiftRecommendation? _pickGift({
    required String contactId,
    required String contactName,
    required String relationType,
    required String relationDetail,
    required String relationshipLevel,
    required List<String> keywords,
    required double intimacyScore,
    required int totalMessages,
    required int activeDays,
    required int positiveHits,
    required bool hasPlanSignals,
    required bool hasMilestoneSignals,
  }) {
    final evidenceStrength = positiveHits +
        (hasPlanSignals ? 2 : 0) +
        (hasMilestoneSignals ? 2 : 0) +
        (activeDays >= 4 ? 1 : 0);
    if (totalMessages < 8 ||
        intimacyScore < 38 ||
        (activeDays <= 1 && evidenceStrength <= 1)) {
      return null;
    }

    final candidateIndexes = _buildGiftPool(
      contactName: contactName,
      relationType: relationType,
      relationDetail: relationDetail,
      keywords: keywords,
      intimacyScore: intimacyScore,
      hasPlanSignals: hasPlanSignals,
      hasMilestoneSignals: hasMilestoneSignals,
    );
    if (candidateIndexes.isEmpty) {
      return null;
    }

    final seed = [
      contactId,
      contactName,
      relationType,
      relationDetail,
      relationshipLevel,
      keywords.join(','),
      intimacyScore.toStringAsFixed(2),
    ].join('|');
    final index = candidateIndexes[_stableGiftIndex(seed, candidateIndexes.length)];
    final candidate = _giftCatalog[index].split('|');
    final confidence = _giftConfidence(
      intimacyScore: intimacyScore,
      positiveHits: positiveHits,
      activeDays: activeDays,
      hasPlanSignals: hasPlanSignals,
      hasMilestoneSignals: hasMilestoneSignals,
    );
    final reasonHint = _giftReasonHint(
      relationType: relationType,
      relationDetail: relationDetail,
      keywords: keywords,
      hasPlanSignals: hasPlanSignals,
      hasMilestoneSignals: hasMilestoneSignals,
    );

    return GiftRecommendation(
      id: 'gift_${contactId}_${candidate[0]}',
      contactId: contactId,
      contactName: contactName,
      giftName: candidate[0],
      reason:
          '${candidate[3]}$reasonHint 当前关系阶段是“$relationshipLevel”，这份礼物更容易既表达心意，又不会显得用力过猛。',
      occasion: candidate[1],
      budgetRange: candidate[2],
      confidence: confidence,
    );
  }

  List<int> _buildGiftPool({
    required String contactName,
    required String relationType,
    required String relationDetail,
    required List<String> keywords,
    required double intimacyScore,
    required bool hasPlanSignals,
    required bool hasMilestoneSignals,
  }) {
    final pool = <int>{};
    final normalizedName = contactName.replaceAll(RegExp(r'\s+'), '');

    switch (relationType) {
      case AppConstants.relationTypeFamily:
        pool.addAll(
          _containsRoleToken(normalizedName, _parentTokens) ||
                  relationDetail == '父母'
              ? const [14, 3, 0, 13]
              : const [0, 3, 14, 11],
        );
        break;
      case AppConstants.relationTypePartner:
        pool.addAll(const [10, 2, 5, 13]);
        break;
      case AppConstants.relationTypeColleague:
        pool.addAll(const [15, 6, 9, 12, 1]);
        break;
      case AppConstants.relationTypeClassmate:
        pool.addAll(const [7, 11, 12, 8, 9]);
        break;
      case AppConstants.relationTypeFriend:
        pool.addAll(const [7, 5, 6, 11, 13, 1]);
        break;
      default:
        pool.addAll(const [4, 8, 12, 6, 9]);
        break;
    }

    if (keywords.contains('项目') ||
        keywords.contains('合作') ||
        keywords.contains('工作')) {
      pool.addAll(const [15, 6, 9, 12]);
    }
    if (keywords.contains('生日')) {
      pool.addAll(const [5, 2, 12, 11, 1]);
    }
    if (keywords.contains('纪念日')) {
      pool.addAll(const [10, 2, 5, 13]);
    }
    if (keywords.contains('回家') || keywords.contains('家里')) {
      pool.addAll(const [14, 3, 0]);
    }
    if (hasPlanSignals) {
      pool.addAll(const [7, 10, 11]);
    }
    if (hasMilestoneSignals) {
      pool.addAll(const [2, 5, 10]);
    }
    if (intimacyScore >= 82) {
      pool.addAll(const [10, 5, 13, 1]);
    } else if (intimacyScore < 60) {
      pool.addAll(const [4, 8, 12, 9]);
    }

    return pool.toList();
  }

  int _stableGiftIndex(String seed, int length) {
    if (length <= 1) {
      return 0;
    }
    var value = 0;
    for (final codeUnit in seed.codeUnits) {
      value = (value * 131 + codeUnit) & 0x7fffffff;
    }
    return value % length;
  }

  double _giftConfidence({
    required double intimacyScore,
    required int positiveHits,
    required int activeDays,
    required bool hasPlanSignals,
    required bool hasMilestoneSignals,
  }) {
    final signalBoost = math.min(positiveHits, 4) * 0.025 +
        math.min(activeDays, 5) * 0.015 +
        (hasPlanSignals ? 0.04 : 0) +
        (hasMilestoneSignals ? 0.03 : 0);
    final scoreBoost = ((intimacyScore - 40) / 60).clamp(0.0, 1.0) * 0.2;
    return (0.56 + signalBoost + scoreBoost).clamp(0.58, 0.92).toDouble();
  }

  String _giftReasonHint({
    required String relationType,
    required String relationDetail,
    required List<String> keywords,
    required bool hasPlanSignals,
    required bool hasMilestoneSignals,
  }) {
    if (relationType == AppConstants.relationTypeFamily) {
      return ' 结合你们的家人关系，这类礼物更容易落到照顾和实际使用上。';
    }
    if (relationType == AppConstants.relationTypePartner) {
      return ' 你们更适合带一点仪式感和陪伴感的方向。';
    }
    if (relationType == AppConstants.relationTypeColleague) {
      return ' 这类建议会尽量避开过度私人化，保持体面和边界感。';
    }
    if (hasMilestoneSignals || keywords.contains('生日') || keywords.contains('纪念日')) {
      return ' 聊天里出现过节点型信号，所以礼物可以更聚焦纪念意义。';
    }
    if (hasPlanSignals) {
      return ' 你们已经有线下或具体安排信号，礼物更适合做轻量助推。';
    }
    if (relationDetail.isNotEmpty) {
      return ' 结合当前识别到的“$relationDetail”关系，这个方向更自然。';
    }
    return '';
  }

  int _countTrailingSelfMessages(List<ConversationRecord> messages) {
    var count = 0;
    for (final message in messages.reversed) {
      if (!message.isSelf) {
        break;
      }
      count++;
    }
    return count;
  }

  int _countReciprocalPairs(List<ConversationRecord> messages) {
    if (messages.length < 2) {
      return 0;
    }

    var count = 0;
    for (var index = 1; index < messages.length; index++) {
      final previous = messages[index - 1];
      final current = messages[index];
      final gap = current.sentAt.difference(previous.sentAt).inHours.abs();
      if (previous.isSelf != current.isSelf && gap <= 72) {
        count++;
      }
    }
    return count;
  }

  _RelationProfile _buildRelationProfile({
    required String contactName,
    required List<String> keywords,
    required bool hasWorkSignals,
    required bool hasServiceSignals,
    required bool hasPlanSignals,
    required bool hasMilestoneSignals,
    required int positiveHits,
    required int activeDays,
  }) {
    final normalizedName = contactName.replaceAll(RegExp(r'\s+'), '');

    if (_containsRoleToken(normalizedName, _parentTokens)) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypeFamily,
        relationDetail: '父母',
        scoreBonus: 8,
        floorScore: 82,
        isFamily: true,
        baselineReason: '父母属于直系家人，会优先保留较高的关系参考基线。',
      );
    }

    if (_containsRoleToken(normalizedName, _closeFamilyTokens)) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypeFamily,
        relationDetail: '直系家人',
        scoreBonus: 2,
        floorScore: 64,
        isFamily: true,
        baselineReason: '直系家人会保留家人档位，不会只按聊天频率来算。',
      );
    }

    if (_containsRoleToken(normalizedName, _extendedFamilyTokens)) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypeFamily,
        relationDetail: '亲戚',
        scoreBonus: 0,
        floorScore: 58,
        isFamily: true,
        baselineReason: '亲戚会保留家人档位，再按最近互动强弱做档内区分。',
      );
    }

    if (_containsRoleToken(normalizedName, _partnerTokens) ||
        keywords.contains('纪念日')) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypePartner,
        relationDetail: '伴侣',
        scoreBonus: 6,
        floorScore: 76,
        baselineReason: '伴侣关系会优先看长期亲密度，不会只按单次聊天热度判断。',
      );
    }

    if (hasWorkSignals || hasServiceSignals) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypeColleague,
        relationDetail: '同事',
        baselineReason: '当前更像事务或工作联系，所以主要看回应质量和持续度。',
      );
    }

    if (_containsRoleToken(normalizedName, _classmateTokens)) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypeClassmate,
        relationDetail: '同学',
        baselineReason: '同学关系更看最近是否还在持续联系，而不是默认判高。',
      );
    }

    final looksLikeCloseFriend =
        hasPlanSignals ||
        hasMilestoneSignals ||
        positiveHits >= 2 ||
        activeDays >= 4;
    if (looksLikeCloseFriend) {
      return const _RelationProfile(
        relationType: AppConstants.relationTypeFriend,
        relationDetail: '朋友',
        baselineReason: '朋友档主要看最近互动、双向回应和具体关心内容。',
      );
    }

    return const _RelationProfile(
      relationType: AppConstants.relationTypeAcquaintance,
      relationDetail: '熟人',
      baselineReason: '当前没有识别出稳定的亲属或高亲密关系标签，先按互动证据判断。',
      needsAiRefinement: true,
    );
  }

  bool _containsRoleToken(String source, List<String> tokens) {
    for (final token in tokens) {
      if (source.contains(token)) {
        return true;
      }
    }
    return false;
  }
}

class _EvidenceCandidate {
  final double score;
  final String text;

  const _EvidenceCandidate({
    required this.score,
    required this.text,
  });
}

class _RelationProfile {
  final String relationType;
  final String relationDetail;
  final double scoreBonus;
  final double floorScore;
  final bool isFamily;
  final bool needsAiRefinement;
  final String baselineReason;

  const _RelationProfile({
    required this.relationType,
    required this.relationDetail,
    this.scoreBonus = 0,
    this.floorScore = 0,
    this.isFamily = false,
    this.needsAiRefinement = false,
    required this.baselineReason,
  });
}

