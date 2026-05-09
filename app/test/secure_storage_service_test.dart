import 'dart:convert';

import 'package:app/core/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterSecureStorageService', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('ensureMasterKey generates a base64 encoded 32 byte key', () async {
      final service = FlutterSecureStorageService();

      final key = await service.ensureMasterKey();

      expect(base64Decode(key), hasLength(32));
      expect(await service.readMasterKey(), key);
    });

    test('ensureMasterKey replaces an existing invalid key', () async {
      FlutterSecureStorage.setMockInitialValues({'master_key': 'invalid'});
      final service = FlutterSecureStorageService();

      final key = await service.ensureMasterKey();

      expect(key, isNot('invalid'));
      expect(base64Decode(key), hasLength(32));
      expect(await service.readMasterKey(), key);
    });

    test('ensureMasterKey keeps an existing valid key', () async {
      final validKey = base64Encode(List<int>.filled(32, 7));
      FlutterSecureStorage.setMockInitialValues({'master_key': validKey});
      final service = FlutterSecureStorageService();

      final key = await service.ensureMasterKey();

      expect(key, validKey);
      expect(await service.readMasterKey(), validKey);
    });

    test('clearAllLocalSecrets deletes the master key', () async {
      final service = FlutterSecureStorageService();
      await service.ensureMasterKey();

      await service.clearAllLocalSecrets();

      expect(await service.readMasterKey(), isNull);
    });
  });

  group('InMemorySecureStorage', () {
    test('ensureMasterKey generates a base64 encoded 32 byte key', () async {
      final storage = InMemorySecureStorage();

      final key = await storage.ensureMasterKey();

      expect(base64Decode(key), hasLength(32));
      expect(await storage.readMasterKey(), key);
    });

    test('ensureMasterKey replaces an existing invalid key', () async {
      final storage = InMemorySecureStorage(
        initialValues: {'master_key': 'invalid'},
      );

      final key = await storage.ensureMasterKey();

      expect(key, isNot('invalid'));
      expect(base64Decode(key), hasLength(32));
      expect(await storage.readMasterKey(), key);
    });

    test('ensureMasterKey keeps an existing valid key', () async {
      final validKey = base64Encode(List<int>.filled(32, 7));
      final storage = InMemorySecureStorage(
        initialValues: {'master_key': validKey},
      );

      final key = await storage.ensureMasterKey();

      expect(key, validKey);
      expect(await storage.readMasterKey(), validKey);
    });

    test('clearAllLocalSecrets deletes the master key', () async {
      final storage = InMemorySecureStorage();
      await storage.ensureMasterKey();

      await storage.clearAllLocalSecrets();

      expect(await storage.readMasterKey(), isNull);
    });
  });
}
