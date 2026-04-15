import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.initialize();
  });

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('renmai-storage-service-test');
    await StorageService.instance.setStorageDirectoryForTest(tempDirectory);
    await StorageService.instance.clear();
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('stores large json payloads on disk instead of shared preferences', () async {
    final largeContent = List.filled(250000, 'A').join();
    final largeValue = [
      {
        'id': 'record_1',
        'content': largeContent,
      },
    ];

    await StorageService.instance.setJsonList('large_records', largeValue);

    final rawPointer = StorageService.instance.getString('large_records');
    expect(rawPointer, startsWith('__renmai_file__:'));

    final storedFile = File(
      rawPointer!.replaceFirst('__renmai_file__:', ''),
    );
    expect(storedFile.existsSync(), isTrue);
    expect(
      StorageService.instance.getJsonList('large_records'),
      largeValue,
    );
  });

  test('remove deletes spilled payload file', () async {
    final largeContent = List.filled(250000, 'B').join();
    final largeValue = [
      {
        'id': 'record_2',
        'content': largeContent,
      },
    ];

    await StorageService.instance.setJsonList('large_records', largeValue);
    final rawPointer = StorageService.instance.getString('large_records');
    final storedFile = File(
      rawPointer!.replaceFirst('__renmai_file__:', ''),
    );
    expect(storedFile.existsSync(), isTrue);

    await StorageService.instance.remove('large_records');

    expect(storedFile.existsSync(), isFalse);
    expect(StorageService.instance.getString('large_records'), isNull);
    expect(StorageService.instance.getJsonList('large_records'), isEmpty);
  });
}
