import 'dart:async';
import 'dart:convert';

import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/models/group.dart';
import 'package:app/models/message.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/social_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test(
    'presence events update online state without hardcoded status',
    () async {
      final api = _FakeApiService(user: _me);
      final storage = InMemorySecureStorage();
      await storage.saveSession(_me);
      final auth = AuthProvider(apiService: api, storageService: storage);
      await auth.initialize();
      final events = _FakeWebSocketEvents();
      final social = SocialProvider(
        apiService: api,
        auth: auth,
        webSocketService: events.service,
      );
      addTearDown(social.dispose);
      addTearDown(events.dispose);

      events.add(
        const WebSocketEvent(
          type: 'presence.snapshot',
          payload: {
            'onlineUserIds': ['2'],
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(social.isOnline('2'), isTrue);
      expect(social.isOnline('3'), isFalse);

      events.add(
        const WebSocketEvent(
          type: 'presence.updated',
          payload: {'userId': '2', 'isOnline': false},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(social.isOnline('2'), isFalse);
    },
  );

  test('message and group websocket events refresh the home lists', () async {
    final api = _FakeApiService(user: _me);
    final storage = InMemorySecureStorage();
    await storage.saveSession(_me);
    final auth = AuthProvider(apiService: api, storageService: storage);
    await auth.initialize();
    final events = _FakeWebSocketEvents();
    final social = SocialProvider(
      apiService: api,
      auth: auth,
      webSocketService: events.service,
    );
    addTearDown(social.dispose);
    addTearDown(events.dispose);
    await social.load();
    expect(api.listContactsCalls, 1);

    api.contacts = [_bob];
    events.add(
      WebSocketEvent(
        type: 'message.send',
        payload: {
          'message': Message(
            id: 'm1',
            fromId: '2',
            toId: '1',
            toType: ConversationType.user,
            type: MessageType.text,
            content: 'hello',
            timestamp: DateTime.utc(2026, 5, 10),
            status: MessageStatus.sent,
          ).toJson(),
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(api.listContactsCalls, 2);
    expect(social.contacts.single.id, '2');

    api.groups = [_team];
    events.add(
      WebSocketEvent(type: 'group.updated', payload: {'group': _teamJson}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(social.groups.single.id, '7');
  });
}

const _me = User(
  id: '1',
  displayName: 'Me',
  account: '1000000001',
  token: 'token-1',
);

const _bob = User(
  id: '2',
  displayName: 'Bob',
  account: '1000000002',
  token: 'token-1',
);

const _teamJson = {
  'id': 7,
  'groupCode': '12345678',
  'name': 'Team',
  'ownerId': 1,
  'members': [
    {
      'userId': 1,
      'role': 'owner',
      'account': '1000000001',
      'displayName': 'Me',
      'avatarIndex': 0,
    },
    {
      'userId': 2,
      'role': 'member',
      'account': '1000000002',
      'displayName': 'Bob',
      'avatarIndex': 0,
    },
  ],
};

final _team = Group.fromJson(_teamJson);

class _FakeWebSocketEvents {
  final channel = _FakeWebSocketChannel();
  late final service = WebSocketService(connector: (_) => channel);

  _FakeWebSocketEvents() {
    service.connect(token: 'token-1');
    channel.clearSent();
  }

  void add(WebSocketEvent event) {
    channel.addIncoming(event);
  }

  Future<void> dispose() async {
    await service.dispose();
  }
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();

  void addIncoming(WebSocketEvent event) {
    _incoming.add(event.toJsonString());
  }

  void clearSent() {
    _sink.sent.clear();
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

extension on WebSocketEvent {
  String toJsonString() => jsonEncode(toJson());
}

class _FakeApiService implements ApiService {
  _FakeApiService({required this.user});

  final User user;
  List<User> contacts = const [];
  List<Group> groups = const [];
  int listContactsCalls = 0;
  int listGroupsCalls = 0;

  @override
  Future<User> validate(String token) async => user.copyWith(token: token);

  @override
  Future<List<User>> listContacts({required String token}) async {
    listContactsCalls += 1;
    return contacts;
  }

  @override
  Future<List<Group>> listGroups({required String token}) async {
    listGroupsCalls += 1;
    return groups;
  }

  @override
  Future<User> addContact({required String token, required String account}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> checkAccount(String account) {
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
  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Group> getGroup({required String token, required String groupId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String pushToken,
    String platform = 'android',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> register({required String displayName}) {
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
  Future<User> updateAvatar({required String token, required int avatarIndex}) {
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
  Future<Group> addGroupMembers({
    required String token,
    required String groupId,
    required List<String> memberIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Message>> syncMessages({required String token}) {
    throw UnimplementedError();
  }
}
