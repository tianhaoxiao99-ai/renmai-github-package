import 'package:flutter/material.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/services/storage_service.dart';

class DisplaySettingsProvider extends ChangeNotifier {
  DisplaySettingsProvider() {
    if (StorageService.instance.isInitialized) {
      _highContrast = StorageService.instance
              .getString(AppConstants.keyHighContrastEnabled) ==
          'true';
      _themeMode = _parseThemeMode(
        StorageService.instance.getString(AppConstants.keyThemeMode),
      );
      _themePreset = AppThemePresetX.fromStorage(
        StorageService.instance.getString(AppConstants.keyThemePreset),
      );
    }
  }

  bool _highContrast = false;
  ThemeMode _themeMode = ThemeMode.system;
  AppThemePreset _themePreset = AppThemePreset.warmApricot;

  bool get highContrast => _highContrast;
  ThemeMode get themeMode => _themeMode;
  AppThemePreset get themePreset => _themePreset;

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) return;
    _highContrast = value;
    await StorageService.instance.setString(
      AppConstants.keyHighContrastEnabled,
      value ? 'true' : 'false',
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    await StorageService.instance.setString(
      AppConstants.keyThemeMode,
      value.name,
    );
    notifyListeners();
  }

  Future<void> setThemePreset(AppThemePreset value) async {
    if (_themePreset == value) return;
    _themePreset = value;
    await StorageService.instance.setString(
      AppConstants.keyThemePreset,
      value.storageValue,
    );
    notifyListeners();
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
