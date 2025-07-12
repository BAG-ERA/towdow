/// Service that manages encrypted file storage using an S3-compatible endpoint (MinIO).
///
/// Flow:
/// 1. Obtain existing Keycloak JWT from the `AuthService` (passed in).
/// 2. Decode JWT to extract claims, particularly the 'sub' claim for S3 key prefix.
/// 3. Exchange JWT for temporary STS credentials through MinIO's `AssumeRoleWithWebIdentity`.
/// 4. Create an `aws_s3_api` S3 client with the temporary credentials.
/// 5. Expose basic operations: upload, download, delete, list.
/// 6. Transparently refresh STS credentials before they expire.
///
/// NOTE: For now, encryption/decryption is stubbed – `EncryptionUtil` currently returns unmodified data so
/// integration can proceed while crypto implementation is finalised.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aws_s3_api/s3-2006-03-01.dart' as aws;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/stored_file_metadata.dart';
import 'encryption_util.dart';

class S3StorageService {
  static const _stsVersion = '2011-06-15';
  static const _stsAction = 'AssumeRoleWithWebIdentity';

  final String s3EndpointUrl;
  final String bucketPrivate;
  final String bucketShared;
  final String region;
  final Future<String> Function() jwtProvider;

  aws.S3? _client;
  DateTime? _clientExpiry;
  String? _currentSubClaim; // Cache the sub claim from JWT

  S3StorageService({
    required this.s3EndpointUrl,
    required this.bucketPrivate,
    required this.bucketShared,
    required this.region,
    required this.jwtProvider,
  });

