import 'package:app/core/services/secure_window_service.dart';
import 'package:app/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  return FlutterSecureSettingsStorage();
});

final secureWindowServiceProvider = Provider<SecureWindowService>((ref) {
  return const SecureWindowService();
});

final settingsProvider = ChangeNotifierProvider<SettingsProvider>((ref) {
  return SettingsProvider(
    storage: ref.watch(settingsStorageProvider),
    secureWindowService: ref.watch(secureWindowServiceProvider),
  )..initialize();
});

abstract interface class SettingsStorage {
  Future<AppSettings?> readSettings();

  Future<void> saveSettings(AppSettings settings);

  Future<void> clearCache();
}

class FlutterSecureSettingsStorage implements SettingsStorage {
  FlutterSecureSettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _settingsKey = 'app_settings';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearCache() async {
    // TODO(local-cache): clear media/cache directories when cache service lands.
  }

  @override
  Future<AppSettings?> readSettings() async {
    final source = await _storage.read(key: _settingsKey);
    return source == null ? null : AppSettings.fromStorageJson(source);
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return _storage.write(key: _settingsKey, value: settings.toStorageJson());
  }
}

class InMemorySettingsStorage implements SettingsStorage {
  InMemorySettingsStorage({AppSettings? initialSettings})
    : _settings = initialSettings;

  AppSettings? _settings;
  int clearCacheCalls = 0;

  @override
  Future<void> clearCache() async {
    clearCacheCalls++;
  }

  @override
  Future<AppSettings?> readSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required SettingsStorage storage,
    required SecureWindowService secureWindowService,
  }) : _storage = storage,
       _secureWindowService = secureWindowService;

  final SettingsStorage _storage;
  final SecureWindowService _secureWindowService;

  AppSettings _settings = const AppSettings();
  bool _initialized = false;

  AppSettings get settings => _settings;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    _settings = await _storage.readSettings() ?? const AppSettings();
    _initialized = true;
    await _secureWindowService.setEnabled(_settings.disableScreenshots);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) {
    return _update(_settings.copyWith(languageCode: languageCode));
  }

  Future<void> setAvatarIndex(int avatarIndex) {
    if (avatarIndex < 0 || avatarIndex > 8) {
      return Future.value();
    }
    return _update(_settings.copyWith(avatarIndex: avatarIndex));
  }

  Future<void> setMessageNotifications(bool value) {
    return _update(_settings.copyWith(messageNotifications: value));
  }

  Future<void> setSoundNotifications(bool value) {
    return _update(_settings.copyWith(soundNotifications: value));
  }

  Future<void> setVibrationNotifications(bool value) {
    return _update(_settings.copyWith(vibrationNotifications: value));
  }

  Future<void> setDisableScreenshots(bool value) async {
    await _secureWindowService.setEnabled(value);
    await _update(_settings.copyWith(disableScreenshots: value));
  }

  Future<void> setDefaultBurnTimerSeconds(int seconds) {
    return _update(_settings.copyWith(defaultBurnTimerSeconds: seconds));
  }

  Future<void> setHideLastSeen(bool value) {
    return _update(_settings.copyWith(hideLastSeen: value));
  }

  Future<void> setChatFontSize(double value) {
    return _update(_settings.copyWith(chatFontSize: value));
  }

  Future<void> setEnterKeyBehavior(ChatEnterKeyBehavior value) {
    return _update(_settings.copyWith(enterKeyBehavior: value));
  }

  Future<void> setHoldToRecord(bool value) {
    return _update(_settings.copyWith(holdToRecord: value));
  }

  Future<void> setWifiOnlyMediaLoading(bool value) {
    return _update(_settings.copyWith(wifiOnlyMediaLoading: value));
  }

  Future<void> setFileAutoDownloadLimit(FileAutoDownloadLimit value) {
    return _update(_settings.copyWith(fileAutoDownloadLimit: value));
  }

  Future<void> setThemeMode(ThemeMode value) {
    return _update(_settings.copyWith(themeMode: value));
  }

  Future<void> clearCache() {
    return _storage.clearCache();
  }

  Future<void> _update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _storage.saveSettings(next);
  }
}
