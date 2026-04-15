class RelationshipRankItem {
  final String contactId;
  final String contactName;
  final double score;
  final String rationale;
  final String referenceTier;
  final String relationDetail;

  const RelationshipRankItem({
    required this.contactId,
    required this.contactName,
    required this.score,
    required this.rationale,
    this.referenceTier = '',
    this.relationDetail = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'contact_id': contactId,
      'contact_name': contactName,
      'score': score,
      'rationale': rationale,
      'reference_tier': referenceTier,
      'relation_detail': relationDetail,
    };
  }

  factory RelationshipRankItem.fromJson(Map<String, dynamic> json) {
    return RelationshipRankItem(
      contactId: (json['contact_id'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      rationale: (json['rationale'] ?? '').toString(),
      referenceTier: (json['reference_tier'] ?? '').toString(),
      relationDetail: (json['relation_detail'] ?? '').toString(),
    );
  }
}

class GiftRecommendation {
  final String id;
  final String contactId;
  final String contactName;
  final String giftName;
  final String reason;
  final String occasion;
  final String budgetRange;
  final double confidence;

  const GiftRecommendation({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.giftName,
    required this.reason,
    required this.occasion,
    required this.budgetRange,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'contact_name': contactName,
      'gift_name': giftName,
      'reason': reason,
      'occasion': occasion,
      'budget_range': budgetRange,
      'confidence': confidence,
    };
  }

  factory GiftRecommendation.fromJson(Map<String, dynamic> json) {
    return GiftRecommendation(
      id: (json['id'] ?? '').toString(),
      contactId: (json['contact_id'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      giftName: (json['gift_name'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      occasion: (json['occasion'] ?? '').toString(),
      budgetRange: (json['budget_range'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ContactInsight {
  final String contactId;
  final String contactName;
  final String relationshipLevel;
  final double intimacyScore;
  final String referenceTier;
  final String relationType;
  final String relationDetail;
  final String referenceReason;
  final String activityLevel;
  final int totalMessages;
  final int activeDays;
  final DateTime? lastInteractionAt;
  final List<String> positiveSignals;
  final List<String> riskPoints;
  final List<String> suggestions;
  final List<String> evidenceQuotes;
  final List<String> keywords;
  final GiftRecommendation? giftSuggestion;

  const ContactInsight({
    required this.contactId,
    required this.contactName,
    required this.relationshipLevel,
    required this.intimacyScore,
    this.referenceTier = '',
    this.relationType = '',
    this.relationDetail = '',
    this.referenceReason = '',
    required this.activityLevel,
    required this.totalMessages,
    required this.activeDays,
    required this.lastInteractionAt,
    required this.positiveSignals,
    required this.riskPoints,
    required this.suggestions,
    required this.evidenceQuotes,
    required this.keywords,
    required this.giftSuggestion,
  });

  Map<String, dynamic> toJson() {
    return {
      'contact_id': contactId,
      'contact_name': contactName,
      'relationship_level': relationshipLevel,
      'intimacy_score': intimacyScore,
      'reference_tier': referenceTier,
      'relation_type': relationType,
      'relation_detail': relationDetail,
      'reference_reason': referenceReason,
      'activity_level': activityLevel,
      'total_messages': totalMessages,
      'active_days': activeDays,
      'last_interaction_at': lastInteractionAt?.toIso8601String(),
      'positive_signals': positiveSignals,
      'risk_points': riskPoints,
      'suggestions': suggestions,
      'evidence_quotes': evidenceQuotes,
      'keywords': keywords,
      'gift_suggestion': giftSuggestion?.toJson(),
    };
  }

  factory ContactInsight.fromJson(Map<String, dynamic> json) {
    final giftJson = json['gift_suggestion'];
    return ContactInsight(
      contactId: (json['contact_id'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      relationshipLevel: (json['relationship_level'] ?? '').toString(),
      intimacyScore: (json['intimacy_score'] as num?)?.toDouble() ?? 0,
      referenceTier: (json['reference_tier'] ?? '').toString(),
      relationType: (json['relation_type'] ?? '').toString(),
      relationDetail: (json['relation_detail'] ?? '').toString(),
      referenceReason: (json['reference_reason'] ?? '').toString(),
      activityLevel: (json['activity_level'] ?? '').toString(),
      totalMessages: (json['total_messages'] as num?)?.toInt() ?? 0,
      activeDays: (json['active_days'] as num?)?.toInt() ?? 0,
      lastInteractionAt: DateTime.tryParse((json['last_interaction_at'] ?? '').toString()),
      positiveSignals: (json['positive_signals'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      riskPoints: (json['risk_points'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      suggestions: (json['suggestions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      evidenceQuotes: (json['evidence_quotes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      giftSuggestion: giftJson is Map<String, dynamic>
          ? GiftRecommendation.fromJson(giftJson)
          : (giftJson is Map ? GiftRecommendation.fromJson(Map<String, dynamic>.from(giftJson)) : null),
    );
  }
}

class ComparisonReport {
  final String id;
  final DateTime generatedAt;
  final String overallSummary;
  final List<RelationshipRankItem> relationshipRanking;
  final List<ContactInsight> contactInsights;
  final List<GiftRecommendation> giftRecommendations;
  final List<String> actionSuggestions;
  final List<String> evidenceQuotes;
  final List<String> sourcePackageIds;
  final bool usedAi;
  final String workspaceFingerprint;

  const ComparisonReport({
    required this.id,
    required this.generatedAt,
    required this.overallSummary,
    required this.relationshipRanking,
    required this.contactInsights,
    required this.giftRecommendations,
    required this.actionSuggestions,
    required this.evidenceQuotes,
    required this.sourcePackageIds,
    required this.usedAi,
    this.workspaceFingerprint = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'generated_at': generatedAt.toIso8601String(),
      'overall_summary': overallSummary,
      'relationship_ranking': relationshipRanking.map((item) => item.toJson()).toList(),
      'contact_insights': contactInsights.map((item) => item.toJson()).toList(),
      'gift_recommendations': giftRecommendations.map((item) => item.toJson()).toList(),
      'action_suggestions': actionSuggestions,
      'evidence_quotes': evidenceQuotes,
      'source_package_ids': sourcePackageIds,
      'used_ai': usedAi,
      'workspace_fingerprint': workspaceFingerprint,
    };
  }

  factory ComparisonReport.fromJson(Map<String, dynamic> json) {
    return ComparisonReport(
      id: (json['id'] ?? '').toString(),
      generatedAt: DateTime.tryParse((json['generated_at'] ?? '').toString()) ?? DateTime.now(),
      overallSummary: (json['overall_summary'] ?? '').toString(),
      relationshipRanking: (json['relationship_ranking'] as List<dynamic>? ?? const [])
          .map((item) => RelationshipRankItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      contactInsights: (json['contact_insights'] as List<dynamic>? ?? const [])
          .map((item) => ContactInsight.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      giftRecommendations: (json['gift_recommendations'] as List<dynamic>? ?? const [])
          .map((item) => GiftRecommendation.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      actionSuggestions: (json['action_suggestions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      evidenceQuotes: (json['evidence_quotes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      sourcePackageIds: (json['source_package_ids'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      usedAi: json['used_ai'] == true,
      workspaceFingerprint:
          (json['workspace_fingerprint'] ?? '').toString(),
    );
  }
}
