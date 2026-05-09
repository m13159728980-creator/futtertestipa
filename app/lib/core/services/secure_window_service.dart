import 'package:app/native/secure_window_channel.dart';

class SecureWindowService {
  const SecureWindowService({SecureWindowChannel? channel})
    : _channel = channel ?? const SecureWindowChannel();

  final SecureWindowChannel _channel;

  Future<void> enable() {
    return setEnabled(true);
  }

  Future<void> disable() {
    return setEnabled(false);
  }

  Future<void> setEnabled(bool enabled) {
    return _channel.setEnabled(enabled);
  }
}
