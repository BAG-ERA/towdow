// S3 Storage Service for file operations with Keycloak authentication
// Provides S3-compatible storage operations using MinIO backend

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/caldav_account.dart';
import '../../core/result.dart';
import '../../core/logger.dart';
import 'webdav_client.dart';
import 'encryption_service.dart';

/// S3 credentials obtained from JWT token
class S3Credentials {
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;
  final DateTime expiration;
  final int? maxFileSize;

  S3Credentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.sessionToken,
    required this.expiration,
    this.maxFileSize,
  });

  bool get isExpired => DateTime.now().isAfter(expiration);
}

/// S3 file metadata
class S3FileInfo {
  final String key;
  final String bucket;
  final int size;
  final DateTime lastModified;
  final String? etag;
  final String? contentType;

  S3FileInfo({
    required this.key,
    required this.bucket,
    required this.size,
    required this.lastModified,
    this.etag,
    this.contentType,
  });
}

/// S3 storage service for file operations
class S3StorageService {
  CaldavAccount account;
  final void Function(String accessToken, String? refreshToken, DateTime? tokenExpiry)? onTokenRefresh;
  final EncryptionService _encryptionService;
  
  // Fixed bucket names and constants
  static const String _bucketPrivate = 'towdow-private';
  static const String _bucketShared = 'towdow-shared';
  static const String _s3Region = 'eu-central-1';
  static const int _defaultMaxFileSize = 20 * 1024 * 1024; // 20MB
  
  S3? _s3Client;
  S3Credentials? _credentials;
  
  S3StorageService({
    required this.account,
    this.onTokenRefresh,
    EncryptionService? encryptionService,
  }) : _encryptionService = encryptionService ?? EncryptionService();

  /// Get S3 endpoint URL from account configuration
  String get _s3Endpoint {
    // Extract S3 endpoint from account configuration
    final serverUrl = Uri.parse(account.serverUrl);
    
    if (account.providerType == 'towdow_cloud') {
      // For TowDow Cloud, use the correct MinIO endpoint
      if (serverUrl.host == 'api.towdow.app') {
        return 'https://minio.towdow.app';
      }
    }
    
    // For self-hosted TowDow or custom setups, assume MinIO on port 9000
    return '${serverUrl.scheme}://${serverUrl.host}:9000';
  }

  /// Get maximum file size
  int get _maxFileSize => _credentials?.maxFileSize ?? _defaultMaxFileSize;

