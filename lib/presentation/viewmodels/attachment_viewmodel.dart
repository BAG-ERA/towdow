// Unified Attachment ViewModel for managing all attachment operations
// Follows MVVM architecture: ViewModel → Repository (task updates) → OfflineService (file operations)
// Provides a single interface for both file and media attachments

import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attachment.dart';
import '../../data/services/parsers/attachment_parser.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/storage/offline_file_service.dart';
import '../../data/services/storage/file_upload_queue_service.dart';
import '../../data/services/storage/s3_storage_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../core/logger.dart';

/// State for unified attachment operations
class UnifiedAttachmentState {
  final bool isUploading;
  final bool isDownloading;
  final String? downloadingFileId;
  final String? error;
  final String? successMessage;
  final Set<String> uploadingFileIds; // Track multiple uploads

  const UnifiedAttachmentState({
    this.isUploading = false,
    this.isDownloading = false,
    this.downloadingFileId,
    this.error,
    this.successMessage,
    this.uploadingFileIds = const {},
  });

  UnifiedAttachmentState copyWith({
    bool? isUploading,
    bool? isDownloading,
    String? downloadingFileId,
    String? error,
    String? successMessage,
    Set<String>? uploadingFileIds,
  }) {
    return UnifiedAttachmentState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingFileId: downloadingFileId ?? this.downloadingFileId,
      error: error,
      successMessage: successMessage,
      uploadingFileIds: uploadingFileIds ?? this.uploadingFileIds,
    );
  }

  UnifiedAttachmentState clearMessages() {
    return copyWith(error: null, successMessage: null);
  }
}

/// Unified Attachment ViewModel
/// Follows MVVM: ViewModel → Repository → Services
/// ViewModel only updates repositories, never calls services directly
class UnifiedAttachmentViewModel extends StateNotifier<UnifiedAttachmentState> {
  final TaskRepository _taskRepository;
  final JournalRepository _journalRepository;
  final AccountRepository _accountRepository;
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService? _fileUploadQueueService;
  StreamSubscription<FileUploadStatus>? _uploadStatusSubscription;

  UnifiedAttachmentViewModel({
    required TaskRepository taskRepository,
    required JournalRepository journalRepository,
    required AccountRepository accountRepository,
    required OfflineFileService offlineFileService,
    FileUploadQueueService? fileUploadQueueService,
  })  : _taskRepository = taskRepository,
        _journalRepository = journalRepository,
        _accountRepository = accountRepository,
        _offlineFileService = offlineFileService,
        _fileUploadQueueService = fileUploadQueueService,
        super(const UnifiedAttachmentState()) {
    _setupUploadStatusListener();
  }

  /// Setup listener for upload status updates from FileUploadQueueService
  void _setupUploadStatusListener() {
    if (_fileUploadQueueService != null) {
      _uploadStatusSubscription = _fileUploadQueueService.statusStream.listen(
        (status) {
          _handleUploadStatusUpdate(status);
        },
        onError: (error) {
          AppLogger.error('UnifiedAttachmentViewModel: Upload status stream error', error);
        },
      );
    }
  }

