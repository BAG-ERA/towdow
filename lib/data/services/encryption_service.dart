// AES-256-GCM encryption service using PointyCastle for secure file encryption/decryption
// Implements proper authenticated encryption with PBKDF2 key derivation

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';
import '../../core/result.dart';
import '../../core/logger.dart';

/// AES-256-GCM encryption service using PointyCastle
/// Provides authenticated encryption with proper key derivation
class EncryptionService {
  static const Uuid _uuid = Uuid();
  static const int _saltLength = 32; // 256 bits
  static const int _ivLength = 12; // 96 bits for GCM
  static const int _tagLength = 16; // 128 bits for GCM tag
  static const int _keyLength = 32; // 256 bits for AES-256
  static const int _pbkdf2Iterations = 100000; // OWASP recommended minimum
  
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

  /// Derive encryption key from password and salt using PBKDF2
  Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    
    return pbkdf2.process(utf8.encode(password));
  }

  /// Encrypt file data with AES-256-GCM
  /// Returns: [salt(32)] + [iv(12)] + [tag(16)] + [encrypted_data]
  Future<Result<Uint8List>> encryptFile(Uint8List data, String key) async {
    try {
      AppLogger.debug('EncryptionService.encryptFile: Encrypting ${data.length} bytes with AES-256-GCM');
      
      // Generate salt and IV
      final salt = _generateSalt();
      final iv = _generateIV();
      
      // Derive encryption key using PBKDF2
      final derivedKey = _deriveKey(key, salt);
      
      // Set up AES-GCM cipher
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(derivedKey),
        _tagLength * 8, // tag length in bits
        iv,
        Uint8List(0), // no additional authenticated data
      );
      
      cipher.init(true, params); // true for encryption
      
      // Encrypt data
      final encryptedData = cipher.process(data);
      
      // Extract encrypted data and tag
      final ciphertext = encryptedData.sublist(0, encryptedData.length - _tagLength);
      final tag = encryptedData.sublist(encryptedData.length - _tagLength);
      
      // Combine: salt + iv + tag + encrypted_data
      final result = Uint8List(_saltLength + _ivLength + _tagLength + ciphertext.length);
      int offset = 0;
      
      result.setRange(offset, offset + _saltLength, salt);
      offset += _saltLength;
      
      result.setRange(offset, offset + _ivLength, iv);
      offset += _ivLength;
      
      result.setRange(offset, offset + _tagLength, tag);
      offset += _tagLength;
      
      result.setRange(offset, offset + ciphertext.length, ciphertext);
      
      AppLogger.debug('EncryptionService.encryptFile: Successfully encrypted ${data.length} bytes to ${result.length} bytes');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('EncryptionService.encryptFile: Failed to encrypt', e, stackTrace);
      return Result.failure(Failure(message: 'Failed to encrypt file: $e'));
    }
  }

  /// Decrypt file data with AES-256-GCM
  /// Expects: [salt(32)] + [iv(12)] + [tag(16)] + [encrypted_data]
  Future<Result<Uint8List>> decryptFile(Uint8List encryptedData, String key) async {
    try {
      AppLogger.debug('EncryptionService.decryptFile: Decrypting ${encryptedData.length} bytes with AES-256-GCM');
      
      // Validate minimum length
      const minLength = _saltLength + _ivLength + _tagLength;
      if (encryptedData.length < minLength) {
        return Result.failure(Failure(message: 'Invalid encrypted data: too short'));
      }
      
      // Extract components
      int offset = 0;
      
      final salt = encryptedData.sublist(offset, offset + _saltLength);
      offset += _saltLength;
      
      final iv = encryptedData.sublist(offset, offset + _ivLength);
      offset += _ivLength;
      
      final tag = encryptedData.sublist(offset, offset + _tagLength);
      offset += _tagLength;
      
      final ciphertext = encryptedData.sublist(offset);
      
      // Derive decryption key using PBKDF2
      final derivedKey = _deriveKey(key, salt);
      
      // Set up AES-GCM cipher for decryption
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(derivedKey),
        _tagLength * 8, // tag length in bits
        iv,
        Uint8List(0), // no additional authenticated data
      );
      
      cipher.init(false, params); // false for decryption
      
      // Combine ciphertext and tag for decryption
      final dataToDecrypt = Uint8List(ciphertext.length + tag.length);
      dataToDecrypt.setRange(0, ciphertext.length, ciphertext);
      dataToDecrypt.setRange(ciphertext.length, dataToDecrypt.length, tag);
      
      // Decrypt and verify
      final decryptedData = cipher.process(dataToDecrypt);
      
      AppLogger.debug('EncryptionService.decryptFile: Successfully decrypted ${encryptedData.length} bytes to ${decryptedData.length} bytes');
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