import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

// Local storage service.
// On Windows, portable bundles prefer keeping data beside the executable in
// RenmaiData so old AppData workspace state is not auto-restored.
class StorageService {
  static const String _filePointerPrefix = '__renmai_file__:';
  static const int _largePayloadThreshold = 180000;
  static const String _portableDataDirectoryName = 'RenmaiData';
  static const String _payloadDirectoryName = 'storage';
  static const String _valuesFileName = 'preferences.json';
  static const String _portableSecureValuesFileName =
      'portable_secure_preferences.json';

  static final StorageService _instance = StorageService._internal();
  static StorageService get instance => _instance;

  late Directory _rootDirectory;
  late Directory _storageDirectory;
  late File _valuesFile;
  late File _portableSecureValuesFile;

  final Map<String, String> _values = <String, String>{};
  final Map<String, String> _portableSecureValues = <String, String>{};

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _initialized = false;
  bool _usesPortableStorage = false;
  bool _usesPortableSecureValues = false;

  bool get isInitialized => _initialized;
  bool get usesPortableStorage => _usesPortableStorage;

  StorageService._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    final context = await _resolveStorageContext();
    await _configureStorage(
      rootDirectory: context.rootDirectory,
      usePortableStorage: context.usePortableStorage,
      usePortableSecureValues: context.usePortableSecureValues,
    );

