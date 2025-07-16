// File Upload Queue Service for managing offline file uploads
// Handles queuing, retry logic, and automatic upload when connection is available

import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/offline_file.dart';
import '../repositories/account_repository.dart';
import '../repositories/task_repository.dart';
import 'local_storage_service.dart';
import 'offline_file_service.dart';
import 's3_storage_service.dart';
import 'connection_monitor_service.dart';
import 'sync_service.dart';
import 'validator_service.dart';

/// Upload status types
enum UploadStatusType {
  queued,
  uploading,
  success,
  failed,
}

/// Upload status for UI updates
class FileUploadStatus {
  final String fileId;
  final String fileName;
  final UploadStatusType status;
  final String? error;
  final double? progress;

  const FileUploadStatus({
    required this.fileId,
    required this.fileName,
    required this.status,
    this.error,
    this.progress,
  });
}

/// Service for managing file upload queue and automatic uploads
class FileUploadQueueService {
  final LocalStorageService _localStorage;
  final OfflineFileService _offlineFileService;
  final AccountRepository _accountRepository;
  final ConnectionMonitorService _connectionMonitorService;
  final TaskRepository _taskRepository;
  final SyncService _syncService;

  // Queue processing
  Timer? _queueTimer;
  bool _isProcessingQueue = false;
  
  // Configuration
  static const Duration _queueProcessingInterval = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(minutes: 5);
  static const int _maxRetryCount = 3;
  
  // Status updates
  final _statusController = StreamController<FileUploadStatus>.broadcast();
  
  FileUploadQueueService({
    required LocalStorageService localStorage,
    required OfflineFileService offlineFileService,
    required AccountRepository accountRepository,
    required ConnectionMonitorService connectionMonitorService,
    required TaskRepository taskRepository,
    required SyncService syncService,
  })  : _localStorage = localStorage,
        _offlineFileService = offlineFileService,
        _accountRepository = accountRepository,
        _connectionMonitorService = connectionMonitorService,
        _taskRepository = taskRepository,
        _syncService = syncService;

  /// Stream for upload status updates
  Stream<FileUploadStatus> get statusStream => _statusController.stream;

