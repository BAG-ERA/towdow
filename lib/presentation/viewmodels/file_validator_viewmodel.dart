// File Validator ViewModel for managing file upload/download operations
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
import '../../data/providers/providers.dart';
import '../../core/logger.dart';
import '../../core/result.dart';

/// File Validator ViewModel State
class FileValidatorState {
  final bool isUploading;
  final bool isDownloading;
  final String? downloadingFileId;
  final String? error;
  final String? successMessage;

  const FileValidatorState({
    this.isUploading = false,
    this.isDownloading = false,
    this.downloadingFileId,
    this.error,
    this.successMessage,
  });

  FileValidatorState copyWith({
    bool? isUploading,
    bool? isDownloading,
    String? downloadingFileId,
    String? error,
    String? successMessage,
  }) {
    return FileValidatorState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingFileId: downloadingFileId ?? this.downloadingFileId,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  FileValidatorState clearMessages() {
    return copyWith(error: null, successMessage: null);
  }
}

/// File Validator ViewModel
class FileValidatorViewModel extends StateNotifier<FileValidatorState> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final SyncService? _syncService;

  FileValidatorViewModel(
    this._taskRepository,
    this._accountRepository, [
    this._syncService,
  ]) : super(const FileValidatorState());

  /// Upload a file to a validator
  Future<bool> uploadFile({
    required String taskUid,
    required String validatorId,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    state = state.copyWith(isUploading: true, error: null);

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
            throw Exception('You do not have permission to upload files to this task');
          }

          return task;
        },
        failure: (failure) async {
          throw Exception('Failed to get task: ${failure.message}');
        },
      );

      // Get account for S3 service
      final account = await accountResult.when(
        success: (acc) async => acc!,
        failure: (_) async => throw Exception('No active account found'),
      );

      // Create S3 service and upload file
      final s3Service = S3StorageService(account: account);
      
      // Generate file metadata
      const uuid = Uuid();
      final fileId = uuid.v4();
      final userPrefix = s3Service.getUserPrefix();
      
      // Sanitize fileName to avoid S3 signature issues with special characters
      final sanitizedFileName = _sanitizeFileName(fileName);
      AppLogger.debug('FileValidatorViewModel.uploadFile: Original filename: $fileName');
      AppLogger.debug('FileValidatorViewModel.uploadFile: Sanitized filename: $sanitizedFileName');
      
      // Build S3 path: {userPrefix}{taskUid}/{sanitizedFileName}
      final s3Key = '$userPrefix$taskUid/$sanitizedFileName';
      
      // Upload to S3
      final uploadResult = await s3Service.uploadFile(
        key: s3Key,
        data: fileData,
        isPrivate: false, // Use shared bucket
        contentType: contentType,
      );

      final success = await uploadResult.when(
        success: (fileUrl) async {
          // Create file info
          final fileInfo = {
            'id': fileId,
            'name': fileName,
            'size': fileData.length,
            'contentType': contentType,
            's3Key': s3Key,
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
              await _queueSyncOperation(updatedTask);
            },
            failure: (failure) async {
              throw Exception('Failed to save file info: ${failure.message}');
            },
          );

          state = state.copyWith(
            isUploading: false,
            successMessage: 'File uploaded successfully',
          );
          return true;
        },
        failure: (failure) async {
          throw Exception('File upload failed: ${failure.message}');
        },
      );

      return success;
    } catch (e) {
      AppLogger.error('FileValidatorViewModel: Upload failed', e);
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: $e',
      );
      return false;
    }
  }

  /// Download file bytes for platform-specific saving (Android/iOS compatibility)
  Future<Uint8List?> downloadFileBytes({
    required String fileId,
    required String fileName,
    required String s3Key,
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

      // Create S3 service and download file
      final s3Service = S3StorageService(account: account);
      
      // Download from S3
      final downloadResult = await s3Service.downloadFile(
        key: s3Key,
        isPrivate: false, // Use shared bucket
      );

      final fileBytes = await downloadResult.when(
        success: (data) async {
          state = state.copyWith(
            isDownloading: false,
            downloadingFileId: null,
            successMessage: 'File ready for download',
          );
          
          return data;
        },
        failure: (failure) async {
          throw Exception('Download failed: ${failure.message}');
        },
      );

      return fileBytes;
    } catch (e) {
      AppLogger.error('FileValidatorViewModel: Download failed', e);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Download a file from a validator (legacy method for desktop platforms)
  Future<String?> downloadFile({
    required String fileId,
    required String fileName,
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

      // Create S3 service and download file
      final s3Service = S3StorageService(account: account);
      
      // Download from S3
      final downloadResult = await s3Service.downloadFile(
        key: s3Key,
        isPrivate: false, // Use shared bucket
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
            finalPath = '${downloadsDir.path}/task_attachment_$fileName';
          }
          
          // Save file to chosen location
          try {
            final localFile = File(finalPath);
            await localFile.writeAsBytes(data);
            
            state = state.copyWith(
              isDownloading: false,
              downloadingFileId: null,
              successMessage: 'File downloaded to: $finalPath',
            );
            
            return finalPath;
          } catch (e) {
            throw Exception('Could not save file: $e');
          }
        },
        failure: (failure) async {
          throw Exception('Download failed: ${failure.message}');
        },
      );

      return filePath;
    } catch (e) {
      AppLogger.error('FileValidatorViewModel: Download failed', e);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Remove a file from a validator
  Future<bool> removeFile({
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
            throw Exception('You do not have permission to remove files from this task');
          }

          return task;
        },
        failure: (failure) async {
          throw Exception('Failed to get task: ${failure.message}');
        },
      );

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
          throw Exception('Failed to remove file: ${failure.message}');
        },
      );

      state = state.copyWith(successMessage: 'File removed successfully');
      return true;
    } catch (e) {
      AppLogger.error('FileValidatorViewModel: Remove file failed', e);
      state = state.copyWith(error: 'Failed to remove file: $e');
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
          AppLogger.debug('FileValidatorViewModel: Queued sync for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('FileValidatorViewModel: Failed to queue sync: ${failure.message}');
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

/// Provider for file validator view model
final fileValidatorViewModelProvider = StateNotifierProvider.family<FileValidatorViewModel, FileValidatorState, String>(
  (ref, taskUid) => FileValidatorViewModel(
    ref.watch(taskRepositoryProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(syncServiceProvider),
  ),
); 