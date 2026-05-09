import 'dart:async';

import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  final database = LocalDatabaseService(
    cryptoService: CryptoService(CryptoService.generateKey()),
  );
  ref.onDispose(database.close);
  return database;
});

final messageSyncServiceProvider = Provider<MessageSyncService>((ref) {
  return NoopMessageSyncService();
});

final chatProvider = ChangeNotifierProvider<ChatProvider>((ref) {
  final auth = ref.watch(authProvider);
  final service = ChatProvider(
    currentUserId: auth.user?.id ?? '',
    database: ref.watch(localDatabaseServiceProvider),
    syncService: ref.watch(messageSyncServiceProvider),
    webSocketService: ref.watch(webSocketServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

abstract interface class MessageSyncService {
  Future<List<Message>> sync({
    required ConversationType toType,
    required String peerId,
    required String currentUserId,
  });
}

class NoopMessageSyncService implements MessageSyncService {
  @override
  Future<List<Message>> sync({
    required ConversationType toType,
    required String peerId,
    required String currentUserId,
  }) async {
    return const [];
  }
}

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required String currentUserId,
    required LocalDatabaseService database,
    required MessageSyncService syncService,
    required WebSocketService webSocketService,
    Uuid? uuid,
  }) : _currentUserId = currentUserId,
       _database = database,
       _syncService = syncService,
       _webSocketService = webSocketService,
       _uuid = uuid ?? const Uuid() {
    _socketSubscription = _webSocketService.events.listen(handleEvent);
  }

  final String _currentUserId;
  final LocalDatabaseService _database;
  final MessageSyncService _syncService;
  final WebSocketService _webSocketService;
  final Uuid _uuid;
  StreamSubscription<WebSocketEvent>? _socketSubscription;

  final Map<String, List<Message>> _messagesByConversation = {};
  final Map<String, int> _unreadCounts = {};
  bool _isLoading = false;
  Future<void>? _openDatabaseFuture;

  bool get isLoading => _isLoading;
  Map<String, int> get unreadCounts => Map.unmodifiable(_unreadCounts);

  List<Message> messagesFor(String peerId) {
    return messagesForConversation(
      toType: ConversationType.user,
      peerId: peerId,
    );
  }

  List<Message> messagesForConversation({
    required ConversationType toType,
    required String peerId,
  }) {
    return List.unmodifiable(
      _messagesByConversation[_key(toType, peerId)] ?? const [],
    );
  }

  int unreadCountFor(String peerId) {
    return _unreadCounts[_key(ConversationType.user, peerId)] ?? 0;
  }

  Future<void> loadMessages(String peerId) async {
    await loadConversation(toType: ConversationType.user, peerId: peerId);
  }

  Future<void> loadConversation({
    required ConversationType toType,
    required String peerId,
  }) async {
    _isLoading = true;
    notifyListeners();
    await _ensureDatabaseOpen();
    final local = await _database.listMessages(
      toType: toType,
      peerId: peerId,
      currentUserId: _currentUserId,
    );
    final remote = await _syncService.sync(
      toType: toType,
      peerId: peerId,
      currentUserId: _currentUserId,
    );
    final merged = <String, Message>{
      for (final message in local) message.id: message,
    };
    for (final message in remote) {
      merged[message.id] = message;
      await _database.upsertMessage(message);
    }
    _messagesByConversation[_key(toType, peerId)] = _sorted(merged.values);
    _unreadCounts[_key(toType, peerId)] = 0;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendText(String peerId, String text) async {
    await sendConversationText(
      toType: ConversationType.user,
      peerId: peerId,
      text: text,
    );
  }

  Future<void> sendConversationText({
    required ConversationType toType,
    required String peerId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final message = Message(
      id: _uuid.v4(),
      fromId: _currentUserId,
      toId: peerId,
      toType: toType,
      type: MessageType.text,
      content: trimmed,
      timestamp: DateTime.now().toUtc(),
      status: MessageStatus.sent,
    );
    await _upsertLocal(message);
    _webSocketService.send(
      WebSocketEvent(type: 'message.send', payload: message.toJson()),
    );
  }

  Future<void> handleEvent(WebSocketEvent event) async {
    switch (event.type) {
      case 'message.created':
      case 'message.received':
        final message = Message.fromJson(event.payload);
        await _upsertLocal(message);
        if (message.fromId != _currentUserId) {
          final key = _key(message.toType, _conversationPeer(message));
          _unreadCounts[key] = (_unreadCounts[key] ?? 0) + 1;
          notifyListeners();
        }
      case 'message.delivered':
        await _updateStatus(
          event.payload['messageId'],
          MessageStatus.delivered,
        );
      case 'message.read':
        await _updateStatus(event.payload['messageId'], MessageStatus.read);
      case 'message.revoked':
        await _updateStatus(event.payload['messageId'], MessageStatus.revoked);
      case 'message.burned':
        await _updateStatus(event.payload['messageId'], MessageStatus.burned);
      case 'message.burn.start':
        await _markBurnStarted(event.payload['messageId']);
    }
  }

  Future<void> _upsertLocal(Message message) async {
    await _ensureDatabaseOpen();
    await _database.upsertMessage(message);
    final key = _key(message.toType, _conversationPeer(message));
    final current = _messagesByConversation[key] ?? const [];
    _messagesByConversation[key] = _sorted([
      ...current.where((item) => item.id != message.id),
      message,
    ]);
    notifyListeners();
  }

  Future<void> _updateStatus(Object? messageId, MessageStatus status) async {
    if (messageId == null) {
      return;
    }
    final id = messageId.toString();
    for (final entry in _messagesByConversation.entries) {
      final index = entry.value.indexWhere((message) => message.id == id);
      if (index == -1) {
        continue;
      }
      final updated = entry.value[index].copyWith(status: status);
      final copy = [...entry.value]..[index] = updated;
      _messagesByConversation[entry.key] = copy;
      if (status == MessageStatus.burned) {
        await _ensureDatabaseOpen();
        await _database.markBurned(id);
      } else {
        await _ensureDatabaseOpen();
        await _database.upsertMessage(updated);
      }
      notifyListeners();
      return;
    }
  }

  Future<void> _markBurnStarted(Object? messageId) async {
    if (messageId == null) {
      return;
    }
    final id = messageId.toString();
    for (final entry in _messagesByConversation.entries) {
      if (entry.value.any((message) => message.id == id)) {
        notifyListeners();
        return;
      }
    }
  }

  String _conversationPeer(Message message) {
    if (message.toType == ConversationType.group) {
      return message.toId;
    }
    return message.fromId == _currentUserId ? message.toId : message.fromId;
  }

  List<Message> _sorted(Iterable<Message> messages) {
    return messages.toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
  }

  String _key(ConversationType type, String peerId) => '${type.name}:$peerId';

  Future<void> _ensureDatabaseOpen() {
    return _openDatabaseFuture ??= _database.open();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}
