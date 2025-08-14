// Journal Media Attachment ViewModel for images/videos on journals

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/storage/offline_file_service.dart';
import '../../data/services/storage/file_upload_queue_service.dart';
import '../../data/services/storage/s3_storage_service.dart';
import '../../core/logger.dart';

class JournalMediaAttachmentState {
  final bool isUploading;
  final String? error;
  final String? successMessage;
  const JournalMediaAttachmentState({this.isUploading = false, this.error, this.successMessage});

  JournalMediaAttachmentState copyWith({bool? isUploading, String? error, String? successMessage}) {
    return JournalMediaAttachmentState(
      isUploading: isUploading ?? this.isUploading,
      error: error,
      successMessage: successMessage,
    );
  }
}

class JournalMediaAttachmentViewModel extends StateNotifier<JournalMediaAttachmentState> {
  final JournalRepository _journalRepository;
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService _fileUploadQueueService;
  final AccountRepository _accountRepository;

  JournalMediaAttachmentViewModel({
    required JournalRepository journalRepository,
    required OfflineFileService offlineFileService,
    required FileUploadQueueService fileUploadQueueService,
    required AccountRepository accountRepository,
  })  : _journalRepository = journalRepository,
        _offlineFileService = offlineFileService,
        _fileUploadQueueService = fileUploadQueueService,
        _accountRepository = accountRepository,
        super(const JournalMediaAttachmentState());

  Future<bool> uploadMediaFile({
    required String journalUid,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    state = state.copyWith(isUploading: true, error: null);
    try {
      final jr = await _journalRepository.getById(journalUid);
      final journal = await jr.when(success: (j) async => j, failure: (f) async => throw Exception(f.message));
      if (journal == null) throw Exception('Journal not found');

      final storeRes = await _offlineFileService.storeFileLocally(
        taskUid: journalUid,
        aesKey: _generateEncryptionKey(),
        fileName: fileName,
        fileData: fileData,
        contentType: contentType,
        validatorId: null,
      );
      final offlineFile = await storeRes.when(success: (f) async => f, failure: (f) async => throw Exception(f.message));

      final media = _parseMedia(journal.mediaAttachments);
      media.add({
        'uri': offlineFile.id,
        'filename': fileName,
        'size': fileData.length,
        'contentType': contentType,
        'offlineFileId': offlineFile.id,
        'status': 'local',
        'uploadedAt': DateTime.now().toIso8601String(),
        'aesKey': offlineFile.aesKey,
      });

      final updated = journal.copyWith(
        mediaAttachments: jsonEncode(media),
        lastModified: DateTime.now(),
      );
      final saveRes = await _journalRepository.save(updated);
      await saveRes.when(success: (_) async {}, failure: (f) async => throw Exception(f.message));

      await _fileUploadQueueService.queueFileUpload(offlineFile.id);

      state = state.copyWith(isUploading: false, successMessage: 'Media attached');
      return true;
    } catch (e, st) {
      AppLogger.error('JournalMediaAttachmentVM: Upload failed', e, st);
      state = state.copyWith(isUploading: false, error: 'Upload failed: $e');
      return false;
    }
  }

  String _generateEncryptionKey() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final rnd = DateTime.now().microsecondsSinceEpoch.toString();
    return '$ts-$rnd';
  }

  List<Map<String, dynamic>> _parseMedia(String jsonList) {
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
          AppLogger.debug('JournalMediaAttachmentViewModel: Failed to get image data: ${failure.message}');
          return null;
        },
      );
    } catch (e) {
      AppLogger.debug('JournalMediaAttachmentViewModel: Error getting image data: $e');
      return null;
    }
  }

  /// Download media file bytes for platform-specific saving
  Future<Uint8List?> downloadMediaFileBytes({
    required String fileId,
    required String fileName,
    String? s3Key,
    required String aesKey,
  }) async {
    try {
      // Try offline first
      final localRes = await _offlineFileService.readLocalFile(fileId);
      final localData = await localRes.when(success: (d) async => d, failure: (_) async => null);
      if (localData != null) {
        return localData;
      }
      if (s3Key == null || s3Key.isEmpty) {
        return null;
      }
      // Download from S3
      final accRes = await _accountRepository.getActiveAccount();
      final account = await accRes.when(success: (a) async => a, failure: (_) async => null);
      if (account == null) return null;
      final s3 = S3StorageService(account: account);
      final dlRes = await s3.downloadFile(key: s3Key, isPrivate: false, symmetricKey: aesKey);
      return await dlRes.when(success: (bytes) async => bytes, failure: (_) async => null);
    } catch (_) {
      return null;
    }
  }
}


