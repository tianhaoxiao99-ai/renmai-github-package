class ImportedPackage {
  final String id;
  final String source;
  final List<String> originPaths;
  final List<String> discoveredFiles;
  final DateTime importedAt;
  final String status;
  final int contactCount;
  final int messageCount;
  final String packageSummary;

  const ImportedPackage({
    required this.id,
    required this.source,
    required this.originPaths,
    required this.discoveredFiles,
    required this.importedAt,
    required this.status,
    required this.contactCount,
    required this.messageCount,
    required this.packageSummary,
  });

  ImportedPackage copyWith({
    String? id,
    String? source,
    List<String>? originPaths,
    List<String>? discoveredFiles,
    DateTime? importedAt,
    String? status,
    int? contactCount,
    int? messageCount,
    String? packageSummary,
  }) {
    return ImportedPackage(
      id: id ?? this.id,
      source: source ?? this.source,
      originPaths: originPaths ?? this.originPaths,
      discoveredFiles: discoveredFiles ?? this.discoveredFiles,
      importedAt: importedAt ?? this.importedAt,
      status: status ?? this.status,
      contactCount: contactCount ?? this.contactCount,
      messageCount: messageCount ?? this.messageCount,
      packageSummary: packageSummary ?? this.packageSummary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'origin_paths': originPaths,
      'discovered_files': discoveredFiles,
      'imported_at': importedAt.toIso8601String(),
      'status': status,
      'contact_count': contactCount,
      'message_count': messageCount,
      'summary': packageSummary,
    };
  }

  factory ImportedPackage.fromJson(Map<String, dynamic> json) {
    return ImportedPackage(
      id: (json['id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      originPaths: (json['origin_paths'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      discoveredFiles: (json['discovered_files'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      importedAt: DateTime.tryParse((json['imported_at'] ?? '').toString()) ?? DateTime.now(),
      status: (json['status'] ?? 'completed').toString(),
      contactCount: (json['contact_count'] as num?)?.toInt() ?? 0,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      packageSummary: (json['summary'] ?? '').toString(),
    );
  }
}