  /// Handle upload status updates from FileUploadQueueService
  void _handleUploadStatusUpdate(FileUploadStatus status) {
    AppLogger.debug('UnifiedAttachmentViewModel: Received upload status update: ${status.fileId} - ${status.status}');
    
    switch (status.status) {
      case UploadStatusType.queued:
        // Add to uploading set
        final newUploadingIds = Set<String>.from(state.uploadingFileIds)..add(status.fileId);
        state = state.copyWith(
          uploadingFileIds: newUploadingIds,
          isUploading: newUploadingIds.isNotEmpty,
        );
        break;
        
      case UploadStatusType.uploading:
        // File is being uploaded, ensure it's in the set
        if (!state.uploadingFileIds.contains(status.fileId)) {
          final newUploadingIds = Set<String>.from(state.uploadingFileIds)..add(status.fileId);
          state = state.copyWith(
            uploadingFileIds: newUploadingIds,
            isUploading: newUploadingIds.isNotEmpty,
          );
        }
        break;
        
      case UploadStatusType.success:
        // Remove from uploading set
        final newUploadingIds = Set<String>.from(state.uploadingFileIds)..remove(status.fileId);
        state = state.copyWith(
          uploadingFileIds: newUploadingIds,
          isUploading: newUploadingIds.isNotEmpty,
          successMessage: 'File uploaded successfully: ${status.fileName}',
        );
        break;
        
      case UploadStatusType.failed:
        // Remove from uploading set and show error
        final newUploadingIds = Set<String>.from(state.uploadingFileIds)..remove(status.fileId);
        state = state.copyWith(
          uploadingFileIds: newUploadingIds,
          isUploading: newUploadingIds.isNotEmpty,
          error: 'Upload failed: ${status.fileName} - ${status.error ?? 'Unknown error'}',
        );
        break;
    }
  }

  @override
  void dispose() {
    _uploadStatusSubscription?.cancel();
    super.dispose();
  }

  /// Upload an attachment to a task
  /// MVVM: ViewModel only updates repository, repository handles file operations
  Future<bool> uploadTaskAttachment({
    required String taskUid,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
    required AttachmentType type,
  }) async {
    // Remove the blocking logic - allow multiple uploads
    state = state.copyWith(error: null);

    try {
      AppLogger.info('UnifiedAttachmentViewModel: Starting task attachment upload for $fileName');

      // Get current user for permission check
      final currentUserEmail = await _getCurrentUserEmail();
      if (currentUserEmail == null) {
        state = state.copyWith(error: 'No active account found');
        return false;
      }

      // Get task and check permissions
      final task = await _getTaskWithPermission(taskUid, currentUserEmail);
      if (task == null) {
        state = state.copyWith(error: 'Task not found or permission denied');
        return false;
      }

      // Store file locally via OfflineFileService (handles encryption key generation)
      final offlineFileResult = await _offlineFileService.storeFileLocally(
        taskUid: taskUid,
        aesKey: '', // OfflineFileService will generate AES key if empty
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
        validatorId: null,
      );

      final offlineFile = await offlineFileResult.when(
        success: (file) async => file,
        failure: (failure) async => throw Exception('Failed to store file locally: ${failure.message}'),
      );

      // Queue file for upload (if service is available)
      if (_fileUploadQueueService != null) {
        await _fileUploadQueueService.queueFileUpload(offlineFile.id);
      } else {
        AppLogger.warning('UnifiedAttachmentViewModel: FileUploadQueueService not available, skipping queue');
      }

      // Create attachment object with the actual file ID
      final attachment = type == AttachmentType.media
          ? Attachment.createMedia(
              uri: offlineFile.id,
              filename: fileName,
              size: fileData.length,
              contentType: contentType,
              aesKey: offlineFile.aesKey,
              mediaType: fileName.mediaTypeFromExtension,
              offlineFileId: offlineFile.id,
            )
          : Attachment.createFile(
              uri: offlineFile.id,
              filename: fileName,
              size: fileData.length,
              contentType: contentType,
              aesKey: offlineFile.aesKey,
              offlineFileId: offlineFile.id,
            );

      // Update task with new attachment - repository handles file operations
      final updatedTask = await _addAttachmentToTask(task, attachment);
      if (updatedTask == null) {
        state = state.copyWith(error: 'Failed to update task with attachment');
        return false;
      }

      AppLogger.info('UnifiedAttachmentViewModel: Task attachment upload completed: $fileName');
      return true;
    } catch (e) {
      AppLogger.error('UnifiedAttachmentViewModel: Task attachment upload failed', e);
      state = state.copyWith(error: 'Upload failed: $e');
      return false;
    }
  }

