import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/services/import_service.dart';

void main() {
  test('fallback import keeps every paragraph instead of truncating at 200', () async {
    final paragraphs = List<String>.generate(
      250,
      (index) => 'Paragraph $index\nThis is unique message block $index.',
    );
    final session = await ImportService.instance.importPlainText(
      paragraphs.join('\n\n'),
      sourceFile: 'Alice_chat.txt',
      lockedContactName: 'Alice',
    );

    expect(session.records.length, 250);
    expect(session.importedPackage.messageCount, 250);
    expect(session.records.first.contactName, 'Alice');
    expect(session.records.last.content, contains('unique message block 249'));
  });
}
