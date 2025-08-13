// Journal File Attachment ViewModel for managing journal-level file attachments
// Mirrors TaskFileAttachmentViewModel but operates on Journal via JournalRepository

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/journal_repository.dart';
import '../../data/services/storage/offline_file_service.dart';
import '../../data/services/storage/file_upload_queue_service.dart';
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
  final OfflineFileService _offlineFileService;
  final FileUploadQueueService _fileUploadQueueService;

  JournalFileAttachmentViewModel({
    required JournalRepository journalRepository,
    required OfflineFileService offlineFileService,
    required FileUploadQueueService fileUploadQueueService,
  })  : _journalRepository = journalRepository,
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


