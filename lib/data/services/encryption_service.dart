// AES-256-GCM encryption service using PointyCastle for secure file encryption/decryption
// Implements proper authenticated encryption with PBKDF2 key derivation

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../../core/result.dart';
import '../../core/logger.dart';

/// Parameters for encryption operation in isolate
class _EncryptionParams {
  final Uint8List data;
  final String key;
  final Uint8List salt;
  final Uint8List iv;

  _EncryptionParams({
    required this.data,
    required this.key,
    required this.salt,
    required this.iv,
  });
}

/// Parameters for decryption operation in isolate
class _DecryptionParams {
  final Uint8List encryptedData;
  final String key;
  final Uint8List salt;
  final Uint8List iv;
  final Uint8List tag;
  final Uint8List ciphertext;

  _DecryptionParams({
    required this.encryptedData,
    required this.key,
    required this.salt,
    required this.iv,
    required this.tag,
    required this.ciphertext,
  });
}

/// Static function for encryption in isolate
Uint8List _encryptInIsolate(_EncryptionParams params) {
  try {
    const int saltLength = 32;
    const int ivLength = 12;
    const int tagLength = 16;
    const int keyLength = 32;
    const int pbkdf2Iterations = 100000;

    // Derive encryption key using PBKDF2
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(params.salt, pbkdf2Iterations, keyLength));
    final derivedKey = pbkdf2.process(utf8.encode(params.key));
    
    // Set up AES-GCM cipher
    final cipher = GCMBlockCipher(AESEngine());
    final cipherParams = AEADParameters(
      KeyParameter(derivedKey),
      tagLength * 8, // tag length in bits
      params.iv,
      Uint8List(0), // no additional authenticated data
    );
    
    cipher.init(true, cipherParams); // true for encryption
    
    // Encrypt data
    final encryptedData = cipher.process(params.data);
    
    // Extract encrypted data and tag
    final ciphertext = encryptedData.sublist(0, encryptedData.length - tagLength);
    final tag = encryptedData.sublist(encryptedData.length - tagLength);
    
    // Combine: salt + iv + tag + encrypted_data
    final result = Uint8List(saltLength + ivLength + tagLength + ciphertext.length);
    int offset = 0;
    
    result.setRange(offset, offset + saltLength, params.salt);
    offset += saltLength;
    
    result.setRange(offset, offset + ivLength, params.iv);
    offset += ivLength;
    
    result.setRange(offset, offset + tagLength, tag);
    offset += tagLength;
    
    result.setRange(offset, offset + ciphertext.length, ciphertext);
    
    return result;
  } catch (e) {
    throw Exception('Encryption failed in isolate: $e');
  }
}

/// Static function for decryption in isolate
Uint8List _decryptInIsolate(_DecryptionParams params) {
  try {
    const int tagLength = 16;
    const int keyLength = 32;
    const int pbkdf2Iterations = 100000;

    // Derive decryption key using PBKDF2
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(params.salt, pbkdf2Iterations, keyLength));
    final derivedKey = pbkdf2.process(utf8.encode(params.key));
    
    // Set up AES-GCM cipher for decryption
    final cipher = GCMBlockCipher(AESEngine());
    final cipherParams = AEADParameters(
      KeyParameter(derivedKey),
      tagLength * 8, // tag length in bits
      params.iv,
      Uint8List(0), // no additional authenticated data
    );
    
    cipher.init(false, cipherParams); // false for decryption
    
    // Combine ciphertext and tag for decryption
    final dataToDecrypt = Uint8List(params.ciphertext.length + params.tag.length);
    dataToDecrypt.setRange(0, params.ciphertext.length, params.ciphertext);
    dataToDecrypt.setRange(params.ciphertext.length, dataToDecrypt.length, params.tag);
    
    // Decrypt and verify
    final decryptedData = cipher.process(dataToDecrypt);
    
    return decryptedData;
  } catch (e) {
    throw Exception('Decryption failed in isolate: $e');
  }
}

/// AES-256-GCM encryption service using PointyCastle
/// Provides authenticated encryption with proper key derivation
class EncryptionService {
  static const Uuid _uuid = Uuid();
  static const int _saltLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM
  static const int _tagLength = 16; // 128 bits for GCM tag
  
