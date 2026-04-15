class AppConstants {
  AppConstants._();

  static const String appName = '仁迈';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String appDescription = '桌面端聊天记录分析与关系经营助手';
  static const String appCopyright = 'Copyright 2026 All Rights Reserved.';

  static const String keyAiBaseUrl = 'ai_base_url';
  static const String keyAiApiKey = 'ai_api_key';
  static const String keyAiModel = 'ai_model';
  static const String keyAiEnabled = 'ai_enabled';
  static const String keyHighContrastEnabled = 'high_contrast_enabled';
  static const String keyThemeMode = 'theme_mode';
  static const String keyThemePreset = 'theme_preset';
  static const String keyImportedPackages = 'imported_packages';
  static const String keyConversationRecords = 'conversation_records';
  static const String keyComparisonReport = 'comparison_report';
  static const String keySelectedContactId = 'selected_contact_id';

  static const int maxEvidenceQuotes = 6;
  static const int maxContactQuotes = 3;
  static const int maxActionSuggestions = 5;
  static const List<String> supportedImportExtensions = [
    '.txt',
    '.html',
    '.htm',
    '.zip',
  ];

  static const String relationTypeFamily = 'family';
  static const String relationTypeFriend = 'friend';
  static const String relationTypeColleague = 'colleague';
  static const String relationTypeClassmate = 'classmate';
  static const String relationTypeAcquaintance = 'acquaintance';
  static const String relationTypePartner = 'partner';

  static const Map<String, String> relationTypeLabels = {
    relationTypeFamily: '家人',
    relationTypeFriend: '朋友',
    relationTypeColleague: '同事',
    relationTypeClassmate: '同学',
    relationTypeAcquaintance: '熟人',
    relationTypePartner: '伴侣',
  };

  static String displayRelationshipLevel(String value) {
    switch (value) {
      case '重点经营':
        return '优先关注';
      case '稳定升温':
        return '持续互动';
      case '保持联系':
        return '保持联系';
      case '有待修复':
        return '需要修复';
      default:
        return value;
    }
  }

  static String displayReferenceTier(String value) {
    switch (value) {
      case '好':
      case '中等':
      case '不好':
        return '$value（仅供参考）';
      default:
        return value;
    }
  }
}
