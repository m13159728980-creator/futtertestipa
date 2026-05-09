import 'dart:async';
import 'dart:convert';

import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/utils/crypto_service.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final localDatabaseServiceProvider = Provider<Future<LocalDatabaseService>>((
  ref,
) {
  final future = _createLocalDatabaseService(
    ref.watch(secureStorageServiceProvider),
    ref.watch(messageStoreProvider),
  );
  ref.onDispose(() {
    unawaited(future.then((database) => database.close()));
  });
  return future;
});

final messageStoreProvider = Provider<MessageStore>((ref) {
  return SqfliteMessageStore();
});

final messageSyncServiceProvider = Provider<MessageSyncService>((ref) {
  return NoopMessageSyncService();
});

final chatProvider = ChangeNotifierProvider<ChatProvider>((ref) {
  final auth = ref.watch(authProvider);
  final webSocketService = ref.watch(webSocketServiceProvider);
  final token = auth.user?.token;
  if (token == null || token.isEmpty) {
    unawaited(webSocketService.disconnect());
  } else {
    webSocketService.connect(token: token);
  }
  final service = ChatProvider.initializing(
    currentUserId: auth.user?.id ?? '',
    databaseFuture: ref.watch(localDatabaseServiceProvider),
    syncService: ref.watch(messageSyncServiceProvider),
    webSocketService: webSocketService,
  );
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
  }) : this._(
         currentUserId: currentUserId,
         database: database,
         databaseFuture: Future.value(database),
         syncService: syncService,
         webSocketService: webSocketService,
         uuid: uuid,
       );

  ChatProvider.initializing({
    required String currentUserId,
    required Future<LocalDatabaseService> databaseFuture,
    required MessageSyncService syncService,
    required WebSocketService webSocketService,
    Uuid? uuid,
  }) : this._(
         currentUserId: currentUserId,
         databaseFuture: databaseFuture,
         syncService: syncService,
         webSocketService: webSocketService,
         uuid: uuid,
       );

  ChatProvider._({
    required String currentUserId,
    LocalDatabaseService? database,
    required Future<LocalDatabaseService> databaseFuture,
    required MessageSyncService syncService,
    required WebSocketService webSocketService,
    Uuid? uuid,
  }) : _currentUserId = currentUserId,
       _database = database,
       _databaseFuture = databaseFuture,
       _syncService = syncService,
       _webSocketService = webSocketService,
       _uuid = uuid ?? const Uuid() {
    _socketSubscription = _webSocketService.events.listen(handleEvent);
  }

  final String _currentUserId;
  LocalDatabaseService? _database;
  final Future<LocalDatabaseService> _databaseFuture;
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
    final database = await _databaseService();
    final local = await database.listMessages(
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
      await database.upsertMessage(message);
    }
    _messagesByConversation[_key(toType, peerId)] = _sorted(merged.values);
    _unreadCounts[_key(toType, peerId)] = 0;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendText(
    String peerId,
    String text, {
    Duration? burnAfter,
  }) async {
    await sendConversationText(
      toType: ConversationType.user,
      peerId: peerId,
      text: text,
      burnAfter: burnAfter,
    );
  }

  Future<void> sendConversationText({
    required ConversationType toType,
    required String peerId,
    required String text,
    Duration? burnAfter,
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
      type: burnAfter == null ? MessageType.text : MessageType.burn,
      content: trimmed,
      timestamp: DateTime.now().toUtc(),
      burnAfter: burnAfter,
      status: MessageStatus.sent,
    );
    await _upsertLocal(message);
    _webSocketService.send(
      WebSocketEvent(type: 'message.send', payload: message.toJson()),
    );
  }

  Future<void> handleEvent(WebSocketEvent event) async {
    switch (event.type) {
      case 'message.send':
      case 'message.created':
      case 'message.received':
        final message = _messageFromPayload(event.payload);
        if (message == null) {
          return;
        }
        await _upsertLocal(message);
        if (message.fromId != _currentUserId) {
          final key = _key(message.toType, _conversationPeer(message));
          _unreadCounts[key] = (_unreadCounts[key] ?? 0) + 1;
          notifyListeners();
        }
      case 'message.delivered':
        await _updateFromStatusEvent(event.payload, MessageStatus.delivered);
      case 'message.read':
        await _updateFromStatusEvent(event.payload, MessageStatus.read);
      case 'message.revoke':
      case 'message.revoked':
        await _updateFromStatusEvent(event.payload, MessageStatus.revoked);
      case 'message.burned':
        await _updateFromStatusEvent(event.payload, MessageStatus.burned);
      case 'message.burn.start':
        final message = _messageFromPayload(event.payload);
        await _markBurnStarted(
          message?.id ?? _messageIdFromPayload(event.payload),
        );
    }
  }

  Future<void> _upsertLocal(Message message) async {
    await _ensureDatabaseOpen();
    final database = await _databaseService();
    await database.upsertMessage(message);
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
        final database = await _databaseService();
        await database.markBurned(id);
      } else {
        await _ensureDatabaseOpen();
        final database = await _databaseService();
        await database.upsertMessage(updated);
      }
      notifyListeners();
      return;
    }
  }

  Future<void> _updateFromStatusEvent(
    Map<String, dynamic> payload,
    MessageStatus status,
  ) async {
    final message = _messageFromPayload(payload);
    if (message != null) {
      await _upsertLocal(message.copyWith(status: status));
      return;
    }
    await _updateStatus(_messageIdFromPayload(payload), status);
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

  Future<void> markBurned(String messageId) {
    return _updateStatus(messageId, MessageStatus.burned);
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

  Future<LocalDatabaseService> _databaseService() async {
    return _database ??= await _databaseFuture;
  }

  Future<void> _ensureDatabaseOpen() async {
    final database = await _databaseService();
    return _openDatabaseFuture ??= database.open();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}

Future<LocalDatabaseService> _createLocalDatabaseService(
  SecureStorageService storageService,
  MessageStore store,
) async {
  final masterKey = await storageService.ensureMasterKey();
  return LocalDatabaseService(
    cryptoService: CryptoService(base64Decode(masterKey)),
    store: store,
  );
}

Message? _messageFromPayload(Map<String, dynamic> payload) {
  final nested = payload['message'];
  if (nested is Map<String, dynamic>) {
    return Message.fromJson(nested);
  }
  if (nested is Map) {
    return Message.fromJson(Map<String, dynamic>.from(nested));
  }
  if (payload.containsKey('id')) {
    return Message.fromJson(payload);
  }
  return null;
}

Object? _messageIdFromPayload(Map<String, dynamic> payload) {
  return payload['messageId'] ?? payload['message_id'] ?? payload['id'];
}
