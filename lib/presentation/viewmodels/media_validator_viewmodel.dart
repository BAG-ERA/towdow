// Media Validator ViewModel for managing media upload/download operations
// Handles all S3 integration and business logic following MVVM architecture
// Widgets should only handle UI concerns and call these ViewModel methods

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/s3_storage_service.dart';
import '../../data/services/validator_service.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/offline_file_service.dart';
import '../../data/services/file_upload_queue_service.dart';
import '../../data/providers/providers.dart';
import '../../data/models/offline_file.dart';
import '../../core/logger.dart';

/// Media Validator ViewModel State
class MediaValidatorState {
  final bool isUploading;
  final bool isDownloading;
  final String? downloadingFileId;
  final String? error;
  final String? successMessage;

  const MediaValidatorState({
    this.isUploading = false,
    this.isDownloading = false,
    this.downloadingFileId,
    this.error,
    this.successMessage,
  });

  MediaValidatorState copyWith({
    bool? isUploading,
    bool? isDownloading,
    String? downloadingFileId,
    String? error,
    String? successMessage,
  }) {
    return MediaValidatorState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingFileId: downloadingFileId ?? this.downloadingFileId,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  MediaValidatorState clearMessages() {
    return copyWith(error: null, successMessage: null);
  }
}

/// Media Validator ViewModel
class MediaValidatorViewModel extends StateNotifier<MediaValidatorState> {
  final String _taskUid;
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final SyncService? _syncService;
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService _fileUploadQueueService;

  MediaValidatorViewModel(
    this._taskUid,
    this._taskRepository,
    this._accountRepository,
    this._offlineFileService,
    this._fileUploadQueueService, [
    this._syncService,
  ]) : super(const MediaValidatorState());

  /// Get encryption key for a specific validator
  Future<String> _getValidatorEncryptionKey(String validatorId) async {
    final taskResult = await _taskRepository.getById(_taskUid);
    final task = await taskResult.when(
      success: (task) async {
        if (task == null) {
          throw Exception('Task not found: $_taskUid');
        }
        return task;
      },
      failure: (failure) async => throw Exception('Failed to get task: ${failure.message}'),
    );
    
    // Extract encryption key from validator
    final validators = ValidatorService.parseValidators(task.flowitValidator);
    
    for (final validatorList in validators) {
      for (final validator in validatorList) {
        if (validator['id'] == validatorId && validator['type'] == 'media') {
          final encryptionKey = validator['encryptionKey'] as String?;
          if (encryptionKey != null) {
            return encryptionKey;
          }
        }
      }
    }
    
    throw Exception('Encryption key not found for validator $validatorId');
  }

