import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/models/conversation_record.dart';

void main() {
  test('builds search text for media understanding', () {
    final record = ConversationRecord(
      id: '1',
      packageId: 'pkg',
      source: 'wechat',
      contactId: 'alice',
      contactName: 'Alice',
      senderName: 'Alice',
      isSelf: false,
      sentAt: DateTime(2026, 4, 3, 20, 0),
      content: '【语音转写】\n我明天去机场接你',
      messageType: 'voice',
      evidenceSnippet: '我明天去机场接你',
      sourceFile: 'message_0.db',
    );

    expect(record.searchText, contains('语音'));
    expect(record.searchText, contains('转写'));
    expect(record.searchText, contains('录音内容'));
    expect(record.searchText, contains('机场'));
  });

  test('rebuilds search text for legacy json without search_text', () {
    final record = ConversationRecord.fromJson({
      'id': '2',
      'package_id': 'pkg',
      'source': 'wechat',
      'contact_id': 'bob',
      'contact_name': 'Bob',
      'sender_name': 'Bob',
      'is_self': false,
      'sent_at': DateTime(2026, 4, 3, 20, 1).toIso8601String(),
      'content': '【表情包】\n吃瓜',
      'message_type': 'emoji',
      'evidence_snippet': '吃瓜',
      'source_file': 'message_1.db',
    });

    expect(record.searchText, contains('表情包'));
    expect(record.searchText, contains('围观'));
    expect(record.searchText, contains('看戏'));
  });
}
