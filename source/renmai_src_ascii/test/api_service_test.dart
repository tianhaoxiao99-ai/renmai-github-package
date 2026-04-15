import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/api_service.dart';
import 'package:renmai/services/local_report_service.dart';

void main() {
  test('AI analysis uses chunked full-history requests instead of first-N sampling',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestBodies = <String>[];
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requestBodies.add(body);

      final isFinalPrompt = body.contains(
        'Build the final report from fully covered, chunk-merged chat analysis data.',
      );
      final responsePayload = isFinalPrompt
          ? {
              'overall_summary': 'Full transcript covered and merged.',
              'relationship_ranking': [
                {
                  'contact_id': 'alice',
                  'contact_name': 'Alice',
                  'score': 91,
                  'rationale': 'High activity and chunk-wide positive signals.',
                },
              ],
              'contact_insights': [
                {
                  'contact_id': 'alice',
                  'contact_name': 'Alice',
                  'relationship_level': '重点经营',
                  'intimacy_score': 91,
                  'activity_level': '持续互动',
                  'total_messages': 30,
                  'active_days': 5,
                  'last_interaction_at': DateTime(2026, 3, 30, 12, 0)
                      .toIso8601String(),
                  'positive_signals': ['Chunk coverage remained positive.'],
                  'risk_points': ['No major risk.'],
                  'suggestions': ['Prepare a thoughtful follow-up.'],
                  'evidence_quotes': ['message 0', 'message 29'],
                  'keywords': ['birthday', 'gift', 'weekend'],
                  'gift_suggestion': {
                    'id': 'gift_alice',
                    'contact_id': 'alice',
                    'contact_name': 'Alice',
                    'gift_name': 'Notebook',
                    'reason': 'Gift planning appeared across the full transcript.',
                    'occasion': 'Birthday',
                    'budget_range': '100-200',
                    'confidence': 0.9,
                  },
                },
              ],
              'gift_recommendations': [
                {
                  'id': 'gift_alice',
                  'contact_id': 'alice',
                  'contact_name': 'Alice',
                  'gift_name': 'Notebook',
                  'reason': 'Gift planning appeared across the full transcript.',
                  'occasion': 'Birthday',
                  'budget_range': '100-200',
                  'confidence': 0.9,
                },
              ],
              'action_suggestions': ['Follow up this weekend.'],
              'evidence_quotes': ['message 0', 'message 29'],
            }
          : {
              'keywords': [
                if (body.contains('message 0')) 'start',
                if (body.contains('message 29')) 'end',
                'gift',
              ],
              'positive_signals': ['positive reply'],
              'risk_points': ['none'],
              'gift_cues': ['birthday'],
              'event_cues': ['weekend'],
              'evidence_quotes': [
                if (body.contains('message 0')) 'message 0',
                if (body.contains('message 29')) 'message 29',
              ],
              'summary': body.contains('message 29')
                  ? 'Late transcript chunk.'
                  : 'Earlier transcript chunk.',
            };

      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode(responsePayload),
              },
            },
          ],
        }),
      );
      await request.response.close();
    });

    final records = List<ConversationRecord>.generate(
      30,
      (index) => _record(
        id: '$index',
        contactId: 'alice',
        contactName: 'Alice',
        senderName: index.isEven ? 'Alice' : '我',
        isSelf: index.isOdd,
        sentAt: DateTime(2026, 3, 1 + (index % 5), 12, index),
        content:
            'message $index ${'birthday and gift weekend '.padRight(140, 'x')}',
      ),
    );
    final packages = [_package('pkg_api')];
    final seedReport =
        LocalReportService.instance.buildReport(packages: packages, records: records);
    final config = AiProviderConfig(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      model: 'test-model',
      enabled: true,
    );

    final report = await ApiService.instance.generateComparisonReport(
      config: config,
      seedReport: seedReport,
      records: records,
    );

    expect(
      requestBodies
          .where((body) => body.contains('Analyze this transcript chunk'))
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(requestBodies.every((body) => !body.contains('sample_messages')), isTrue);
    final combinedBodies = requestBodies.join('\n');
    expect(combinedBodies, contains('message 0'));
    expect(combinedBodies, contains('message 29'));
    expect(report.usedAi, isTrue);
    expect(report.workspaceFingerprint, seedReport.workspaceFingerprint);
    expect(report.overallSummary, contains('Full transcript covered'));
  });
}

ConversationRecord _record({
  required String id,
  required String contactId,
  required String contactName,
  required String senderName,
  required bool isSelf,
  required DateTime sentAt,
  required String content,
}) {
  return ConversationRecord(
    id: id,
    packageId: 'pkg_api',
    source: 'wechat',
    contactId: contactId,
    contactName: contactName,
    senderName: senderName,
    isSelf: isSelf,
    sentAt: sentAt,
    content: content,
    messageType: 'text',
    evidenceSnippet: content,
    sourceFile: 'memory',
  );
}

ImportedPackage _package(String id) {
  return ImportedPackage(
    id: id,
    source: 'wechat',
    originPaths: const ['memory'],
    discoveredFiles: const ['memory'],
    importedAt: DateTime.now(),
    status: 'completed',
    contactCount: 1,
    messageCount: 30,
    packageSummary: 'test package',
  );
}
