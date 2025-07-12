import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../models/cached_file.dart';
import '../services/s3_storage_service.dart';
import '../models/stored_file_metadata.dart';
import '../../core/result.dart';
import '../models/storage_config.dart';
import '../services/auth_token_provider.dart';

/// Repository that coordinates local cached files and remote S3 storage.
///
/// All write operations are queued through the existing sync mechanism.
/// For now we expose synchronous methods that immediately act; integration
/// with `BackgroundSyncService` will be done by the caller (e.g. ViewModels)
/// until the queue refactor is finished.
class FileRepository {
  final String accountId;
  final S3StorageService storageService;
  final Box<CachedFile> _cacheBox;

  FileRepository._internal({required this.accountId, required this.storageService}) : _cacheBox = Hive.box<CachedFile>('file_cache_$accountId');

  static const _defaultCloudEndpoint = 'https://minio.towdow.app';

  /// Factory constructor that resolves the endpoint from [StorageConfig]
  static Future<FileRepository> forAccount(String accountId, Future<String> Function()? jwtProvider, {String region = 'us-east-1'}) async {
    String resolvedAccountId = accountId;
    if (resolvedAccountId.isEmpty) {
      // Fallback: use first account in Hive box
      final accBox = await Hive.openBox('accounts');
      if (accBox.isNotEmpty) {
        resolvedAccountId = accBox.keys.first as String;
      }
    }

    final configBox = await Hive.openBox<StorageConfig>('storage_configs');
    final cfg = configBox.get(resolvedAccountId);
    final endpoint = cfg?.s3Endpoint ?? _defaultCloudEndpoint;

    final storage = S3StorageService(
      s3EndpointUrl: endpoint,
      bucketPrivate: 'towdow-private',
      bucketShared: 'towdow-shared',
      region: region,
      jwtProvider: jwtProvider ?? () => AuthTokenProvider.getTokenByAccountId(resolvedAccountId),
    );

    if (!Hive.isBoxOpen('file_cache_$resolvedAccountId')) {
      await Hive.openBox<CachedFile>('file_cache_$resolvedAccountId');
    }

    return FileRepository._internal(accountId: resolvedAccountId, storageService: storage);
  }

  /// Save or update a local CachedFile entry.
  Future<void> _putCache(CachedFile file) async {
    await _cacheBox.put(file.key, file);
  }

  /// Upload a local file buffer to S3 (private scope) and cache metadata.
  Future<Result<StoredFileMetadata>> uploadPrivate({required String key, required Uint8List data, required String localPath}) async {
    final uploadResult = await storageService.uploadPrivate(key: key, data: data);
    return await uploadResult.when(
      success: (meta) async {
        final cacheItem = CachedFile(
          key: key,
          localPath: localPath,
          size: data.length,
          status: CachedFileStatus.synced,
          lastModified: meta.lastModified,
        );
        await _putCache(cacheItem);
        return Result.success(meta);
      },
      failure: (f) async => Result.failure(f),
    );
  }

  /// Download a file and store on disk via [writeFile] callback.
  Future<Result<String>> download({required String bucket, required String key, required Future<String> Function(Uint8List) writeFile}) async {
    final dl = await storageService.download(bucket: bucket, key: key);
    return await dl.when(
      success: (bytes) async {
        final path = await writeFile(bytes);
        final cacheItem = CachedFile(
          key: key,
          localPath: path,
          size: bytes.length,
          status: CachedFileStatus.synced,
          lastModified: DateTime.now().toUtc(),
        );
        await _putCache(cacheItem);
        return Result.success(path);
      },
      failure: (f) async => Result.failure(f),
    );
  }

  CachedFile? getCached(String key) => _cacheBox.get(key);

  List<CachedFile> pendingUploads() => _cacheBox.values.where((e) => e.status == CachedFileStatus.queued).toList();
} 