    _initialized = true;
  }

  Future<void> setString(String key, String value) async {
    _values[key] = value;
    await _persistValues();
  }

  String? getString(String key) {
    return _values[key];
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _persistJsonPayload(key, value);
  }

  Map<String, dynamic>? getJson(String key) {
    final str = _loadStoredString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    await _persistJsonPayload(key, value);
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    final str = _loadStoredString(key);
    if (str == null || str.isEmpty) return const [];
    try {
      final decoded = jsonDecode(str);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> remove(String key) async {
    await _deletePayloadFileForKey(key);

    _values.remove(key);
    await _persistValues();

    if (_usesPortableSecureValues) {
      _portableSecureValues.remove(key);
      await _persistPortableSecureValues();
      return;
    }

    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }

  Future<void> setSecureString(String key, String value) async {
    if (_usesPortableSecureValues) {
      _portableSecureValues[key] = value;
      await _persistPortableSecureValues();
      return;
    }

    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      _portableSecureValues[key] = value;
      await _persistPortableSecureValues();
    }
  }

  Future<String?> getSecureString(String key) async {
    if (_usesPortableSecureValues) {
      return _portableSecureValues[key];
    }

    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return _portableSecureValues[key];
    }
  }

  Future<void> clear() async {
    _values.clear();
    await _persistValues();

    if (_storageDirectory.existsSync()) {
      try {
        await _storageDirectory.delete(recursive: true);
      } catch (_) {}
    }
    if (!_storageDirectory.existsSync()) {
      await _storageDirectory.create(recursive: true);
    }

    if (_usesPortableSecureValues) {
      _portableSecureValues.clear();
      await _persistPortableSecureValues();
      return;
    }

    try {
      await _secureStorage.deleteAll();
    } catch (_) {
      _portableSecureValues.clear();
      await _persistPortableSecureValues();
    }
  }

  Future<void> setStorageDirectoryForTest(Directory directory) async {
    await _configureStorage(
      rootDirectory: directory,
      usePortableStorage: true,
      usePortableSecureValues: true,
    );
    _initialized = true;
  }

  Future<void> _configureStorage({
    required Directory rootDirectory,
    required bool usePortableStorage,
    required bool usePortableSecureValues,
  }) async {
    _rootDirectory = rootDirectory;
    _usesPortableStorage = usePortableStorage;
    _usesPortableSecureValues = usePortableSecureValues;

    if (!_rootDirectory.existsSync()) {
      await _rootDirectory.create(recursive: true);
    }

    _storageDirectory = Directory(
      p.join(_rootDirectory.path, _payloadDirectoryName),
    );
    if (!_storageDirectory.existsSync()) {
      await _storageDirectory.create(recursive: true);
    }

    _valuesFile = File(p.join(_rootDirectory.path, _valuesFileName));
    _portableSecureValuesFile = File(
      p.join(_rootDirectory.path, _portableSecureValuesFileName),
    );

    _values
      ..clear()
      ..addAll(await _readStoredMap(_valuesFile));

    _portableSecureValues
      ..clear()
      ..addAll(await _readStoredMap(_portableSecureValuesFile));
  }

  Future<
      ({
        Directory rootDirectory,
        bool usePortableStorage,
        bool usePortableSecureValues,
      })> _resolveStorageContext() async {
    if (Platform.isWindows) {
      final executableDirectory = File(Platform.resolvedExecutable).parent;
      final flutterBundleDataDirectory = Directory(
        p.join(executableDirectory.path, 'data'),
      );
      final portableRoot = Directory(
        p.join(executableDirectory.path, _portableDataDirectoryName),
      );

      if (flutterBundleDataDirectory.existsSync() &&
          await _canUseDirectory(portableRoot)) {
        return (
          rootDirectory: portableRoot,
          usePortableStorage: true,
          usePortableSecureValues: true,
        );
      }

      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        final fallbackRoot = Directory(p.join(appData, 'Renmai'));
        if (await _canUseDirectory(fallbackRoot)) {
          return (
            rootDirectory: fallbackRoot,
            usePortableStorage: false,
            usePortableSecureValues: false,
          );
        }
      }
    }

    final fallbackRoot = Directory(p.join(Directory.systemTemp.path, 'renmai'));
    if (await _canUseDirectory(fallbackRoot)) {
      return (
        rootDirectory: fallbackRoot,
        usePortableStorage: false,
        usePortableSecureValues: false,
      );
    }

    throw const FileSystemException('Failed to initialize local storage.');
  }

  Future<bool> _canUseDirectory(Directory directory) async {
    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      final probe = File(p.join(directory.path, '.storage_probe'));
      await probe.writeAsString('ok', flush: true);
      if (probe.existsSync()) {
        await probe.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistJsonPayload(String key, Object value) async {
    final encoded = await Isolate.run(() => jsonEncode(value));
    if (encoded.length >= _largePayloadThreshold) {
      final file = _payloadFileForKey(key);
      await file.parent.create(recursive: true);
      await file.writeAsString(encoded);
      _values[key] = '$_filePointerPrefix${file.path}';
      await _persistValues();
      return;
    }

    await _deletePayloadFileForKey(key);
    _values[key] = encoded;
    await _persistValues();
  }

  String? _loadStoredString(String key) {
    final raw = _values[key];
    if (raw == null || raw.isEmpty) {
      return raw;
    }
    if (!raw.startsWith(_filePointerPrefix)) {
      return raw;
    }

    final filePath = raw.substring(_filePointerPrefix.length);
    if (filePath.trim().isEmpty) {
      return null;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return null;
    }

    try {
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  File _payloadFileForKey(String key) {
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]+'), '_');
    return File(p.join(_storageDirectory.path, '$safeKey.json'));
  }

  Future<void> _deletePayloadFileForKey(String key) async {
    final raw = _values[key];
    final filePath = raw != null && raw.startsWith(_filePointerPrefix)
        ? raw.substring(_filePointerPrefix.length)
        : _payloadFileForKey(key).path;
    if (filePath.trim().isEmpty) {
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> _persistValues() async {
    await _writeStoredMap(_valuesFile, _values);
  }

  Future<void> _persistPortableSecureValues() async {
    await _writeStoredMap(_portableSecureValuesFile, _portableSecureValues);
  }

  Future<Map<String, String>> _readStoredMap(File file) async {
    if (!file.existsSync()) {
      return <String, String>{};
    }

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <String, String>{};
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }

      final result = <String, String>{};
      decoded.forEach((key, value) {
        if (key is String && value is String) {
          result[key] = value;
        }
      });
      return result;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _writeStoredMap(File file, Map<String, String> data) async {
    await file.parent.create(recursive: true);
    final encoded = await Isolate.run(() => jsonEncode(data));
    await file.writeAsString(encoded, flush: true);
  }
}
