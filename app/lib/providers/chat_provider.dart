import 'dart:async';
import 'dart:convert';

import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/local_database_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/services/sound_effect_service.dart';
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
  return ApiMessageSyncService(
    apiService: ref.watch(apiServiceProvider),
    auth: ref.watch(authProvider),
  );
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
    soundEffects: ref.watch(soundEffectPlayerProvider),
  );
  return service;
}, dependencies: [soundEffectPlayerProvider]);

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

class ApiMessageSyncService implements MessageSyncService {
  const ApiMessageSyncService({
    required ApiService apiService,
    required AuthProvider auth,
  }) : _apiService = apiService,
       _auth = auth;

  final ApiService _apiService;
  final AuthProvider _auth;

  @override
  Future<List<Message>> sync({
    required ConversationType toType,
    required String peerId,
    required String currentUserId,
  }) async {
    final token = _auth.user?.token;
    if (token == null || token.isEmpty) {
      return const [];
    }
    final messages = await _apiService.syncMessages(token: token);
    return messages
        .where((message) {
          if (message.toType != toType) {
            return false;
          }
          if (toType == ConversationType.group) {
            return message.toId == peerId;
          }
          return (message.fromId == currentUserId && message.toId == peerId) ||
              (message.fromId == peerId && message.toId == currentUserId);
        })
        .toList(growable: false);
  }
}

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required String currentUserId,
    required LocalDatabaseService database,
    required MessageSyncService syncService,
    required WebSocketService webSocketService,
    SoundEffectPlayer? soundEffects,
    Uuid? uuid,
  }) : this._(
         currentUserId: currentUserId,
         database: database,
         databaseFuture: Future.value(database),
         syncService: syncService,
         webSocketService: webSocketService,
         soundEffects: soundEffects,
         uuid: uuid,
       );

  ChatProvider.initializing({
    required String currentUserId,
    required Future<LocalDatabaseService> databaseFuture,
    required MessageSyncService syncService,
    required WebSocketService webSocketService,
    SoundEffectPlayer? soundEffects,
    Uuid? uuid,
  }) : this._(
         currentUserId: currentUserId,
         databaseFuture: databaseFuture,
         syncService: syncService,
         webSocketService: webSocketService,
         soundEffects: soundEffects,
         uuid: uuid,
       );

  ChatProvider._({
    required String currentUserId,
    LocalDatabaseService? database,
    required Future<LocalDatabaseService> databaseFuture,
    required MessageSyncService syncService,
    required WebSocketService webSocketService,
    SoundEffectPlayer? soundEffects,
    Uuid? uuid,
  }) : _currentUserId = currentUserId,
       _database = database,
       _databaseFuture = databaseFuture,
       _syncService = syncService,
       _webSocketService = webSocketService,
       _soundEffects = soundEffects,
       _uuid = uuid ?? const Uuid() {
    _socketSubscription = _webSocketService.events.listen(handleEvent);
  }

  final String _currentUserId;
  LocalDatabaseService? _database;
  final Future<LocalDatabaseService> _databaseFuture;
  final MessageSyncService _syncService;
  final WebSocketService _webSocketService;
  final SoundEffectPlayer? _soundEffects;
  final Uuid _uuid;
  StreamSubscription<WebSocketEvent>? _socketSubscription;

  final Map<String, List<Message>> _messagesByConversation = {};
  final Map<String, int> _unreadCounts = {};
  final Map<String, Duration?> _burnAfterByConversation = {};
  String? _activeConversationKey;
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

  int unreadCountForConversation({
    required ConversationType toType,
    required String peerId,
  }) {
    return _unreadCounts[_key(toType, peerId)] ?? 0;
  }

  Message? lastMessageForConversation({
    required ConversationType toType,
    required String peerId,
  }) {
    final messages = _messagesByConversation[_key(toType, peerId)];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.last;
  }

  Duration? burnAfterFor(String peerId) {
    return _burnAfterByConversation[_key(ConversationType.user, peerId)];
  }

  Future<void> setBurnAfter(String peerId, Duration? burnAfter) async {
    final seconds = burnAfter?.inSeconds ?? 0;
    _webSocketService.send(
      WebSocketEvent(
        type: 'conversation.burn.set',
        payload: {'peerId': peerId, 'burnAfter': seconds},
      ),
    );
    _setBurnSettingFromPeerIds(
      peerIds: [_currentUserId, peerId],
      burnAfterSeconds: seconds,
    );
  }

  Future<void> loadMessages(String peerId) async {
    await loadConversation(toType: ConversationType.user, peerId: peerId);
  }

  void closeConversation({
    required ConversationType toType,
    required String peerId,
  }) {
    final conversationKey = _key(toType, peerId);
    if (_activeConversationKey != conversationKey) {
      return;
    }
    _activeConversationKey = null;
  }

  Future<void> loadConversation({
    required ConversationType toType,
    required String peerId,
  }) async {
    final conversationKey = _key(toType, peerId);
    _activeConversationKey = conversationKey;
    _isLoading = true;
    notifyListeners();
    await _ensureDatabaseOpen();
    final database = await _databaseService();
    final local = await database.listMessages(
      toType: toType,
      peerId: peerId,
      currentUserId: _currentUserId,
      includeBurned: true,
    );
    final remote = await _syncService.sync(
      toType: toType,
      peerId: peerId,
      currentUserId: _currentUserId,
    );
    final localBurnedIds = {
      for (final message in local)
        if (message.status == MessageStatus.burned) message.id,
    };
    final merged = <String, Message>{
      for (final message in local)
        if (message.status != MessageStatus.burned) message.id: message,
    };
    for (final message in remote) {
      if (localBurnedIds.contains(message.id)) {
        continue;
      }
      if (message.status == MessageStatus.burned) {
        merged.remove(message.id);
        await database.markBurned(message.id);
        continue;
      }
      merged[message.id] = message;
      await database.upsertMessage(message);
    }
    _messagesByConversation[conversationKey] = _sorted(merged.values);
    _unreadCounts[conversationKey] = 0;
    await _sendReadReceipts(
      _messagesByConversation[conversationKey] ?? const [],
    );
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

  Future<void> sendVoice(String peerId, VoiceMessagePayload payload) async {
    return sendMedia(peerId: peerId, type: MessageType.voice, payload: payload);
  }

  Future<void> sendMedia({
    required String peerId,
    required MessageType type,
    required MessageMediaPayload payload,
  }) async {
    return sendConversationMedia(
      toType: ConversationType.user,
      peerId: peerId,
      type: type,
      payload: payload,
    );
  }

  Future<void> sendConversationMedia({
    required ConversationType toType,
    required String peerId,
    required MessageType type,
    required MessageMediaPayload payload,
    Duration? burnAfter,
  }) async {
    if (type == MessageType.text || type == MessageType.burn) {
      throw ArgumentError('sendMedia only supports image, voice, and file');
    }
    final effectiveBurnAfter =
        burnAfter ?? _burnAfterByConversation[_key(toType, peerId)];
    final payloadJson = payload.toJson();
    payloadJson['kind'] ??= type.name;
    final content = jsonEncode(payloadJson);
    final message = Message(
      id: _uuid.v4(),
      fromId: _currentUserId,
      toId: peerId,
      toType: toType,
      type: effectiveBurnAfter == null ? type : MessageType.burn,
      content: content,
      timestamp: DateTime.now().toUtc(),
      burnAfter: effectiveBurnAfter,
      status: MessageStatus.sent,
    );
    await _upsertLocal(message);
    unawaited(_soundEffects?.play(SoundEffect.messageSent) ?? Future.value());
    _webSocketService.send(
      WebSocketEvent(type: 'message.send', payload: message.toJson()),
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
    final effectiveBurnAfter =
        burnAfter ?? _burnAfterByConversation[_key(toType, peerId)];
    final message = Message(
      id: _uuid.v4(),
      fromId: _currentUserId,
      toId: peerId,
      toType: toType,
      type: effectiveBurnAfter == null ? MessageType.text : MessageType.burn,
      content: trimmed,
      timestamp: DateTime.now().toUtc(),
      burnAfter: effectiveBurnAfter,
      status: MessageStatus.sent,
    );
    await _upsertLocal(message);
    unawaited(_soundEffects?.play(SoundEffect.messageSent) ?? Future.value());
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
          unawaited(
            _soundEffects?.play(SoundEffect.messageReceived) ?? Future.value(),
          );
          final key = _key(message.toType, _conversationPeer(message));
          if (key == _activeConversationKey) {
            _unreadCounts[key] = 0;
            await _sendReadReceipt(message);
          } else {
            _unreadCounts[key] = (_unreadCounts[key] ?? 0) + 1;
          }
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
      case 'conversation.burn.updated':
        _handleBurnSetting(event.payload);
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
      if (status == MessageStatus.burned) {
        final copy = [...entry.value]..removeAt(index);
        _messagesByConversation[entry.key] = copy;
        await _ensureDatabaseOpen();
        final database = await _databaseService();
        await database.markBurned(id);
        notifyListeners();
        return;
      }
      final copy = [...entry.value]..[index] = updated;
      _messagesByConversation[entry.key] = copy;
      await _ensureDatabaseOpen();
      final database = await _databaseService();
      await database.upsertMessage(updated);
      notifyListeners();
      return;
    }
  }

  Future<void> _updateFromStatusEvent(
    Map<String, dynamic> payload,
    MessageStatus status,
  ) async {
    final message = _messageFromPayload(payload);
    if (status == MessageStatus.burned) {
      await _updateStatus(
        message?.id ?? _messageIdFromPayload(payload),
        status,
      );
      return;
    }
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

  Future<void> _sendReadReceipts(List<Message> messages) async {
    for (final message in messages) {
      if (message.fromId == _currentUserId ||
          message.status == MessageStatus.read ||
          message.status == MessageStatus.burned ||
          message.status == MessageStatus.revoked) {
        continue;
      }
      _webSocketService.send(_readEvent(message.id));
    }
  }

  Future<void> _sendReadReceipt(Message message) async {
    if (message.fromId == _currentUserId ||
        message.status == MessageStatus.read ||
        message.status == MessageStatus.burned ||
        message.status == MessageStatus.revoked) {
      return;
    }
    _webSocketService.send(_readEvent(message.id));
  }

  WebSocketEvent _readEvent(String messageId) {
    return WebSocketEvent(
      type: 'message.read',
      payload: {'messageId': messageId},
    );
  }

  void _handleBurnSetting(Map<String, dynamic> payload) {
    final setting = payload['setting'];
    if (setting is! Map) {
      return;
    }
    final peerIds = (setting['peerIds'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final burnAfter = _toInt(setting['burnAfter']);
    _setBurnSettingFromPeerIds(peerIds: peerIds, burnAfterSeconds: burnAfter);
  }

  void _setBurnSettingFromPeerIds({
    required List<String> peerIds,
    required int burnAfterSeconds,
  }) {
    final peerId = peerIds.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    if (peerId.isEmpty) {
      return;
    }
    _burnAfterByConversation[_key(ConversationType.user, peerId)] =
        burnAfterSeconds > 0 ? Duration(seconds: burnAfterSeconds) : null;
    notifyListeners();
  }

  Future<void> markBurned(String messageId) async {
    await _updateStatus(messageId, MessageStatus.burned);
    _webSocketService.send(
      WebSocketEvent(type: 'message.burned', payload: {'messageId': messageId}),
    );
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

abstract interface class MessageMediaPayload {
  Map<String, Object?> toJson();
}

class VoiceMessagePayload implements MessageMediaPayload {
  const VoiceMessagePayload({
    required this.url,
    required this.localPath,
    required this.duration,
    required this.sizeBytes,
  });

  final String url;
  final String localPath;
  final Duration duration;
  final int sizeBytes;

  @override
  Map<String, Object?> toJson() {
    return {
      'url': url,
      'localPath': localPath,
      'durationMs': duration.inMilliseconds,
      'sizeBytes': sizeBytes,
    };
  }
}

class MediaMessagePayload implements MessageMediaPayload {
  const MediaMessagePayload({
    this.kind = 'file',
    required this.url,
    required this.localPath,
    required this.title,
    required this.sizeBytes,
  });

  final String kind;
  final String url;
  final String localPath;
  final String title;
  final int sizeBytes;

  @override
  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'url': url,
      'localPath': localPath,
      'title': title,
      'sizeBytes': sizeBytes,
    };
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

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
