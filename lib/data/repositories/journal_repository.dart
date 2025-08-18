// Journal repository interface and local implementation
// Follows repository pattern for journal data access

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/journal.dart';
import '../services/storage/local_storage_service.dart';
import '../services/sync/sync_service.dart';

abstract class JournalRepository {
  Future<Result<List<Journal>>> getAll();
  Future<Result<Journal?>> getById(String uid);
  Future<Result<List<Journal>>> getByProject(String projectUid);
  Future<Result<void>> save(Journal journal);
  Future<Result<void>> delete(String uid);
  Stream<List<Journal>> watchJournals();

  // Internal method used by sync (does not queue sync)
  Future<Result<void>> saveFromSync(Journal journal);
}

class LocalJournalRepository implements JournalRepository {
  final LocalStorageService _storageService;
  SyncService? _syncService;

  LocalJournalRepository(this._storageService);

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  @override
  Future<Result<List<Journal>>> getAll() async {
    return await _storageService.getAll<Journal>(LocalStorageService.journalsBoxName);
  }

  @override
  Future<Result<Journal?>> getById(String uid) async {
    return await _storageService.get<Journal>(LocalStorageService.journalsBoxName, uid);
  }

  @override
  Future<Result<List<Journal>>> getByProject(String projectUid) async {
    final result = await getAll();
    return result.when(
      success: (journals) => Result.success(journals.where((j) => j.projectPath == projectUid).toList()),
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> save(Journal journal) async {
    // Check if journal already exists to determine operation type
    final existingJournalResult = await getById(journal.uid);
    final isNewJournal = existingJournalResult.when(
      success: (existingJournal) => existingJournal == null,
      failure: (_) => true, // Assume new if we can't check
    );
    
    // Save to local storage first (offline-first)
    final saveResult = await _storageService.put(LocalStorageService.journalsBoxName, journal.uid, journal);
    
    // Queue sync if sync service is available and journal has project path
    if (saveResult is Success && _syncService != null && journal.projectPath != null && journal.projectPath!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarPath': journal.projectPath,
        'journalUid': journal.uid,
      };
      
      // Use appropriate operation type
      final operation = isNewJournal ? SyncOperation.createJournal : SyncOperation.updateJournal;
      _syncService!.queueSyncOperation(
        operation,
        journal.uid,
        syncData,
      );
    }
    
    return saveResult;
  }

  @override
  Future<Result<void>> delete(String uid) async {
    // Get journal before deletion for sync operation
    final journalResult = await getById(uid);
    final journalToDelete = journalResult.when(
      success: (journal) => journal,
      failure: (_) => null,
    );
    
    // Delete from local storage first (offline-first)
    final deleteResult = await _storageService.delete(LocalStorageService.journalsBoxName, uid);
    
    // Queue sync if sync service is available and journal had project path
    if (deleteResult is Success && _syncService != null && journalToDelete != null && 
        journalToDelete.projectPath != null && journalToDelete.projectPath!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarPath': journalToDelete.projectPath,
        'journalUid': uid,
      };
      
      _syncService!.queueSyncOperation(
        SyncOperation.deleteJournal,
        uid,
        syncData,
      );
    }
    
    return deleteResult;
  }

  @override
  Stream<List<Journal>> watchJournals() {
    // Emit current list immediately, then on every box change
    final changes = _storageService
        .getStream(LocalStorageService.journalsBoxName)
        .asyncMap((_) async {
      final res = await _storageService.getAll<Journal>(LocalStorageService.journalsBoxName);
      return res.when(success: (list) => list, failure: (_) => <Journal>[]);
    });

    return Stream<List<Journal>>.multi((controller) async {
      // Initial emit
      final initial = await _storageService.getAll<Journal>(LocalStorageService.journalsBoxName);
      controller.add(initial.when(success: (list) => list, failure: (_) => <Journal>[]));
      // Forward subsequent updates
      await for (final list in changes) {
        controller.add(list);
      }
    });
  }

  @override
  Future<Result<void>> saveFromSync(Journal journal) async {
    return await _storageService.put(LocalStorageService.journalsBoxName, journal.uid, journal);
  }
}