  /// Initialize S3 client with STS credentials from JWT
  Future<Result<void>> _initializeS3Client() async {
    try {
      AppLogger.debug('S3StorageService._initializeS3Client: Getting STS credentials from JWT');
      
      // Get STS credentials using the access token
      final stsResult = await _getStsCredentials();
      return stsResult.when(
        success: (credentials) async {
          _credentials = credentials;
          
          // Initialize S3 client with temporary credentials
          _s3Client = S3(
            region: _s3Region,
            credentials: AwsClientCredentials(
              accessKey: _credentials!.accessKeyId,
              secretKey: _credentials!.secretAccessKey,
              sessionToken: _credentials!.sessionToken,
            ),
            endpointUrl: _s3Endpoint,
          );
          
          AppLogger.debug('S3StorageService._initializeS3Client: S3 client initialized successfully');
          return const Result.success(null);
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('S3StorageService._initializeS3Client: Failed to initialize S3 client', e, stackTrace);
      return Result.failure(Failure(message: 'Failed to initialize S3 client: $e'));
    }
  }

  /// Get STS credentials from Keycloak JWT token
  Future<Result<S3Credentials>> _getStsCredentials() async {
    try {
      // Get fresh access token using WebDAV client (handles refresh automatically)
      if (account.providerType == 'towdow_cloud') {
        final webdavClient = WebDAVClient.fromAccount(account, onTokenRefresh: (accessToken, refreshToken, tokenExpiry) {
          // Update our local account object with refreshed tokens
          account = account.copyWith(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry,
          );
          AppLogger.debug('S3StorageService._getStsCredentials: Updated local account with refreshed token, new expiry: $tokenExpiry');
          
          // Also call the external callback if provided
          if (onTokenRefresh != null) {
            onTokenRefresh!(accessToken, refreshToken, tokenExpiry);
          }
        });
        
        try {
          // This will automatically refresh the token if needed
          await webdavClient.getAuthHeaders();
        } on RefreshTokenExpiredException {
          // Re-throw this specific exception so it can be handled by the UI
          rethrow;
        } catch (e) {
          AppLogger.warning('S3StorageService._getStsCredentials: Token refresh failed, trying with existing token: $e');
        }
      }

      if (account.accessToken == null || account.accessToken!.isEmpty) {
        AppLogger.error('S3StorageService._getStsCredentials: No access token available');
        return Result.failure(Failure(message: 'No access token available for STS request'));
      }

      // Debug: Parse JWT to check token details
      try {
        final jwtPayload = _parseJwtPayload(account.accessToken!);
        final exp = jwtPayload['exp'] as int?;
        final sub = jwtPayload['sub'] as String?;
        if (exp != null) {
          final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          AppLogger.debug('S3StorageService._getStsCredentials: JWT sub=$sub, expires at $expiryTime');
          if (DateTime.now().isAfter(expiryTime)) {
            AppLogger.warning('S3StorageService._getStsCredentials: JWT token appears expired! Current time: ${DateTime.now()}');
          }
        }
      } catch (e) {
        AppLogger.warning('S3StorageService._getStsCredentials: Could not parse JWT payload: $e');
      }

      // Use query parameters approach like in sample code
      final stsUrl = Uri.parse('$_s3Endpoint?Action=AssumeRoleWithWebIdentity&WebIdentityToken=${account.accessToken!}&Version=2011-06-15&DurationSeconds=3600');
      AppLogger.debug('S3StorageService._getStsCredentials: Making STS request to $stsUrl');

      final response = await http.post(stsUrl).timeout(Duration(seconds: 30));

      AppLogger.debug('S3StorageService._getStsCredentials: STS response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        AppLogger.error('S3StorageService._getStsCredentials: STS request failed with status ${response.statusCode}');
        AppLogger.error('S3StorageService._getStsCredentials: Response body: ${response.body}');
        return Result.failure(Failure(message: 'STS request failed: ${response.statusCode} ${response.body}'));
      }

      AppLogger.debug('S3StorageService._getStsCredentials: Parsing STS XML response');
      
      // Parse XML response
      final document = XmlDocument.parse(response.body);
      final credentials = document.findAllElements('Credentials').first;
      
      final accessKeyId = credentials.findElements('AccessKeyId').first.innerText;
      final secretAccessKey = credentials.findElements('SecretAccessKey').first.innerText;
      final sessionToken = credentials.findElements('SessionToken').first.innerText;
      final expirationStr = credentials.findElements('Expiration').first.innerText;
      
      final expiration = DateTime.parse(expirationStr);
      
      AppLogger.debug('S3StorageService._getStsCredentials: STS credentials parsed successfully, expires at $expiration');
      
      // Parse JWT to get file size limits
      final jwtPayload = _parseJwtPayload(account.accessToken!);
      AppLogger.debug('S3StorageService._getStsCredentials: JWT payload extracted for file limits');
      
      return Result.success(S3Credentials(
        accessKeyId: accessKeyId,
        secretAccessKey: secretAccessKey,
        sessionToken: sessionToken,
        expiration: expiration,
        maxFileSize: jwtPayload['s3_max_file_size'],
      ));
    } on RefreshTokenExpiredException {
      // Re-throw so it can be handled by the calling code
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      AppLogger.error('S3StorageService._getStsCredentials: STS request timeout', e, stackTrace);
      return Result.failure(Failure(message: 'STS request timeout - check S3 endpoint configuration'));
    } catch (e, stackTrace) {
      AppLogger.error('S3StorageService._getStsCredentials: Failed to get STS credentials', e, stackTrace);
      return Result.failure(Failure(message: 'Failed to get STS credentials: $e'));
    }
  }

  /// Parse JWT payload to extract S3 configuration
  Map<String, dynamic> _parseJwtPayload(String token) {
    try {
      // DEBUG: Log token details for diagnosis
      AppLogger.debug('S3StorageService._parseJwtPayload: Token length: ${token.length}');
      AppLogger.debug('S3StorageService._parseJwtPayload: Token starts with: ${token.length > 20 ? token.substring(0, 20) : token}...');
      
      final parts = token.split('.');
      AppLogger.debug('S3StorageService._parseJwtPayload: JWT parts count: ${parts.length}');
      
      if (parts.length != 3) {
        AppLogger.warning('S3StorageService._parseJwtPayload: Invalid JWT - expected 3 parts, got ${parts.length}');
        return {};
      }
      
      final payload = parts[1];
      AppLogger.debug('S3StorageService._parseJwtPayload: Payload part length: ${payload.length}');
      
      // Remove any existing padding and add correct padding
      String normalizedPayload = payload.replaceAll('=', '');
      final paddingNeeded = (4 - normalizedPayload.length % 4) % 4;
      final padded = normalizedPayload + '=' * paddingNeeded;
      
      final decoded = base64Url.decode(padded);
      final jsonStr = utf8.decode(decoded);
      
      final claims = json.decode(jsonStr) as Map<String, dynamic>;
      AppLogger.debug('S3StorageService._parseJwtPayload: Successfully parsed JWT with ${claims.keys.length} claims');
      AppLogger.debug('S3StorageService._parseJwtPayload: Claims keys: ${claims.keys.toList()}');
      
      return claims;
    } catch (e, stackTrace) {
      AppLogger.error('S3StorageService._parseJwtPayload: Failed to parse JWT', e, stackTrace);
      return {};
    }
  }

  /// Get JWT claims for debugging (public method)
  Map<String, dynamic> getJwtClaims() {
    if (account.accessToken == null || account.accessToken!.isEmpty) {
      return {'error': 'No access token available'};
    }
    return _parseJwtPayload(account.accessToken!);
  }

  /// Get current S3 credentials info for debugging
  Map<String, dynamic> getCredentialsInfo() {
    if (_credentials == null) {
      return {'status': 'Not initialized'};
    }
    
    return {
      'status': 'Initialized',
      'accessKeyId': _credentials!.accessKeyId,
      'isExpired': _credentials!.isExpired,
      'expiration': _credentials!.expiration.toIso8601String(),
      'bucketPrivate': _bucketPrivate,
      'bucketShared': _bucketShared,
      'maxFileSize': _credentials!.maxFileSize,
    };
  }

  /// Get connection status and configuration info
  Map<String, dynamic> getConnectionInfo() {
    return {
      's3Endpoint': _s3Endpoint,
      's3Region': _s3Region,
      'hasS3Client': _s3Client != null,
      'hasCredentials': _credentials != null,
      'credentialsExpired': _credentials?.isExpired ?? true,
      'accountServerUrl': account.serverUrl,
      'hasAccessToken': account.accessToken != null && account.accessToken!.isNotEmpty,
      'accessTokenPreview': account.accessToken != null 
          ? '${account.accessToken!.substring(0, 20)}...' 
          : 'null',
    };
  }

  /// Ensure S3 client is initialized and credentials are valid
  Future<Result<void>> _ensureInitialized() async {
    if (_s3Client == null || _credentials == null || _credentials!.isExpired) {
      return await _initializeS3Client();
    }
    return const Result.success(null);
  }

  /// List all buckets accessible to the user
  Future<Result<List<String>>> listBuckets() async {
    final initResult = await _ensureInitialized();
    return initResult.when(
      success: (_) async {
        try {
          final response = await _s3Client!.listBuckets();
          final bucketNames = response.buckets?.map((b) => b.name ?? '').where((name) => name.isNotEmpty).toList() ?? [];
          
          AppLogger.debug('S3StorageService.listBuckets: Found ${bucketNames.length} buckets: ${bucketNames.join(', ')}');
          AppLogger.debug('S3StorageService.listBuckets: Expected buckets: $_bucketPrivate, $_bucketShared');
          
          // Check if both expected buckets are present
          final hasPrivate = bucketNames.contains(_bucketPrivate);
          final hasShared = bucketNames.contains(_bucketShared);
          AppLogger.debug('S3StorageService.listBuckets: Has private bucket ($_bucketPrivate): $hasPrivate');
          AppLogger.debug('S3StorageService.listBuckets: Has shared bucket ($_bucketShared): $hasShared');
          
          return Result.success(bucketNames);
        } catch (e, stackTrace) {
          AppLogger.error('S3StorageService.listBuckets: Failed to list buckets', e, stackTrace);
          return Result.failure(Failure(message: 'Failed to list buckets: $e'));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// List objects in a bucket
  Future<Result<List<S3FileInfo>>> listObjects(String bucket, {String? prefix}) async {
    final initResult = await _ensureInitialized();
    return initResult.when(
      success: (_) async {
        try {
          final response = await _s3Client!.listObjectsV2(
            bucket: bucket,
            prefix: prefix,
          );
          
          final files = response.contents?.map((obj) => S3FileInfo(
            key: obj.key ?? '',
            bucket: bucket,
            size: obj.size ?? 0,
            lastModified: obj.lastModified ?? DateTime.now(),
            etag: obj.eTag,
          )).toList() ?? [];
          
          AppLogger.debug('S3StorageService.listObjects: Found ${files.length} objects in bucket $bucket');
          return Result.success(files);
        } catch (e, stackTrace) {
          AppLogger.error('S3StorageService.listObjects: Failed to list objects in $bucket', e, stackTrace);
          return Result.failure(Failure(message: 'Failed to list objects: $e'));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Upload a file to S3 with encryption
  Future<Result<String>> uploadFile({
    required String key,
    required Uint8List data,
    required bool isPrivate,
    required String symmetricKey,
    String? contentType,
  }) async {
    final initResult = await _ensureInitialized();
    return initResult.when(
      success: (_) async {
        // Check file size limit
        if (data.length > _maxFileSize) {
          return Result.failure(Failure(message: 'File size ${data.length} exceeds limit ${_maxFileSize}'));
        }

        // Encrypt the data before uploading
        final encryptionResult = await _encryptionService.encryptFile(data, symmetricKey);
        return encryptionResult.when(
          success: (encryptedData) async {
            final bucket = isPrivate ? _bucketPrivate : _bucketShared;
            
            // Ensure we have a content type - fallback to octet-stream if none provided
            final finalContentType = contentType?.isNotEmpty == true ? contentType : 'application/octet-stream';
            
            try {
              // Add debug logging for troubleshooting
              AppLogger.debug('S3StorageService.uploadFile: Uploading encrypted file');
              AppLogger.debug('S3StorageService.uploadFile: Key: $key');
              AppLogger.debug('S3StorageService.uploadFile: Bucket: $bucket');
              AppLogger.debug('S3StorageService.uploadFile: Content-Type: $contentType');
              AppLogger.debug('S3StorageService.uploadFile: Original data length: ${data.length} bytes');
              AppLogger.debug('S3StorageService.uploadFile: Encrypted data length: ${encryptedData.length} bytes');
              AppLogger.debug('S3StorageService.uploadFile: Final Content-Type: $finalContentType');
              
              await _s3Client!.putObject(
                bucket: bucket,
                key: key,
                body: encryptedData,
                contentType: finalContentType,
              );
              
              final fileUrl = '$_s3Endpoint/$bucket/$key';
              AppLogger.debug('S3StorageService.uploadFile: Uploaded encrypted file $key to $bucket');
              return Result.success(fileUrl);
            } catch (e, stackTrace) {
              AppLogger.error('S3StorageService.uploadFile: Failed to upload encrypted file $key', e, stackTrace);
              AppLogger.error('S3StorageService.uploadFile: Upload parameters - Bucket: $bucket, Key: $key, ContentType: $finalContentType, EncryptedDataLength: ${encryptedData.length}');
              AppLogger.error('S3StorageService.uploadFile: S3 Endpoint: $_s3Endpoint');
              
              // Provide more specific error information
              String errorMessage = 'Failed to upload encrypted file: $e';
              if (e.toString().contains('SignatureDoesNotMatch')) {
                errorMessage += '\n\nThis error often occurs due to:'
                    '\n- Special characters in filename (em dashes, Unicode characters)'
                    '\n- Incorrect content type for binary files'
                    '\n- Clock synchronization issues'
                    '\n- Invalid S3 credentials or configuration';
              }
              
              return Result.failure(Failure(message: errorMessage));
            }
          },
          failure: (failure) => Result.failure(failure),
        );
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Download a file from S3 with decryption
  Future<Result<Uint8List>> downloadFile({
    required String key,
    required bool isPrivate,
    required String symmetricKey,
  }) async {
    final initResult = await _ensureInitialized();
    return initResult.when(
      success: (_) async {
        try {
          final bucket = isPrivate ? _bucketPrivate : _bucketShared;
          
          final response = await _s3Client!.getObject(
            bucket: bucket,
            key: key,
          );
          
          // Response body is already Uint8List for S3 GetObject
          final encryptedData = response.body!;
          AppLogger.debug('S3StorageService.downloadFile: Downloaded encrypted file $key from $bucket (${encryptedData.length} bytes)');
          
          // Decrypt the data before returning
          final decryptionResult = await _encryptionService.decryptFile(encryptedData, symmetricKey);
          return decryptionResult.when(
            success: (decryptedData) {
              AppLogger.debug('S3StorageService.downloadFile: Decrypted file $key, original size: ${decryptedData.length} bytes');
              return Result.success(decryptedData);
            },
            failure: (failure) => Result.failure(failure),
          );
        } catch (e, stackTrace) {
          AppLogger.error('S3StorageService.downloadFile: Failed to download file $key', e, stackTrace);
          return Result.failure(Failure(message: 'Failed to download file: $e'));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Delete a file from S3
  Future<Result<void>> deleteFile({
    required String key,
    required bool isPrivate,
  }) async {
    final initResult = await _ensureInitialized();
    return initResult.when(
      success: (_) async {
        try {
          final bucket = isPrivate ? _bucketPrivate : _bucketShared;
          
          await _s3Client!.deleteObject(
            bucket: bucket,
            key: key,
          );
          
          AppLogger.debug('S3StorageService.deleteFile: Deleted file $key from $bucket');
          return const Result.success(null);
        } catch (e, stackTrace) {
          AppLogger.error('S3StorageService.deleteFile: Failed to delete file $key', e, stackTrace);
          return Result.failure(Failure(message: 'Failed to delete file: $e'));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get file metadata
  Future<Result<S3FileInfo>> getFileInfo({
    required String key,
    required bool isPrivate,
  }) async {
    final initResult = await _ensureInitialized();
    return initResult.when(
      success: (_) async {
        try {
          final bucket = isPrivate ? _bucketPrivate : _bucketShared;
          
          final response = await _s3Client!.headObject(
            bucket: bucket,
            key: key,
          );
          
          final fileInfo = S3FileInfo(
            key: key,
            bucket: bucket,
            size: response.contentLength ?? 0,
            lastModified: response.lastModified ?? DateTime.now(),
            etag: response.eTag,
            contentType: response.contentType,
          );
          
          return Result.success(fileInfo);
        } catch (e, stackTrace) {
          AppLogger.error('S3StorageService.getFileInfo: Failed to get file info for $key', e, stackTrace);
          return Result.failure(Failure(message: 'Failed to get file info: $e'));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Generate a user-specific path prefix  
  String getUserPrefix() {
    // Use JWT 'sub' claim as user identifier (matches bucket permissions: {jwt_sub}/)
    AppLogger.debug('S3StorageService.getUserPrefix: AccessToken null: ${account.accessToken == null}, empty: ${account.accessToken?.isEmpty ?? true}');
    AppLogger.debug('S3StorageService.getUserPrefix: AccessToken length: ${account.accessToken?.length ?? 0}');
    
    // Validate token exists before parsing
    if (account.accessToken == null || account.accessToken!.isEmpty) {
      AppLogger.error('S3StorageService.getUserPrefix: No access token available for S3 operations');
      throw Exception('No access token available for S3 operations');
    }
    
    final jwtPayload = _parseJwtPayload(account.accessToken!);
    final userId = jwtPayload['sub'];
    
    if (userId == null) {
      AppLogger.error('S3StorageService.getUserPrefix: JWT token missing sub claim');
      throw Exception('Invalid JWT token: missing sub claim');
    }
    
    AppLogger.debug('S3StorageService.getUserPrefix: Using userId=$userId from JWT sub=${jwtPayload['sub']}');
    return '$userId/';
  }

  /// Generate a shared path prefix for a specific context
  String getSharedPrefix(String context) {
    // For shared bucket, use JWT 'sub' as folder name (matches bucket permissions: {jwt_sub}/)
    if (account.accessToken == null || account.accessToken!.isEmpty) {
      AppLogger.error('S3StorageService.getSharedPrefix: No access token available for S3 operations');
      throw Exception('No access token available for S3 operations');
    }
    
    final jwtPayload = _parseJwtPayload(account.accessToken!);
    final userId = jwtPayload['sub']; 
    
    if (userId == null) {
      AppLogger.error('S3StorageService.getSharedPrefix: JWT token missing sub claim');
      throw Exception('Invalid JWT token: missing sub claim');
    }
    
    return '$userId/';
  }

  /// Dispose resources
  void dispose() {
    _s3Client?.close();
    _s3Client = null;
    _credentials = null;
  }
} 