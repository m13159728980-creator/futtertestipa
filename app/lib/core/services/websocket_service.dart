import 'dart:async';
import 'dart:convert';

import 'package:app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

typedef WebSocketConnector = WebSocketChannel Function(Uri uri);
typedef ReconnectDelay = Duration Function(int attempt);

class WebSocketEvent {
  const WebSocketEvent({required this.type, this.payload = const {}});

  final String type;
  final Map<String, dynamic> payload;

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return WebSocketEvent(
      type: json['type'].toString(),
      payload: payload is Map<String, dynamic> ? payload : const {},
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

class WebSocketService {
  WebSocketService({
    String url = AppConfig.wsUrl,
    WebSocketConnector? connector,
    ReconnectDelay? reconnectDelay,
  }) : _url = url,
       _connector = connector ?? WebSocketChannel.connect,
       _reconnectDelay = reconnectDelay ?? _defaultReconnectDelay;

  final String _url;
  final WebSocketConnector _connector;
  final ReconnectDelay _reconnectDelay;
  final StreamController<WebSocketEvent> _events =
      StreamController<WebSocketEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  String? _token;
  bool _disposed = false;
  bool _shouldReconnect = false;
  int _attempt = 0;

  Stream<WebSocketEvent> get events => _events.stream;
  bool get isConnected => _channel != null;

  void connect({required String token}) {
    if (_shouldReconnect && _token == token && _channel != null) {
      return;
    }
    _token = token;
    _shouldReconnect = true;
    _open();
  }

  void send(WebSocketEvent event) {
    _channel?.sink.add(jsonEncode(event.toJson()));
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final subscription = _subscription;
    _subscription = null;
    final channel = _channel;
    _channel = null;
    await subscription?.cancel();
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _events.close();
  }

  void _open() {
    if (_disposed) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();

    try {
      final channel = _connector(Uri.parse(_url));
      _channel = channel;
      _attempt = 0;
      send(WebSocketEvent(type: 'auth', payload: {'token': _token}));
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is Map<String, dynamic>) {
        _events.add(WebSocketEvent.fromJson(decoded));
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'websocket_service',
          context: ErrorDescription('while decoding a websocket event'),
        ),
      );
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    if (!_shouldReconnect || _disposed) {
      return;
    }
    _attempt += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay(_attempt), _open);
  }
}

Duration _defaultReconnectDelay(int attempt) {
  final seconds = 1 << (attempt - 1).clamp(0, 5);
  return Duration(seconds: seconds);
}
