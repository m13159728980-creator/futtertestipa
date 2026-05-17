import 'dart:async';
import 'dart:convert';

import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/sound_effect_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:app/models/group.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test(
    'chatProvider connects and authenticates websocket when auth user exists',
    () async {
      final user = _user(token: 'token-1');
      final storage = InMemorySecureStorage();
      await storage.saveSession(user);
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(_FakeApiService(user)),
          secureStorageServiceProvider.overrideWithValue(storage),
          webSocketServiceProvider.overrideWithValue(webSocketService),
          messageStoreProvider.overrideWithValue(InMemoryMessageStore()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(webSocketService.dispose);

      await container.read(authProvider).initialize();
      container.read(chatProvider);

      expect(socket.sentJson, [
        {
          'type': 'auth',
          'payload': {'token': 'token-1'},
        },
      ]);
    },
  );

  test('chatProvider disconnects and does not connect without auth user', () {
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    webSocketService.connect(token: 'old-token');
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(_FakeApiService(null)),
        secureStorageServiceProvider.overrideWithValue(InMemorySecureStorage()),
        webSocketServiceProvider.overrideWithValue(webSocketService),
        messageStoreProvider.overrideWithValue(InMemoryMessageStore()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(webSocketService.dispose);

    container.read(chatProvider);

    expect(socket.sentJson, [
      {
        'type': 'auth',
        'payload': {'token': 'old-token'},
      },
    ]);
    expect(webSocketService.isConnected, isFalse);
  });

  test('WebSocketService ignores connect calls for the active token', () {
    var connectCount = 0;
    final socket = _FakeWebSocketChannel();
    final service = WebSocketService(
      connector: (_) {
        connectCount += 1;
        return socket;
      },
    );
    addTearDown(service.dispose);

    service.connect(token: 'token-1');
    service.connect(token: 'token-1');

    expect(connectCount, 1);
    expect(socket.sentJson, [
      {
        'type': 'auth',
        'payload': {'token': 'token-1'},
      },
    ]);
  });

  test('loads group messages separately from direct messages', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    await database.open();
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: WebSocketService(
        connector: (_) => throw StateError('unused'),
      ),
    );

    await database.upsertMessage(
      _message(id: 'direct', toId: 'team', toType: ConversationType.user),
    );
    await database.upsertMessage(
      _message(id: 'group', toId: 'team', toType: ConversationType.group),
    );

    await provider.loadConversation(
      toType: ConversationType.group,
      peerId: 'team',
    );

    expect(
      provider
          .messagesForConversation(
            toType: ConversationType.group,
            peerId: 'team',
          )
          .map((message) => message.id),
      ['group'],
    );

    provider.dispose();
    await database.close();
  });

  test('opens the local database before loading messages', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: WebSocketService(
        connector: (_) => throw StateError('unused'),
      ),
    );

    await provider.loadMessages('alice');

    expect(provider.messagesFor('alice'), isEmpty);

    provider.dispose();
    await database.close();
  });

  test('sends burn text messages with burn duration', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    webSocketService.connect(token: 'token-1');
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: webSocketService,
    );

    await provider.sendText(
      'alice',
      'secret',
      burnAfter: const Duration(seconds: 30),
    );

    final message = provider.messagesFor('alice').single;
    expect(message.type, MessageType.burn);
    expect(message.burnAfter, const Duration(seconds: 30));
    expect(socket.sentJson.last['payload'], containsPair('type', 'burn'));
    expect(socket.sentJson.last['payload'], containsPair('burnAfter', 30));

    provider.dispose();
    await database.close();
    await webSocketService.dispose();
  });

  test('sends voice messages with uploaded media metadata', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    webSocketService.connect(token: 'token-1');
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: webSocketService,
    );

    await provider.sendVoice(
      'alice',
      const VoiceMessagePayload(
        url: '/media/voice-1',
        localPath: '/local/voice-1.m4a',
        duration: Duration(seconds: 3),
        sizeBytes: 1024,
      ),
    );

    final message = provider.messagesFor('alice').single;
    expect(message.type, MessageType.voice);
    expect(message.content, contains('/media/voice-1'));
    expect(message.content, contains('/local/voice-1.m4a'));
    expect(message.content, contains('"durationMs":3000'));
    expect(socket.sentJson.last['payload'], containsPair('type', 'voice'));

    provider.dispose();
    await database.close();
    await webSocketService.dispose();
  });

  test('sends image messages with uploaded media metadata', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    webSocketService.connect(token: 'token-1');
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: webSocketService,
      uuid: const _FixedUuid('11111111-1111-4111-8111-111111111111'),
    );

    await provider.sendMedia(
      peerId: 'alice',
      type: MessageType.image,
      payload: const MediaMessagePayload(
        url: '/media/photo-1',
        localPath: '/local/photo.jpg',
        title: 'photo.jpg',
        sizeBytes: 4096,
      ),
    );

    final message = provider.messagesFor('alice').single;
    expect(message.type, MessageType.image);
    expect(message.content, contains('/media/photo-1'));
    expect(message.content, contains('/local/photo.jpg'));
    expect(message.content, contains('"title":"photo.jpg"'));
    expect(socket.sentJson.last['payload'], containsPair('type', 'image'));

    provider.dispose();
    await database.close();
    await webSocketService.dispose();
  });

  test('sends file messages with uploaded media metadata', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    webSocketService.connect(token: 'token-1');
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: webSocketService,
    );

    await provider.sendMedia(
      peerId: 'alice',
      type: MessageType.file,
      payload: const MediaMessagePayload(
        url: '/media/doc-1',
        localPath: '/local/doc.pdf',
        title: 'doc.pdf',
        sizeBytes: 8192,
      ),
    );

    final message = provider.messagesFor('alice').single;
    expect(message.type, MessageType.file);
    expect(message.content, contains('"kind":"file"'));
    expect(message.content, contains('/media/doc-1'));
    expect(socket.sentJson.last['payload'], containsPair('type', 'file'));

    provider.dispose();
    await database.close();
    await webSocketService.dispose();
  });

  test('sent messages and incoming messages play chat sound effects', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final socket = _FakeWebSocketChannel();
    final webSocketService = WebSocketService(connector: (_) => socket);
    webSocketService.connect(token: 'token-1');
    final sounds = _FakeSoundEffects();
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: NoopMessageSyncService(),
      webSocketService: webSocketService,
      soundEffects: sounds,
    );

    await provider.sendText('alice', 'hello');
    await provider.handleEvent(
      WebSocketEvent(
        type: 'message.created',
        payload: {
          'message': _message(
            id: 'incoming-sound',
            fromId: 'alice',
            toId: 'me',
          ).toJson(),
        },
      ),
    );

    expect(sounds.played, [
      SoundEffect.messageSent,
      SoundEffect.messageReceived,
    ]);

    provider.dispose();
    await database.close();
    await webSocketService.dispose();
  });

  test(
    'synced private burn setting applies to later outgoing messages',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      webSocketService.connect(token: 'token-1');
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: webSocketService,
      );

      await provider.handleEvent(
        const WebSocketEvent(
          type: 'conversation.burn.updated',
          payload: {
            'setting': {
              'toType': 'user',
              'peerIds': ['me', 'alice'],
              'burnAfter': 10,
              'enabled': true,
            },
          },
        ),
      );
      await provider.sendText('alice', 'synced secret');

      expect(provider.burnAfterFor('alice'), const Duration(seconds: 10));
      final message = provider.messagesFor('alice').single;
      expect(message.type, MessageType.burn);
      expect(message.burnAfter, const Duration(seconds: 10));

      provider.dispose();
      await database.close();
      await webSocketService.dispose();
    },
  );

  test(
    'backend message.send with payload.message upserts and increments unread',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: WebSocketService(
          connector: (_) => throw StateError('unused'),
        ),
      );

      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.send',
          payload: {
            'message': _message(
              id: 'backend-send',
              fromId: 'alice',
              toId: 'me',
              toType: ConversationType.user,
            ).toJson(),
          },
        ),
      );

      expect(provider.messagesFor('alice').map((message) => message.id), [
        'backend-send',
      ]);
      expect(provider.unreadCountFor('alice'), 1);

      provider.dispose();
      await database.close();
    },
  );

  test(
    'loading a conversation sends read receipts for incoming unread messages',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      await database.open();
      await database.upsertMessage(
        _message(
          id: 'incoming-unread',
          fromId: 'alice',
          toId: 'me',
          content: 'unread',
        ),
      );
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      webSocketService.connect(token: 'token-1');
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: webSocketService,
      );

      await provider.loadMessages('alice');

      expect(
        socket.sentJson,
        anyElement(
          predicate<Map<String, dynamic>>(
            (event) =>
                event['type'] == 'message.read' &&
                (event['payload'] as Map)['messageId'] == 'incoming-unread',
          ),
        ),
      );

      provider.dispose();
      await database.close();
      await webSocketService.dispose();
    },
  );

  test(
    'incoming messages for the open conversation are marked read immediately',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      webSocketService.connect(token: 'token-1');
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: webSocketService,
      );

      await provider.loadMessages('alice');
      socket.clearSent();
      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.created',
          payload: {
            'message': _message(
              id: 'open-incoming',
              fromId: 'alice',
              toId: 'me',
            ).toJson(),
          },
        ),
      );

      expect(provider.unreadCountFor('alice'), 0);
      expect(
        socket.sentJson,
        anyElement(
          predicate<Map<String, dynamic>>(
            (event) =>
                event['type'] == 'message.read' &&
                (event['payload'] as Map)['messageId'] == 'open-incoming',
          ),
        ),
      );

      provider.dispose();
      await database.close();
      await webSocketService.dispose();
    },
  );

  test(
    'incoming messages are unread after the conversation is closed',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      webSocketService.connect(token: 'token-1');
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: webSocketService,
      );

      await provider.loadMessages('alice');
      provider.closeConversation(
        toType: ConversationType.user,
        peerId: 'alice',
      );
      socket.clearSent();
      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.created',
          payload: {
            'message': _message(
              id: 'closed-incoming',
              fromId: 'alice',
              toId: 'me',
            ).toJson(),
          },
        ),
      );

      expect(provider.unreadCountFor('alice'), 1);
      expect(
        socket.sentJson.where(
          (event) =>
              event['type'] == 'message.read' &&
              (event['payload'] as Map)['messageId'] == 'closed-incoming',
        ),
        isEmpty,
      );

      provider.dispose();
      await database.close();
      await webSocketService.dispose();
    },
  );

  test(
    'server echo with same message id replaces the local sent message instead of duplicating it',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      webSocketService.connect(token: 'token-1');
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: webSocketService,
        uuid: const _FixedUuid('11111111-1111-4111-8111-111111111111'),
      );

      await provider.sendText('alice', 'hello');
      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.send',
          payload: {
            'message': _message(
              id: '11111111-1111-4111-8111-111111111111',
              fromId: 'me',
              toId: 'alice',
              content: 'hello',
            ).copyWith(status: MessageStatus.delivered).toJson(),
          },
        ),
      );

      expect(provider.messagesFor('alice'), hasLength(1));
      expect(
        provider.messagesFor('alice').single.status,
        MessageStatus.delivered,
      );

      provider.dispose();
      await database.close();
      await webSocketService.dispose();
    },
  );

  test(
    'backend message.read and message.revoke with payload.message update status',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: WebSocketService(
          connector: (_) => throw StateError('unused'),
        ),
      );

      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.send',
          payload: {
            'message': _message(
              id: 'status-message',
              fromId: 'me',
              toId: 'alice',
              toType: ConversationType.user,
            ).toJson(),
          },
        ),
      );
      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.read',
          payload: {
            'message': _message(
              id: 'status-message',
              fromId: 'me',
              toId: 'alice',
              toType: ConversationType.user,
            ).copyWith(status: MessageStatus.read).toJson(),
          },
        ),
      );

      expect(provider.messagesFor('alice').single.status, MessageStatus.read);

      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.revoke',
          payload: {
            'message': _message(
              id: 'status-message',
              fromId: 'me',
              toId: 'alice',
              toType: ConversationType.user,
            ).copyWith(status: MessageStatus.revoked).toJson(),
          },
        ),
      );

      expect(
        provider.messagesFor('alice').single.status,
        MessageStatus.revoked,
      );

      provider.dispose();
      await database.close();
    },
  );

  test(
    'backend burned message event removes the message from the open conversation',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: WebSocketService(
          connector: (_) => throw StateError('unused'),
        ),
      );

      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.send',
          payload: {
            'message': _message(
              id: 'burned-message',
              fromId: 'alice',
              toId: 'me',
              content: 'secret',
            ).toJson(),
          },
        ),
      );
      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.burned',
          payload: {
            'message': _message(
              id: 'burned-message',
              fromId: 'alice',
              toId: 'me',
              content: 'secret',
            ).copyWith(status: MessageStatus.burned).toJson(),
          },
        ),
      );

      expect(provider.messagesFor('alice'), isEmpty);

      provider.dispose();
      await database.close();
    },
  );

  test(
    'local burn expiry notifies the server so messages stay burned',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final socket = _FakeWebSocketChannel();
      final webSocketService = WebSocketService(connector: (_) => socket);
      webSocketService.connect(token: 'token-1');
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: NoopMessageSyncService(),
        webSocketService: webSocketService,
      );
      await provider.handleEvent(
        WebSocketEvent(
          type: 'message.send',
          payload: {
            'message': _message(
              id: 'local-burned-message',
              fromId: 'alice',
              toId: 'me',
              content: 'secret',
            ).toJson(),
          },
        ),
      );
      socket.clearSent();

      await provider.markBurned('local-burned-message');

      expect(provider.messagesFor('alice'), isEmpty);
      expect(socket.sentJson, [
        {
          'type': 'message.burned',
          'payload': {'messageId': 'local-burned-message'},
        },
      ]);

      provider.dispose();
      await database.close();
      await webSocketService.dispose();
    },
  );

  test('sync does not resurrect remotely burned messages', () async {
    final database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: InMemoryMessageStore(),
    );
    final remote = _StaticMessageSyncService();
    final provider = ChatProvider(
      currentUserId: 'me',
      database: database,
      syncService: remote,
      webSocketService: WebSocketService(
        connector: (_) => throw StateError('unused'),
      ),
    );
    await database.open();
    await database.upsertMessage(
      Message(
        id: 'burned-sync-message',
        fromId: 'peer',
        toId: 'me',
        toType: ConversationType.user,
        type: MessageType.burn,
        content: 'gone',
        timestamp: DateTime.utc(2026, 5, 10),
        burnAfter: const Duration(seconds: 5),
        status: MessageStatus.burned,
      ),
    );
    remote.messages = [
      Message(
        id: 'burned-sync-message',
        fromId: 'peer',
        toId: 'me',
        toType: ConversationType.user,
        type: MessageType.burn,
        content: 'gone',
        timestamp: DateTime.utc(2026, 5, 10),
        burnAfter: const Duration(seconds: 5),
        status: MessageStatus.burned,
      ),
    ];

    await provider.loadMessages('peer');

    expect(provider.messagesFor('peer'), isEmpty);
  });

  test(
    'sync does not resurrect a locally burned message awaiting server echo',
    () async {
      final database = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: InMemoryMessageStore(),
      );
      final remote = _StaticMessageSyncService();
      final provider = ChatProvider(
        currentUserId: 'me',
        database: database,
        syncService: remote,
        webSocketService: WebSocketService(
          connector: (_) => throw StateError('unused'),
        ),
      );
      await database.open();
      await database.upsertMessage(
        Message(
          id: 'local-burn-tombstone',
          fromId: 'peer',
          toId: 'me',
          toType: ConversationType.user,
          type: MessageType.burn,
          content: 'gone',
          timestamp: DateTime.utc(2026, 5, 10),
          burnAfter: const Duration(seconds: 5),
          status: MessageStatus.burned,
        ),
      );
      remote.messages = [
        Message(
          id: 'local-burn-tombstone',
          fromId: 'peer',
          toId: 'me',
          toType: ConversationType.user,
          type: MessageType.burn,
          content: 'gone',
          timestamp: DateTime.utc(2026, 5, 10),
          burnAfter: const Duration(seconds: 5),
          status: MessageStatus.read,
        ),
      ];

      await provider.loadMessages('peer');

      expect(provider.messagesFor('peer'), isEmpty);
      provider.dispose();
      await database.close();
    },
  );

  test(
    'localDatabaseServiceProvider decrypts existing messages with persisted master key',
    () async {
      final storage = InMemorySecureStorage();
      final store = InMemoryMessageStore();
      final firstContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storage),
          messageStoreProvider.overrideWithValue(store),
        ],
      );
      final firstDatabase = await firstContainer.read(
        localDatabaseServiceProvider,
      );
      await firstDatabase.open();
      await firstDatabase.upsertMessage(
        _message(
          id: 'persisted-provider',
          fromId: 'alice',
          toId: 'me',
          toType: ConversationType.user,
        ),
      );
      await firstDatabase.close();
      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storage),
          messageStoreProvider.overrideWithValue(store),
        ],
      );
      final secondDatabase = await secondContainer.read(
        localDatabaseServiceProvider,
      );
      await secondDatabase.open();

      final messages = await secondDatabase.listMessages(
        toType: ConversationType.user,
        peerId: 'alice',
        currentUserId: 'me',
      );

      expect(messages.single.content, 'persisted-provider');

      await secondDatabase.close();
      secondContainer.dispose();
    },
  );
}

