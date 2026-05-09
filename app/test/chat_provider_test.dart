import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

Message _message({
  required String id,
  String fromId = 'alice',
  required String toId,
  required ConversationType toType,
}) {
  return Message(
    id: id,
    fromId: fromId,
    toId: toId,
    toType: toType,
    type: MessageType.text,
    content: id,
    timestamp: DateTime.utc(2026, 5, 10, 1),
    status: MessageStatus.sent,
  );
}
