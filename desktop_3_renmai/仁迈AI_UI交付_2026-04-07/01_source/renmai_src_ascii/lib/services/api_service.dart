import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  Future<ComparisonReport> generateComparisonReport({
    required AiProviderConfig config,
    required ComparisonReport seedReport,
    required List<ConversationRecord> records,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
      ),
    );
    final endpoint = _buildEndpoint(config.baseUrl);
    final bundles = _buildContactAnalysisBundles(
      seedReport: seedReport,
      records: records,
    );

    final mergedAnalyses = <_MergedContactAnalysis>[];
    for (final bundle in bundles) {
      final chunkAnalyses = <_ChunkAnalysis>[];
      for (final chunk in bundle.chunks) {
        chunkAnalyses.add(
          await _requestChunkAnalysis(
            dio: dio,
            endpoint: endpoint,
            model: config.model,
            bundle: bundle,
            chunk: chunk,
          ),
        );
      }
      mergedAnalyses.add(
        _mergeChunkAnalyses(
          bundle: bundle,
          analyses: chunkAnalyses,
        ),
      );
    }

    final parsedJson = await _requestFinalReport(
      dio: dio,
      endpoint: endpoint,
      model: config.model,
      seedReport: seedReport,
      mergedAnalyses: mergedAnalyses,
    );
    return _mergeAiReport(seedReport, parsedJson);
  }

  Future<String> transcribeAudio({
    required AiProviderConfig config,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const FileSystemException('Audio file not found for transcription.');
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
        },
      ),
    );

    final formData = FormData.fromMap({
      'model': config.model,
      'response_format': 'text',
      'file': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });

    final endpoint = _buildAudioEndpoint(config.baseUrl);
    final response = await _postWithDiagnostics(
      dio: dio,
      endpoint: endpoint,
      data: formData,
      operationLabel: 'Audio transcription',
    );

    final data = response.data;
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    if (data is Map && (data['text'] ?? '').toString().trim().isNotEmpty) {
      return (data['text'] ?? '').toString().trim();
    }
    throw const FormatException('Audio transcription returned an empty response.');
  }

  String _buildEndpoint(String baseUrl) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/chat/completions')) {
      return trimmed;
    }
    return '$trimmed/chat/completions';
  }

  String _buildAudioEndpoint(String baseUrl) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/audio/transcriptions')) {
      return trimmed;
    }
    return '$trimmed/audio/transcriptions';
  }

  List<_ContactAnalysisBundle> _buildContactAnalysisBundles({
    required ComparisonReport seedReport,
    required List<ConversationRecord> records,
  }) {
    final grouped = <String, List<ConversationRecord>>{};
    for (final record in records) {
      grouped
          .putIfAbsent(record.contactId, () => <ConversationRecord>[])
          .add(record);
    }

    final insightById = <String, ContactInsight>{
      for (final insight in seedReport.contactInsights) insight.contactId: insight,
    };
    final orderedIds = grouped.keys.toList()
      ..sort((a, b) {
        final left = insightById[a];
        final right = insightById[b];
        if (left != null && right != null) {
          return right.intimacyScore.compareTo(left.intimacyScore);
        }
        return a.compareTo(b);
      });

    return orderedIds.map((contactId) {
      final contactRecords = [...grouped[contactId]!]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      final first = contactRecords.first;
      return _ContactAnalysisBundle(
        contactId: first.contactId,
        contactName: first.contactName,
        records: contactRecords,
        seedInsight: insightById[first.contactId],
        chunks: _chunkContactRecords(contactRecords),
      );
    }).toList();
  }

  List<_TranscriptChunk> _chunkContactRecords(
    List<ConversationRecord> records, {
    int maxChars = 3000,
  }) {
    final segments = <_TranscriptSegment>[];
    for (final record in records) {
      segments.addAll(_formatRecordSegments(record, maxSegmentChars: 2600));
    }

    if (segments.isEmpty) {
      return const [];
    }

    final chunks = <_TranscriptChunk>[];
    final current = StringBuffer();
    var currentMessageCount = 0;
    var currentSegmentCount = 0;

    void flush() {
      if (currentSegmentCount == 0) {
        return;
      }
      chunks.add(
        _TranscriptChunk(
          transcript: current.toString().trim(),
          messageCount: currentMessageCount,
        ),
      );
      current.clear();
      currentMessageCount = 0;
      currentSegmentCount = 0;
    }

    for (final segment in segments) {
      final candidate = currentSegmentCount == 0
          ? segment.text
          : '${current.toString()}\n${segment.text}';
      if (candidate.length > maxChars && currentSegmentCount > 0) {
        flush();
      }

      if (currentSegmentCount > 0) {
        current.write('\n');
      }
      current.write(segment.text);
      currentSegmentCount += 1;
      if (segment.startsMessage) {
        currentMessageCount += 1;
      }
    }

    flush();
    return chunks
        .asMap()
        .entries
        .map(
          (entry) => _TranscriptChunk(
            transcript: entry.value.transcript,
            messageCount: entry.value.messageCount,
            index: entry.key + 1,
            total: chunks.length,
          ),
        )
        .toList();
  }

  List<_TranscriptSegment> _formatRecordSegments(
    ConversationRecord record, {
    required int maxSegmentChars,
  }) {
    final sender = record.isSelf ? 'Me' : record.senderName.trim();
    final time = record.sentAt.toIso8601String();
    final normalizedContent = record.content.replaceAll('\r\n', '\n').trim();
    final content = normalizedContent.isEmpty ? '[empty]' : normalizedContent;
    final headPrefix = '[$time] $sender: ';
    if ((headPrefix + content).length <= maxSegmentChars) {
      return [
        _TranscriptSegment(
          text: '$headPrefix$content',
          startsMessage: true,
        ),
      ];
    }

    final segments = <_TranscriptSegment>[];
    var offset = 0;
    var part = 1;
    while (offset < content.length) {
      final prefix = part == 1
          ? headPrefix
          : '[$time] $sender (continued $part): ';
      final available = maxSegmentChars - prefix.length;
      final nextOffset =
          available <= 0 ? content.length : (offset + available).clamp(0, content.length);
      segments.add(
        _TranscriptSegment(
          text: '$prefix${content.substring(offset, nextOffset)}',
          startsMessage: part == 1,
        ),
      );
      offset = nextOffset;
      part += 1;
    }
    return segments;
  }

  Future<_ChunkAnalysis> _requestChunkAnalysis({
    required Dio dio,
    required String endpoint,
    required String model,
    required _ContactAnalysisBundle bundle,
    required _TranscriptChunk chunk,
  }) async {
    final response = await _postWithDiagnostics(
      dio: dio,
      endpoint: endpoint,
      operationLabel: 'AI 分块分析',
      data: {
        'model': model,
        'temperature': 0.1,
        'messages': [
          {
            'role': 'system',
            'content':
                'You analyze a chat transcript chunk. Return strict JSON only.',
          },
          {
            'role': 'user',
            'content': _buildChunkPrompt(
              bundle: bundle,
              chunk: chunk,
            ),
          },
        ],
      },
    );

    final content = _extractResponseContent(response.data);
    final parsed = jsonDecode(_extractJson(content)) as Map<String, dynamic>;
    return _ChunkAnalysis.fromJson(parsed);
  }

  String _buildChunkPrompt({
    required _ContactAnalysisBundle bundle,
    required _TranscriptChunk chunk,
  }) {
    final payload = {
      'contact_id': bundle.contactId,
      'contact_name': bundle.contactName,
      'chunk_index': chunk.index,
      'chunk_total': chunk.total,
      'chunk_message_count': chunk.messageCount,
      'local_context': {
        'relationship_level': bundle.seedInsight?.relationshipLevel ?? '',
        'intimacy_score': bundle.seedInsight?.intimacyScore ?? 0,
        'reference_tier': bundle.seedInsight?.referenceTier ?? '',
        'relation_type': bundle.seedInsight?.relationType ?? '',
        'relation_detail': bundle.seedInsight?.relationDetail ?? '',
        'reference_reason': bundle.seedInsight?.referenceReason ?? '',
        'activity_level': bundle.seedInsight?.activityLevel ?? '',
        'total_messages': bundle.seedInsight?.totalMessages ?? bundle.records.length,
        'active_days': bundle.seedInsight?.activeDays ?? 0,
        'keywords': bundle.seedInsight?.keywords ?? const <String>[],
        'positive_signals':
            bundle.seedInsight?.positiveSignals ?? const <String>[],
        'risk_points': bundle.seedInsight?.riskPoints ?? const <String>[],
        'gift_suggestion': bundle.seedInsight?.giftSuggestion?.toJson(),
      },
      'transcript': chunk.transcript,
    };

    return '''
Analyze this transcript chunk and return JSON with exactly these keys:
- keywords
- positive_signals
- risk_points
- gift_cues
- event_cues
- evidence_quotes
- summary

Rules:
- Each list must contain short strings only.
- evidence_quotes must be copied from the transcript chunk only.
- Keep evidence_quotes concise and relevant.
- summary must be one concise paragraph.
- If family / parent / relative clues are weak locally, use transcript naming clues to refine relation_detail cautiously.
- Do not add any keys.

Input:
${jsonEncode(payload)}
''';
  }

  _MergedContactAnalysis _mergeChunkAnalyses({
    required _ContactAnalysisBundle bundle,
    required List<_ChunkAnalysis> analyses,
  }) {
    return _MergedContactAnalysis(
      contactId: bundle.contactId,
      contactName: bundle.contactName,
      chunkCount: analyses.length,
      totalMessages: bundle.records.length,
      keywords: _mergeUniqueStrings(
        analyses.expand((item) => item.keywords),
        limit: 12,
      ),
      positiveSignals: _mergeUniqueStrings(
        analyses.expand((item) => item.positiveSignals),
        limit: 12,
      ),
      riskPoints: _mergeUniqueStrings(
        analyses.expand((item) => item.riskPoints),
        limit: 12,
      ),
      giftCues: _mergeUniqueStrings(
        analyses.expand((item) => item.giftCues),
        limit: 12,
      ),
      eventCues: _mergeUniqueStrings(
        analyses.expand((item) => item.eventCues),
        limit: 12,
      ),
      evidenceQuotes: _mergeUniqueStrings(
        analyses.expand((item) => item.evidenceQuotes),
        limit: 8,
      ),
      summary: analyses
          .map((item) => item.summary.trim())
          .where((item) => item.isNotEmpty)
          .take(6)
          .join(' '),
    );
  }

  List<String> _mergeUniqueStrings(
    Iterable<String> values, {
    required int limit,
  }) {
    final normalized = <String>{};
    final merged = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (!normalized.add(key)) {
        continue;
      }
      merged.add(trimmed);
      if (merged.length >= limit) {
        break;
      }
    }
    return merged;
  }

  Future<Map<String, dynamic>> _requestFinalReport({
    required Dio dio,
    required String endpoint,
    required String model,
    required ComparisonReport seedReport,
    required List<_MergedContactAnalysis> mergedAnalyses,
  }) async {
    final payload = {
      'seed_report': seedReport.toJson(),
      'contacts': mergedAnalyses.map((item) => item.toJson()).toList(),
    };

    final response = await _postWithDiagnostics(
      dio: dio,
      endpoint: endpoint,
      operationLabel: 'AI 总报告生成',
      data: {
        'model': model,
        'temperature': 0.2,
        'messages': [
          {
            'role': 'system',
            'content':
                'You produce a final relationship and gift report. Return strict JSON only.',
          },
          {
            'role': 'user',
            'content': '''
Build the final report from fully covered, chunk-merged chat analysis data.

Return valid JSON with exactly these top-level keys:
- overall_summary
- relationship_ranking
- contact_insights
- gift_recommendations
- action_suggestions
- evidence_quotes

Requirements:
- relationship_ranking items: contact_id, contact_name, score, rationale
- relationship_ranking items may also include reference_tier, relation_detail
- contact_insights items: contact_id, contact_name, relationship_level, intimacy_score, reference_tier, relation_type, relation_detail, reference_reason, activity_level, total_messages, active_days, last_interaction_at, positive_signals, risk_points, suggestions, evidence_quotes, keywords, gift_suggestion
- gift_suggestion fields: id, contact_id, contact_name, gift_name, reason, occasion, budget_range, confidence
- gift_recommendations items use the same shape as gift_suggestion
- Keep outputs practical and grounded in the provided data.
- Do not add any extra keys.

Input:
${jsonEncode(payload)}
''',
          },
        ],
      },
    );

    final content = _extractResponseContent(response.data);
    return jsonDecode(_extractJson(content)) as Map<String, dynamic>;
  }

  String _extractResponseContent(dynamic responseData) {
    if (responseData is String) {
      return responseData;
    }
    if (responseData is! Map) {
      return responseData.toString();
    }

    final choices = responseData['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final message = firstChoice['message'];
        if (message is Map) {
          final content = message['content'];
          if (content is String) {
            return content;
          }
          if (content is List) {
            return content
                .whereType<Map>()
                .map((part) => (part['text'] ?? '').toString())
                .join('\n');
          }
        }
      }
    }

    return jsonEncode(responseData);
  }

  Future<Response<dynamic>> _postWithDiagnostics({
    required Dio dio,
    required String endpoint,
    required dynamic data,
    required String operationLabel,
  }) async {
    try {
      return await dio.post(endpoint, data: data);
    } on DioException catch (error) {
      throw Exception(
        _describeDioFailure(
          error: error,
          endpoint: endpoint,
          operationLabel: operationLabel,
        ),
      );
    }
  }

  String _describeDioFailure({
    required DioException error,
    required String endpoint,
    required String operationLabel,
  }) {
    final status = error.response?.statusCode;
    final responseData = error.response?.data;
    final serverMessage = _extractServerMessage(responseData);
    final suffix = serverMessage == null ? '' : ': $serverMessage';

    if (status == 401 || status == 403) {
      return '$operationLabel失败：API Key 无效或权限不足（HTTP $status）$suffix';
    }
    if (status == 404) {
      return '$operationLabel失败：接口地址不存在，请检查 Base URL（请求地址：$endpoint）$suffix';
    }
    if (status == 429) {
      return '$operationLabel失败：请求过于频繁或额度不足（HTTP 429）$suffix';
    }
    if (status != null) {
      return '$operationLabel失败（HTTP $status）$suffix';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '$operationLabel超时，请检查网络和接口服务状态。';
      case DioExceptionType.connectionError:
        return '$operationLabel连接失败，请检查 Base URL 和当前网络环境。';
      default:
        break;
    }

    final raw = _sanitizeUserFacingText(
      error.message?.trim() ?? '',
      fallback: '接口返回了无法识别的错误文本，请检查服务端日志或稍后重试。',
    );
    if (raw.isNotEmpty) {
      return '$operationLabel失败：$raw';
    }
    return '$operationLabel失败：未知网络错误。';
  }

  String? _extractServerMessage(dynamic responseData) {
    if (responseData == null) {
      return null;
    }
    if (responseData is String) {
      final trimmed = _sanitizeUserFacingText(
        responseData.trim(),
        fallback: '服务返回了无法识别的文本，请检查接口编码或稍后重试。',
      );
      return trimmed.isEmpty ? null : trimmed;
    }
    if (responseData is Map) {
      final message = responseData['message'] ??
          responseData['error'] ??
          responseData['detail'];
      if (message is String && message.trim().isNotEmpty) {
        final trimmed = _sanitizeUserFacingText(
          message.trim(),
          fallback: '服务返回了无法识别的文本，请检查接口编码或稍后重试。',
        );
        return trimmed.isEmpty ? null : trimmed;
      }
      if (message is Map) {
        final nested = message['message'] ?? message['detail'];
        if (nested is String && nested.trim().isNotEmpty) {
          final trimmed = _sanitizeUserFacingText(
            nested.trim(),
            fallback: '服务返回了无法识别的文本，请检查接口编码或稍后重试。',
          );
          return trimmed.isEmpty ? null : trimmed;
        }
      }
    }
    return null;
  }

  String _sanitizeUserFacingText(
    String text, {
    String fallback = '',
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    if (_looksLikeMojibake(trimmed)) {
      return fallback;
    }
    return trimmed;
  }

  List<String> _sanitizeUserFacingList(
    dynamic value, {
    Iterable<String> fallback = const <String>[],
  }) {
    if (value is! List) {
      return fallback.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }

    final cleaned = value
        .map((item) => _sanitizeUserFacingText(item.toString(), fallback: ''))
        .where((item) => item.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return fallback.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    return cleaned;
  }

  Map<String, dynamic> _sanitizeAiObject(
    Map<String, dynamic> source, {
    List<String> stringKeys = const [],
    List<String> listKeys = const [],
    Map<String, List<String>> nestedStringKeys = const {},
  }) {
    final sanitized = Map<String, dynamic>.from(source);
    for (final key in stringKeys) {
      if (!sanitized.containsKey(key)) {
        continue;
      }
      sanitized[key] = _sanitizeUserFacingText(
        sanitized[key]?.toString() ?? '',
        fallback: '',
      );
    }
    for (final key in listKeys) {
      if (!sanitized.containsKey(key)) {
        continue;
      }
      sanitized[key] = _sanitizeUserFacingList(sanitized[key]);
    }
    for (final entry in nestedStringKeys.entries) {
      final nested = sanitized[entry.key];
      if (nested is! Map) {
        continue;
      }
      final nestedMap = Map<String, dynamic>.from(nested);
      for (final key in entry.value) {
        if (!nestedMap.containsKey(key)) {
          continue;
        }
        nestedMap[key] = _sanitizeUserFacingText(
          nestedMap[key]?.toString() ?? '',
          fallback: '',
        );
      }
      sanitized[entry.key] = nestedMap;
    }
    return sanitized;
  }

  bool _looksLikeMojibake(String text) {
    if (text.contains('�')) {
      return true;
    }
    if (RegExp(r'[\uE000-\uF8FF]').hasMatch(text)) {
      return true;
    }

    const suspiciousFragments = [
      '閸掑',
      '鐎介',
      '鍡欏',
      '鏈€',
      '鍏堝',
      '璇风',
      '鐩存',
      '寰俊',
      '鍒嗘',
      '娌℃',
      '宸叉',
      '閫夋',
      '鑱旂',
      '闂插',
      '鍚庨',
      '妫€',
      '绯荤',
      '澶辫触',
    ];

    var hitCount = 0;
    for (final fragment in suspiciousFragments) {
      if (text.contains(fragment)) {
        hitCount += 1;
      }
    }
    return hitCount >= 2;
  }

  String _extractJson(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('AI response does not contain valid JSON.');
    }
    return content.substring(start, end + 1);
  }

  ComparisonReport _mergeAiReport(
    ComparisonReport seedReport,
    Map<String, dynamic> aiJson,
  ) {
    final nameToId = <String, String>{
      for (final item in seedReport.contactInsights)
        item.contactName: item.contactId,
    };
    final seedInsightsById = <String, ContactInsight>{
      for (final item in seedReport.contactInsights) item.contactId: item,
    };

    List<Map<String, dynamic>> normalizeList(String key) {
      final value = aiJson[key];
      if (value is! List) {
        return const [];
      }
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final ranking = normalizeList('relationship_ranking').map((item) {
      item['contact_id'] ??= nameToId[item['contact_name']] ?? '';
      final seedInsight = seedInsightsById[item['contact_id']];
      item['reference_tier'] ??= seedInsight?.referenceTier ?? '';
      item['relation_detail'] ??= seedInsight?.relationDetail ?? '';
      final sanitized = _sanitizeAiObject(
        item,
        stringKeys: [
          'contact_id',
          'contact_name',
          'rationale',
          'reference_tier',
          'relation_detail',
        ],
      );
      return RelationshipRankItem.fromJson(sanitized);
    }).toList();

    final contactInsights = normalizeList('contact_insights').map((item) {
      item['contact_id'] ??= nameToId[item['contact_name']] ?? '';
      final seedInsight = seedInsightsById[item['contact_id']];
      item['reference_tier'] ??= seedInsight?.referenceTier ?? '';
      item['relation_type'] ??= seedInsight?.relationType ?? '';
      item['relation_detail'] ??= seedInsight?.relationDetail ?? '';
      item['reference_reason'] ??= seedInsight?.referenceReason ?? '';
      final gift = item['gift_suggestion'];
      if (gift is Map) {
        final mappedGift = Map<String, dynamic>.from(gift);
        mappedGift['contact_id'] ??= item['contact_id'];
        mappedGift['contact_name'] ??= item['contact_name'];
        item['gift_suggestion'] = mappedGift;
      }
      final sanitized = _sanitizeAiObject(
        item,
        stringKeys: [
          'contact_id',
          'contact_name',
          'relationship_level',
          'reference_tier',
          'relation_type',
          'relation_detail',
          'reference_reason',
          'activity_level',
          'last_interaction_at',
        ],
        listKeys: [
          'positive_signals',
          'risk_points',
          'suggestions',
          'evidence_quotes',
          'keywords',
        ],
        nestedStringKeys: {
          'gift_suggestion': [
            'id',
            'contact_id',
            'contact_name',
            'gift_name',
            'reason',
            'occasion',
            'budget_range',
          ],
        },
      );
      return ContactInsight.fromJson(sanitized);
    }).toList();

    final giftRecommendations =
        normalizeList('gift_recommendations').map((item) {
      item['contact_id'] ??= nameToId[item['contact_name']] ?? '';
      final sanitized = _sanitizeAiObject(
        item,
        stringKeys: [
          'id',
          'contact_id',
          'contact_name',
          'gift_name',
          'reason',
          'occasion',
          'budget_range',
        ],
      );
      return GiftRecommendation.fromJson(sanitized);
    }).toList();

    final actionSuggestionsSource = aiJson['action_suggestions'];
    final evidenceQuotesSource = aiJson['evidence_quotes'];

    return ComparisonReport(
      id: 'report_ai_${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      overallSummary: _sanitizeUserFacingText(
        (aiJson['overall_summary'] ?? '').toString(),
        fallback: seedReport.overallSummary,
      ),
      relationshipRanking:
          ranking.isEmpty ? seedReport.relationshipRanking : ranking,
      contactInsights: contactInsights.isEmpty
          ? seedReport.contactInsights
          : contactInsights,
      giftRecommendations: giftRecommendations.isEmpty
          ? seedReport.giftRecommendations
          : giftRecommendations,
      actionSuggestions: _sanitizeUserFacingList(
        actionSuggestionsSource,
        fallback: seedReport.actionSuggestions,
      ),
      evidenceQuotes: _sanitizeUserFacingList(
        evidenceQuotesSource,
        fallback: seedReport.evidenceQuotes,
      ),
      sourcePackageIds: seedReport.sourcePackageIds,
      usedAi: true,
      workspaceFingerprint: seedReport.workspaceFingerprint,
    );
  }
}

