import 'dart:typed_data';
import 'dart:convert';

import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
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
      );

      expect(messages, hasLength(1));
      expect(messages.single.content, 'meet at 9');
    },
  );

  test('lists only messages for the requested conversation', () async {
    await database.upsertMessage(
      _message(id: 'direct-1', fromId: 'alice', toId: 'bob', content: 'one'),
    );
    await database.upsertMessage(
      _message(id: 'direct-2', fromId: 'alice', toId: 'carol', content: 'two'),
    );
    await database.upsertMessage(
      _message(
        id: 'group-1',
        fromId: 'alice',
        toId: 'bob',
        toType: ConversationType.group,
        content: 'group',
      ),
    );

    final messages = await database.listMessages(
      toType: ConversationType.user,
      peerId: 'bob',
    );

    expect(messages.map((message) => message.id), ['direct-1']);
  });
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
