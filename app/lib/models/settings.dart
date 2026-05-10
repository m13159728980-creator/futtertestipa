import 'dart:convert';

import 'package:flutter/material.dart';

enum ChatEnterKeyBehavior { send, newline }

enum FileAutoDownloadLimit { none, tenMb, fiftyMb, unlimited }

enum AppAccentColor { blue, green, purple, pink, orange }

class AppSettings {
  const AppSettings({
    this.languageCode = 'zh',
    this.avatarIndex = 0,
    this.messageNotifications = true,
    this.soundNotifications = true,
    this.vibrationNotifications = true,
    this.disableScreenshots = false,
    this.defaultBurnTimerSeconds = 0,
    this.hideLastSeen = false,
    this.chatFontSize = 16,
    this.enterKeyBehavior = ChatEnterKeyBehavior.send,
    this.holdToRecord = true,
    this.wifiOnlyMediaLoading = true,
    this.fileAutoDownloadLimit = FileAutoDownloadLimit.tenMb,
    this.themeMode = ThemeMode.system,
    this.accentColor = AppAccentColor.blue,
  });

  final String languageCode;
  final int avatarIndex;
  final bool messageNotifications;
  final bool soundNotifications;
  final bool vibrationNotifications;
  final bool disableScreenshots;
  final int defaultBurnTimerSeconds;
  final bool hideLastSeen;
  final double chatFontSize;
  final ChatEnterKeyBehavior enterKeyBehavior;
  final bool holdToRecord;
  final bool wifiOnlyMediaLoading;
  final FileAutoDownloadLimit fileAutoDownloadLimit;
  final ThemeMode themeMode;
  final AppAccentColor accentColor;

  AppSettings copyWith({
    String? languageCode,
    int? avatarIndex,
    bool? messageNotifications,
    bool? soundNotifications,
    bool? vibrationNotifications,
    bool? disableScreenshots,
    int? defaultBurnTimerSeconds,
    bool? hideLastSeen,
    double? chatFontSize,
    ChatEnterKeyBehavior? enterKeyBehavior,
    bool? holdToRecord,
    bool? wifiOnlyMediaLoading,
    FileAutoDownloadLimit? fileAutoDownloadLimit,
    ThemeMode? themeMode,
    AppAccentColor? accentColor,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      soundNotifications: soundNotifications ?? this.soundNotifications,
      vibrationNotifications:
          vibrationNotifications ?? this.vibrationNotifications,
      disableScreenshots: disableScreenshots ?? this.disableScreenshots,
      defaultBurnTimerSeconds:
          defaultBurnTimerSeconds ?? this.defaultBurnTimerSeconds,
      hideLastSeen: hideLastSeen ?? this.hideLastSeen,
      chatFontSize: chatFontSize ?? this.chatFontSize,
      enterKeyBehavior: enterKeyBehavior ?? this.enterKeyBehavior,
      holdToRecord: holdToRecord ?? this.holdToRecord,
      wifiOnlyMediaLoading: wifiOnlyMediaLoading ?? this.wifiOnlyMediaLoading,
      fileAutoDownloadLimit:
          fileAutoDownloadLimit ?? this.fileAutoDownloadLimit,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      languageCode: json['languageCode'] as String? ?? 'zh',
      avatarIndex: _avatarIndex(json['avatarIndex']),
      messageNotifications: json['messageNotifications'] as bool? ?? true,
      soundNotifications: json['soundNotifications'] as bool? ?? true,
      vibrationNotifications: json['vibrationNotifications'] as bool? ?? true,
      disableScreenshots: json['disableScreenshots'] as bool? ?? false,
      defaultBurnTimerSeconds: json['defaultBurnTimerSeconds'] as int? ?? 0,
      hideLastSeen: json['hideLastSeen'] as bool? ?? false,
      chatFontSize: (json['chatFontSize'] as num?)?.toDouble() ?? 16,
      enterKeyBehavior: _enumValue(
        ChatEnterKeyBehavior.values,
        json['enterKeyBehavior'],
        ChatEnterKeyBehavior.send,
      ),
      holdToRecord: json['holdToRecord'] as bool? ?? true,
      wifiOnlyMediaLoading: json['wifiOnlyMediaLoading'] as bool? ?? true,
      fileAutoDownloadLimit: _enumValue(
        FileAutoDownloadLimit.values,
        json['fileAutoDownloadLimit'],
        FileAutoDownloadLimit.tenMb,
      ),
      themeMode: _enumValue(
        ThemeMode.values,
        json['themeMode'],
        ThemeMode.system,
      ),
      accentColor: _enumValue(
        AppAccentColor.values,
        json['accentColor'],
        AppAccentColor.blue,
      ),
    );
  }

  factory AppSettings.fromStorageJson(String source) {
    return AppSettings.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() {
    return {
      'languageCode': languageCode,
      'avatarIndex': avatarIndex,
      'messageNotifications': messageNotifications,
      'soundNotifications': soundNotifications,
      'vibrationNotifications': vibrationNotifications,
      'disableScreenshots': disableScreenshots,
      'defaultBurnTimerSeconds': defaultBurnTimerSeconds,
      'hideLastSeen': hideLastSeen,
      'chatFontSize': chatFontSize,
      'enterKeyBehavior': enterKeyBehavior.name,
      'holdToRecord': holdToRecord,
      'wifiOnlyMediaLoading': wifiOnlyMediaLoading,
      'fileAutoDownloadLimit': fileAutoDownloadLimit.name,
      'themeMode': themeMode.name,
      'accentColor': accentColor.name,
    };
  }

  String toStorageJson() => jsonEncode(toJson());

  static int _avatarIndex(Object? value) {
    if (value is int && value >= 0 && value <= 8) {
      return value;
    }
    return 0;
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