  /// Upload an attachment to a journal
  Future<bool> uploadJournalAttachment({
    required String journalUid,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
    required AttachmentType type,
  }) async {
    // Remove the blocking logic - allow multiple uploads
    state = state.copyWith(error: null);

    try {
      AppLogger.info('UnifiedAttachmentViewModel: Starting journal attachment upload for $fileName');

      // Get current user for permission check
      final currentUserEmail = await _getCurrentUserEmail();
      if (currentUserEmail == null) {
        state = state.copyWith(error: 'No active account found');
        return false;
      }

      // Get journal and check permissions
      final journal = await _getJournalWithPermission(journalUid, currentUserEmail);
      if (journal == null) {
        state = state.copyWith(error: 'Journal not found or permission denied');
        return false;
      }

      // Store file locally via OfflineFileService (handles encryption key generation)
      final offlineFileResult = await _offlineFileService.storeFileLocally(
        taskUid: journalUid,
        aesKey: '', // OfflineFileService will generate AES key if empty
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
        validatorId: null,
      );

      final offlineFile = await offlineFileResult.when(
        success: (file) async => file,
        failure: (failure) async => throw Exception('Failed to store file locally: ${failure.message}'),
      );

      // Queue file for upload (if service is available)
      if (_fileUploadQueueService != null) {
        await _fileUploadQueueService.queueFileUpload(offlineFile.id);
      } else {
        AppLogger.warning('UnifiedAttachmentViewModel: FileUploadQueueService not available, skipping queue');
      }

      // Now create attachment object with the correct file ID
      final attachment = type == AttachmentType.media
          ? Attachment.createMedia(
              uri: offlineFile.id, // Use the actual file ID
              filename: fileName,
              size: fileData.length,
              contentType: contentType,
              aesKey: offlineFile.aesKey,
              mediaType: fileName.mediaTypeFromExtension,
              offlineFileId: offlineFile.id, // Set the offline file ID
            )
          : Attachment.createFile(
              uri: offlineFile.id, // Use the actual file ID
              filename: fileName,
              size: fileData.length,
              contentType: contentType,
              aesKey: offlineFile.aesKey,
              offlineFileId: offlineFile.id, // Set the offline file ID
            );

      // Update journal with new attachment metadata
      final updatedJournal = await _addAttachmentToJournal(journal, attachment);
      if (updatedJournal == null) {
        state = state.copyWith(error: 'Failed to update journal with attachment');
        return false;
      }

      AppLogger.info('UnifiedAttachmentViewModel: Journal attachment upload process completed: $fileName (${type == AttachmentType.media ? 'media' : 'file'})');
      return true;
    } catch (e) {
      AppLogger.error('UnifiedAttachmentViewModel: Journal attachment upload failed', e);
      state = state.copyWith(error: 'Upload failed: $e');
      return false;
    }
  }