class _ContactAnalysisBundle {
  final String contactId;
  final String contactName;
  final List<ConversationRecord> records;
  final ContactInsight? seedInsight;
  final List<_TranscriptChunk> chunks;

  const _ContactAnalysisBundle({
    required this.contactId,
    required this.contactName,
    required this.records,
    required this.seedInsight,
    required this.chunks,
  });
}

class _TranscriptSegment {
  final String text;
  final bool startsMessage;

  const _TranscriptSegment({
    required this.text,
    required this.startsMessage,
  });
}

class _TranscriptChunk {
  final String transcript;
  final int messageCount;
  final int index;
  final int total;

  const _TranscriptChunk({
    required this.transcript,
    required this.messageCount,
    this.index = 1,
    this.total = 1,
  });
}

class _ChunkAnalysis {
  final List<String> keywords;
  final List<String> positiveSignals;
  final List<String> riskPoints;
  final List<String> giftCues;
  final List<String> eventCues;
  final List<String> evidenceQuotes;
  final String summary;

  const _ChunkAnalysis({
    required this.keywords,
    required this.positiveSignals,
    required this.riskPoints,
    required this.giftCues,
    required this.eventCues,
    required this.evidenceQuotes,
    required this.summary,
  });

  factory _ChunkAnalysis.fromJson(Map<String, dynamic> json) {
    List<String> readList(String key) {
      final value = json[key];
      if (value is! List) {
        return const [];
      }
      return value.map((item) => item.toString()).toList();
    }

    return _ChunkAnalysis(
      keywords: ApiService.instance._sanitizeUserFacingList(readList('keywords')),
      positiveSignals:
          ApiService.instance._sanitizeUserFacingList(readList('positive_signals')),
      riskPoints:
          ApiService.instance._sanitizeUserFacingList(readList('risk_points')),
      giftCues: ApiService.instance._sanitizeUserFacingList(readList('gift_cues')),
      eventCues:
          ApiService.instance._sanitizeUserFacingList(readList('event_cues')),
      evidenceQuotes:
          ApiService.instance._sanitizeUserFacingList(readList('evidence_quotes')),
      summary: ApiService.instance._sanitizeUserFacingText(
        (json['summary'] ?? '').toString(),
        fallback: '',
      ),
    );
  }
}

class _MergedContactAnalysis {
  final String contactId;
  final String contactName;
  final int chunkCount;
  final int totalMessages;
  final List<String> keywords;
  final List<String> positiveSignals;
  final List<String> riskPoints;
  final List<String> giftCues;
  final List<String> eventCues;
  final List<String> evidenceQuotes;
  final String summary;

  const _MergedContactAnalysis({
    required this.contactId,
    required this.contactName,
    required this.chunkCount,
    required this.totalMessages,
    required this.keywords,
    required this.positiveSignals,
    required this.riskPoints,
    required this.giftCues,
    required this.eventCues,
    required this.evidenceQuotes,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'contact_id': contactId,
      'contact_name': contactName,
      'chunk_count': chunkCount,
      'total_messages': totalMessages,
      'keywords': keywords,
      'positive_signals': positiveSignals,
      'risk_points': riskPoints,
      'gift_cues': giftCues,
      'event_cues': eventCues,
      'evidence_quotes': evidenceQuotes,
      'summary': summary,
    };
  }
}
