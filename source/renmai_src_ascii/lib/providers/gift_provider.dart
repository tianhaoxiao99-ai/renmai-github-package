import 'package:flutter/material.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/providers/analysis_provider.dart';

class GiftProvider extends ChangeNotifier {
  List<GiftRecommendation> _recommendedGifts = [];
  final List<GiftRecommendation> _giftHistory = [];
  GiftRecommendation? _selectedGift;

  List<GiftRecommendation> get recommendedGifts => _recommendedGifts;
  List<GiftRecommendation> get giftHistory => _giftHistory;
  GiftRecommendation? get selectedGift => _selectedGift;

  void syncFromAnalysis(AnalysisProvider analysis) {
    _recommendedGifts = analysis.giftRecommendations;
    if (_selectedGift != null) {
      try {
        _selectedGift = _recommendedGifts.firstWhere((item) => item.id == _selectedGift!.id);
      } catch (_) {
        _selectedGift = _recommendedGifts.isNotEmpty ? _recommendedGifts.first : null;
      }
    } else if (_recommendedGifts.isNotEmpty) {
      _selectedGift = _recommendedGifts.first;
    }
    notifyListeners();
  }

  void selectGift(GiftRecommendation gift) {
    _selectedGift = gift;
    notifyListeners();
  }

  void addToHistory(GiftRecommendation gift) {
    final exists = _giftHistory.any((item) => item.id == gift.id);
    if (!exists) {
      _giftHistory.insert(0, gift);
      notifyListeners();
    }
  }

  GiftRecommendation? findGiftById(String id) {
    for (final gift in _recommendedGifts) {
      if (gift.id == id) return gift;
    }
    return null;
  }
}