  static final SecureRandom _secureRandom = SecureRandom('Fortuna')
    ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));

  /// Generate a cryptographically secure salt
  Uint8List _generateSalt() {
    return _secureRandom.nextBytes(_saltLength);
  }

  /// Generate a cryptographically secure IV for GCM
  Uint8List _generateIV() {
    return _secureRandom.nextBytes(_ivLength);
  }

  /// Encrypt file data with AES-256-GCM in background isolate
  /// Returns: [salt(32)] + [iv(12)] + [tag(16)] + [encrypted_data]
  Future<Result<Uint8List>> encryptFile(Uint8List data, String key) async {
    try {
      AppLogger.debug('EncryptionService.encryptFile: Encrypting ${data.length} bytes with AES-256-GCM in background isolate');
      
      // Generate salt and IV on main thread (fast operations)
      final salt = _generateSalt();
      final iv = _generateIV();
      
      // Prepare parameters for isolate
      final params = _EncryptionParams(
        data: data,
        key: key,
        salt: salt,
        iv: iv,
      );
      
      // Run CPU-intensive encryption in background isolate
      final result = await compute(_encryptInIsolate, params);
      
      AppLogger.debug('EncryptionService.encryptFile: Successfully encrypted ${data.length} bytes to ${result.length} bytes in background isolate');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('EncryptionService.encryptFile: Failed to encrypt', e, stackTrace);
      return Result.failure(Failure(message: 'Failed to encrypt file: $e'));
    }
  }

  /// Decrypt file data with AES-256-GCM in background isolate
  /// Expects: [salt(32)] + [iv(12)] + [tag(16)] + [encrypted_data]
  Future<Result<Uint8List>> decryptFile(Uint8List encryptedData, String key) async {
    try {
      AppLogger.debug('EncryptionService.decryptFile: Decrypting ${encryptedData.length} bytes with AES-256-GCM in background isolate');
      
      // Validate minimum length (fast operation on main thread)
      const minLength = _saltLength + _ivLength + _tagLength;
      if (encryptedData.length < minLength) {
        return Result.failure(Failure(message: 'Invalid encrypted data: too short'));
      }
      
      // Extract components on main thread (fast operations)
      int offset = 0;
      
      final salt = encryptedData.sublist(offset, offset + _saltLength);
      offset += _saltLength;
      
      final iv = encryptedData.sublist(offset, offset + _ivLength);
      offset += _ivLength;
      
      final tag = encryptedData.sublist(offset, offset + _tagLength);
      offset += _tagLength;
      
      final ciphertext = encryptedData.sublist(offset);
      
      // Prepare parameters for isolate
      final params = _DecryptionParams(
        encryptedData: encryptedData,
        key: key,
        salt: salt,
        iv: iv,
        tag: tag,
        ciphertext: ciphertext,
      );
      
      // Run CPU-intensive decryption in background isolate
      final decryptedData = await compute(_decryptInIsolate, params);
      
      AppLogger.debug('EncryptionService.decryptFile: Successfully decrypted ${encryptedData.length} bytes to ${decryptedData.length} bytes in background isolate');
      return Result.success(decryptedData);
    } catch (e, stackTrace) {
      AppLogger.error('EncryptionService.decryptFile: Failed to decrypt', e, stackTrace);
      return Result.failure(Failure(message: 'Failed to decrypt file: $e'));
    }
  }

  /// Generate a default encryption key for user data
  /// In production this would be derived from user credentials or stored securely
  String generateUserKey(String userId) {
    AppLogger.debug('EncryptionService.generateUserKey: Generating secure key for user $userId');
    
    // Generate a strong key using UUID and timestamp with additional entropy
    final uuid = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomBytes = _secureRandom.nextBytes(32);
    final randomHex = randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    
    final combined = '$userId-$uuid-$timestamp-$randomHex';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Generate a unique encryption key for file validator
  /// Returns a cryptographically secure random key
  String generateEncryptionKey() {
    AppLogger.debug('EncryptionService.generateEncryptionKey: Generating new encryption key');
    
    // Generate a secure random key using multiple entropy sources
    final uuid = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomBytes = _secureRandom.nextBytes(64);
    final randomHex = randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    
    final combined = '$uuid-$timestamp-$randomHex';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    final key = digest.toString();
    
    AppLogger.debug('EncryptionService.generateEncryptionKey: Generated secure key with length ${key.length}');
    return key;
  }

  /// Check if encryption is enabled
  bool get isEncryptionEnabled => true;

  /// Get encryption algorithm info
  String get algorithmInfo => 'AES-256-GCM with PBKDF2-HMAC-SHA256 (PointyCastle)';
} 