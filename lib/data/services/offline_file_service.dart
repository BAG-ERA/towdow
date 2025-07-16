// Offline file service for managing local file storage and upload queue
// Implements offline-first architecture with automatic sync when connection is available

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/offline_file.dart';
import '../models/caldav_account.dart';
import 'local_storage_service.dart';
import 's3_storage_service.dart';
import '../../core/result.dart';
import '../../core/logger.dart';

/// Service for managing offline files and upload queue
class OfflineFileService {
  final LocalStorageService _localStorage;
  static const String _fileDirectoryName = 'offline_files';
  static const int _maxRetryCount = 3;
  
  OfflineFileService(this._localStorage);

  /// Store a file locally for offline access
  Future<Result<OfflineFile>> storeFileLocally({
    required String taskUid,
    required String validatorId,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    try {
      AppLogger.debug('OfflineFileService: Storing file locally: $fileName');
      
      // Create unique file ID
      const uuid = Uuid();
      final fileId = uuid.v4();
      
      // Get app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final offlineFilesDir = Directory('${appDocDir.path}/$_fileDirectoryName');
      
      // Create directory if it doesn't exist
      if (!await offlineFilesDir.exists()) {
        await offlineFilesDir.create(recursive: true);
      }
      
      // Create local file path with unique name to avoid conflicts
      final sanitizedFileName = _sanitizeFileName(fileName);
      final localPath = '${offlineFilesDir.path}/${fileId}_$sanitizedFileName';
      
      // Write file to local storage
      final localFile = File(localPath);
      await localFile.writeAsBytes(fileData);
      
      // Create offline file metadata
      final offlineFile = OfflineFile(
        id: fileId,
        taskUid: taskUid,
        validatorId: validatorId,
        fileName: fileName,
        localPath: localPath,
        fileSize: fileData.length,
        contentType: contentType,
        createdAt: DateTime.now(),
        status: OfflineFileStatus.local,
      );
      
      // Store metadata in Hive
      final result = await _localStorage.put(
        LocalStorageService.offlineFilesBoxName,
        fileId,
        offlineFile,
      );
      
      return await result.when(
        success: (_) async {
          AppLogger.info('OfflineFileService: File stored locally: $fileName (${fileData.length} bytes)');
          return Result.success(offlineFile);
        },
        failure: (failure) async {
          // Clean up local file if metadata storage failed
          try {
            await localFile.delete();
          } catch (e) {
            AppLogger.warning('OfflineFileService: Failed to clean up local file: $e');
          }
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('OfflineFileService: Failed to store file locally', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to store file locally: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get offline file by ID
  Future<Result<OfflineFile?>> getOfflineFile(String fileId) async {
    return await _localStorage.get<OfflineFile>(
      LocalStorageService.offlineFilesBoxName,
      fileId,
    );
  }

  /// Get all offline files for a task
  Future<Result<List<OfflineFile>>> getOfflineFilesForTask(String taskUid) async {
    final result = await _localStorage.getAll<OfflineFile>(
      LocalStorageService.offlineFilesBoxName,
    );
    
    return result.when(
      success: (files) {
        final taskFiles = files.where((file) => file.taskUid == taskUid).toList();
        return Result.success(taskFiles);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Get all offline files for a specific validator
  Future<Result<List<OfflineFile>>> getOfflineFilesForValidator(String taskUid, String validatorId) async {
    final result = await getOfflineFilesForTask(taskUid);
    return result.when(
      success: (files) {
        final validatorFiles = files.where((file) => file.validatorId == validatorId).toList();
        return Result.success(validatorFiles);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Read file data from local storage
  Future<Result<Uint8List>> readLocalFile(String fileId) async {
    try {
      final fileResult = await getOfflineFile(fileId);
      return await fileResult.when(
        success: (offlineFile) async {
          if (offlineFile == null) {
            return Result.failure(Failure(message: 'File not found'));
          }
          
          final localFile = File(offlineFile.localPath);
          if (!await localFile.exists()) {
            return Result.failure(Failure(message: 'Local file no longer exists'));
          }
          
          final fileData = await localFile.readAsBytes();
          return Result.success(fileData);
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('OfflineFileService: Failed to read local file', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to read local file: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Delete offline file and its local storage
  Future<Result<void>> deleteOfflineFile(String fileId) async {
    try {
      final fileResult = await getOfflineFile(fileId);
      return await fileResult.when(
        success: (offlineFile) async {
          if (offlineFile == null) {
            return const Result.success(null);
          }
          
          // Delete local file
          try {
            final localFile = File(offlineFile.localPath);
            if (await localFile.exists()) {
              await localFile.delete();
            }
          } catch (e) {
            AppLogger.warning('OfflineFileService: Failed to delete local file: $e');
          }
          
          // Delete metadata from Hive
          final deleteResult = await _localStorage.delete(
            LocalStorageService.offlineFilesBoxName,
            fileId,
          );
          
          return await deleteResult.when(
            success: (_) async {
              AppLogger.info('OfflineFileService: Deleted offline file: ${offlineFile.fileName}');
              return const Result.success(null);
            },
            failure: (failure) async => Result.failure(failure),
          );
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('OfflineFileService: Failed to delete offline file', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete offline file: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update offline file status
  Future<Result<void>> updateFileStatus(String fileId, OfflineFileStatus status, {
    String? s3Key,
    String? s3Url,
    String? errorMessage,
  }) async {
    try {
      final fileResult = await getOfflineFile(fileId);
      return await fileResult.when(
        success: (offlineFile) async {
          if (offlineFile == null) {
            return Result.failure(Failure(message: 'File not found'));
          }
          
          final updatedFile = offlineFile.copyWith(
            status: status,
            s3Key: s3Key ?? offlineFile.s3Key,
            s3Url: s3Url ?? offlineFile.s3Url,
            errorMessage: errorMessage,
            uploadedAt: status == OfflineFileStatus.uploaded ? DateTime.now() : offlineFile.uploadedAt,
            retryCount: status == OfflineFileStatus.failed ? offlineFile.retryCount + 1 : offlineFile.retryCount,
            lastRetryAt: status == OfflineFileStatus.failed ? DateTime.now() : offlineFile.lastRetryAt,
          );
          
          return await _localStorage.put(
            LocalStorageService.offlineFilesBoxName,
            fileId,
            updatedFile,
          );
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('OfflineFileService: Failed to update file status', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to update file status: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get files pending upload
  Future<Result<List<OfflineFile>>> getFilesPendingUpload() async {
    final result = await _localStorage.getAll<OfflineFile>(
      LocalStorageService.offlineFilesBoxName,
    );
    
    return result.when(
      success: (files) {
        final pendingFiles = files.where((file) => 
          file.status == OfflineFileStatus.local || 
          (file.status == OfflineFileStatus.failed && file.retryCount < _maxRetryCount)
        ).toList();
        return Result.success(pendingFiles);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  /// Clean up old failed files that exceeded retry limit
  Future<Result<void>> cleanupFailedFiles() async {
    try {
      final result = await _localStorage.getAll<OfflineFile>(
        LocalStorageService.offlineFilesBoxName,
      );
      
      return await result.when(
        success: (files) async {
          final failedFiles = files.where((file) => 
            file.status == OfflineFileStatus.failed && 
            file.retryCount >= _maxRetryCount
          ).toList();
          
          for (final file in failedFiles) {
            await deleteOfflineFile(file.id);
          }
          
          if (failedFiles.isNotEmpty) {
            AppLogger.info('OfflineFileService: Cleaned up ${failedFiles.length} failed files');
          }
          
          return const Result.success(null);
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('OfflineFileService: Failed to cleanup failed files', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to cleanup failed files: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get storage usage statistics
  Future<Result<Map<String, dynamic>>> getStorageStats() async {
    try {
      final result = await _localStorage.getAll<OfflineFile>(
        LocalStorageService.offlineFilesBoxName,
      );
      
      return await result.when(
        success: (files) async {
          int totalFiles = files.length;
          int totalSize = 0;
          int localFiles = 0;
          int uploadedFiles = 0;
          int failedFiles = 0;
          
          for (final file in files) {
            totalSize += file.fileSize;
            switch (file.status) {
              case OfflineFileStatus.local:
                localFiles++;
                break;
              case OfflineFileStatus.uploaded:
                uploadedFiles++;
                break;
              case OfflineFileStatus.failed:
                failedFiles++;
                break;
              case OfflineFileStatus.uploading:
                // Count as local for now
                localFiles++;
                break;
            }
          }
          
          return Result.success({
            'totalFiles': totalFiles,
            'totalSize': totalSize,
            'localFiles': localFiles,
            'uploadedFiles': uploadedFiles,
            'failedFiles': failedFiles,
          });
        },
        failure: (failure) => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('OfflineFileService: Failed to get storage stats', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get storage stats: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Sanitize filename to avoid filesystem issues
  String _sanitizeFileName(String fileName) {
    // Replace problematic characters for filesystem
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'[\u0000-\u001F]'), '_')
        .replaceAll(RegExp(r'\.+$'), '')
        .trim();
  }
} 