// Task repository interface and local implementation
// Follows repository pattern for task data access

import 'package:towdow_app/data/models/task_helpers.dart';

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task.dart';
import '../services/storage/local_storage_service.dart';
import '../services/sync/sync_service.dart';

// Abstract repository interface
abstract class TaskRepository {
  Future<Result<List<Task>>> getAll();
  Future<Result<Task?>> getById(String uid);
  Future<Result<List<Task>>> getByProject(String projectUid);
  Future<Result<List<Task>>> getTasksWithDueDate(DateTime date);
  Future<Result<List<Task>>> getTasksWithoutDueDate();
  Future<Result<List<Task>>> getUnregisteredTasks();
  Future<Result<void>> save(Task task);
  Future<Result<void>> delete(String uid);
  Stream<List<Task>> watchTasks();
    Stream<List<Task>> watchTasksByProject(String projectPath);
  
  // Internal methods for sync operations (don't trigger sync)
  Future<Result<void>> saveFromSync(Task task);

  // Local-only maintenance utilities (no sync side effects)
  Future<Result<void>> deleteByProjectLocalOnly(String projectPath);
  Future<Result<void>> deleteOrphanedTasksLocalOnly(Set<String> validCalendarPaths);
}

// Local implementation using Hive
class LocalTaskRepository implements TaskRepository {
  final LocalStorageService _storageService;
  SyncService? _syncService;

  LocalTaskRepository(this._storageService);
  
  // Allow sync service to be injected after creation
  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  @override
  Future<Result<List<Task>>> getAll() async {
    final result = await _storageService.getAll<Task>(LocalStorageService.tasksBoxName);

    return result;
  }

  @override
  Future<Result<Task?>> getById(String uid) async {
    return await _storageService.get<Task>(LocalStorageService.tasksBoxName, uid);
  }