class _StaticMessageSyncService implements MessageSyncService {
  List<Message> messages = const [];

  @override
  Future<List<Message>> sync({
    required ConversationType toType,
    required String peerId,
    required String currentUserId,
  }) async {
    return messages;
  }
}

class _FakeSoundEffects implements SoundEffectPlayer {
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async {
    played.add(effect);
  }

  @override
  Future<void> startRinging() async {
    played.add(SoundEffect.callRinging);
  }

  @override
  Future<void> stopRinging() async {}
}

User _user({String token = 'token-1'}) {
  return User(id: 'me', displayName: 'Me', account: '1000000001', token: token);
}

class _FakeApiService implements ApiService {
  const _FakeApiService(this.user);

  final User? user;

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
  Future<bool> checkAccount(String account) {
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
  Future<List<User>> listContacts({required String token}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Group>> listGroups({required String token}) {
    throw UnimplementedError();
  }

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
  Future<List<Message>> syncMessages({required String token}) {
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
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();

  List<Map<String, dynamic>> get sentJson => _sink.sent
      .map((source) => jsonDecode(source) as Map<String, dynamic>)
      .toList();

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
  bool closed = false;

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
  Future close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  Future get done => Future.value();
}

class _FixedUuid extends Uuid {
  const _FixedUuid(this.value);

  final String value;

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) => value;
}

Message _message({
  required String id,
  String fromId = 'alice',
  required String toId,
  ConversationType toType = ConversationType.user,
  String? content,
}) {
  return Message(
    id: id,
    fromId: fromId,
    toId: toId,
    toType: toType,
    type: MessageType.text,
    content: content ?? id,
    timestamp: DateTime.utc(2026, 5, 10, 1),
    status: MessageStatus.sent,
  );
}
