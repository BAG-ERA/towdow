// Task Media Attachment ViewModel for managing media upload/download operations
// Handles all media attachment business logic following MVVM architecture
// Reuses infrastructure from MediaValidatorViewModel but adapts for task attachments

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/offline_file_service.dart';
import '../../data/services/file_upload_queue_service.dart';
import '../../core/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Task Media Attachment ViewModel State
class TaskMediaAttachmentState {
  final bool isUploading;
  final bool isDownloading;
  final String? downloadingFileId;
  final String? error;
  final String? successMessage;

  const TaskMediaAttachmentState({
    this.isUploading = false,
    this.isDownloading = false,
    this.downloadingFileId,
    this.error,
    this.successMessage,
  });

  TaskMediaAttachmentState copyWith({
    bool? isUploading,
    bool? isDownloading,
    String? downloadingFileId,
    String? error,
    String? successMessage,
  }) {
    return TaskMediaAttachmentState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingFileId: downloadingFileId ?? this.downloadingFileId,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  TaskMediaAttachmentState clearMessages() {
    return copyWith(error: null, successMessage: null);
  }
}

/// Task Media Attachment ViewModel
class TaskMediaAttachmentViewModel extends StateNotifier<TaskMediaAttachmentState> {
  final String _taskUid;
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService _fileUploadQueueService;

  TaskMediaAttachmentViewModel(
    this._taskUid,
    this._taskRepository,
    this._accountRepository,
    this._offlineFileService,
    this._fileUploadQueueService,
  ) : super(const TaskMediaAttachmentState());

