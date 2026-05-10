import 'dart:async';
import 'dart:convert';

import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/main.dart';
import 'package:app/models/user.dart';
import 'package:app/models/group.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/chat_provider.dart';
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
    expect(find.text('聊天'), findsOneWidget);
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

    expect(find.text('Bob'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('创建群聊'), findsOneWidget);
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
}

Widget _testApp({
  SecureStorageService? secureStorageService,
  ApiService? apiService,
  WebSocketService? webSocketService,
}) {
  return ProviderScope(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(
        secureStorageService ?? InMemorySecureStorage(),
      ),
      apiServiceProvider.overrideWithValue(apiService ?? _OfflineApiService()),
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
  Future<List<Message>> syncMessages({required String token}) async => const [];
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
