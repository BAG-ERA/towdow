// Journal File Attachment ViewModel for managing journal-level file attachments
// Mirrors TaskFileAttachmentViewModel but operates on Journal via JournalRepository

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/storage/offline_file_service.dart';
import '../../data/services/storage/file_upload_queue_service.dart';
import '../../data/services/storage/s3_storage_service.dart';
import '../../core/logger.dart';

class JournalFileAttachmentState {
  final bool isUploading;
  final bool isDownloading;
  final String? downloadingFileId;
  final String? error;
  final String? successMessage;

  const JournalFileAttachmentState({
    this.isUploading = false,
    this.isDownloading = false,
    this.downloadingFileId,
    this.error,
    this.successMessage,
  });

  JournalFileAttachmentState copyWith({
    bool? isUploading,
    bool? isDownloading,
    String? downloadingFileId,
    String? error,
    String? successMessage,
  }) {
    return JournalFileAttachmentState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingFileId: downloadingFileId ?? this.downloadingFileId,
      error: error,
      successMessage: successMessage,
    );
  }
}

class JournalFileAttachmentViewModel extends StateNotifier<JournalFileAttachmentState> {
  final JournalRepository _journalRepository;
  final AccountRepository _accountRepository;
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService _fileUploadQueueService;

  JournalFileAttachmentViewModel({
    required JournalRepository journalRepository,
    required AccountRepository accountRepository,
    required OfflineFileService offlineFileService,
    required FileUploadQueueService fileUploadQueueService,
  })  : _journalRepository = journalRepository,
        _accountRepository = accountRepository,
        _offlineFileService = offlineFileService,
        _fileUploadQueueService = fileUploadQueueService,
        super(const JournalFileAttachmentState());

  Future<bool> uploadFile({
    required String journalUid,
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
      AppLogger.debug('JournalFileAttachmentVM: Upload start journal=$journalUid file=$fileName');

      final journalRes = await _journalRepository.getById(journalUid);
      final journal = await journalRes.when(
        success: (j) async {
          if (j == null) throw Exception('Journal not found: $journalUid');
          return j;
        },
        failure: (f) async => throw Exception('Failed to load journal: ${f.message}'),
      );

      // Use offline-first flow
      final storeRes = await _offlineFileService.storeFileLocally(
        taskUid: journalUid, // generic vobject uid
        aesKey: _generateEncryptionKey(),
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
        validatorId: null,
      );

      final offlineFile = await storeRes.when(
        success: (f) async => f,
        failure: (f) async => throw Exception('Failed to store file locally: ${f.message}'),
      );

      // Update journal attachments (same schema as tasks)
      final attachments = _parseAttachments(journal.attachments);
      attachments.add({
        'uri': offlineFile.id,
        'filename': fileName,
        'size': fileData.length,
        'fmttype': contentType,
        'attachType': 'file',
        'aesKey': offlineFile.aesKey,
        'status': 'local',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final updatedJournal = journal.copyWith(
        attachments: jsonEncode(attachments),
        lastModified: DateTime.now(),
      );

      final saveRes = await _journalRepository.save(updatedJournal);
      await saveRes.when(
        success: (_) async {},
        failure: (f) async => throw Exception('Failed to save journal: ${f.message}'),
      );

      // Queue upload
      await _fileUploadQueueService.queueFileUpload(offlineFile.id);

      state = state.copyWith(isUploading: false, successMessage: 'File attached');
      return true;
    } catch (e, st) {
      AppLogger.error('JournalFileAttachmentVM: Upload failed', e, st);
      state = state.copyWith(isUploading: false, error: 'Upload failed: $e');
      return false;
    }
  }

  /// Download file bytes for a journal attachment (offline-first)
  Future<Uint8List?> downloadFileBytes({
    required String fileId,
    required String fileName,
    String? s3Key,
    required String aesKey,
  }) async {
    AppLogger.debug('JournalFileAttachmentVM: Starting download for file $fileId ($fileName)');
    
    try {
      // Try offline first
      AppLogger.debug('JournalFileAttachmentVM: Checking local file for $fileId');
      final localRes = await _offlineFileService.readLocalFile(fileId);
      final localData = await localRes.when(
        success: (d) async => d, 
        failure: (f) async {
          AppLogger.debug('JournalFileAttachmentVM: Local file not found for $fileId: ${f.message}');
          return null;
        }
      );
      
      if (localData != null) {
        AppLogger.debug('JournalFileAttachmentVM: Found local file for $fileId, size: ${localData.length} bytes');
        return localData;
      }
      
      if (s3Key == null || s3Key.isEmpty) {
        AppLogger.error('JournalFileAttachmentVM: No S3 key provided for file $fileId');
        return null;
      }
      
      // Download from S3
      AppLogger.debug('JournalFileAttachmentVM: Downloading from S3 for file $fileId, key: $s3Key');
      final accRes = await _accountRepository.getActiveAccount();
      final account = await accRes.when(
        success: (a) async => a, 
        failure: (f) async {
          AppLogger.error('JournalFileAttachmentVM: Failed to get active account for file $fileId: ${f.message}');
          return null;
        }
      );
      
      if (account == null) {
        AppLogger.error('JournalFileAttachmentVM: No active account found for file $fileId');
        return null;
      }
      
      final s3 = S3StorageService(account: account);
      final dlRes = await s3.downloadFile(key: s3Key, isPrivate: false, symmetricKey: aesKey);
      
      return await dlRes.when(
        success: (bytes) async {
          AppLogger.debug('JournalFileAttachmentVM: Successfully downloaded file $fileId from S3, size: ${bytes.length} bytes');
          return bytes;
        }, 
        failure: (f) async {
          AppLogger.error('JournalFileAttachmentVM: S3 download failed for file $fileId: ${f.message}');
          return null;
        }
      );
    } catch (e, stackTrace) {
      AppLogger.error('JournalFileAttachmentVM: Unexpected error downloading file $fileId', e, stackTrace);
      return null;
    }
  }

  String _generateEncryptionKey() {
    // Reuse simple approach from task VM
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final rnd = DateTime.now().microsecondsSinceEpoch.toString();
    return '$ts-$rnd';
  }

  List<Map<String, dynamic>> _parseAttachments(String jsonList) {
    try {
      if (jsonList.isEmpty || jsonList == '[]') return [];
      final decoded = jsonDecode(jsonList);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((a) => a is Map<String, dynamic> ? a : <String, dynamic>{}).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}