  /// Generate a unique encryption key for media files
  String _generateEncryptionKey() {
    const uuid = Uuid();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = '${uuid.v4()}-$timestamp';
    
    // Create a hash for additional security
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Upload a media file to task media attachments (offline-first)
  Future<bool> uploadMediaFile({
    required String taskUid,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    state = state.copyWith(isUploading: true, error: null);

    try {
      AppLogger.info('TaskMediaAttachmentViewModel: Starting media upload for $fileName');
      
      // Get current user for permission check
      String? currentUserEmail;
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          currentUserEmail = account?.email ?? account?.username;
          AppLogger.debug('TaskMediaAttachmentViewModel: Current user: $currentUserEmail');
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

          // For media attachments, allow upload if user is organizer or attendee
          if (task.organizer != currentUserEmail && 
              !task.attendees.any((a) => a.email == currentUserEmail)) {
            throw Exception('You do not have permission to upload media to this task');
          }

          return task;
        },
        failure: (failure) async {
          throw Exception('Failed to get task: ${failure.message}');
        },
      );

      AppLogger.info('TaskMediaAttachmentViewModel: Storing media file locally for task $taskUid');
      
      // Generate encryption key for this media file
      final encryptionKey = _generateEncryptionKey();
      
      // Store file locally first (offline-first approach)
      final offlineFileResult = await _offlineFileService.storeFileLocally(
        taskUid: taskUid,
        aesKey: encryptionKey,
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
        validatorId: null, // Not used for task attachments
      );

      final success = await offlineFileResult.when(
        success: (offlineFile) async {
          AppLogger.info('TaskMediaAttachmentViewModel: Media file stored locally with ID: ${offlineFile.id}');
          
          // Create media attachment info using VTODO parser field names
          final mediaAttachmentInfo = {
            'uri': offlineFile.id, // Use URI as the primary identifier
            'filename': fileName,
            'size': fileData.length,
            'contentType': contentType,
            'offlineFileId': offlineFile.id,
            'status': 'local', // Indicates file is stored locally
            'uploadedAt': DateTime.now().toIso8601String(),
            'aesKey': encryptionKey,
            'mediaType': _getMediaType(fileName),
          };

          // Parse existing media attachments
          final existingMediaAttachments = _parseMediaAttachments(task.mediaAttachments);
          existingMediaAttachments.add(mediaAttachmentInfo);

          // Save updated task
          final updatedTask = task.copyWith(
            mediaAttachments: _serializeMediaAttachments(existingMediaAttachments),
            lastModified: DateTime.now(),
          );

          final saveResult = await _taskRepository.save(updatedTask);
          await saveResult.when(
            success: (_) async {
              AppLogger.info('TaskMediaAttachmentViewModel: Task updated successfully');
              // Sync is now handled by repository
            },
            failure: (failure) async {
              throw Exception('Failed to save media info: ${failure.message}');
            },
          );

          // Queue file for upload
          AppLogger.info('TaskMediaAttachmentViewModel: Queueing media file for upload: ${offlineFile.id}');
          final queueResult = await _fileUploadQueueService.queueFileUpload(offlineFile.id);
          await queueResult.when(
            success: (_) async {
              AppLogger.info('TaskMediaAttachmentViewModel: Media file successfully queued for upload');
            },
            failure: (failure) async {
              AppLogger.error('TaskMediaAttachmentViewModel: Failed to queue media file for upload: ${failure.message}');
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
      AppLogger.error('TaskMediaAttachmentViewModel: Upload failed', e);
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: $e',
      );
      return false;
    }
  }

  /// Download media file bytes for platform-specific saving
  Future<Uint8List?> downloadMediaFileBytes({
    required String fileId,
    required String fileName,
    String? s3Key,
  }) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingFileId: fileId,
      error: null,
    );

    try {
      AppLogger.info('TaskMediaAttachmentViewModel: Downloading media file: $fileName');

      // Try to get file from offline storage first (offline-first)
      final offlineFileResult = await _offlineFileService.getOfflineFile(fileId);
      
      return await offlineFileResult.when(
        success: (offlineFile) async {
          if (offlineFile != null) {
            AppLogger.info('TaskMediaAttachmentViewModel: Found file in offline storage');
            
            state = state.copyWith(
              isDownloading: false,
              downloadingFileId: null,
              successMessage: 'Media file downloaded successfully',
            );
            
                         // Read file data from local path
             final fileDataResult = await _offlineFileService.readLocalFile(fileId);
             return await fileDataResult.when(
               success: (fileData) async => fileData,
               failure: (_) async => null,
             );
          } else {
            // File not found offline, try S3 if we have s3Key
            if (s3Key != null) {
              AppLogger.info('TaskMediaAttachmentViewModel: File not found offline, trying S3');
              // S3 download would be implemented here if needed
              throw Exception('S3 download not implemented for media attachments yet');
            } else {
              throw Exception('Media file not found locally and no S3 key available');
            }
          }
        },
        failure: (failure) async {
          throw Exception('Failed to access offline file: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('TaskMediaAttachmentViewModel: Download failed', e);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Get image data for preview
  Future<Uint8List?> getImageData({
    required String fileId,
    required String fileName,
    String? s3Key,
  }) async {
    try {
      // For image preview, we use the same logic as download but without state updates
      final offlineFileResult = await _offlineFileService.getOfflineFile(fileId);
      
              return await offlineFileResult.when(
          success: (offlineFile) async {
            if (offlineFile != null) {
              // Read file data from local path
              final fileDataResult = await _offlineFileService.readLocalFile(fileId);
              return await fileDataResult.when(
                success: (fileData) async => fileData,
                failure: (_) async => null,
              );
            }
            return null;
          },
        failure: (failure) async {
          AppLogger.debug('TaskMediaAttachmentViewModel: Failed to get image data: ${failure.message}');
          return null;
        },
      );
    } catch (e) {
      AppLogger.debug('TaskMediaAttachmentViewModel: Error getting image data: $e');
      return null;
    }
  }

  /// Remove a media file from task media attachments
  Future<bool> removeMediaFile({
    required String taskUid,
    required String fileId,
  }) async {
    try {
      AppLogger.info('TaskMediaAttachmentViewModel: Removing media file: $fileId');

      // Get task
      final taskResult = await _taskRepository.getById(taskUid);
      final task = await taskResult.when(
        success: (task) async {
          if (task == null) {
            throw Exception('Task not found');
          }
          return task;
        },
        failure: (failure) async {
          throw Exception('Failed to get task: ${failure.message}');
        },
      );

      // Parse existing media attachments and remove the specified one
      final existingMediaAttachments = _parseMediaAttachments(task.mediaAttachments);
      existingMediaAttachments.removeWhere((attachment) => attachment['uri'] == fileId);

      // Save updated task
      final updatedTask = task.copyWith(
        mediaAttachments: _serializeMediaAttachments(existingMediaAttachments),
        lastModified: DateTime.now(),
      );

      final saveResult = await _taskRepository.save(updatedTask);
      await saveResult.when(
        success: (_) async {
          AppLogger.info('TaskMediaAttachmentViewModel: Media file removed from task');
          // Sync is now handled by repository
        },
        failure: (failure) async {
          throw Exception('Failed to save updated task: ${failure.message}');
        },
      );

      // Remove from offline storage
      final removeResult = await _offlineFileService.deleteOfflineFile(fileId);
      await removeResult.when(
        success: (_) async {
          AppLogger.info('TaskMediaAttachmentViewModel: Media file removed from offline storage');
        },
        failure: (failure) async {
          AppLogger.warning('TaskMediaAttachmentViewModel: Failed to remove file from offline storage: ${failure.message}');
        },
      );

      state = state.copyWith(
        successMessage: 'Media file removed successfully',
      );
      return true;
    } catch (e) {
      AppLogger.error('TaskMediaAttachmentViewModel: Remove failed', e);
      state = state.copyWith(
        error: 'Remove failed: $e',
      );
      return false;
    }
  }

  /// Clear error and success messages
  void clearMessages() {
    state = state.clearMessages();
  }

  // Sync is now handled by repository

  /// Parse media attachments JSON array
  List<Map<String, dynamic>> _parseMediaAttachments(String mediaAttachmentsJson) {
    try {
      if (mediaAttachmentsJson.isEmpty || mediaAttachmentsJson == '[]') {
        return [];
      }
      
      final decoded = jsonDecode(mediaAttachmentsJson);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((attachment) {
          return attachment is Map<String, dynamic> ? attachment : <String, dynamic>{};
        }).toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.error('TaskMediaAttachmentViewModel: Failed to parse media attachments JSON', e);
      return [];
    }
  }

  /// Serialize media attachments to JSON array
  String _serializeMediaAttachments(List<Map<String, dynamic>> mediaAttachments) {
    try {
      return jsonEncode(mediaAttachments);
    } catch (e) {
      AppLogger.error('TaskMediaAttachmentViewModel: Failed to serialize media attachments', e);
      return '[]';
    }
  }

  /// Get media type from file extension
  String _getMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image';
      case 'png':
        return 'image';
      case 'gif':
        return 'image';
      case 'bmp':
        return 'image';
      case 'webp':
        return 'image';
      case 'svg':
        return 'image';
      case 'tiff':
      case 'tif':
        return 'image';
      case 'mp4':
        return 'video';
      case 'avi':
        return 'video';
      case 'mov':
        return 'video';
      case 'wmv':
        return 'video';
      case 'flv':
        return 'video';
      case 'webm':
        return 'video';
      case 'mkv':
        return 'video';
      case '3gp':
        return 'video';
      case 'm4v':
        return 'video';
      default:
        return 'unknown';
    }
  }
} 