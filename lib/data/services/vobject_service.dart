// VObjectService: generic operations on CalDAV vobjects (VTODO, VJOURNAL, later VEVENT, VALARM)
// Provides UID-based lookup and save, and helpers to update attachments/media with S3 info.

import 'dart:convert';

import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/task.dart';
import '../models/journal.dart';
import '../models/offline_file.dart';
import '../repositories/task_repository.dart';
import '../repositories/journal_repository.dart';
import 'validator_service.dart';

enum VObjectType { task, journal }

class VObject {
  final VObjectType type;
  final Task? task;
  final Journal? journal;

  const VObject._(this.type, {this.task, this.journal});

  factory VObject.task(Task task) => VObject._(VObjectType.task, task: task);
  factory VObject.journal(Journal journal) => VObject._(VObjectType.journal, journal: journal);
}

class VObjectUpdateResult {
  final bool updated;
  final VObjectType? type;
  final String uid;
  final String? projectPath; // calendar path if applicable
  const VObjectUpdateResult({required this.updated, required this.uid, this.type, this.projectPath});
}

class VObjectService {
  final TaskRepository _taskRepository;
  final JournalRepository _journalRepository;

  VObjectService({required TaskRepository taskRepository, required JournalRepository journalRepository})
      : _taskRepository = taskRepository,
        _journalRepository = journalRepository;

  Future<Result<VObject?>> getByUid(String uid) async {
    // Try task first
    final taskRes = await _taskRepository.getById(uid);
    final task = await taskRes.when(
      success: (t) async => t,
      failure: (_) async => null,
    );
    if (task != null) return Result.success(VObject.task(task));

    // Try journal
    final journalRes = await _journalRepository.getById(uid);
    final journal = await journalRes.when(
      success: (j) async => j,
      failure: (_) async => null,
    );
    if (journal != null) return Result.success(VObject.journal(journal));

    return const Result.success(null);
  }

  Future<Result<void>> save(VObject vobject) async {
    switch (vobject.type) {
      case VObjectType.task:
        return _taskRepository.save(vobject.task!);
      case VObjectType.journal:
        return _journalRepository.save(vobject.journal!);
    }
  }

  /// Update attachments/media (or task validator) after a successful S3 upload
  /// Returns VObjectUpdateResult with context for further actions (e.g., queue sync for tasks)
  Future<Result<VObjectUpdateResult>> updateWithS3Info(OfflineFile offlineFile, Map<String, String> s3Info) async {
    try {
      final uid = offlineFile.taskUid; // vobject uid (task or journal)
      final objRes = await getByUid(uid);
      final vobj = await objRes.when(success: (o) async => o, failure: (_) async => null);
      if (vobj == null) {
        AppLogger.error('VObjectService: VObject not found for uid=$uid');
        return Result.success(VObjectUpdateResult(updated: false, uid: uid));
      }

      if (vobj.type == VObjectType.task) {
        final task = vobj.task!;
        Task updatedTask = task;
        bool hasUpdates = false;

        if (offlineFile.validatorId != null) {
          final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
          final updateData = {
            'type': 'update_file_s3',
            'offlineFileId': offlineFile.id,
            's3Key': s3Info['s3Key'],
            's3Url': s3Info['s3Url'],
            'status': 'uploaded',
            'removeOfflineRef': true,
          };
          final updatedValidatorLists = ValidatorService.updateValidatorState(
            validatorLists,
            offlineFile.validatorId!,
            updateData,
          );
          final newValidatorString = ValidatorService.serializeValidators(updatedValidatorLists);
          updatedTask = updatedTask.copyWith(
            flowitValidator: newValidatorString,
            lastModified: DateTime.now(),
          );
          hasUpdates = true;
        } else {
          final a1 = _updateAttachmentsJson(updatedTask.attachments, offlineFile.id, s3Info);
          if (a1 != null) {
            updatedTask = updatedTask.copyWith(attachments: a1, lastModified: DateTime.now());
            hasUpdates = true;
          } else {
            final a2 = _updateAttachmentsJson(updatedTask.mediaAttachments, offlineFile.id, s3Info);
            if (a2 != null) {
              updatedTask = updatedTask.copyWith(mediaAttachments: a2, lastModified: DateTime.now());
              hasUpdates = true;
            }
          }
        }

        if (!hasUpdates) {
          return Result.success(VObjectUpdateResult(updated: false, uid: uid, type: VObjectType.task, projectPath: task.projectPath));
        }

        final saveRes = await _taskRepository.save(updatedTask);
        return await saveRes.when(
          success: (_) async => Result.success(VObjectUpdateResult(updated: true, uid: uid, type: VObjectType.task, projectPath: updatedTask.projectPath)),
          failure: (f) async => Result.failure(f),
        );
      }

      // Journal
      final journal = vobj.journal!;
      bool changed = false;
      final j1 = _updateAttachmentsJson(journal.attachments, offlineFile.id, s3Info);
      String attachments = journal.attachments;
      String mediaAttachments = journal.mediaAttachments;
      if (j1 != null) {
        attachments = j1;
        changed = true;
      } else {
        final j2 = _updateAttachmentsJson(journal.mediaAttachments, offlineFile.id, s3Info);
        if (j2 != null) {
          mediaAttachments = j2;
          changed = true;
        }
      }

      if (!changed) {
        return Result.success(VObjectUpdateResult(updated: false, uid: uid, type: VObjectType.journal, projectPath: journal.projectPath));
      }

      final updatedJournal = journal.copyWith(
        attachments: attachments,
        mediaAttachments: mediaAttachments,
        lastModified: DateTime.now(),
      );
      final saveRes = await _journalRepository.save(updatedJournal);
      return await saveRes.when(
        success: (_) async => Result.success(VObjectUpdateResult(updated: true, uid: uid, type: VObjectType.journal, projectPath: updatedJournal.projectPath)),
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('VObjectService: updateWithS3Info failed', e, st);
      return Result.failure(Failure(message: 'updateWithS3Info failed: $e', exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  String? _updateAttachmentsJson(String jsonList, String offlineId, Map<String, String> s3Info) {
    try {
      if (jsonList.isEmpty || jsonList == '[]') return null;
      final decoded = jsonDecode(jsonList);
      if (decoded is! List) return null;
      bool changed = false;
      final updated = decoded.map<Map<String, dynamic>>((att) {
        if (att is Map<String, dynamic>) {
          final uri = att['uri'] as String?;
          if (uri == offlineId) {
            changed = true;
            return {
              ...att,
              's3Key': s3Info['s3Key'],
              's3Url': s3Info['s3Url'],
              'status': 'uploaded',
              'uploadedAt': att['uploadedAt'] ?? DateTime.now().toIso8601String(),
            };
          }
        }
        return att is Map<String, dynamic> ? att : <String, dynamic>{};
      }).toList();
      if (!changed) return null;
      return jsonEncode(updated);
    } catch (_) {
      return null;
    }
  }
}


