import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/chat_provider.dart';
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
}

Message _message({
  required String id,
  required String toId,
  required ConversationType toType,
}) {
  return Message(
    id: id,
    fromId: 'alice',
    toId: toId,
    toType: toType,
    type: MessageType.text,
    content: id,
    timestamp: DateTime.utc(2026, 5, 10, 1),
    status: MessageStatus.sent,
  );
}