  /// Upload a media file to a validator (offline-first)
  Future<bool> uploadMediaFile({
    required String taskUid,
    required String validatorId,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    state = state.copyWith(isUploading: true, error: null);

    try {
      AppLogger.info('MediaValidatorViewModel: Starting media upload for $fileName');
      
      // Get current user for permission check
      String? currentUserEmail;
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          currentUserEmail = account?.email ?? account?.username;
          AppLogger.debug('MediaValidatorViewModel: Current user: $currentUserEmail');
        },
        failure: (_) async {
          throw Exception('No active account found');
        },
      );

      // Get task and check permissions
      final taskResult = await _taskRepository.getById(taskUid);
      final task = await taskResult.when(
        success: (task) async {
          if (task == null) {
            throw Exception('Task not found');
          }

          if (!ValidatorService.canEditValidators(task.organizer, currentUserEmail)) {
            throw Exception('You do not have permission to upload media to this task');
          }

          return task;
        },
        failure: (failure) async {
          throw Exception('Failed to get task: ${failure.message}');
        },
      );

      AppLogger.info('MediaValidatorViewModel: Storing media file locally for task $taskUid');
      
      // Store file locally first (offline-first approach)
      final offlineFileResult = await _offlineFileService.storeFileLocally(
        taskUid: taskUid,
        validatorId: validatorId,
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
      );

      final success = await offlineFileResult.when(
        success: (offlineFile) async {
          AppLogger.info('MediaValidatorViewModel: Media file stored locally with ID: ${offlineFile.id}');
          
          // Create file info for validator (using offline file ID)
          final fileInfo = {
            'id': offlineFile.id,
            'name': fileName,
            'size': fileData.length,
            'contentType': contentType,
            'offlineFileId': offlineFile.id,
            'status': 'local', // Indicates file is stored locally
            'uploadedAt': DateTime.now().toIso8601String(),
          };

          // Update validator with file info
          final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
          final updatedValidatorLists = ValidatorService.updateValidatorState(
            validatorLists,
            validatorId,
            {
              'type': 'add_file',
              'fileInfo': fileInfo,
            },
          );

          // Save updated task
          final updatedTask = task.copyWith(
            flowitValidator: ValidatorService.serializeValidators(updatedValidatorLists),
            lastModified: DateTime.now(),
          );

          final saveResult = await _taskRepository.save(updatedTask);
          await saveResult.when(
            success: (_) async {
              AppLogger.info('MediaValidatorViewModel: Task updated successfully');
              await _queueSyncOperation(updatedTask);
            },
            failure: (failure) async {
              throw Exception('Failed to save media info: ${failure.message}');
            },
          );

          // Queue file for upload
          AppLogger.info('MediaValidatorViewModel: Queueing media file for upload: ${offlineFile.id}');
          final queueResult = await _fileUploadQueueService.queueFileUpload(offlineFile.id);
          await queueResult.when(
            success: (_) async {
              AppLogger.info('MediaValidatorViewModel: Media file successfully queued for upload');
            },
            failure: (failure) async {
              AppLogger.error('MediaValidatorViewModel: Failed to queue media file for upload: ${failure.message}');
            },
          );

          state = state.copyWith(
            isUploading: false,
            successMessage: 'Media file added successfully (will upload when online)',
          );
          return true;
        },
        failure: (failure) async {
          throw Exception('Failed to store media file locally: ${failure.message}');
        },
      );

      return success;
    } catch (e) {
      AppLogger.error('MediaValidatorViewModel: Upload failed', e);
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: $e',
      );
      return false;
    }
  }

  /// Download media file bytes for platform-specific saving (Android/iOS compatibility)
  Future<Uint8List?> downloadMediaFileBytes({
    required String fileId,
    required String fileName,
    required String validatorId,
    String? s3Key,
  }) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingFileId: fileId,
      error: null,
    );

    try {
      // First try to get file from local storage (offline-first)
      final localFileResult = await _offlineFileService.readLocalFile(fileId);
      
      final fileBytes = await localFileResult.when(
        success: (data) async {
          state = state.copyWith(
            isDownloading: false,
            downloadingFileId: null,
            successMessage: 'Media file ready for download',
          );
          return data;
        },
        failure: (failure) async {
          // If local file not found, try to download from S3
          if (s3Key != null) {
            AppLogger.debug('MediaValidatorViewModel: Local media file not found, trying S3 download');
            return await _downloadFromS3(s3Key, validatorId);
          } else {
            throw Exception('Media file not available locally and no S3 key provided');
          }
        },
      );

      return fileBytes;
    } catch (e) {
      AppLogger.error('MediaValidatorViewModel: Download failed', e);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Download media file from S3 (fallback when local file not available)
  Future<Uint8List> _downloadFromS3(String s3Key, String validatorId) async {
    // Get account for S3 service
    final accountResult = await _accountRepository.getActiveAccount();
    final account = await accountResult.when(
      success: (acc) async => acc!,
      failure: (_) async => throw Exception('No active account found'),
    );

    // Get encryption key for the validator
    final encryptionKey = await _getValidatorEncryptionKey(validatorId);

    // Create S3 service and download file
    final s3Service = S3StorageService(account: account);
    
    // Download from S3 with decryption
    final downloadResult = await s3Service.downloadFile(
      key: s3Key,
      isPrivate: false, // Use shared bucket
      symmetricKey: encryptionKey, // Use validator's encryption key
    );

    return await downloadResult.when(
      success: (data) async {
        state = state.copyWith(
          isDownloading: false,
          downloadingFileId: null,
          successMessage: 'Media file downloaded from server',
        );
        return data;
      },
      failure: (failure) async {
        throw Exception('S3 download failed: ${failure.message}');
      },
    );
  }

  /// Download a media file from a validator (legacy method for desktop platforms)
  Future<String?> downloadMediaFile({
    required String fileId,
    required String fileName,
    required String validatorId,
    required String s3Key,
    String? savePath,
  }) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingFileId: fileId,
      error: null,
    );

    try {
      // Get account for S3 service
      final accountResult = await _accountRepository.getActiveAccount();
      final account = await accountResult.when(
        success: (acc) async => acc!,
        failure: (_) async => throw Exception('No active account found'),
      );

      // Get encryption key for the validator
      final encryptionKey = await _getValidatorEncryptionKey(validatorId);

      // Create S3 service and download file
      final s3Service = S3StorageService(account: account);
      
      // Download from S3 with decryption
      final downloadResult = await s3Service.downloadFile(
        key: s3Key,
        isPrivate: false, // Use shared bucket
        symmetricKey: encryptionKey, // Use validator's encryption key
      );

      final filePath = await downloadResult.when(
        success: (data) async {
          // Use provided save path or default to Downloads directory
          String finalPath;
          if (savePath != null) {
            finalPath = savePath;
          } else {
            final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            finalPath = '${downloadsDir.path}/task_media_$fileName';
          }
          
          // Save file to chosen location
          try {
            final localFile = File(finalPath);
            await localFile.writeAsBytes(data);
            
            state = state.copyWith(
              isDownloading: false,
              downloadingFileId: null,
              successMessage: 'Media file downloaded to: $finalPath',
            );
            
            return finalPath;
          } catch (e) {
            throw Exception('Could not save media file: $e');
          }
        },
        failure: (failure) async {
          throw Exception('Download failed: ${failure.message}');
        },
      );

      return filePath;
    } catch (e) {
      AppLogger.error('MediaValidatorViewModel: Download failed', e);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Remove a media file from a validator
  Future<bool> removeMediaFile({
    required String taskUid,
    required String validatorId,
    required String fileId,
  }) async {
    try {
      // Get current user for permission check
      String? currentUserEmail;
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          currentUserEmail = account?.email ?? account?.username;
        },
        failure: (_) async {
          throw Exception('No active account found');
        },
      );

      // Get task and check permissions
      final taskResult = await _taskRepository.getById(taskUid);
      final task = await taskResult.when(
        success: (task) async {
          if (task == null) {
            throw Exception('Task not found');
          }

          if (!ValidatorService.canEditValidators(task.organizer, currentUserEmail)) {
            throw Exception('You do not have permission to remove media files from this task');
          }

          return task;
        },
        failure: (failure) async {
          throw Exception('Failed to get task: ${failure.message}');
        },
      );

      // Remove offline file if it exists
      await _offlineFileService.deleteOfflineFile(fileId);
      
      // Remove from upload queue if it exists
      await _fileUploadQueueService.removeFromQueue(fileId);

      // Update validator by removing file
      final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
      final updatedValidatorLists = ValidatorService.updateValidatorState(
        validatorLists,
        validatorId,
        {
          'type': 'remove_file',
          'fileId': fileId,
        },
      );

      // Save updated task
      final updatedTask = task.copyWith(
        flowitValidator: ValidatorService.serializeValidators(updatedValidatorLists),
        lastModified: DateTime.now(),
      );

      final saveResult = await _taskRepository.save(updatedTask);
      await saveResult.when(
        success: (_) async {
          await _queueSyncOperation(updatedTask);
        },
        failure: (failure) async {
          throw Exception('Failed to remove media file: ${failure.message}');
        },
      );

      state = state.copyWith(successMessage: 'Media file removed successfully');
      return true;
    } catch (e) {
      AppLogger.error('MediaValidatorViewModel: Remove media file failed', e);
      state = state.copyWith(error: 'Failed to remove media file: $e');
      return false;
    }
  }

  /// Clear current state messages
  void clearMessages() {
    state = state.clearMessages();
  }

  /// Queue sync operation for updated task
  Future<void> _queueSyncOperation(task) async {
    if (_syncService != null && task.projectPath != null && task.projectPath!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarUid': task.projectPath,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        syncData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('MediaValidatorViewModel: Queued sync for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('MediaValidatorViewModel: Failed to queue sync: ${failure.message}');
        },
      );
    }
  }

  /// Sanitize filename to avoid S3 signature issues with special characters
  String _sanitizeFileName(String fileName) {
    // Replace problematic characters that can cause S3 signature mismatches
    return fileName
        // Replace em dash and en dash with regular hyphen
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        // Replace other Unicode spaces and dashes
        .replaceAll(RegExp(r'[\u2000-\u206F\u2E00-\u2E7F\u3000]'), '-')
        // Replace multiple consecutive spaces/dashes with single dash
        .replaceAll(RegExp(r'[-\s]+'), '-')
        // Remove leading/trailing dashes and spaces
        .trim()
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// Provider for media validator view model
final mediaValidatorViewModelProvider = StateNotifierProvider.family<MediaValidatorViewModel, MediaValidatorState, String>(
  (ref, taskUid) => MediaValidatorViewModel(
    taskUid,
    ref.watch(taskRepositoryProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(offlineFileServiceProvider),
    ref.watch(fileUploadQueueServiceProvider),
    ref.watch(syncServiceProvider),
  ),
); 