  /// Decodes JWT and extracts claims
  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT format');
      }
      
      String decode(String part) {
        // Add padding if needed for base64Url decode
        String normalized = part;
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        return utf8.decode(base64Url.decode(normalized));
      }
      
      final payload = decode(parts[1]);
      AppLogger.debug('S3 JWT payload decoded: ${payload.length} characters');
      return json.decode(payload);
    } catch (e, stackTrace) {
      AppLogger.error('S3 Failed to decode JWT', e, stackTrace);
      throw Exception('Failed to decode JWT: $e');
    }
  }

  /// Uploads bytes to the private bucket – encrypted with user key.
  /// Uses the JWT 'sub' claim as the key prefix to comply with bucket policies.
  Future<Result<StoredFileMetadata>> uploadPrivate(
      {required String key, required Uint8List data}) async {
    AppLogger.debug('S3 uploadPrivate request → bucket: $bucketPrivate, key: $key, bytes: ${data.length}');
    
    // Ensure we have the sub claim for proper key prefixing
    await _ensureSubClaim();
    
    // Prefix the key with the sub claim
    final prefixedKey = _currentSubClaim != null ? '$_currentSubClaim/$key' : key;
    AppLogger.debug('S3 uploadPrivate using prefixed key: $prefixedKey');
    
    return _upload(
      bucket: bucketPrivate,
      key: prefixedKey,
      data: data,
      encryptWith: const UserScope(),
    );
  }

  /// Uploads bytes to the shared bucket – encrypted with project key.
  /// Uses the JWT 'sub' claim as the key prefix to comply with bucket policies.
  Future<Result<StoredFileMetadata>> uploadShared(
      {required String key,
      required Uint8List data,
      required String projectUuid}) async {
    AppLogger.debug('S3 uploadShared request → bucket: $bucketShared, key: $projectUuid/$key, bytes: ${data.length}');
    
    // Ensure we have the sub claim for proper key prefixing
    await _ensureSubClaim();
    
    // Prefix the project path with the sub claim
    final prefixedKey = _currentSubClaim != null ? '$_currentSubClaim/$projectUuid/$key' : '$projectUuid/$key';
    AppLogger.debug('S3 uploadShared using prefixed key: $prefixedKey');
    
    return _upload(
      bucket: bucketShared,
      key: prefixedKey,
      data: data,
      encryptWith: ProjectScope(projectUuid),
    );
  }

  /// Downloads an object. Automatically decrypts.
  /// Handles both prefixed and non-prefixed keys.
  Future<Result<Uint8List>> download(
      {required String bucket, required String key}) async {
    AppLogger.debug('S3 download request → bucket: $bucket, key: $key');
    
    // Ensure we have the sub claim for proper key prefixing
    await _ensureSubClaim();
    
    // If key doesn't already have sub prefix, add it
    final prefixedKey = _currentSubClaim != null && !key.startsWith('$_currentSubClaim/') 
        ? '$_currentSubClaim/$key' 
        : key;
    
    if (prefixedKey != key) {
      AppLogger.debug('S3 download using prefixed key: $prefixedKey');
    }
    
    try {
      final client = await _ensureClient();
      final obj = await client.getObject(bucket: bucket, key: prefixedKey);
      final List<int> raw = await obj.body!.toList();
      final decrypted = await EncryptionUtil.decrypt(raw);
      AppLogger.debug('S3 download response ← bytes: ${decrypted.length}');
      return Result.success(Uint8List.fromList(decrypted));
    } catch (e, st) {
      AppLogger.error('S3 download failed', e, st);
      return Result.failure(Failure(message: 'Download failed', exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  /// Deletes an object.
  /// Handles both prefixed and non-prefixed keys.
  Future<Result<void>> delete({required String bucket, required String key}) async {
    AppLogger.debug('S3 delete request → bucket: $bucket, key: $key');
    
    // Ensure we have the sub claim for proper key prefixing
    await _ensureSubClaim();
    
    // If key doesn't already have sub prefix, add it
    final prefixedKey = _currentSubClaim != null && !key.startsWith('$_currentSubClaim/') 
        ? '$_currentSubClaim/$key' 
        : key;
    
    if (prefixedKey != key) {
      AppLogger.debug('S3 delete using prefixed key: $prefixedKey');
    }
    
    try {
      final client = await _ensureClient();
      await client.deleteObject(bucket: bucket, key: prefixedKey);
      AppLogger.debug('S3 delete response ← success');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.error('S3 delete failed', e, st);
      return Result.failure(Failure(message: 'Delete failed', exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  Future<Result<List<StoredFileMetadata>>> list({
    required String bucket,
    required String prefix,
  }) async {
    AppLogger.debug('S3 list request → bucket: $bucket, prefix: $prefix');
    
    // Ensure we have the sub claim for proper key prefixing
    await _ensureSubClaim();
    
    // If prefix doesn't already have sub prefix, add it
    final prefixedPrefix = _currentSubClaim != null && !prefix.startsWith('$_currentSubClaim/') 
        ? '$_currentSubClaim/$prefix' 
        : prefix;
    
    if (prefixedPrefix != prefix) {
      AppLogger.debug('S3 list using prefixed prefix: $prefixedPrefix');
    }
    
    try {
      final client = await _ensureClient();
      final result = await client.listObjectsV2(bucket: bucket, prefix: prefixedPrefix);
      final objects = result.contents ?? [];
      final meta = objects
          .map((o) => StoredFileMetadata(
                key: o.key ?? '',
                size: o.size?.toInt() ?? 0,
                lastModified: o.lastModified?.toUtc(),
              ))
          .toList();
      AppLogger.debug('S3 list response ← ${meta.length} objects');
      return Result.success(meta);
    } catch (e, st) {
      AppLogger.error('S3 list failed', e, st);
      return Result.failure(Failure(message: 'List failed', exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  /// Lists all buckets accessible to the authenticated user
  Future<Result<List<String>>> listBuckets() async {
    AppLogger.debug('S3 listBuckets request');
    try {
      final client = await _ensureClient();
      final result = await client.listBuckets();
      final bucketNames = result.buckets?.map((b) => b.name ?? '').where((name) => name.isNotEmpty).toList() ?? [];
      AppLogger.debug('S3 listBuckets response ← ${bucketNames.length} buckets: ${bucketNames.join(', ')}');
      return Result.success(bucketNames);
    } catch (e, st) {
      AppLogger.error('S3 listBuckets failed', e, st);
      return Result.failure(Failure(message: 'List buckets failed', exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  /// Gets JWT claims for debugging purposes
  Future<Result<Map<String, dynamic>>> getJwtClaims() async {
    try {
      final jwt = await jwtProvider();
      if (jwt.isEmpty || !jwt.contains('.')) {
        throw Exception('Invalid or empty JWT received from jwtProvider');
      }
      
      final claims = _decodeJwt(jwt);
      AppLogger.debug('S3 JWT claims extracted: ${claims.keys.join(', ')}');
      return Result.success(claims);
    } catch (e, st) {
      AppLogger.error('S3 Failed to get JWT claims', e, st);
      return Result.failure(Failure(message: 'Failed to get JWT claims', exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  /// Ensures we have the sub claim from the JWT
  Future<void> _ensureSubClaim() async {
    if (_currentSubClaim != null) return;
    
    try {
      final jwt = await jwtProvider();
      if (jwt.isEmpty || !jwt.contains('.')) {
        throw Exception('Invalid or empty JWT received from jwtProvider');
      }
      
      final claims = _decodeJwt(jwt);
      _currentSubClaim = claims['sub'] as String?;
      
      if (_currentSubClaim == null) {
        AppLogger.warning('S3 JWT missing sub claim, using unprefixed keys');
      } else {
        AppLogger.debug('S3 JWT sub claim: $_currentSubClaim');
      }
    } catch (e, stackTrace) {
      AppLogger.error('S3 Failed to extract sub claim from JWT', e, stackTrace);
      // Continue without sub claim - will use unprefixed keys
    }
  }

  /* ────────────────────────────────────────────────────────────── */
  Future<Result<StoredFileMetadata>> _upload({
    required String bucket,
    required String key,
    required Uint8List data,
    required EncryptionScope encryptWith,
  }) async {
    AppLogger.debug('S3 _upload → bucket: $bucket, key: $key, bytes: ${data.length}');
    try {
      final encrypted = await EncryptionUtil.encrypt(data, scope: encryptWith);
      final client = await _ensureClient();
      await client.putObject(bucket: bucket, key: key, body: encrypted);
      final meta = StoredFileMetadata(
        key: key,
        size: encrypted.length,
        lastModified: DateTime.now().toUtc(),
      );
      AppLogger.debug('S3 _upload response ← success, encryptedBytes: ${encrypted.length}');
      return Result.success(meta);
    } catch (e, st) {
      // Attempt to include server response (status code / body) when available
      String msg = 'Upload failed';
      // Attempt to extract details from common AWS error types without explicit dependency
      final str = e.toString();
      if (str.isNotEmpty) {
        msg = 'Upload failed: $str';
      }
      AppLogger.error('S3 upload failed', e, st);
      return Result.failure(Failure(message: msg, exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  Future<aws.S3> _ensureClient() async {
    final now = DateTime.now().toUtc();
    if (_client != null && _clientExpiry != null && now.isBefore(_clientExpiry!)) {
      return _client!;
    }

    final jwt = await jwtProvider();
    if (jwt.isEmpty || !jwt.contains('.')) {
      throw Exception('Invalid or empty JWT received from jwtProvider');
    }
    
    // Decode JWT to extract claims and cache sub claim
    final claims = _decodeJwt(jwt);
    _currentSubClaim = claims['sub'] as String?;
    AppLogger.debug('S3 JWT sub claim: ${_currentSubClaim ?? "null"}');
    
    AppLogger.debug('Fetching STS credentials');
    final creds = await _fetchStsCredentials(jwt);

    AppLogger.debug('STS credentials received – creating S3 client');
    _client = aws.S3(
      region: region,
      credentials: aws.AwsClientCredentials(
        accessKey: creds['accessKey']!,
        secretKey: creds['secretKey']!,
        sessionToken: creds['sessionToken'],
      ),
      endpointUrl: s3EndpointUrl,
    );
    // MinIO's default STS expiry is 15 minutes; refresh at 12 min.
    _clientExpiry = now.add(const Duration(minutes: 12));
    return _client!;
  }

  Future<Map<String, String>> _fetchStsCredentials(String jwt) async {
    AppLogger.debug('STS request → POST ?Action=$_stsAction');
    final uri = Uri.parse('$s3EndpointUrl?Action=$_stsAction&WebIdentityToken=$jwt&Version=$_stsVersion');
    final res = await http.post(uri);
    AppLogger.debug('STS response ← status: ${res.statusCode}');
    if (res.statusCode != 200) {
      throw Exception('STS request failed: ${res.statusCode} ${res.body}');
    }

    final xmlDoc = xml.XmlDocument.parse(res.body);
    String _text(String tag) => xmlDoc.findAllElements(tag, namespace: '*').first.text;

    return {
      'accessKey': _text('AccessKeyId'),
      'secretKey': _text('SecretAccessKey'),
      'sessionToken': _text('SessionToken'),
    };
  }
} 