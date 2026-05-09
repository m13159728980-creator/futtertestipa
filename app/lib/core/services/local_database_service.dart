import 'dart:typed_data';

import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

abstract interface class MessageStore {
  Future<void> open();

  Future<void> upsert(Map<String, Object?> row);

  Future<List<Map<String, Object?>>> listByConversation({
    required ConversationType toType,
    required String peerId,
    String? currentUserId,
  });

  Future<Map<String, Object?>?> getById(String id);

  Future<void> delete(String id);

  Future<void> updateStatus(String id, MessageStatus status);

  Future<void> close();
}

class LocalDatabaseService {
  LocalDatabaseService({
    required CryptoService cryptoService,
    MessageStore? store,
  }) : _cryptoService = cryptoService,
       _store = store ?? SqfliteMessageStore();

  final CryptoService _cryptoService;
  final MessageStore _store;

  Future<void> open() => _store.open();

  Future<void> upsertMessage(Message message) async {
    final encrypted = await _cryptoService.encryptString(
      message.content ?? message.encryptedContent ?? '',
    );
    await _store.upsert({
      'id': message.id,
      'from_id': message.fromId,
      'to_id': message.toId,
      'to_type': message.toType.name,
      'type': message.type.name,
      'encrypted_content': encrypted.cipherText,
      'nonce': encrypted.nonce,
      'mac': encrypted.mac,
      'timestamp': message.timestamp.toUtc().millisecondsSinceEpoch,
      'burn_after': message.burnAfter?.inSeconds,
      'status': message.status.name,
    });
  }

  Future<List<Message>> listMessages({
    required ConversationType toType,
    required String peerId,
    String? currentUserId,
  }) async {
    final rows = await _store.listByConversation(
      toType: toType,
      peerId: peerId,
      currentUserId: currentUserId,
    );
    return Future.wait(rows.map(_messageFromRow));
  }

  Future<void> deleteMessage(String id) => _store.delete(id);

  Future<void> markBurned(String id) =>
      _store.updateStatus(id, MessageStatus.burned);

  Future<void> close() => _store.close();

  Future<Message> _messageFromRow(Map<String, Object?> row) async {
    final content = await _cryptoService.decryptString(
      EncryptedPayload(
        nonce: _bytes(row['nonce']),
        cipherText: _bytes(row['encrypted_content']),
        mac: _bytes(row['mac']),
      ),
    );
    return Message(
      id: row['id'].toString(),
      fromId: row['from_id'].toString(),
      toId: row['to_id'].toString(),
      toType: ConversationType.fromJson(row['to_type']),
      type: MessageType.fromJson(row['type']),
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row['timestamp'] as int,
        isUtc: true,
      ),
      burnAfter: row['burn_after'] == null
          ? null
          : Duration(seconds: row['burn_after'] as int),
      status: MessageStatus.fromJson(row['status']),
    );
  }

  Uint8List _bytes(Object? value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    throw StateError('Expected encrypted message bytes, got $value');
  }
}

class SqfliteMessageStore implements MessageStore {
  Database? _database;

  @override
  Future<void> open() async {
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'gram_messages.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            from_id TEXT NOT NULL,
            to_id TEXT NOT NULL,
            to_type TEXT NOT NULL,
            type TEXT NOT NULL,
            encrypted_content BLOB NOT NULL,
            nonce BLOB NOT NULL,
            mac BLOB NOT NULL,
            timestamp INTEGER NOT NULL,
            burn_after INTEGER,
            status TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conversation '
          'ON messages (to_type, to_id, timestamp)',
        );
      },
    );
  }

  @override
  Future<void> upsert(Map<String, Object?> row) async {
    await _db.insert(
      'messages',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Map<String, Object?>>> listByConversation({
    required ConversationType toType,
    required String peerId,
    String? currentUserId,
  }) {
    if (toType == ConversationType.user && currentUserId != null) {
      return _db.query(
        'messages',
        where:
            'to_type = ? AND ((from_id = ? AND to_id = ?) OR '
            '(from_id = ? AND to_id = ?))',
        whereArgs: [toType.name, currentUserId, peerId, peerId, currentUserId],
        orderBy: 'timestamp ASC',
      );
    }
    return _db.query(
      'messages',
      where: 'to_type = ? AND to_id = ?',
      whereArgs: [toType.name, peerId],
      orderBy: 'timestamp ASC',
    );
  }

  @override
  Future<Map<String, Object?>?> getById(String id) async {
    final rows = await _db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateStatus(String id, MessageStatus status) async {
    await _db.update(
      'messages',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Database get _db {
    final db = _database;
    if (db == null) {
      throw StateError('Local database is not open');
    }
    return db;
  }
}

class InMemoryMessageStore implements MessageStore {
  final Map<String, Map<String, Object?>> _messages = {};
  bool _isOpen = false;

  @override
  Future<void> open() async {
    _isOpen = true;
  }

  @override
  Future<void> upsert(Map<String, Object?> row) async {
    _checkOpen();
    _messages[row['id'].toString()] = Map<String, Object?>.from(row);
  }

  @override
  Future<List<Map<String, Object?>>> listByConversation({
    required ConversationType toType,
    required String peerId,
    String? currentUserId,
  }) async {
    _checkOpen();
    final rows =
        _messages.values
            .where(
              (row) => _matchesConversation(
                row,
                toType: toType,
                peerId: peerId,
                currentUserId: currentUserId,
              ),
            )
            .map(Map<String, Object?>.from)
            .toList()
          ..sort(
            (left, right) =>
                (left['timestamp'] as int).compareTo(right['timestamp'] as int),
          );
    return rows;
  }

  bool _matchesConversation(
    Map<String, Object?> row, {
    required ConversationType toType,
    required String peerId,
    required String? currentUserId,
  }) {
    if (row['to_type'] != toType.name) {
      return false;
    }
    if (toType != ConversationType.user || currentUserId == null) {
      return row['to_id'] == peerId;
    }
    return (row['from_id'] == currentUserId && row['to_id'] == peerId) ||
        (row['from_id'] == peerId && row['to_id'] == currentUserId);
  }

  @override
  Future<Map<String, Object?>?> getById(String id) async {
    _checkOpen();
    final row = _messages[id];
    return row == null ? null : Map<String, Object?>.from(row);
  }

  Map<String, Object?>? rawMessage(String id) {
    final row = _messages[id];
    return row == null ? null : Map<String, Object?>.from(row);
  }

  @override
  Future<void> delete(String id) async {
    _checkOpen();
    _messages.remove(id);
  }

  @override
  Future<void> updateStatus(String id, MessageStatus status) async {
    _checkOpen();
    final row = _messages[id];
    if (row != null) {
      row['status'] = status.name;
    }
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  void _checkOpen() {
    if (!_isOpen) {
      throw StateError('Local message store is not open');
    }
  }
}
