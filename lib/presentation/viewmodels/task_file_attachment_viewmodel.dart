// Task File Attachment ViewModel for managing task-level file attachments
// Handles file upload/download logic following MVVM architecture
// Uses existing S3 storage, encryption, and upload queue services

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';

import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/s3_storage_service.dart';

import '../../data/services/offline_file_service.dart';
import '../../data/services/file_upload_queue_service.dart';
import '../../core/logger.dart';

/// State for task file attachment operations
class TaskFileAttachmentState {
  final bool isUploading;
  final bool isDownloading;
  final String? downloadingFileId;
  final String? error;
  final String? successMessage;

  const TaskFileAttachmentState({
    this.isUploading = false,
    this.isDownloading = false,
    this.downloadingFileId,
    this.error,
    this.successMessage,
  });

  TaskFileAttachmentState copyWith({
    bool? isUploading,
    bool? isDownloading,
    String? downloadingFileId,
    String? error,
    String? successMessage,
  }) {
    return TaskFileAttachmentState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingFileId: downloadingFileId ?? this.downloadingFileId,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// ViewModel for task file attachments
class TaskFileAttachmentViewModel extends StateNotifier<TaskFileAttachmentState> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService _fileUploadQueueService;
  // SyncService removed - sync now handled by repository


  TaskFileAttachmentViewModel({
    required TaskRepository taskRepository,
    required AccountRepository accountRepository,
    required OfflineFileService offlineFileService,
    required FileUploadQueueService fileUploadQueueService,

  })  : _taskRepository = taskRepository,
        _accountRepository = accountRepository,
        _offlineFileService = offlineFileService,
        _fileUploadQueueService = fileUploadQueueService,

        super(const TaskFileAttachmentState());

  /// Upload a file attachment to a task
  Future<bool> uploadFile({
    required String taskUid,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    if (state.isUploading) {
      state = state.copyWith(error: 'Upload already in progress');
      return false;
    }

    state = state.copyWith(isUploading: true, error: null);

    try {
      AppLogger.debug('TaskFileAttachmentViewModel: Starting file upload for task $taskUid');
      AppLogger.debug('TaskFileAttachmentViewModel: File: $fileName, Size: ${fileData.length} bytes');

      // Get the task to update its attachments
      final taskResult = await _taskRepository.getById(taskUid);
      final task = await taskResult.when(
        success: (task) async {
          if (task == null) {
            throw Exception('Task not found: $taskUid');
          }
          return task;
        },
        failure: (failure) async => throw Exception('Failed to get task: ${failure.message}'),
      );

      // Generate encryption key
      final encryptionKey = _generateEncryptionKey();

      // Store file locally using the service
      final storeResult = await _offlineFileService.storeFileLocally(
        taskUid: taskUid,
        aesKey: encryptionKey, // Use the generated encryption key directly
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
        validatorId: null, // Not used for task attachments
      );

      final offlineFile = await storeResult.when(
        success: (file) async {
          AppLogger.debug('TaskFileAttachmentViewModel: File stored locally: ${file.id}');
          return file;
        },
        failure: (failure) async => throw Exception('Failed to store file locally: ${failure.message}'),
      );

      // Use the file ID from the stored offline file
      final fileId = offlineFile.id;

      // Update task with new attachment using VTODO parser field names
      final attachments = _parseAttachments(task.attachments);
      attachments.add({
        'uri': fileId, // Use URI as the primary identifier (like VTODO parser)
        'filename': fileName,
        'size': fileData.length,
        'fmttype': contentType,
        'attachType': 'file',
        'aesKey': encryptionKey,
        'status': 'local',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final updatedTask = task.copyWith(
        attachments: _serializeAttachments(attachments),
        lastModified: DateTime.now(),
      );

      // Save updated task
      final saveTaskResult = await _taskRepository.save(updatedTask);
      await saveTaskResult.when(
        success: (_) async {
          AppLogger.debug('TaskFileAttachmentViewModel: Task updated with attachment');
        },
        failure: (failure) async => throw Exception('Failed to save task: ${failure.message}'),
      );

      // Queue file for upload
      await _fileUploadQueueService.queueFileUpload(fileId);

      // Sync is now handled by repository

      state = state.copyWith(
        isUploading: false,
        successMessage: 'File attached successfully',
      );

      AppLogger.info('TaskFileAttachmentViewModel: File attachment completed for $fileName');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('TaskFileAttachmentViewModel: Upload failed', e, stackTrace);
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: $e',
      );
      return false;
    }
  }

  /// Download a file attachment as bytes (offline-first)
  Future<Uint8List?> downloadFileBytes({
    required String fileId,
    required String fileName,
    required String taskUid,
    required String encryptionKey,
    String? s3Key,
  }) async {
    if (state.isDownloading) {
      state = state.copyWith(error: 'Download already in progress');
      return null;
    }

    state = state.copyWith(
      isDownloading: true,
      downloadingFileId: fileId,
      error: null,
    );

    try {
      AppLogger.debug('TaskFileAttachmentViewModel: Starting download for file $fileId');

      // Try to get file locally first (offline-first)
      final localResult = await _offlineFileService.readLocalFile(fileId);
      final localData = await localResult.when(
        success: (data) async => data,
        failure: (_) async => null,
      );

      if (localData != null) {
        AppLogger.debug('TaskFileAttachmentViewModel: File found locally: $fileName');
        state = state.copyWith(
          isDownloading: false,
          downloadingFileId: null,
          successMessage: 'File downloaded successfully',
        );
        return localData;
      }

      // If not available locally and we have S3 key, download from S3
      if (s3Key != null && s3Key.isNotEmpty) {
        AppLogger.debug('TaskFileAttachmentViewModel: Downloading from S3: $s3Key');

        // Get account for S3 service
        final accountResult = await _accountRepository.getActiveAccount();
        final account = await accountResult.when(
          success: (acc) async {
            if (acc == null) {
              throw Exception('No active account found');
            }
            return acc;
          },
          failure: (failure) async => throw Exception('Failed to get account: ${failure.message}'),
        );

        // Create S3 service and download
        final s3Service = S3StorageService(account: account);
        final downloadResult = await s3Service.downloadFile(
          key: s3Key,
          isPrivate: false, // Use shared bucket
          symmetricKey: encryptionKey,
        );

        final data = await downloadResult.when(
          success: (data) async => data,
          failure: (failure) async => throw Exception('S3 download failed: ${failure.message}'),
        );

        state = state.copyWith(
          isDownloading: false,
          downloadingFileId: null,
          successMessage: 'File downloaded successfully',
        );

        AppLogger.info('TaskFileAttachmentViewModel: File downloaded from S3: $fileName');
        return data;
      }

      throw Exception('File not available locally or on server');
    } catch (e, stackTrace) {
      AppLogger.error('TaskFileAttachmentViewModel: Download failed', e, stackTrace);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Remove a file attachment from task
  Future<bool> removeFile({
    required String taskUid,
    required String fileId,
  }) async {
    try {
      AppLogger.debug('TaskFileAttachmentViewModel: Removing file $fileId from task $taskUid');

      // Get the task
      final taskResult = await _taskRepository.getById(taskUid);
      final task = await taskResult.when(
        success: (task) async {
          if (task == null) {
            throw Exception('Task not found: $taskUid');
          }
          return task;
        },
        failure: (failure) async => throw Exception('Failed to get task: ${failure.message}'),
      );

      // Remove attachment from task
      final attachments = _parseAttachments(task.attachments);
      final originalCount = attachments.length;
      attachments.removeWhere((attachment) => attachment['uri'] == fileId);

      if (attachments.length == originalCount) {
        throw Exception('File attachment not found');
      }

      final updatedTask = task.copyWith(
        attachments: _serializeAttachments(attachments),
        lastModified: DateTime.now(),
      );

      // Save updated task
      final saveResult = await _taskRepository.save(updatedTask);
      await saveResult.when(
        success: (_) async {
          AppLogger.debug('TaskFileAttachmentViewModel: Task updated after file removal');
        },
        failure: (failure) async => throw Exception('Failed to save task: ${failure.message}'),
      );

      // Clean up local file
      await _offlineFileService.deleteOfflineFile(fileId);

      // Sync is now handled by repository

      state = state.copyWith(successMessage: 'File removed successfully');
      AppLogger.info('TaskFileAttachmentViewModel: File removed successfully: $fileId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('TaskFileAttachmentViewModel: Remove failed', e, stackTrace);
      state = state.copyWith(error: 'Remove failed: $e');
      return false;
    }
  }

  /// Clear error and success messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }

  /// Generate a unique encryption key for file attachment
  String _generateEncryptionKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final combined = '$timestamp-$random';
    
    // Create a hash for additional security
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Parse attachments JSON array
  List<Map<String, dynamic>> _parseAttachments(String attachmentsJson) {
    try {
      if (attachmentsJson.isEmpty || attachmentsJson == '[]') {
        return [];
      }
      
      final decoded = jsonDecode(attachmentsJson);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((attachment) {
          return attachment is Map<String, dynamic> ? attachment : <String, dynamic>{};
        }).toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.error('TaskFileAttachmentViewModel: Failed to parse attachments JSON', e, StackTrace.current);
      return [];
    }
  }

  /// Serialize attachments to JSON array
  String _serializeAttachments(List<Map<String, dynamic>> attachments) {
    try {
      return jsonEncode(attachments);
    } catch (e) {
      AppLogger.error('TaskFileAttachmentViewModel: Failed to serialize attachments', e, StackTrace.current);
      return '[]';
    }
  }
} 