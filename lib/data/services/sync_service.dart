import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import 'caldav_service.dart';
import 'local_storage_service.dart';

/// Service for handling synchronization between local storage and CalDAV server
class SyncService extends ChangeNotifier {
  final CalDAVService _caldav;
  final LocalStorageService _storage;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _syncTimer;

  SyncService({
    required CalDAVService caldav,
    required LocalStorageService storage,
  })  : _caldav = caldav,
        _storage = storage;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Start periodic sync (every 5 minutes)
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Perform a sync operation between local storage and CalDAV server
  Future<void> sync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      notifyListeners();

      // Fetch remote tasks
      final remoteTasks = await _caldav.fetchTasks();
      final localTasks = _storage.getAllTasks();

      // Create maps for easier lookup
      final remoteTaskMap = {for (var task in remoteTasks) task.uid: task};
      final localTaskMap = {for (var task in localTasks) task.uid: task};

      // Handle tasks that exist in both local and remote
      final commonUids = remoteTaskMap.keys.toSet().intersection(localTaskMap.keys.toSet());
      for (final uid in commonUids) {
        final remoteTask = remoteTaskMap[uid]!;
        final localTask = localTaskMap[uid]!;

        // If remote is newer, update local
        if (remoteTask.lastModified.isAfter(localTask.lastModified)) {
          await _storage.saveTask(remoteTask);
        }
        // If local is newer, update remote
        else if (localTask.lastModified.isAfter(remoteTask.lastModified)) {
          await _caldav.updateTask(localTask);
        }
      }

      // Handle tasks that only exist remotely
      final remoteOnlyUids = remoteTaskMap.keys.toSet().difference(localTaskMap.keys.toSet());
      for (final uid in remoteOnlyUids) {
        await _storage.saveTask(remoteTaskMap[uid]!);
      }

      // Handle tasks that only exist locally
      final localOnlyUids = localTaskMap.keys.toSet().difference(remoteTaskMap.keys.toSet());
      for (final uid in localOnlyUids) {
        await _caldav.createTask(localTaskMap[uid]!);
      }

      _lastSyncTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      // Log the error but don't rethrow - we want sync to fail gracefully
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Queue a task for sync
  Future<void> queueTaskForSync(TaskModel task) async {
    try {
      // Save locally first (optimistic update)
      await _storage.saveTask(task);

      // Try to sync immediately if possible
      if (!_isSyncing) {
        final existingTask = _storage.getTask(task.uid);
        if (existingTask != null) {
          await _caldav.updateTask(task);
        } else {
          await _caldav.createTask(task);
        }
      }
    } catch (e) {
      debugPrint('Failed to queue task for sync: $e');
      // The task is still saved locally and will be synced during the next sync operation
    }
  }

  /// Queue a task deletion for sync
  Future<void> queueTaskDeletionForSync(String uid) async {
    try {
      // Delete locally first (optimistic update)
      await _storage.deleteTask(uid);

      // Try to sync immediately if possible
      if (!_isSyncing) {
        await _caldav.deleteTask(uid);
      }
    } catch (e) {
      debugPrint('Failed to queue task deletion for sync: $e');
      // The task is still deleted locally and will be synced during the next sync operation
    }
  }

  @override
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
} 