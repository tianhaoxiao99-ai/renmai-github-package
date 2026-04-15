import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/services/wechat_raw_backup_service.dart';

void main() {
  test('importFromSelections reads payload from output file', () async {
    final root =
        await Directory.systemTemp.createTemp('renmai-wechat-raw-service');
    addTearDown(() => root.delete(recursive: true));

    final accountDir = Directory(
      p.join(root.path, 'xwechat_files', 'wxid_demo_1234'),
    );
    await Directory(p.join(accountDir.path, 'db_storage')).create(
      recursive: true,
    );

    late String writtenOutputPath;
    final service = WeChatRawBackupService(
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        bool runInShell = false,
      }) async {
        final outputIndex = arguments.indexOf('--output-file');
        final mediaIndex = arguments.indexOf('--media-output-dir');
        expect(outputIndex, isNot(-1));
        expect(mediaIndex, -1);

        writtenOutputPath = arguments[outputIndex + 1];
        await File(writtenOutputPath).writeAsString(
          jsonEncode({
            'ok': true,
            'warnings': ['raw ok'],
            'records': [
              {
                'id': 'raw_1',
                'package_id': 'pkg',
                'source': 'wechat',
                'contact_id': 'alice',
                'contact_name': 'Alice',
                'sender_name': 'Alice',
                'is_self': false,
                'sent_at': DateTime(2026, 4, 3, 10, 30).toIso8601String(),
                'content': 'hello from db',
                'message_type': 'text',
                'evidence_snippet': 'hello from db',
                'source_file': 'message_0.db',
              },
            ],
            'discovered_files': ['message_0.db'],
            'matched_account_roots': [accountDir.path],
          }),
        );

        return ProcessResult(
          1,
          0,
          jsonEncode({
            'ok': true,
            'output_file': writtenOutputPath,
            'record_count': 1,
          }),
          '',
        );
      },
    );

    final result = await service.importFromSelections(
      [accountDir.path],
      packageId: 'pkg',
    );

    expect(result, isNotNull);
    expect(result!.records, hasLength(1));
    expect(result.records.single.contactName, 'Alice');
    expect(result.discoveredFiles, ['message_0.db']);
    expect(result.warnings, contains('raw ok'));
    expect(File(writtenOutputPath).existsSync(), isFalse);
  });

  test('importFromSelections enriches media attachments before cleanup',
      () async {
    final root =
        await Directory.systemTemp.createTemp('renmai-wechat-raw-enrich');
    addTearDown(() => root.delete(recursive: true));

    final accountDir = Directory(
      p.join(root.path, 'xwechat_files', 'wxid_demo_5678'),
    );
    await Directory(p.join(accountDir.path, 'db_storage')).create(
      recursive: true,
    );

    final service = WeChatRawBackupService(
      processRunner: (
        String executable,
        List<String> arguments, {
        String? workingDirectory,
        bool runInShell = false,
      }) async {
        final outputIndex = arguments.indexOf('--output-file');
        final mediaIndex = arguments.indexOf('--media-output-dir');
        final outputPath = arguments[outputIndex + 1];
        final mediaDir = Directory(arguments[mediaIndex + 1]);
        await mediaDir.create(recursive: true);

        final imageFile = File(p.join(mediaDir.path, 'sample.png'));
        final voiceFile = File(p.join(mediaDir.path, 'sample.wav'));
        await imageFile.writeAsBytes([1, 2, 3]);
        await voiceFile.writeAsBytes([4, 5, 6]);

        await File(outputPath).writeAsString(
          jsonEncode({
            'ok': true,
            'warnings': [],
            'records': [
              {
                'id': 'image_1',
                'package_id': 'pkg',
                'source': 'wechat',
                'contact_id': 'alice',
                'contact_name': 'Alice',
                'sender_name': 'Alice',
                'is_self': false,
                'sent_at': DateTime(2026, 4, 3, 10, 30).toIso8601String(),
                'content': '[图片]',
                'message_type': 'image',
                'evidence_snippet': '[图片]',
                'source_file': 'message_0.db',
                'attachment_path': imageFile.path,
              },
              {
                'id': 'voice_1',
                'package_id': 'pkg',
                'source': 'wechat',
                'contact_id': 'alice',
                'contact_name': 'Alice',
                'sender_name': 'Alice',
                'is_self': false,
                'sent_at': DateTime(2026, 4, 3, 10, 31).toIso8601String(),
                'content': '[语音]',
                'message_type': 'voice',
                'evidence_snippet': '[语音]',
                'source_file': 'message_0.db',
                'attachment_path': voiceFile.path,
              },
            ],
            'discovered_files': ['message_0.db'],
            'matched_account_roots': [accountDir.path],
          }),
        );

        return ProcessResult(
          1,
          0,
          jsonEncode({
            'ok': true,
            'output_file': outputPath,
            'record_count': 2,
          }),
          '',
        );
      },
      imageTextExtractor: (filePath) async {
        expect(File(filePath).existsSync(), isTrue);
        return '海报上的文字';
      },
      audioTranscriber: (config, filePath) async {
        expect(config.isReady, isTrue);
        expect(File(filePath).existsSync(), isTrue);
        return '这是一段语音转写';
      },
    );

    final result = await service.importFromSelections(
      [accountDir.path],
      packageId: 'pkg',
      aiConfig: const AiProviderConfig(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'test-key',
        model: 'whisper-1',
        enabled: true,
      ),
      enrichAttachments: true,
    );

    expect(result, isNotNull);
    expect(result!.records, hasLength(2));
    expect(result.records[0].content, contains('图片文字识别'));
    expect(result.records[0].content, contains('海报上的文字'));
    expect(result.records[0].attachmentPath, isEmpty);
    expect(result.records[1].content, contains('语音转写'));
    expect(result.records[1].content, contains('这是一段语音转写'));
    expect(result.records[1].attachmentPath, isEmpty);
  });
}
