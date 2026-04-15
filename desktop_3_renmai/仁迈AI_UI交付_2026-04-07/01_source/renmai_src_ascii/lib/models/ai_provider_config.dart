class AiProviderConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool enabled;

  const AiProviderConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.enabled = false,
  });

  bool get isReady => enabled && baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  AiProviderConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    bool? enabled,
  }) {
    return AiProviderConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'enabled': enabled,
    };
  }

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      baseUrl: (json['base_url'] ?? '').toString(),
      apiKey: (json['api_key'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      enabled: json['enabled'] == true,
    );
  }
}
