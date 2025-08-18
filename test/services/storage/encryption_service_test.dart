// Test for EncryptionService AES key generation
// Verifies that the service can generate secure encryption keys

import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/services/storage/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('should generate unique encryption keys', () {
      final key1 = encryptionService.generateEncryptionKey();
      final key2 = encryptionService.generateEncryptionKey();
      final key3 = encryptionService.generateEncryptionKey();

      // Keys should be different
      expect(key1, isNot(equals(key2)));
      expect(key1, isNot(equals(key3)));
      expect(key2, isNot(equals(key3)));

      // Keys should be non-empty strings
      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      expect(key3, isNotEmpty);

      // Keys should be SHA-256 hashes (64 characters)
      expect(key1.length, equals(64));
      expect(key2.length, equals(64));
      expect(key3.length, equals(64));

      // Keys should contain only hexadecimal characters
      expect(key1, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(key2, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(key3, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('should generate user keys', () {
      final userKey1 = encryptionService.generateUserKey('user1');
      final userKey2 = encryptionService.generateUserKey('user2');
      final userKey3 = encryptionService.generateUserKey('user1'); // Same user, different key

      // Keys should be different
      expect(userKey1, isNot(equals(userKey2)));
      expect(userKey1, isNot(equals(userKey3)));

      // Keys should be non-empty strings
      expect(userKey1, isNotEmpty);
      expect(userKey2, isNotEmpty);
      expect(userKey3, isNotEmpty);

      // Keys should be SHA-256 hashes (64 characters)
      expect(userKey1.length, equals(64));
      expect(userKey2.length, equals(64));
      expect(userKey3.length, equals(64));

      // Keys should contain only hexadecimal characters
      expect(userKey1, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(userKey2, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(userKey3, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('should have encryption enabled', () {
      expect(encryptionService.isEncryptionEnabled, isTrue);
    });

    test('should provide algorithm info', () {
      final algorithmInfo = encryptionService.algorithmInfo;
      expect(algorithmInfo, isNotEmpty);
      expect(algorithmInfo, contains('AES-256-GCM'));
      expect(algorithmInfo, contains('PBKDF2'));
    });
  });
}