  @override
  Future<Result<List<Task>>> getByProject(String projectUid) async {
    final result = await getAll();
    return result.when(
      success: (tasks) {
        // Filter tasks by their project path (Calendar = Project model)
        final projectTasks = tasks.where((task) => task.projectPath == projectUid).toList();
        return Result.success(projectTasks);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<Task>>> getTasksWithDueDate(DateTime date) async {
    final result = await getAll();
    return result.when(
      success: (tasks) {
        final dueTasks = tasks.where((task) {
          if (task.due == null) return false;
          final dueDate = DateTime(task.due!.year, task.due!.month, task.due!.day);
          final targetDate = DateTime(date.year, date.month, date.day);
          return dueDate.isAtSameMomentAs(targetDate);
        }).toList();
        return Result.success(dueTasks);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<Task>>> getTasksWithoutDueDate() async {
    final result = await getAll();
    return result.when(
      success: (tasks) {
        final unscheduledTasks = tasks.where((task) => task.due == null).toList();
        return Result.success(unscheduledTasks);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<Task>>> getUnregisteredTasks() async {
    final result = await getAll();
    return result.when(
      success: (tasks) {
        // Unregistered tasks (tasks with null projectPath) should be deleted
        AppLogger.warning('TaskRepository: getUnregisteredTasks() found ${tasks.where((task) => task.projectPath == null).length} unregistered tasks');
        final unregisteredTasks = tasks.where((task) => task.projectPath == null).toList();
        
        // Delete unregistered tasks as they are considered errors
        for (final task in unregisteredTasks) {
          delete(task.uid);
        }
        
        // Return empty list since unregistered tasks should not exist
        return Result.success(<Task>[]);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> save(Task task) async {
    // Check if task already exists to determine operation type
    final existingTaskResult = await getById(task.uid);
    final isNewTask = existingTaskResult.when(
      success: (existingTask) => existingTask == null,
      failure: (_) => true, // Assume new if we can't check
    );
    
    // Save to local storage first (offline-first)
    final saveResult = await _storageService.put(LocalStorageService.tasksBoxName, task.uid, task);
    
    // Queue sync if sync service is available and task has project path
    if (saveResult is Success && _syncService != null && task.projectPath != null && task.projectPath!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarPath': task.projectPath,
        'taskUid': task.uid,
      };
      
      // Use appropriate operation type
      final operation = isNewTask ? SyncOperation.create : SyncOperation.update;
      _syncService!.queueSyncOperation(
        operation,
        task.uid,
        syncData,
      );
    }
    
    return saveResult;
  }

  @override
  Future<Result<void>> delete(String uid) async {
    // Get task before deletion for sync operation
    final taskResult = await getById(uid);
    final taskToDelete = taskResult.when(
      success: (task) => task,
      failure: (_) => null,
    );
    
    // Delete from local storage first (offline-first)
    final deleteResult = await _storageService.delete(LocalStorageService.tasksBoxName, uid);
    
    // Queue sync if sync service is available and task had project path
    if (deleteResult is Success && _syncService != null && taskToDelete != null && 
        taskToDelete.projectPath != null && taskToDelete.projectPath!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarPath': taskToDelete.projectPath,
        'taskUid': uid,
      };
      
      _syncService!.queueSyncOperation(
        SyncOperation.delete,
        uid,
        syncData,
      );
    }
    
    return deleteResult;
  }

  @override
  Stream<List<Task>> watchTasks() async* {
    // Emit initial value
    final result = await getAll();
    yield result.when(
      success: (tasks) => tasks,
      failure: (_) => <Task>[],
    );
    
    // Then listen to changes
    yield* _storageService.getStream(LocalStorageService.tasksBoxName)
        .asyncMap((_) async {
          final result = await getAll();
          return result.when(
            success: (tasks) => tasks,
            failure: (_) => <Task>[],
          );
        });
  }

  @override
  Stream<List<Task>> watchTasksByProject(String projectPath) async* {
    final encoded = projectPath.replaceAll('@', '%40');
    // Emit initial
    final init = await getByProject(encoded);
    yield init.when(success: (tasks) => tasks, failure: (_) => <Task>[]);
    // Then listen for changes and filter
    yield* _storageService.getStream(LocalStorageService.tasksBoxName).asyncMap((_) async {
      final res = await getByProject(encoded);
      return res.when(success: (tasks) => tasks, failure: (_) => <Task>[]);
    });
  }

  @override
  Future<Result<void>> saveFromSync(Task task) async {
    return await _storageService.put(LocalStorageService.tasksBoxName, task.uid, task);
  }

  @override
  Future<Result<void>> deleteByProjectLocalOnly(String projectPath) async {
    try {
      final encodedProjectPath = projectPath.replaceAll('@', '%40');
      final tasksResult = await getAll();
      return await tasksResult.when(
        success: (tasks) async {
          final tasksToDelete = tasks.where((t) => t.projectPath == encodedProjectPath).toList();
          AppLogger.info('TaskRepository: Local-only delete of ${tasksToDelete.length} tasks for project $projectPath');
          for (final task in tasksToDelete) {
            final res = await _storageService.delete(LocalStorageService.tasksBoxName, task.uid);
            if (res is Error<void>) {
              return res;
            }
          }
          return const Result.success(null);
        },
        failure: (failure) async {
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskRepository: Exception during local-only delete by project', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete tasks for project: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> deleteOrphanedTasksLocalOnly(Set<String> validCalendarPaths) async {
    try {
      // Ensure we compare against encoded paths because tasks store encoded projectPath
      final encodedValid = validCalendarPaths
          .map((p) => p.replaceAll('@', '%40'))
          .toSet();
      final tasksResult = await getAll();
      return await tasksResult.when(
        success: (tasks) async {
          final orphans = tasks.where((t) => t.projectPath == null || !encodedValid.contains(t.projectPath)).toList();
          if (orphans.isNotEmpty) {
            AppLogger.warning('TaskRepository: Cleaning ${orphans.length} orphan task(s) locally');
          }
          for (final task in orphans) {
            final res = await _storageService.delete(LocalStorageService.tasksBoxName, task.uid);
            if (res is Error<void>) {
              return res;
            }
          }
          return const Result.success(null);
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskRepository: Exception during orphan cleanup', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to cleanup orphan tasks: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 
