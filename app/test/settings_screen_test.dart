import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/secure_window_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:app/models/group.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/providers/settings_provider.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-language-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(settings.settings.languageCode, 'en');

    await tester.tap(find.byKey(const ValueKey('settings-language-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文').last);
    await tester.pumpAndSettle();

    expect(settings.settings.languageCode, 'zh');
  });

  testWidgets('theme mode can follow system or be forced light and dark', (
    tester,
  ) async {
    final settings = SettingsProvider(
      storage: InMemorySettingsStorage(),
      secureWindowService: _FakeSecureWindowService(),
    );
    await tester.pumpWidget(_testApp(settingsNotifier: settings));

    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-theme-mode-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();

    expect(settings.settings.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('settings-theme-mode-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色').last);
    await tester.pumpAndSettle();

    expect(settings.settings.themeMode, ThemeMode.light);

    await tester.tap(find.byKey(const ValueKey('settings-theme-mode-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随系统').last);
    await tester.pumpAndSettle();

    expect(settings.settings.themeMode, ThemeMode.system);
  });

  testWidgets('profile header copies own numeric ID', (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map?)?['text']?.toString();
            return null;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final storage = InMemorySecureStorage();
    await storage.saveSession(_testUser);
    final auth = AuthProvider(
      apiService: _FakeApiService(),
      storageService: storage,
    );
    await auth.initialize();
    final settings = SettingsProvider(
      storage: InMemorySettingsStorage(),
      secureWindowService: _FakeSecureWindowService(),
    );
    await tester.pumpWidget(
      _testApp(settingsNotifier: settings, authNotifier: auth),
    );

    await tester.tap(find.byKey(const ValueKey('settings-copy-id')));
    await tester.pumpAndSettle();

    expect(clipboardText, '1000000001');
    expect(find.text('ID 已复制'), findsOneWidget);
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

  testWidgets(
    'account deletion clears local cache and resets settings after exact confirmation',
    (tester) async {
      _useTallTestViewport(tester);
      final api = _FakeApiService();
      final storage = InMemorySecureStorage();
      final settingsStorage = InMemorySettingsStorage();
      final cacheService = _FakeCacheService();
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      await database.open();
      await database.upsertMessage(_message(id: 'm1'));
      await storage.saveSession(_testUser);
      final auth = AuthProvider(apiService: api, storageService: storage);
      await auth.initialize();
      final settings = SettingsProvider(
        storage: settingsStorage,
        cacheService: cacheService,
        secureWindowService: _FakeSecureWindowService(),
      );
      await settings.setLanguage('en');
      await settings.setMessageNotifications(false);
      await tester.pumpWidget(
        _testApp(
          settingsNotifier: settings,
          authNotifier: auth,
          database: database,
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('delete-account-tile')),
        160,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -80));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-account-tile')));
      await tester.pumpAndSettle();
      expect(find.text('注销账号'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('继续注销'));
      await tester.pumpAndSettle();
      expect(find.text('确认注销'), findsAtLeastNWidgets(1));
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-confirmation')),
        '@wrong',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认注销'));
      await tester.pumpAndSettle();

      expect(api.deleteAccountCalls, isEmpty);
      expect(find.text('ID不匹配'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('delete-account-confirmation')),
        '1000000001',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认注销'));
      await tester.pumpAndSettle();

      expect(api.deleteAccountCalls, ['1000000001']);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
      expect(cacheService.clearCacheCalls, 1);
      expect(settingsStorage.clearSettingsCalls, 1);
      expect(settings.settings.languageCode, 'zh');
      expect(settings.settings.messageNotifications, isTrue);
      expect(
        await database.listMessages(
          toType: ConversationType.user,
          peerId: 'bob',
          currentUserId: 'alice',
        ),
        isEmpty,
      );
    },
  );
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
  LocalDatabaseService? database,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => settingsNotifier),
      if (authNotifier != null)
        authProvider.overrideWith((ref) => authNotifier),
      if (database != null)
        localDatabaseServiceProvider.overrideWith(
          (ref) => Future.value(database),
        ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

Message _message({required String id}) {
  return Message(
    id: id,
    fromId: 'alice',
    toId: 'bob',
    toType: ConversationType.user,
    type: MessageType.text,
    content: 'hello',
    timestamp: DateTime.utc(2026, 5, 10),
    status: MessageStatus.sent,
  );
}

const _testUser = User(
  id: 'user-1',
  displayName: 'Xiao Ming',
  account: '1000000001',
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

class _FakeCacheService implements CacheService {
  int clearCacheCalls = 0;

  @override
  Future<void> clearCache() async {
    clearCacheCalls++;
  }
}

class _FakeApiService implements ApiService {
  final List<String> deleteAccountCalls = [];
  final List<String> profileNames = [];

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
  Future<User> register({required String displayName}) async => _testUser;

  @override
  Future<User> validate(String token) async => _testUser;

  @override
  Future<List<User>> listContacts({required String token}) async => const [];

  @override
  Future<List<Group>> listGroups({required String token}) async => const [];

  @override
  Future<User> addContact({required String token, required String account}) {
    throw UnimplementedError();
  }

  @override
  Future<Group> createGroup({
    required String token,
    required String name,
    required List<String> memberIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Group> getGroup({required String token, required String groupId}) {
    throw UnimplementedError();
  }

  @override
  Future<Group> renameGroup({
    required String token,
    required String groupId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Group> addGroupMembers({
    required String token,
    required String groupId,
    required List<String> memberIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> updateProfile({
    required String token,
    required String displayName,
  }) async {
    profileNames.add(displayName);
    return _testUser.copyWith(displayName: displayName, token: token);
  }

  @override
  Future<User> updateAvatar({
    required String token,
    required int avatarIndex,
  }) async {
    return _testUser.copyWith(avatarIndex: avatarIndex, token: token);
  }

  @override
  Future<List<Message>> syncMessages({required String token}) async => const [];

  @override
  Future<void> registerPushToken({
    required String token,
    required String pushToken,
    String platform = 'android',
  }) async {}
}
