// Offline file model for managing local file storage and upload queue
// Supports offline-first functionality with automatic sync when connection is available

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'offline_file.freezed.dart';
part 'offline_file.g.dart';

/// Status of an offline file
@HiveType(typeId: 20)
enum OfflineFileStatus {
  @HiveField(0)
  local,        // File stored locally, not uploaded yet
  @HiveField(1)
  uploading,    // File is currently being uploaded
  @HiveField(2)
  uploaded,     // File successfully uploaded to S3
  @HiveField(3)
  failed,       // Upload failed, needs retry
}

/// Offline file model for local storage and upload queue
@HiveType(typeId: 21)
@freezed
abstract class OfflineFile with _$OfflineFile {
  const factory OfflineFile({
    @HiveField(0) required String id,
    @HiveField(1) required String taskUid,
    @HiveField(2) required String aesKey, // AES encryption key for this file
    @HiveField(3) required String fileName,
    @HiveField(4) required String localPath,
    @HiveField(5) required int fileSize,
    @HiveField(6) required String contentType,
    @HiveField(7) required DateTime createdAt,
    @HiveField(8) required OfflineFileStatus status,
    @HiveField(9) String? s3Key,
    @HiveField(10) String? s3Url,
    @HiveField(11) DateTime? uploadedAt,
    @HiveField(12) String? errorMessage,
    @HiveField(13) @Default(0) int retryCount,
    @HiveField(14) DateTime? lastRetryAt,
    @HiveField(15) String? validatorId, // Optional: for validator-specific files (backward compatibility)
    @HiveField(16) String? ownerType, // 'task' | 'journal' (generic owner)
    @HiveField(17) String? ownerUid, // UID of task/journal
    @HiveField(18) String? thumbnailPath, // Path to thumbnail file (for images)
    @HiveField(19) DateTime? lastAccessed, // Last time file was accessed (for retention policy)
  }) = _OfflineFile;

  factory OfflineFile.fromJson(Map<String, dynamic> json) => _$OfflineFileFromJson(json);
}

/// Upload queue item for managing file uploads
@HiveType(typeId: 22)
@freezed
abstract class FileUploadQueueItem with _$FileUploadQueueItem {
  const factory FileUploadQueueItem({
    @HiveField(0) required String id,
    @HiveField(1) required String offlineFileId,
    @HiveField(2) required DateTime queuedAt,
    @HiveField(3) @Default(0) int retryCount,
    @HiveField(4) DateTime? lastAttemptAt,
    @HiveField(5) String? lastError,
    @HiveField(6) @Default(false) bool isProcessing,
  }) = _FileUploadQueueItem;

  factory FileUploadQueueItem.fromJson(Map<String, dynamic> json) => _$FileUploadQueueItemFromJson(json);
} 