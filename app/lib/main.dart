import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/themes/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_list_screen.dart';
import 'screens/create_account_screen.dart';

void main() {
  runApp(const ProviderScope(child: PrivateChatApp()));
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

class PrivateChatShell extends ConsumerWidget {
  const PrivateChatShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return switch (auth.status) {
      AuthStatus.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.unauthenticated => const CreateAccountScreen(),
      AuthStatus.authenticated => const AuthenticatedChatShell(),
    };
  }
}

class AuthenticatedChatShell extends ConsumerWidget {
  const AuthenticatedChatShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatProvider);
    return const ChatListScreen();
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
