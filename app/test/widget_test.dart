import 'dart:async';
import 'dart:convert';

import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/ios_ui_capability_service.dart';
import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/main.dart';
import 'package:app/models/user.dart';
import 'package:app/models/group.dart';
import 'package:app/models/message.dart';
import 'package:app/models/settings.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/providers/settings_provider.dart';
import 'package:app/screens/create_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets('shows create account shell', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('keeps Chinese locale available', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.binding.setLocale('zh', '');
    await tester.pumpAndSettle();

    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('authenticated shell starts the chat websocket connection', (
    WidgetTester tester,
  ) async {
    final user = _user(token: 'token-1');
    final storage = InMemorySecureStorage();
    await storage.saveSession(user);
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    addTearDown(webSocketService.dispose);

    await tester.pumpWidget(
      _testApp(
        apiService: _OfflineApiService(user),
        secureStorageService: storage,
        webSocketService: webSocketService,
      ),
    );
    await tester.pumpAndSettle();

    expect(socket.sentJson, [
      {
        'type': 'auth',
        'payload': {'token': 'token-1'},
      },
    ]);
    expect(find.text('PrvChat'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('authenticated chat list shows contacts and new chat actions', (
    WidgetTester tester,
  ) async {
    final user = _user(token: 'token-1');
    final storage = InMemorySecureStorage();
    await storage.saveSession(user);

    await tester.pumpWidget(
      _testApp(
        apiService: _OfflineApiService(user, [
          const User(
            id: '2',
            displayName: 'Bob',
            account: '2222222222',
            token: 'token-1',
            avatarIndex: 1,
          ),
        ]),
        secureStorageService: storage,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsAtLeastNWidgets(1));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('创建群聊'), findsOneWidget);
  });

  testWidgets('chat list unread marker is a compact dot without count text', (
    WidgetTester tester,
  ) async {
    final user = _user(token: 'token-1');
    final storage = InMemorySecureStorage();
    await storage.saveSession(user);
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    addTearDown(webSocketService.dispose);

    await tester.pumpWidget(
      _testApp(
        apiService: _OfflineApiService(user, [
          const User(
            id: '2',
            displayName: 'Bob',
            account: '2222222222',
            token: 'token-1',
            avatarIndex: 1,
          ),
        ]),
        secureStorageService: storage,
        webSocketService: webSocketService,
      ),
    );
    await tester.pumpAndSettle();

    socket.addIncoming(
      WebSocketEvent(
        type: 'message.created',
        payload: {
          'message': Message(
            id: 'm-unread',
            fromId: '2',
            toId: 'me',
            toType: ConversationType.user,
            type: MessageType.text,
            content: 'hello',
            timestamp: DateTime.utc(2026, 5, 10, 1, 2),
            status: MessageStatus.sent,
          ).toJson(),
        },
      ),
    );
    await tester.pumpAndSettle();

    final unreadDot = tester.widget<SizedBox>(
      find.byKey(const Key('chat-list-unread-dot')),
    );
    expect(unreadDot.width, 10);
    expect(unreadDot.height, 10);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('chat list shows burn voice messages as voice preview', (
    WidgetTester tester,
  ) async {
    final user = _user(token: 'token-1');
    final storage = InMemorySecureStorage();
    await storage.saveSession(user);
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    addTearDown(webSocketService.dispose);

    await tester.pumpWidget(
      _testApp(
        apiService: _OfflineApiService(user, [
          const User(
            id: '2',
            displayName: 'Bob',
            account: '2222222222',
            token: 'token-1',
            avatarIndex: 1,
          ),
        ]),
        secureStorageService: storage,
        webSocketService: webSocketService,
      ),
    );
    await tester.pumpAndSettle();

    socket.addIncoming(
      WebSocketEvent(
        type: 'message.created',
        payload: {
          'message': Message(
            id: 'm-burn-voice',
            fromId: '2',
            toId: 'me',
            toType: ConversationType.user,
            type: MessageType.burn,
            content:
                '{"kind":"voice","url":"/media/voice-1.m4a","durationMs":3000}',
            timestamp: DateTime.utc(2026, 5, 10, 1, 2),
            burnAfter: const Duration(seconds: 10),
            status: MessageStatus.sent,
          ).toJson(),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('语音消息'), findsOneWidget);
    expect(find.textContaining('/media/voice-1.m4a'), findsNothing);
  });

  testWidgets('incoming call opens the call screen automatically', (
    WidgetTester tester,
  ) async {
    final user = _user(token: 'token-1');
    final storage = InMemorySecureStorage();
    await storage.saveSession(user);
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    addTearDown(webSocketService.dispose);

    await tester.pumpWidget(
      _testApp(
        apiService: _OfflineApiService(user),
        secureStorageService: storage,
        webSocketService: webSocketService,
      ),
    );
    await tester.pumpAndSettle();

    socket.addIncoming(
      const WebSocketEvent(
        type: 'call.invite',
        payload: {
          'callId': 'call-1',
          'fromId': '2',
          'participantIds': ['1', '2'],
          'isGroup': false,
          'title': 'Bob',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsAtLeastNWidgets(1));
    expect(find.text('接听'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);
  });

  testWidgets('unauthenticated shell does not start the chat websocket', (
    WidgetTester tester,
  ) async {
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    addTearDown(webSocketService.dispose);

    await tester.pumpWidget(_testApp(webSocketService: webSocketService));
    await tester.pumpAndSettle();

    expect(socket.sentJson, isEmpty);
    expect(webSocketService.isConnected, isFalse);
  });

  testWidgets('ios native ui mode uses cupertino page transitions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        settingsStorage: InMemorySettingsStorage(
          initialSettings: const AppSettings(iosNativeUi: true),
        ),
        iosUiCapabilities: const IosUiCapabilities(
          level: IosInterfaceLevel.cupertino,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final builders = app.theme?.pageTransitionsTheme.builders;
    expect(
      builders?[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });
}

Widget _testApp({
  SecureStorageService? secureStorageService,
  ApiService? apiService,
  WebSocketService? webSocketService,
  SettingsStorage? settingsStorage,
  IosUiCapabilities iosUiCapabilities = const IosUiCapabilities(
    level: IosInterfaceLevel.material,
  ),
}) {
  return ProviderScope(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(
        secureStorageService ?? InMemorySecureStorage(),
      ),
      apiServiceProvider.overrideWithValue(apiService ?? _OfflineApiService()),
      if (settingsStorage != null)
        settingsStorageProvider.overrideWithValue(settingsStorage),
      iosUiCapabilitiesProvider.overrideWith((ref) async => iosUiCapabilities),
      if (webSocketService != null)
        webSocketServiceProvider.overrideWithValue(webSocketService),
      messageStoreProvider.overrideWithValue(InMemoryMessageStore()),
    ],
    child: const PrivateChatApp(),
  );
}

class _OfflineApiService implements ApiService {
  const _OfflineApiService([this.user, this.contacts = const []]);

  final User? user;
  final List<User> contacts;

  @override
  Future<bool> checkAccount(String account) async => true;

  @override
  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  }) async {}

  @override
  Future<User> register({required String displayName}) {
    throw UnimplementedError();
  }

  @override
  Future<User> validate(String token) async {
    final currentUser = user;
    if (currentUser == null) {
      throw const ApiException('unauthenticated');
    }
    return currentUser.copyWith(token: token);
  }

  @override
  Future<List<User>> listContacts({required String token}) async => contacts;

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> updateAvatar({required String token, required int avatarIndex}) {
    throw UnimplementedError();
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

User _user({String token = 'token-1'}) {
  return User(id: 'me', displayName: 'Me', account: '1000000001', token: token);
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();

  List<Map<String, dynamic>> get sentJson => _sink.sent
      .map((source) => jsonDecode(source) as Map<String, dynamic>)
      .toList();

  void addIncoming(WebSocketEvent event) {
    _incoming.add(jsonEncode(event.toJson()));
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketSink implements WebSocketSink {
  final List<String> sent = [];

  @override
  void add(event) {
    sent.add(event.toString());
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {}

  @override
  Future get done => Future.value();
}