  /// Add file to upload queue
  Future<Result<void>> queueFileUpload(String offlineFileId) async {
    try {
      AppLogger.debug('FileUploadQueueService: Queuing file upload: $offlineFileId');
      
      // Check if file is already in queue
      final existingResult = await _localStorage.get<FileUploadQueueItem>(
        LocalStorageService.fileUploadQueueBoxName,
        offlineFileId,
      );
      
      final alreadyQueued = await existingResult.when(
        success: (item) async => item != null,
        failure: (_) async => false,
      );
      
      if (alreadyQueued) {
        AppLogger.debug('FileUploadQueueService: File already in queue: $offlineFileId');
        return const Result.success(null);
      }
      
      // Create queue item
      const uuid = Uuid();
      final queueItem = FileUploadQueueItem(
        id: uuid.v4(),
        offlineFileId: offlineFileId,
        queuedAt: DateTime.now(),
      );
      
      // Add to queue
      final result = await _localStorage.put(
        LocalStorageService.fileUploadQueueBoxName,
        offlineFileId,
        queueItem,
      );
      
      return await result.when(
        success: (_) async {
          AppLogger.info('FileUploadQueueService: File queued for upload: $offlineFileId');
          
          // Trigger immediate processing attempt
          _triggerQueueProcessing();
          
          return const Result.success(null);
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Failed to queue file upload', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue file upload: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Remove file from upload queue
  Future<Result<void>> removeFromQueue(String offlineFileId) async {
    try {
      final result = await _localStorage.delete(
        LocalStorageService.fileUploadQueueBoxName,
        offlineFileId,
      );
      
      return await result.when(
        success: (_) async {
          AppLogger.debug('FileUploadQueueService: Removed from queue: $offlineFileId');
          return const Result.success(null);
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Failed to remove from queue', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to remove from queue: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Start automatic queue processing
  void startQueueProcessing() {
    if (_queueTimer != null) {
      return; // Already started
    }
    
    AppLogger.info('FileUploadQueueService: Starting automatic queue processing');
    
    // Process immediately
    _triggerQueueProcessing();
    
    // Set up periodic processing
    _queueTimer = Timer.periodic(_queueProcessingInterval, (_) {
      _triggerQueueProcessing();
    });
  }

  /// Stop automatic queue processing
  void stopQueueProcessing() {
    _queueTimer?.cancel();
    _queueTimer = null;
    AppLogger.info('FileUploadQueueService: Stopped automatic queue processing');
  }

  /// Trigger immediate queue processing
  void _triggerQueueProcessing() {
    if (_isProcessingQueue) {
      return; // Already processing
    }
    
    // Process queue asynchronously
    _processQueue().catchError((error) {
      AppLogger.error('FileUploadQueueService: Queue processing failed', error);
    });
  }

  /// Process the upload queue
  Future<void> _processQueue() async {
    if (_isProcessingQueue) {
      AppLogger.debug('FileUploadQueueService: Already processing queue, skipping');
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      AppLogger.debug('FileUploadQueueService: Processing upload queue');
      
      // Get all queue items
      final queueResult = await _localStorage.getAll<FileUploadQueueItem>(
        LocalStorageService.fileUploadQueueBoxName,
      );
      
      await queueResult.when(
        success: (queueItems) async {
          AppLogger.debug('FileUploadQueueService: Found ${queueItems.length} items in queue');
          
          if (queueItems.isEmpty) {
            AppLogger.debug('FileUploadQueueService: No items in upload queue');
            return;
          }
          
          AppLogger.info('FileUploadQueueService: Processing ${queueItems.length} items in upload queue');
          
          // Check connection status before processing
          final connectionStatus = _connectionMonitorService.currentStatus;
          AppLogger.debug('FileUploadQueueService: Current connection status: $connectionStatus');
          
          if (connectionStatus != ConnectionStatus.connected) {
            AppLogger.debug('FileUploadQueueService: Not connected to internet, skipping upload processing');
            return;
          }
          
          // Process each item
          for (final queueItem in queueItems) {
            AppLogger.debug('FileUploadQueueService: Processing queue item: ${queueItem.offlineFileId}');
            
            if (queueItem.isProcessing) {
              AppLogger.debug('FileUploadQueueService: Item ${queueItem.offlineFileId} is already being processed');
              continue; // Skip items already being processed
            }
            
            // Check if we should retry this item
            if (queueItem.retryCount >= _maxRetryCount) {
              AppLogger.warning('FileUploadQueueService: Max retry count reached for ${queueItem.offlineFileId}');
              await removeFromQueue(queueItem.offlineFileId);
              continue;
            }
            
            // Check retry delay
            if (queueItem.lastAttemptAt != null) {
              final timeSinceLastAttempt = DateTime.now().difference(queueItem.lastAttemptAt!);
              if (timeSinceLastAttempt < _retryDelay) {
                AppLogger.debug('FileUploadQueueService: Waiting for retry delay for ${queueItem.offlineFileId}');
                continue; // Wait before retrying
              }
            }
            
            // Process this item
            AppLogger.debug('FileUploadQueueService: Starting to process item: ${queueItem.offlineFileId}');
            await _processQueueItem(queueItem);
          }
        },
        failure: (failure) async {
          AppLogger.error('FileUploadQueueService: Failed to get queue items: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Queue processing failed', e, stackTrace);
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Process a single queue item
  Future<void> _processQueueItem(FileUploadQueueItem queueItem) async {
    try {
      AppLogger.debug('FileUploadQueueService: Processing queue item: ${queueItem.offlineFileId}');
      
      // Mark as processing
      final processingItem = queueItem.copyWith(
        isProcessing: true,
        lastAttemptAt: DateTime.now(),
      );
      
      await _localStorage.put(
        LocalStorageService.fileUploadQueueBoxName,
        queueItem.offlineFileId,
        processingItem,
      );
      
      // Get offline file
      final fileResult = await _offlineFileService.getOfflineFile(queueItem.offlineFileId);
      
      await fileResult.when(
        success: (offlineFile) async {
          if (offlineFile == null) {
            AppLogger.warning('FileUploadQueueService: Offline file not found: ${queueItem.offlineFileId}');
            await removeFromQueue(queueItem.offlineFileId);
            return;
          }
          
          // Skip if already uploaded
          if (offlineFile.status == OfflineFileStatus.uploaded) {
            AppLogger.debug('FileUploadQueueService: File already uploaded: ${queueItem.offlineFileId}');
            await removeFromQueue(queueItem.offlineFileId);
            return;
          }
          
          // Update status to uploading
          await _offlineFileService.updateFileStatus(
            offlineFile.id,
            OfflineFileStatus.uploading,
          );
          
          // Attempt upload
          final uploadResult = await _uploadFile(offlineFile);
          
          await uploadResult.when(
            success: (s3Info) async {
              // Upload successful
              await _offlineFileService.updateFileStatus(
                offlineFile.id,
                OfflineFileStatus.uploaded,
                s3Key: s3Info['s3Key'],
                s3Url: s3Info['s3Url'],
              );
              
              // Update task validator with S3 info
              await _updateTaskValidatorWithS3Info(offlineFile, s3Info);
              
              // Remove from queue
              await removeFromQueue(queueItem.offlineFileId);
              
              // Notify success
              _statusController.add(FileUploadStatus(
                fileId: offlineFile.id,
                fileName: offlineFile.fileName,
                status: UploadStatusType.success,
              ));
              
              AppLogger.info('FileUploadQueueService: Successfully uploaded: ${offlineFile.fileName}');
            },
            failure: (failure) async {
              // Upload failed
              await _offlineFileService.updateFileStatus(
                offlineFile.id,
                OfflineFileStatus.failed,
                errorMessage: failure.message,
              );
              
              // Update queue item with retry info
              final retryItem = queueItem.copyWith(
                isProcessing: false,
                retryCount: queueItem.retryCount + 1,
                lastError: failure.message,
              );
              
              await _localStorage.put(
                LocalStorageService.fileUploadQueueBoxName,
                queueItem.offlineFileId,
                retryItem,
              );
              
              // Notify failure
              _statusController.add(FileUploadStatus(
                fileId: offlineFile.id,
                fileName: offlineFile.fileName,
                status: UploadStatusType.failed,
                error: failure.message,
              ));
              
              AppLogger.warning('FileUploadQueueService: Upload failed: ${offlineFile.fileName} - ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('FileUploadQueueService: Failed to get offline file: ${failure.message}');
          await removeFromQueue(queueItem.offlineFileId);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Failed to process queue item', e, stackTrace);
      
      // Mark as not processing
      final failedItem = queueItem.copyWith(
        isProcessing: false,
        retryCount: queueItem.retryCount + 1,
        lastError: e.toString(),
      );
      
      await _localStorage.put(
        LocalStorageService.fileUploadQueueBoxName,
        queueItem.offlineFileId,
        failedItem,
      );
    }
  }

  /// Upload a file to S3
  Future<Result<Map<String, String>>> _uploadFile(OfflineFile offlineFile) async {
    try {
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
      
      // Get task to extract encryption key from validator
      final taskResult = await _taskRepository.getById(offlineFile.taskUid);
      final task = await taskResult.when(
        success: (task) async {
          if (task == null) {
            throw Exception('Task not found: ${offlineFile.taskUid}');
          }
          return task;
        },
        failure: (failure) async => throw Exception('Failed to get task: ${failure.message}'),
      );
      
      // Extract encryption key from validator
      final validators = ValidatorService.parseValidators(task.flowitValidator);
      String? encryptionKey;
      
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator['id'] == offlineFile.validatorId && 
              (validator['type'] == 'file' || validator['type'] == 'media')) {
            encryptionKey = validator['encryptionKey'] as String?;
            break;
          }
        }
        if (encryptionKey != null) break;
      }
      
      if (encryptionKey == null) {
        throw Exception('Encryption key not found for validator ${offlineFile.validatorId}');
      }
      
      // Read file data
      final fileDataResult = await _offlineFileService.readLocalFile(offlineFile.id);
      final fileData = await fileDataResult.when(
        success: (data) async => data,
        failure: (failure) async => throw Exception('Failed to read file: ${failure.message}'),
      );
      
      // Create S3 service
      final s3Service = S3StorageService(account: account);
      
      // Generate S3 key
      final userPrefix = s3Service.getUserPrefix();
      final sanitizedFileName = _sanitizeFileName(offlineFile.fileName);
      final s3Key = '$userPrefix${offlineFile.taskUid}/$sanitizedFileName';
      
      // Upload to S3 with encryption
      final uploadResult = await s3Service.uploadFile(
        key: s3Key,
        data: fileData,
        isPrivate: false, // Use shared bucket
        symmetricKey: encryptionKey, // Use validator's encryption key
        contentType: offlineFile.contentType,
      );
      
      return await uploadResult.when(
        success: (s3Url) async {
          return Result.success({
            's3Key': s3Key,
            's3Url': s3Url,
          });
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: File upload failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'File upload failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update task validator with S3 info
  Future<void> _updateTaskValidatorWithS3Info(OfflineFile offlineFile, Map<String, String> s3Info) async {
    try {
      AppLogger.info('FileUploadQueueService: Updating task validator with S3 info for ${offlineFile.taskUid}');
      AppLogger.debug('FileUploadQueueService: OfflineFile ID: ${offlineFile.id}, ValidatorId: ${offlineFile.validatorId}');
      AppLogger.debug('FileUploadQueueService: S3 Info: $s3Info');
      
      // Get the task from repository
      final taskResult = await _taskRepository.getById(offlineFile.taskUid);
      await taskResult.when(
        success: (task) async {
          if (task == null) {
            AppLogger.error('FileUploadQueueService: Task not found: ${offlineFile.taskUid}');
            return;
          }
          
          AppLogger.debug('FileUploadQueueService: Found task: ${task.uid}');
          AppLogger.debug('FileUploadQueueService: Current validator data: ${task.flowitValidator}');
          
          // Parse current validators
          final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
          AppLogger.debug('FileUploadQueueService: Parsed validators: $validatorLists');
          
          // Update the file validator with S3 info
          final updateData = {
            'type': 'update_file_s3',
            'offlineFileId': offlineFile.id,
            's3Key': s3Info['s3Key'],
            's3Url': s3Info['s3Url'],
            'status': 'uploaded',
          };
          AppLogger.debug('FileUploadQueueService: Update data: $updateData');
          
          final updatedValidatorLists = ValidatorService.updateValidatorState(
            validatorLists,
            offlineFile.validatorId,
            updateData,
          );
          AppLogger.debug('FileUploadQueueService: Updated validators: $updatedValidatorLists');
          
          // Update task with new validator data
          final newValidatorString = ValidatorService.serializeValidators(updatedValidatorLists);
          AppLogger.debug('FileUploadQueueService: New validator string: $newValidatorString');
          
          final updatedTask = task.copyWith(
            flowitValidator: newValidatorString,
            lastModified: DateTime.now(),
          );
          
          AppLogger.debug('FileUploadQueueService: Saving updated task...');
          
          // Save updated task
          final saveResult = await _taskRepository.save(updatedTask);
          await saveResult.when(
            success: (_) async {
              AppLogger.info('FileUploadQueueService: Task validator updated with S3 info for ${offlineFile.taskUid}');
              
              // Queue sync operation to push changes to server
              AppLogger.debug('FileUploadQueueService: Queuing sync operation...');
              await _syncService.queueSyncOperation(
                SyncOperation.update,
                offlineFile.taskUid,
                {
                  'taskUid': offlineFile.taskUid,
                  'calendarUid': task.projectPath,
                },
              );
              
              AppLogger.info('FileUploadQueueService: Sync operation queued for ${offlineFile.taskUid}');
            },
            failure: (failure) async {
              AppLogger.error('FileUploadQueueService: Failed to save updated task: ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('FileUploadQueueService: Failed to get task ${offlineFile.taskUid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Failed to update task validator with S3 info', e, stackTrace);
    }
  }

  /// Get queue status
  Future<Result<Map<String, dynamic>>> getQueueStatus() async {
    try {
      final queueResult = await _localStorage.getAll<FileUploadQueueItem>(
        LocalStorageService.fileUploadQueueBoxName,
      );
      
      return await queueResult.when(
        success: (queueItems) async {
          int totalItems = queueItems.length;
          int processingItems = queueItems.where((item) => item.isProcessing).length;
          int failedItems = queueItems.where((item) => item.retryCount >= _maxRetryCount).length;
          
          return Result.success({
            'totalItems': totalItems,
            'processingItems': processingItems,
            'failedItems': failedItems,
            'isProcessing': _isProcessingQueue,
          });
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Failed to get queue status', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get queue status: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Clean up the queue by removing completed and failed items
  Future<Result<void>> cleanupQueue() async {
    try {
      final queueResult = await _localStorage.getAll<FileUploadQueueItem>(
        LocalStorageService.fileUploadQueueBoxName,
      );
      
      return await queueResult.when(
        success: (queueItems) async {
          int cleanedCount = 0;
          
          for (final queueItem in queueItems) {
            // Remove items that exceeded retry limit
            if (queueItem.retryCount >= _maxRetryCount) {
              await removeFromQueue(queueItem.offlineFileId);
              cleanedCount++;
            }
          }
          
          if (cleanedCount > 0) {
            AppLogger.info('FileUploadQueueService: Cleaned up $cleanedCount failed queue items');
          }
          
          return const Result.success(null);
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FileUploadQueueService: Failed to cleanup queue', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to cleanup queue: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Sanitize filename for S3 storage
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[\u2000-\u206F\u2E00-\u2E7F\u3000]'), '-')
        .replaceAll(RegExp(r'[-\s]+'), '-')
        .trim()
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Dispose resources
  void dispose() {
    stopQueueProcessing();
    _statusController.close();
  }
} 