import 'dart:convert';

import 'package:app/core/utils/crypto_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CryptoService', () {
    test('encrypts and decrypts content with AES-256-GCM', () async {
      final key = CryptoService.generateKey();
      final service = CryptoService(key);

      final encrypted = await service.encryptString('hello private chat');
      final decrypted = await service.decryptString(encrypted);

      expect(decrypted, 'hello private chat');
      expect(encrypted.nonce, hasLength(12));
      expect(encrypted.cipherText, isNot(utf8.encode('hello private chat')));
      expect(encrypted.mac, hasLength(16));
    });

    test('decrypting with the wrong key fails', () async {
      final encrypted = await CryptoService(
        CryptoService.generateKey(),
      ).encryptString('secret');

      final wrongKeyService = CryptoService(CryptoService.generateKey());

      expect(
        () => wrongKeyService.decryptString(encrypted),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('generates stable safe media filenames from message ids', () async {
      final first = await CryptoService.mediaFilenameFor(
        messageId: 'message/with unsafe chars',
        extension: 'jpg',
      );
      final second = await CryptoService.mediaFilenameFor(
        messageId: 'message/with unsafe chars',
        extension: '.jpg',
      );

      expect(first, second);
      expect(first, endsWith('.jpg'));
      expect(first, matches(RegExp(r'^[a-f0-9]{64}\.jpg$')));
    });
  });
}
