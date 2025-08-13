// Journal Media Attachment ViewModel for images/videos on journals

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/storage/offline_file_service.dart';
import '../../data/services/storage/file_upload_queue_service.dart';
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

  JournalMediaAttachmentViewModel({
    required JournalRepository journalRepository,
    required OfflineFileService offlineFileService,
    required FileUploadQueueService fileUploadQueueService,
  })  : _journalRepository = journalRepository,
        _offlineFileService = offlineFileService,
        _fileUploadQueueService = fileUploadQueueService,
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
}


