import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/secure_window_service.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/settings_provider.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('language choices update provider state immediately', (
    tester,
  ) async {
    final settings = SettingsProvider(
      storage: InMemorySettingsStorage(),
      secureWindowService: _FakeSecureWindowService(),
    );
    await tester.pumpWidget(_testApp(settingsNotifier: settings));

    await tester.tap(find.text('English'));
    await tester.pump();

    expect(settings.settings.languageCode, 'en');

    await tester.tap(find.text('中文'));
    await tester.pump();

    expect(settings.settings.languageCode, 'zh');
  });

  testWidgets('avatar selection is limited to fixed avatars 0 through 8', (
    tester,
  ) async {
    final settings = SettingsProvider(
      storage: InMemorySettingsStorage(),
      secureWindowService: _FakeSecureWindowService(),
    );
    await tester.pumpWidget(_testApp(settingsNotifier: settings));

    await tester.tap(find.byKey(const ValueKey('settings-avatar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('avatar-choice-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-choice-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-choice-9')), findsNothing);
    expect(find.text('上传'), findsNothing);
    expect(find.text('拍照'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('avatar-choice-8')));
    await tester.pumpAndSettle();

    expect(settings.settings.avatarIndex, 8);
  });

  testWidgets('secure screen switch calls SecureWindowService', (tester) async {
    _useTallTestViewport(tester);
    final secureWindow = _FakeSecureWindowService();
    final settings = SettingsProvider(
      storage: InMemorySettingsStorage(),
      secureWindowService: secureWindow,
    );
    await tester.pumpWidget(_testApp(settingsNotifier: settings));

    await tester.tap(find.byKey(const ValueKey('secure-screen-switch')));
    await tester.pump();

    expect(secureWindow.calls, [true]);
    expect(settings.settings.disableScreenshots, isTrue);
  });

  testWidgets('account deletion requires exact account confirmation', (
    tester,
  ) async {
    _useTallTestViewport(tester);
    final api = _FakeApiService();
    final storage = InMemorySecureStorage();
    await storage.saveSession(_testUser);
    final auth = AuthProvider(apiService: api, storageService: storage);
    await auth.initialize();
    final settings = SettingsProvider(
      storage: InMemorySettingsStorage(),
      secureWindowService: _FakeSecureWindowService(),
    );
    await tester.pumpWidget(
      _testApp(settingsNotifier: settings, authNotifier: auth),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delete-account-tile')),
      160,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete-account-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续注销'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-account-confirmation')),
      '@wrong',
    );
    await tester.tap(find.widgetWithText(FilledButton, '确认注销'));
    await tester.pumpAndSettle();

    expect(api.deleteAccountCalls, isEmpty);
    expect(find.text('账号不匹配'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('delete-account-confirmation')),
      '@XiaoMing',
    );
    await tester.tap(find.widgetWithText(FilledButton, '确认注销'));
    await tester.pumpAndSettle();

    expect(api.deleteAccountCalls, ['@XiaoMing']);
    expect(auth.status, AuthStatus.unauthenticated);
    expect(await storage.readToken(), isNull);
  });
}

void _useTallTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _testApp({
  required SettingsProvider settingsNotifier,
  AuthProvider? authNotifier,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => settingsNotifier),
      if (authNotifier != null)
        authProvider.overrideWith((ref) => authNotifier),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

const _testUser = User(
  id: 'user-1',
  displayName: 'Xiao Ming',
  account: '@XiaoMing',
  token: 'token-1',
);

class _FakeSecureWindowService extends SecureWindowService {
  _FakeSecureWindowService();

  final List<bool> calls = [];

  @override
  Future<void> disable() => setEnabled(false);

  @override
  Future<void> enable() => setEnabled(true);

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }
}

class _FakeApiService implements ApiService {
  final List<String> deleteAccountCalls = [];

  @override
  Future<bool> checkAccount(String account) async => true;

  @override
  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  }) async {
    deleteAccountCalls.add(accountConfirmation);
  }

  @override
  Future<User> register({
    required String displayName,
    required String account,
  }) async => _testUser;

  @override
  Future<User> validate(String token) async => _testUser;
}
