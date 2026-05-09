import 'package:flutter/services.dart';

class SecureWindowChannel {
  const SecureWindowChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app/secure_window');

  final MethodChannel _channel;

  Future<void> setEnabled(bool enabled) {
    return _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }
}
