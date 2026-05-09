import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}

class CryptoService {
  CryptoService(List<int> key) : _keyBytes = Uint8List.fromList(key) {
    if (_keyBytes.length != 32) {
      throw ArgumentError.value(key.length, 'key.length', 'must be 32 bytes');
    }
  }

  static final _random = Random.secure();

  final Uint8List _keyBytes;
  final AesGcm _algorithm = AesGcm.with256bits();

  static Uint8List generateKey() {
    return Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
  }

  static Future<String> mediaFilenameFor({
    required String messageId,
    String? extension,
  }) async {
    final digest = await Sha256().hash(utf8.encode(messageId));
    final filename = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final normalizedExtension = extension == null || extension.isEmpty
        ? ''
        : '.${extension.replaceFirst(RegExp(r'^\.+'), '').toLowerCase()}';
    return '$filename$normalizedExtension';
  }

  Future<EncryptedPayload> encryptString(String plaintext) {
    return encryptBytes(utf8.encode(plaintext));
  }

  Future<String> decryptString(EncryptedPayload payload) async {
    final bytes = await decryptBytes(payload);
    return utf8.decode(bytes);
  }

  Future<EncryptedPayload> encryptBytes(List<int> plaintext) async {
    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(_keyBytes),
    );
    return EncryptedPayload(
      nonce: Uint8List.fromList(secretBox.nonce),
      cipherText: Uint8List.fromList(secretBox.cipherText),
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  Future<Uint8List> decryptBytes(EncryptedPayload payload) async {
    final decrypted = await _algorithm.decrypt(
      SecretBox(
        payload.cipherText,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: SecretKey(_keyBytes),
    );
    return Uint8List.fromList(decrypted);
  }
}
