import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/providers/analysis_provider.dart';

class RelationshipProvider extends ChangeNotifier {
  List<ContactInsight> _relationships = [];
  ContactInsight? _selectedRelation;
  String _filterType = 'all';

  List<ContactInsight> get relationships => _relationships;
  ContactInsight? get selectedRelation => _selectedRelation;
  String get filterType => _filterType;

  List<ContactInsight> get filteredRelationships {
    if (_filterType == 'all') {
      return _relationships;
    }
    return _relationships
        .where((item) => _relationTypeFromInsight(item) == _filterType)
        .toList();
  }

  Map<String, int> get typeDistribution {
    final result = <String, int>{};
    for (final item in _relationships) {
      final relationType = _relationTypeFromInsight(item);
      result[relationType] = (result[relationType] ?? 0) + 1;
    }
    return result;
  }

  void syncFromAnalysis(AnalysisProvider analysis) {
    final nextRelationships = List<ContactInsight>.from(
      analysis.contactInsights,
    )..sort((a, b) => b.intimacyScore.compareTo(a.intimacyScore));

    _relationships = nextRelationships;
    if (_selectedRelation != null) {
      try {
        _selectedRelation = _relationships.firstWhere(
          (item) => item.contactId == _selectedRelation!.contactId,
        );
      } catch (_) {
        _selectedRelation = _relationships.isNotEmpty ? _relationships.first : null;
      }
    } else if (_relationships.isNotEmpty) {
      _selectedRelation = _relationships.first;
    }
    notifyListeners();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  void selectRelation(ContactInsight relation) {
    _selectedRelation = relation;
    notifyListeners();
  }

  ContactInsight? findById(String id) {
    for (final relationship in _relationships) {
      if (relationship.contactId == id) {
        return relationship;
      }
    }
    return null;
  }

  List<ContactInsight> search(String keyword) {
    if (keyword.trim().isEmpty) {
      return _relationships;
    }
    final normalized = keyword.trim().toLowerCase();
    return _relationships
        .where((item) => item.contactName.toLowerCase().contains(normalized))
        .toList();
  }

  Map<String, Offset> radialLayout() {
    final positions = <String, Offset>{};
    for (var index = 0; index < _relationships.length; index++) {
      final relation = _relationships[index];
      final angle = _relationships.isEmpty
          ? 0.0
          : (index / _relationships.length) * math.pi * 2;
      final radius = 0.62 + (index.isEven ? 0.06 : 0.14);
      positions[relation.contactId] = Offset(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
    }
    return positions;
  }

  String relationTypeLabel(ContactInsight insight) {
    return AppConstants.relationTypeLabels[_relationTypeFromInsight(insight)] ?? '其他';
  }

  String _relationTypeFromInsight(ContactInsight insight) {
    if (insight.relationType.trim().isNotEmpty) {
      return insight.relationType;
    }
    return _relationTypeFromLevel(insight.relationshipLevel, insight.keywords);
  }

  String _relationTypeFromLevel(String relationshipLevel, List<String> keywords) {
    if (keywords.contains('回家') || keywords.contains('家里')) {
      return AppConstants.relationTypeFamily;
    }
    if (keywords.contains('项目') ||
        keywords.contains('合作') ||
        keywords.contains('工作')) {
      return AppConstants.relationTypeColleague;
    }
    if (keywords.contains('纪念日')) {
      return AppConstants.relationTypePartner;
    }

    switch (relationshipLevel) {
      case '重点经营':
      case '稳定升温':
        return AppConstants.relationTypeFriend;
      case '保持联系':
        return AppConstants.relationTypeClassmate;
      default:
        return AppConstants.relationTypeAcquaintance;
    }
  }
}
