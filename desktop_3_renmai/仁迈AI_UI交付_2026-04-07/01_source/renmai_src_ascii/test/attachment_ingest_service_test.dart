import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/services/attachment_ingest_service.dart';

void main() {
  group('AttachmentIngestService', () {
    test('imports text attachments into the current contact', () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-attachment-test');
      addTearDown(() => root.delete(recursive: true));

      final file = File(p.join(root.path, 'gift_note.txt'));
      await file.writeAsString(
        '这份文件里写着：下次见面记得带上生日礼物建议。',
        encoding: utf8,
      );

      final result = await AttachmentIngestService.instance.importForContact(
        paths: [file.path],
        contactId: 'lujun',
        contactName: '陆军',
        aiConfig: const AiProviderConfig(),
      );

      expect(result.records.length, 1);
      expect(result.records.single.contactName, '陆军');
      expect(result.records.single.messageType, 'file');
      expect(result.records.single.content, contains('文件摘录'));
      expect(result.importedPackage.source, 'attachment');
    });
  });
}
