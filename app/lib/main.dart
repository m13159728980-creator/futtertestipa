import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/ios_ui_capability_service.dart';
import 'core/themes/app_theme.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/sound_effect_service.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'models/call_session.dart';
import 'screens/call_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/create_account_screen.dart';

void main() {
  runApp(const ProviderScope(child: PrivateChatApp()));
}

class PrivateChatApp extends ConsumerWidget {
  const PrivateChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final iosUiCapabilities = ref.watch(iosUiCapabilitiesProvider).valueOrNull;
    final useIosUi = settings.iosNativeUi && iosUiCapabilities?.isIos == true;
    final interfaceLevel = useIosUi
        ? iosUiCapabilities!.level
        : IosInterfaceLevel.material;

    return ProviderScope(
      overrides: [
        settingsSoundEnabledProvider.overrideWithValue(
          settings.soundNotifications,
        ),
      ],
      child: MaterialApp(
        title: 'PrvChat',
        theme: AppTheme.lightFor(
          settings.accentColor,
          interfaceLevel: interfaceLevel,
        ),
        darkTheme: AppTheme.darkFor(
          settings.accentColor,
          interfaceLevel: interfaceLevel,
        ),
        themeMode: settings.themeMode,
        scrollBehavior: useIosUi
            ? const CupertinoScrollBehavior()
            : const MaterialScrollBehavior(),
        locale: Locale(settings.languageCode),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PrivateChatShell(),
      ),
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

class AuthenticatedChatShell extends ConsumerStatefulWidget {
  const AuthenticatedChatShell({super.key});

  @override
  ConsumerState<AuthenticatedChatShell> createState() =>
      _AuthenticatedChatShellState();
}

class _AuthenticatedChatShellState
    extends ConsumerState<AuthenticatedChatShell> {
  bool _showingIncomingCall = false;
  bool _showingAnyCall = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(chatProvider);
    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        ref.read(pushNotificationServiceProvider).initialize();
      }
    });
    ref.listen(callProvider, (previous, next) {
      final session = next.session;
      if (previous?.session != null && session == null && _showingAnyCall) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).maybePop();
          }
          _showingIncomingCall = false;
          _showingAnyCall = false;
        });
        return;
      }
      if (session?.state != CallState.incoming || _showingIncomingCall) {
        return;
      }
      _showingIncomingCall = true;
      _showingAnyCall = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _showingIncomingCall = false;
          _showingAnyCall = false;
          return;
        }
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const CallScreen()));
        if (mounted) {
          _showingIncomingCall = false;
          _showingAnyCall = false;
        }
      });
    });
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
      'appTitle': 'PrvChat',
      'chat': 'Chat',
      'settings': 'Settings',
      'connectionStatus': 'Connection status',
    },
    'zh': {
      'appTitle': 'PrvChat',
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
