import 'dart:typed_data';
import 'dart:convert';

import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryMessageStore store;
  late LocalDatabaseService database;

  setUp(() async {
    store = InMemoryMessageStore();
    database = LocalDatabaseService(
      cryptoService: CryptoService(CryptoService.generateKey()),
      store: store,
    );
    await database.open();
  });

  test(
    'stores encrypted content and decrypts it when reading messages',
    () async {
      final message = _message(
        id: 'm1',
        fromId: 'alice',
        toId: 'bob',
        content: 'meet at 9',
      );

      await database.upsertMessage(message);

      final raw = store.rawMessage('m1');
      expect(raw, isNotNull);
      expect(raw!['encrypted_content'], isA<Uint8List>());
      expect(
        utf8.decode(
          raw['encrypted_content'] as List<int>,
          allowMalformed: true,
        ),
        isNot(contains('meet at 9')),
      );

      final messages = await database.listMessages(
        toType: ConversationType.user,
        peerId: 'bob',
        currentUserId: 'alice',
      );

      expect(messages, hasLength(1));
      expect(messages.single.content, 'meet at 9');
    },
  );

  test('lists both directions for the requested direct conversation', () async {
    await database.upsertMessage(
      _message(id: 'direct-1', fromId: 'alice', toId: 'bob', content: 'one'),
    );
    await database.upsertMessage(
      _message(id: 'direct-2', fromId: 'bob', toId: 'alice', content: 'two'),
    );
    await database.upsertMessage(
      _message(
        id: 'direct-3',
        fromId: 'alice',
        toId: 'carol',
        content: 'carol',
      ),
    );
    await database.upsertMessage(
      _message(
        id: 'direct-4',
        fromId: 'carol',
        toId: 'alice',
        content: 'carol inbound',
      ),
    );
    await database.upsertMessage(
      _message(
        id: 'group-1',
        fromId: 'bob',
        toId: 'bob',
        toType: ConversationType.group,
        content: 'group',
      ),
    );

    final messages = await database.listMessages(
      toType: ConversationType.user,
      peerId: 'bob',
      currentUserId: 'alice',
    );

    expect(messages.map((message) => message.id), ['direct-1', 'direct-2']);
  });

  test('lists group messages by group id only', () async {
    await database.upsertMessage(
      _message(
        id: 'direct-1',
        fromId: 'alice',
        toId: 'team',
        content: 'not group',
      ),
    );
    await database.upsertMessage(
      _message(
        id: 'group-1',
        fromId: 'alice',
        toId: 'team',
        toType: ConversationType.group,
        content: 'group one',
      ),
    );
    await database.upsertMessage(
      _message(
        id: 'group-2',
        fromId: 'bob',
        toId: 'team',
        toType: ConversationType.group,
        content: 'group two',
      ),
    );
    await database.upsertMessage(
      _message(
        id: 'other-group',
        fromId: 'bob',
        toId: 'other-team',
        toType: ConversationType.group,
        content: 'other',
      ),
    );

    final messages = await database.listMessages(
      toType: ConversationType.group,
      peerId: 'team',
      currentUserId: 'alice',
    );

    expect(messages.map((message) => message.id), ['group-1', 'group-2']);
  });

  test('upserts existing messages by id', () async {
    await database.upsertMessage(
      _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'old'),
    );
    await database.upsertMessage(
      _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'new'),
    );

    final messages = await database.listMessages(
      toType: ConversationType.user,
      peerId: 'bob',
      currentUserId: 'alice',
    );

    expect(messages, hasLength(1));
    expect(messages.single.content, 'new');
  });

  test('deletes messages by id', () async {
    await database.upsertMessage(
      _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'one'),
    );
    await database.upsertMessage(
      _message(id: 'm2', fromId: 'bob', toId: 'alice', content: 'two'),
    );

    await database.deleteMessage('m1');

    final messages = await database.listMessages(
      toType: ConversationType.user,
      peerId: 'bob',
      currentUserId: 'alice',
    );

    expect(messages.map((message) => message.id), ['m2']);
  });

  test('clears all local messages', () async {
    await database.upsertMessage(
      _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'one'),
    );
    await database.upsertMessage(
      _message(id: 'm2', fromId: 'bob', toId: 'alice', content: 'two'),
    );

    await database.clear();

    final messages = await database.listMessages(
      toType: ConversationType.user,
      peerId: 'bob',
      currentUserId: 'alice',
    );

    expect(messages, isEmpty);
  });

  test('burned messages are hidden when reopening the conversation', () async {
    await database.upsertMessage(
      _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'one'),
    );

    await database.markBurned('m1');

    final messages = await database.listMessages(
      toType: ConversationType.user,
      peerId: 'bob',
      currentUserId: 'alice',
    );

    expect(messages, isEmpty);
  });

  test(
    'decrypts existing messages with the same persisted master key',
    () async {
      final sharedStore = InMemoryMessageStore();
      final masterKey = CryptoService.generateKey();
      final firstDatabase = LocalDatabaseService(
        cryptoService: CryptoService(masterKey),
        store: sharedStore,
      );
      await firstDatabase.open();
      await firstDatabase.upsertMessage(
        _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'persisted'),
      );
      await firstDatabase.close();

      final secondDatabase = LocalDatabaseService(
        cryptoService: CryptoService(masterKey),
        store: sharedStore,
      );
      await secondDatabase.open();

      final messages = await secondDatabase.listMessages(
        toType: ConversationType.user,
        peerId: 'bob',
        currentUserId: 'alice',
      );

      expect(messages.single.content, 'persisted');

      await secondDatabase.close();
    },
  );

  test(
    'does not decrypt existing messages with a different master key',
    () async {
      final sharedStore = InMemoryMessageStore();
      final firstDatabase = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: sharedStore,
      );
      await firstDatabase.open();
      await firstDatabase.upsertMessage(
        _message(id: 'm1', fromId: 'alice', toId: 'bob', content: 'persisted'),
      );
      await firstDatabase.close();

      final secondDatabase = LocalDatabaseService(
        cryptoService: CryptoService(CryptoService.generateKey()),
        store: sharedStore,
      );
      await secondDatabase.open();

      expect(
        () => secondDatabase.listMessages(
          toType: ConversationType.user,
          peerId: 'bob',
          currentUserId: 'alice',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      await secondDatabase.close();
    },
  );
}

Message _message({
  required String id,
  required String fromId,
  required String toId,
  required String content,
  ConversationType toType = ConversationType.user,
}) {
  return Message(
    id: id,
    fromId: fromId,
    toId: toId,
    toType: toType,
    type: MessageType.text,
    content: content,
    timestamp: DateTime.utc(2026, 5, 10, 1),
    status: MessageStatus.sent,
  );
}