  /// Download attachment bytes (offline-first)
  /// MVVM: ViewModel delegates to OfflineFileService for file operations
  Future<Uint8List?> downloadAttachment({
    required String fileId,
    required String aesKey,
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
      AppLogger.info('UnifiedAttachmentViewModel: Starting attachment download: $fileId');

      // Try to get file from offline storage first (offline-first)
      final offlineFileResult = await _offlineFileService.getOfflineFile(fileId);

      final result = await offlineFileResult.when(
        success: (offlineFile) async {
          if (offlineFile != null) {
            AppLogger.info('UnifiedAttachmentViewModel: Found file in offline storage');

            // Read file data from local path
            final fileDataResult = await _offlineFileService.readLocalFile(fileId);
            return await fileDataResult.when(
              success: (fileData) async => fileData,
              failure: (_) async => throw Exception('Failed to read local file'),
            );
          } else {
            // File not found offline, try S3 if we have s3Key
            if (s3Key != null) {
              AppLogger.info('UnifiedAttachmentViewModel: File not found offline, trying S3');
              return await _downloadFromS3(s3Key, aesKey);
            } else {
              throw Exception('File not available locally or on server');
            }
          }
        },
        failure: (failure) async {
          throw Exception('Failed to access offline file: ${failure.message}');
        },
      );

      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        successMessage: 'File downloaded successfully',
      );
      return result;
    } catch (e) {
      AppLogger.error('UnifiedAttachmentViewModel: Download failed', e);
      state = state.copyWith(
        isDownloading: false,
        downloadingFileId: null,
        error: 'Download failed: $e',
      );
      return null;
    }
  }

  /// Remove attachment from task
  Future<bool> removeTaskAttachment({
    required String taskUid,
    required String fileId,
  }) async {
    try {
      AppLogger.info('UnifiedAttachmentViewModel: Removing task attachment: $fileId');

      // Get task
      final taskResult = await _taskRepository.getById(taskUid);
      final task = await taskResult.when(
        success: (task) async => task,
        failure: (failure) async => throw Exception('Failed to get task: ${failure.message}'),
      );

      if (task == null) {
        state = state.copyWith(error: 'Task not found');
        return false;
      }

      // Remove attachment from task first
      final updatedTask = await _removeAttachmentFromTask(task, fileId);
      if (updatedTask == null) {
        state = state.copyWith(error: 'Failed to remove attachment from task');
        return false;
      }

      // Clean up local file via offline service
      final deleteResult = await _offlineFileService.deleteOfflineFile(fileId);
      await deleteResult.when(
        success: (_) async {},
        failure: (failure) async => AppLogger.warning('Failed to delete offline file: ${failure.message}'),
      );

      AppLogger.info('UnifiedAttachmentViewModel: Task attachment removed successfully: $fileId');
      state = state.copyWith(successMessage: 'Attachment removed successfully');
      return true;
    } catch (e) {
      AppLogger.error('UnifiedAttachmentViewModel: Remove task attachment failed', e);
      state = state.copyWith(error: 'Remove failed: $e');
      return false;
    }
  }

  /// Remove attachment from journal
  Future<bool> removeJournalAttachment({
    required String journalUid,
    required String fileId,
  }) async {
    try {
      AppLogger.info('UnifiedAttachmentViewModel: Removing journal attachment: $fileId');

      // Get journal
      final journalResult = await _journalRepository.getById(journalUid);
      final journal = await journalResult.when(
        success: (journal) async => journal,
        failure: (failure) async => throw Exception('Failed to get journal: ${failure.message}'),
      );

      if (journal == null) {
        state = state.copyWith(error: 'Journal not found');
        return false;
      }

      // Remove attachment from journal first
      final updatedJournal = await _removeAttachmentFromJournal(journal, fileId);
      if (updatedJournal == null) {
        state = state.copyWith(error: 'Failed to remove attachment from journal');
        return false;
      }

      // Clean up local file via offline service
      final deleteResult = await _offlineFileService.deleteOfflineFile(fileId);
      await deleteResult.when(
        success: (_) async {},
        failure: (failure) async => AppLogger.warning('Failed to delete offline file: ${failure.message}'),
      );

      AppLogger.info('UnifiedAttachmentViewModel: Journal attachment removed successfully: $fileId');
      state = state.copyWith(successMessage: 'Attachment removed successfully');
      return true;
    } catch (e) {
      AppLogger.error('UnifiedAttachmentViewModel: Remove journal attachment failed', e);
      state = state.copyWith(error: 'Remove failed: $e');
      return false;
    }
  }

  /// Download file from S3 (fallback when local file not available)
  Future<Uint8List> _downloadFromS3(String s3Key, String aesKey) async {
    // Get account for S3 service
    final accountResult = await _accountRepository.getActiveAccount();
    final account = await accountResult.when(
      success: (acc) async => acc!,
      failure: (_) async => throw Exception('No active account found'),
    );

    // Create S3 service and download file
    final s3Service = S3StorageService(account: account);
    
    // Download from S3 with decryption
    final downloadResult = await s3Service.downloadFile(
      key: s3Key,
      isPrivate: false, // Use shared bucket
      symmetricKey: aesKey, // Use attachment's encryption key
    );

    return await downloadResult.when(
      success: (data) async {
        AppLogger.info('UnifiedAttachmentViewModel: Successfully downloaded file from S3, size: ${data.length} bytes');
        return data;
      },
      failure: (failure) async {
        throw Exception('S3 download failed: ${failure.message}');
      },
    );
  }

  /// Parse attachments from JSON string
  List<Attachment> parseAttachments(String attachmentsJson) {
    return AttachmentParser.parseAttachmentsFromJson(attachmentsJson);
  }

  /// Serialize attachments to JSON string
  String serializeAttachments(List<Attachment> attachments) {
    return AttachmentParser.serializeAttachmentsToJson(attachments);
  }

  /// Clear error and success messages
  void clearMessages() {
    state = state.clearMessages();
  }

  // Private helper methods

  Future<String?> _getCurrentUserEmail() async {
    final accountResult = await _accountRepository.getActiveAccount();
    return accountResult.when(
      success: (account) => account?.email ?? account?.username,
      failure: (_) => null,
    );
  }

  Future<dynamic> _getTaskWithPermission(String taskUid, String currentUserEmail) async {
    final taskResult = await _taskRepository.getById(taskUid);
    return taskResult.when(
      success: (task) {
        if (task == null) return null;

        // For attachments, allow if user is organizer or attendee
        if (task.organizer != currentUserEmail &&
            !task.attendees.any((a) => a.email == currentUserEmail)) {
          return null;
        }

        return task;
      },
      failure: (_) => null,
    );
  }

  Future<dynamic> _getJournalWithPermission(String journalUid, String currentUserEmail) async {
    final journalResult = await _journalRepository.getById(journalUid);
    return journalResult.when(
      success: (journal) {
        if (journal == null) return null;

        // For attachments, allow if user is organizer or attendee
        if (journal.organizer != currentUserEmail &&
            !journal.attendees.any((a) => a.email == currentUserEmail)) {
          return null;
        }

        return journal;
      },
      failure: (_) => null,
    );
  }

  Future<dynamic> _addAttachmentToTask(dynamic task, Attachment attachment) async {
    final attachments = parseAttachments(task.attachments);
    attachments.add(attachment);

    final updatedTask = task.copyWith(
      attachments: serializeAttachments(attachments),
      lastModified: DateTime.now(),
    );

    final saveResult = await _taskRepository.save(updatedTask);
    return saveResult.when(
      success: (_) => updatedTask,
      failure: (_) => null,
    );
  }

  Future<dynamic> _addAttachmentToJournal(dynamic journal, Attachment attachment) async {
    final attachments = parseAttachments(journal.attachments);
    attachments.add(attachment);

    final updatedJournal = journal.copyWith(
      attachments: serializeAttachments(attachments),
      lastModified: DateTime.now(),
    );

    final saveResult = await _journalRepository.save(updatedJournal);
    return saveResult.when(
      success: (_) => updatedJournal,
      failure: (_) => null,
    );
  }

  Future<dynamic> _removeAttachmentFromTask(dynamic task, String fileId) async {
    final attachments = parseAttachments(task.attachments);
    attachments.removeWhere((attachment) => attachment.uri == fileId);

    final updatedTask = task.copyWith(
      attachments: serializeAttachments(attachments),
      lastModified: DateTime.now(),
    );

    final saveResult = await _taskRepository.save(updatedTask);
    return saveResult.when(
      success: (_) => updatedTask,
      failure: (_) => null,
    );
  }

  Future<dynamic> _removeAttachmentFromJournal(dynamic journal, String fileId) async {
    final attachments = parseAttachments(journal.attachments);
    attachments.removeWhere((attachment) => attachment.uri == fileId);

    final updatedJournal = journal.copyWith(
      attachments: serializeAttachments(attachments),
      lastModified: DateTime.now(),
    );

    final saveResult = await _journalRepository.save(updatedJournal);
    return saveResult.when(
      success: (_) => updatedJournal,
      failure: (_) => null,
    );
  }


}
