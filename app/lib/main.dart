import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/themes/app_theme.dart';
import 'widgets/default_avatar.dart';

void main() {
  runApp(const PrivateChatApp());
}

class PrivateChatApp extends StatelessWidget {
  const PrivateChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Private Chat',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PrivateChatShell(),
    );
  }
}

class PrivateChatShell extends StatelessWidget {
  const PrivateChatShell({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.chat),
        actions: [
          IconButton(
            tooltip: localizations.settings,
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DefaultAvatar(index: 0, radius: 32),
            const SizedBox(height: 16),
            Text(
              localizations.appTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(localizations.connectionStatus),
          ],
        ),
      ),
    );
  }
}

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Private Chat',
      'chat': 'Chat',
      'settings': 'Settings',
      'connectionStatus': 'Connection status',
    },
    'zh': {
      'appTitle': 'Private Chat',
      'chat': '聊天',
      'settings': '设置',
      'connectionStatus': '连接状态',
    },
  };

  String _text(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }

  String get appTitle => _text('appTitle');
  String get chat => _text('chat');
  String get settings => _text('settings');
  String get connectionStatus => _text('connectionStatus');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
