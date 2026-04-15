import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/services/import_service.dart';
import 'package:renmai/services/wechat_raw_backup_service.dart';

void main() {
  group('ImportService', () {
    test('imports structured chat text and skips non-chat html', () async {
      final root = await Directory.systemTemp.createTemp('renmai-import-test');
      addTearDown(() => root.delete(recursive: true));

      final importDir = Directory(p.join(root.path, 'wechat_export'));
      await importDir.create(recursive: true);

      final chatFile = File(p.join(importDir.path, 'alice_chat.txt'));
      await chatFile.writeAsString(
        '[2026-03-20 10:00] Me: hello\n'
        '[2026-03-20 10:01] Alice: are you there?\n'
        '[2026-03-20 10:02] Me: yes\n',
        encoding: utf8,
      );

      final marketingFile = File(p.join(importDir.path, 'cached_page.htm'));
      await marketingFile.writeAsString(
        '<p>new arrivals https://a.example.com https://b.example.com https://c.example.com</p>',
        encoding: utf8,
      );

      final session =
          await ImportService.instance.importPaths([importDir.path]);

      expect(session.records.length, 3);
      expect(session.records.first.contactName, 'Alice');
      expect(session.warnings.any((item) => item.contains('自动跳过')), isTrue);
    });

    test('smart discovery finds chat exports and flags local backup folders',
        () async {
      final home = await Directory.systemTemp.createTemp('renmai-home-test');
      addTearDown(() => home.delete(recursive: true));

      final exportDir =
          Directory(p.join(home.path, 'Documents', 'wechat_export'));
      await exportDir.create(recursive: true);
      await File(p.join(exportDir.path, 'bob_chat.txt')).writeAsString(
        '2026-03-21 09:00 Bob\nGood morning\n\n'
        '2026-03-21 09:02 Me\nReceived\n',
        encoding: utf8,
      );

      final backupDir = Directory(
        p.join(home.path, 'Documents', 'xwechat_files', 'wxid_demo',
            'db_storage', 'message'),
      );
      await backupDir.create(recursive: true);
      await File(p.join(backupDir.path, 'message_0.db')).writeAsBytes(
        List<int>.generate(32, (index) => index),
      );

      final discovery = await ImportService.instance.discoverAutoImportPaths(
        userHomeOverride: home.path,
      );

      expect(discovery.importablePaths.length, 1);
      expect(discovery.importablePaths.single, contains('bob_chat.txt'));
      expect(discovery.foundWeChatLocalBackup, isTrue);
    });

    test('discovers wechat backup account roots for direct raw import',
        () async {
      final home =
          await Directory.systemTemp.createTemp('renmai-home-wechat-root');
      addTearDown(() => home.delete(recursive: true));

      final accountDir = Directory(
        p.join(home.path, 'Documents', 'xwechat_files', 'wxid_demo_1234'),
      );
      await Directory(p.join(accountDir.path, 'db_storage')).create(
        recursive: true,
      );

      final roots = ImportService.instance.discoverWeChatBackupAccountRoots(
        userHomeOverride: home.path,
      );

      expect(roots, [accountDir.path]);
    });

    test('raw backup service resolves account roots from xwechat_files paths',
        () async {
      final root = await Directory.systemTemp.createTemp('renmai-wechat-raw');
      addTearDown(() => root.delete(recursive: true));

      final accountDir = Directory(
        p.join(root.path, 'xwechat_files', 'wxid_demo_1234'),
      );
      await Directory(p.join(accountDir.path, 'db_storage', 'message'))
          .create(recursive: true);

      final service = WeChatRawBackupService();
      final resolvedFromRoot = service.resolveExplicitBackupSelections(
          [p.join(root.path, 'xwechat_files')]);
      final resolvedFromNested = service.resolveExplicitBackupSelections(
        [p.join(accountDir.path, 'db_storage', 'message')],
      );

      expect(resolvedFromRoot, [accountDir.path]);
      expect(resolvedFromNested, [accountDir.path]);
    });

    test('explicit raw backup import prefers direct xwechat reader', () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-wechat-raw-import');
      addTearDown(() => root.delete(recursive: true));

      final accountDir = Directory(
        p.join(root.path, 'xwechat_files', 'wxid_demo_1234'),
      );
      await Directory(p.join(accountDir.path, 'db_storage'))
          .create(recursive: true);

      final fakeService = _FakeWeChatRawBackupService(
        result: WeChatRawBackupImportResult(
          records: [
            ConversationRecord(
              id: 'raw_1',
              packageId: 'pkg',
              source: 'wechat',
              contactId: 'alice',
              contactName: 'Alice',
              senderName: 'Alice',
              isSelf: false,
              sentAt: DateTime(2026, 3, 27, 10, 0),
              content: 'This came from raw backup.',
              messageType: 'text',
              evidenceSnippet: 'This came from raw backup.',
              sourceFile: 'message_0.db',
            ),
          ],
          warnings: const ['已直读原始备份'],
          discoveredFiles: const ['message_0.db'],
          matchedAccountRoots: const ['wxid_demo_1234'],
        ),
      );

      final service = ImportService(weChatRawBackupService: fakeService);
      final session = await service.importPaths([accountDir.path]);

      expect(fakeService.importCallCount, 1);
      expect(session.records.length, 1);
      expect(session.importedPackage.messageCount, 1);
      expect(session.importedPackage.packageSummary, contains('原始备份'));
      expect(session.warnings, contains('已直读原始备份'));
    });

    test('raw backup failure falls back to readable exports', () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-wechat-raw-fallback');
      addTearDown(() => root.delete(recursive: true));

      final accountDir = Directory(
        p.join(root.path, 'xwechat_files', 'wxid_demo_1234'),
      );
      await Directory(p.join(accountDir.path, 'db_storage'))
          .create(recursive: true);

      final chatFile = File(p.join(root.path, 'alice_chat.txt'));
      await chatFile.writeAsString(
        '[2026-03-27 10:00] Me: hello\n'
        '[2026-03-27 10:01] Alice: hi\n',
        encoding: utf8,
      );

      final fakeService = _FakeWeChatRawBackupService(
        error: const FileSystemException('raw failed'),
      );
      final service = ImportService(weChatRawBackupService: fakeService);
      final session =
          await service.importPaths([accountDir.path, chatFile.path]);

      expect(fakeService.importCallCount, 1);
      expect(session.records.length, 2);
      expect(session.warnings, contains('raw failed'));
    });

    test('raw backup failure surfaces when no readable exports exist',
        () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-wechat-raw-error');
      addTearDown(() => root.delete(recursive: true));

      final accountDir = Directory(
        p.join(root.path, 'xwechat_files', 'wxid_demo_1234'),
      );
      await Directory(p.join(accountDir.path, 'db_storage'))
          .create(recursive: true);

      final fakeService = _FakeWeChatRawBackupService(
        error: const FileSystemException('raw failed'),
      );
      final service = ImportService(weChatRawBackupService: fakeService);

      await expectLater(
        () => service.importPaths([accountDir.path]),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('raw failed'),
          ),
        ),
      );
    });

    test('raw backup failure does not fall back to deep-scanning xwechat_files',
        () async {
      final root = await Directory.systemTemp
          .createTemp('renmai-wechat-raw-no-fallback');
      addTearDown(() => root.delete(recursive: true));

      final accountDir = Directory(
        p.join(root.path, 'xwechat_files', 'wxid_demo_1234'),
      );
      await Directory(p.join(accountDir.path, 'db_storage'))
          .create(recursive: true);
      await File(p.join(accountDir.path, 'fake_chat.txt')).writeAsString(
        '[2026-03-27 10:00] Me: hello\n'
        '[2026-03-27 10:01] Alice: hi\n',
        encoding: utf8,
      );

      final fakeService = _FakeWeChatRawBackupService(
        error: const FileSystemException('raw failed'),
      );
      final service = ImportService(weChatRawBackupService: fakeService);

      await expectLater(
        () => service.importPaths([accountDir.path]),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('raw failed'),
          ),
        ),
      );
    });

    test('smart discovery ignores unrelated project text files', () async {
      final home = await Directory.systemTemp.createTemp('renmai-home-ignore');
      addTearDown(() => home.delete(recursive: true));

      final projectDir =
          Directory(p.join(home.path, 'Documents', 'New project'));
      await projectDir.create(recursive: true);
      await File(p.join(projectDir.path, 'flutter_doctor_output.txt'))
          .writeAsString(
        'Flutter doctor output\n'
        'Flutter version 3.41.5\n'
        'The dart binary is not on your path.\n'
        'Engine revision abcdef\n',
        encoding: utf8,
      );

      final discovery = await ImportService.instance.discoverAutoImportPaths(
        userHomeOverride: home.path,
      );

      expect(discovery.importablePaths, isEmpty);
    });

    test('strict smart import mode rejects fallback text chunks', () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-strict-import');
      addTearDown(() => root.delete(recursive: true));

      final hintedDir = Directory(p.join(root.path, 'wechat_export'));
      await hintedDir.create(recursive: true);
      await File(p.join(hintedDir.path, 'promo_message.txt')).writeAsString(
        'welcome to our vip group\n'
        'exclusive benefits below\n'
        'https://shop.example.com/a\n'
        'https://shop.example.com/b\n',
        encoding: utf8,
      );

      expect(
        () => ImportService.instance.importPaths(
          [hintedDir.path],
          strictContentFilter: true,
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('manual import skips technical logs and config files', () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-manual-filter');
      addTearDown(() => root.delete(recursive: true));

      final importDir = Directory(p.join(root.path, 'manual_import'));
      await importDir.create(recursive: true);

      await File(p.join(importDir.path, 'flutter_err.txt')).writeAsString(
        'Building flutter tool...\n'
        'Found no pubspec.yaml file\n'
        'Retrying in five seconds...\n',
        encoding: utf8,
      );
      await File(p.join(importDir.path, 'AdminRegionConfig.txt')).writeAsString(
        '1|中国|11|北京|1|东城||\n1|中国|11|北京|2|西城||\n',
        encoding: utf8,
      );
      await File(p.join(importDir.path, '张三聊天记录.txt')).writeAsString(
        '2026-03-21 09:00 张三\n早上好\n\n'
        '2026-03-21 09:02 我\n收到\n',
        encoding: utf8,
      );

      final session =
          await ImportService.instance.importPaths([importDir.path]);

      expect(session.records, isNotEmpty);
      expect(session.records.every((item) => item.contactName == '张三'), isTrue);
    });

    test('sanitizeRecords removes machine-like contact names', () {
      final records = [
        ConversationRecord(
          id: '1',
          packageId: 'pkg',
          source: 'unknown',
          contactId: 'flutter_err',
          contactName: 'flutter err',
          senderName: 'flutter err',
          isSelf: false,
          sentAt: DateTime(2026, 3, 26, 9),
          content: 'Found no pubspec.yaml file',
          messageType: 'text',
          evidenceSnippet: 'Found no pubspec.yaml file',
          sourceFile: 'flutter_err.txt',
        ),
        ConversationRecord(
          id: '2',
          packageId: 'pkg',
          source: 'wechat',
          contactId: 'alice_chat',
          contactName: 'alice chat',
          senderName: 'Alice',
          isSelf: false,
          sentAt: DateTime(2026, 3, 26, 10),
          content: '在吗',
          messageType: 'text',
          evidenceSnippet: '在吗',
          sourceFile: 'alice_chat.txt',
        ),
      ];

      final sanitized = ImportService.instance.sanitizeRecords(records);

      expect(sanitized.length, 1);
      expect(sanitized.single.contactName, 'Alice');
    });

    test('sanitizeRecords removes generic placeholder contact names', () {
      final records = [
        ConversationRecord(
          id: '1',
          packageId: 'pkg',
          source: 'unknown',
          contactId: '新建_文本文档',
          contactName: '新建 文本文档',
          senderName: '新建 文本文档',
          isSelf: false,
          sentAt: DateTime(2026, 3, 26, 11),
          content: '这只是一个测试文件',
          messageType: 'text',
          evidenceSnippet: '这只是一个测试文件',
          sourceFile: '新建 文本文档.txt',
        ),
      ];

      final sanitized = ImportService.instance.sanitizeRecords(records);

      expect(sanitized, isEmpty);
    });

    test(
        'manual import prefers the dominant speaker before colon as contact name',
        () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-speaker-name-test');
      addTearDown(() => root.delete(recursive: true));

      final importDir = Directory(p.join(root.path, 'chat_export'));
      await importDir.create(recursive: true);

      final chatFile = File(p.join(importDir.path, 'conversation_dump.txt'));
      await chatFile.writeAsString(
        'Alice: hello\n'
        'Me: hi\n'
        'Alice: are you free tonight\n'
        'Alice: let us talk later\n',
        encoding: utf8,
      );

      final session = await ImportService.instance.importPaths([chatFile.path]);

      expect(session.records, isNotEmpty);
      expect(
          session.records.every((item) => item.contactName == 'Alice'), isTrue);
    });

    test('clipboard import parses copied chat text', () async {
      final session = await ImportService.instance.importPlainText(
        '[2026-03-26 09:00] Me: morning\n'
        '[2026-03-26 09:01] LuJun: free today?\n'
        '[2026-03-26 09:02] LuJun: dinner later\n',
        sourceFile: 'clipboard_import.txt',
      );

      expect(session.records, isNotEmpty);
      expect(
          session.records.every((item) => item.contactName == 'LuJun'), isTrue);
    });

    test('clipboard import keeps multiline message bodies under one timestamp',
        () async {
      final session = await ImportService.instance.importPlainText(
        '[2026-03-26 09:00] 陆军: 这是第一行\n'
        '这是第二行\n'
        '[2026-03-26 09:02] 我: 收到\n',
        sourceFile: 'clipboard_multiline.txt',
      );

      expect(session.records.length, 2);
      expect(session.records.first.contactName, '陆军');
      expect(session.records.first.content, '这是第一行\n这是第二行');
      expect(session.records.last.content, '收到');
    });

    test('clipboard import parses colon-only speaker lines', () async {
      final session = await ImportService.instance.importPlainText(
        '陆军：今天忙吗\n'
        '我：还行\n'
        '陆军：晚上一起吃饭\n',
        sourceFile: 'clipboard_import.txt',
      );

      expect(session.records.length, 3);
      expect(session.records.every((item) => item.contactName == '陆军'), isTrue);
    });

    test('clipboard import parses forwarded summary cards with symbol names',
        () async {
      final session = await ImportService.instance.importPlainText(
        '乐染与一大知闲闲°C的聊天记录\n'
        '一大知闲闲°C: [图片]\n'
        '一大知闲闲°C: [图片]\n'
        '聊天记录\n',
        sourceFile: 'forwarded_card.txt',
      );

      expect(session.records.length, 2);
      expect(
        session.records.every((item) => item.contactName == '一大知闲闲°C'),
        isTrue,
      );
      expect(
        session.records.every((item) => item.senderName == '一大知闲闲°C'),
        isTrue,
      );
      expect(
        session.records.every((item) => item.messageType == 'image'),
        isTrue,
      );
      expect(session.records.last.content, '[图片]');
    });

    test('file import parses forwarded summary cards with symbol names',
        () async {
      final root =
          await Directory.systemTemp.createTemp('renmai-forwarded-card');
      addTearDown(() => root.delete(recursive: true));

      final chatFile = File(p.join(root.path, 'forwarded_card.txt'));
      await chatFile.writeAsString(
        '乐染与一大知闲闲°C的聊天记录\n'
        '一大知闲闲°C: [图片]\n'
        '一大知闲闲°C: [图片]\n'
        '聊天记录\n',
        encoding: utf8,
      );

      final session = await ImportService.instance.importPaths([chatFile.path]);

      expect(session.records.length, 2);
      expect(session.importedPackage.contactCount, 1);
      expect(
        session.records.every((item) => item.contactName == '一大知闲闲°C'),
        isTrue,
      );
      expect(session.records.last.content, '[图片]');
    });

    test('clipboard import parses wechat-style chinese timestamp headers',
        () async {
      final session = await ImportService.instance.importPlainText(
        '陆军（1119） 2026年3月23日 18:19\n'
        '6666\n'
        '我 2026年3月23日 18:20\n'
        '收到\n',
        sourceFile: 'wechat_copy.txt',
      );

      expect(session.records.length, 2);
      expect(session.records.every((item) => item.contactName == '陆军'), isTrue);
    });

    test('window capture import keeps locked contact name for raw OCR text',
        () async {
      final session = await ImportService.instance.importPlainText(
        '不行\n'
        '我们唱四个小时呢\n'
        '他们说他们累了给我\n'
        '就是上面这些已经够了，不够你再找我要\n',
        sourceFile: 'window_capture.txt',
        lockedContactName: '陆军',
      );

      expect(session.records, isNotEmpty);
      expect(session.records.every((item) => item.contactName == '陆军'), isTrue);
    });

    test('window capture import can derive contact name from seeded header',
        () async {
      final session = await ImportService.instance.importPlainText(
        '聊天记录：陆军\n'
        '不行\n'
        '我们唱四个小时呢\n'
        '他们说他们累了给我\n',
        sourceFile: 'window_capture.txt',
      );

      expect(session.records, isNotEmpty);
      expect(session.records.every((item) => item.contactName == '陆军'), isTrue);
    });

    test('append import merges later clipboard chunks into the same contact',
        () async {
      final firstChunk = await ImportService.instance.importPlainText(
        '[2026-03-26 09:00] 我: 早上好\n'
        '[2026-03-26 09:01] 陆军（1119）: 今天忙吗\n',
        sourceFile: 'clipboard_first.txt',
      );
      final secondChunk = await ImportService.instance.importPlainText(
        '陆军：晚上一起吃饭\n'
        '我：可以\n'
        '陆军：那我晚点联系你\n',
        sourceFile: 'clipboard_second.txt',
        lockedContactName: '陆军',
      );

      final aligned = ImportService.instance.alignImportedRecordsToWorkspace(
        existingRecords: firstChunk.records,
        importedRecords: secondChunk.records,
        preferredContactId: firstChunk.records.first.contactId,
        lockedContactName: '陆军',
      );

      expect(aligned, isNotEmpty);
      expect(
        aligned.every(
          (item) => item.contactId == firstChunk.records.first.contactId,
        ),
        isTrue,
      );
      expect(
        aligned.every(
          (item) => item.contactName == firstChunk.records.first.contactName,
        ),
        isTrue,
      );
    });

    test(
        'sanitizeRecords replaces placeholder contact names with dominant speaker',
        () {
      final records = [
        ConversationRecord(
          id: '1',
          packageId: 'pkg',
          source: 'wechat',
          contactId: 'placeholder',
          contactName: '新建联系人',
          senderName: '陆军（1119）',
          isSelf: false,
          sentAt: DateTime(2026, 3, 26, 12, 00),
          content: '今天辛苦了',
          messageType: 'text',
          evidenceSnippet: '今天辛苦了',
          sourceFile: 'conversation.txt',
        ),
        ConversationRecord(
          id: '2',
          packageId: 'pkg',
          source: 'wechat',
          contactId: 'placeholder',
          contactName: '新建联系人',
          senderName: '我',
          isSelf: true,
          sentAt: DateTime(2026, 3, 26, 12, 01),
          content: '收到',
          messageType: 'text',
          evidenceSnippet: '收到',
          sourceFile: 'conversation.txt',
        ),
        ConversationRecord(
          id: '3',
          packageId: 'pkg',
          source: 'wechat',
          contactId: 'placeholder',
          contactName: '新建联系人',
          senderName: '陆军（1119）',
          isSelf: false,
          sentAt: DateTime(2026, 3, 26, 12, 02),
          content: '改天一起吃饭',
          messageType: 'text',
          evidenceSnippet: '改天一起吃饭',
          sourceFile: 'conversation.txt',
        ),
      ];

      final sanitized = ImportService.instance.sanitizeRecords(records);

      expect(sanitized, isNotEmpty);
      expect(
        sanitized.every((item) => item.contactName == '陆军'),
        isTrue,
      );
    });
  });
}

class _FakeWeChatRawBackupService extends WeChatRawBackupService {
  _FakeWeChatRawBackupService({
    this.result,
    this.error,
  });

  final WeChatRawBackupImportResult? result;
  final FileSystemException? error;
  int importCallCount = 0;

  @override
  Future<WeChatRawBackupImportResult?> importFromSelections(
    List<String> paths, {
    required String packageId,
    AiProviderConfig aiConfig = const AiProviderConfig(),
    bool enrichAttachments = false,
  }) async {
    importCallCount += 1;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}
