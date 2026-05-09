import 'dart:convert';
import 'dart:math';

import 'package:app/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return FlutterSecureStorageService();
});

abstract interface class SecureStorageService {
  Future<String?> readToken();

  Future<User?> readUser();

  Future<void> saveSession(User user);

  Future<String?> readMasterKey();

  Future<String> ensureMasterKey();

  Future<void> clear();
}

class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _masterKeyKey = 'master_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<User?> readUser() async {
    final source = await _storage.read(key: _userKey);
    if (source == null) {
      return null;
    }
    return User.fromStorageJson(source);
  }

  @override
  Future<void> saveSession(User user) async {
    await _storage.write(key: _tokenKey, value: user.token);
    await _storage.write(key: _userKey, value: user.toStorageJson());
  }

  @override
  Future<String?> readMasterKey() {
    return _storage.read(key: _masterKeyKey);
  }

  @override
  Future<String> ensureMasterKey() async {
    final existing = await readMasterKey();
    if (existing != null && _isValidMasterKey(existing)) {
      return existing;
    }

    final key = _generateMasterKey();
    await _storage.write(key: _masterKeyKey, value: key);
    return key;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _masterKeyKey);
  }
}

class InMemorySecureStorage implements SecureStorageService {
  InMemorySecureStorage({Map<String, String>? initialValues})
    : _values = {...?initialValues};

  final Map<String, String> _values;

  @override
  Future<String?> readToken() async => _values['auth_token'];

  @override
  Future<User?> readUser() async {
    final source = _values['auth_user'];
    return source == null ? null : User.fromStorageJson(source);
  }

  @override
  Future<void> saveSession(User user) async {
    _values['auth_token'] = user.token;
    _values['auth_user'] = user.toStorageJson();
  }

  @override
  Future<String?> readMasterKey() async => _values['master_key'];

  @override
  Future<String> ensureMasterKey() async {
    final existing = await readMasterKey();
    if (existing != null && _isValidMasterKey(existing)) {
      return existing;
    }
    final key = _generateMasterKey();
    _values['master_key'] = key;
    return key;
  }

  @override
  Future<void> clear() async {
    _values.remove('auth_token');
    _values.remove('auth_user');
    _values.remove('master_key');
  }
}

bool _isValidMasterKey(String key) {
  try {
    return base64Decode(key).length == 32;
  } on FormatException {
    return false;
  }
}

String _generateMasterKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Encode(bytes);
}
