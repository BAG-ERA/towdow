// Task repository interface and local implementation
// Follows repository pattern for task data access

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task.dart';
import '../services/local_storage_service.dart';

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
}

// Local implementation using Hive
class LocalTaskRepository implements TaskRepository {
  final LocalStorageService _storageService;

  LocalTaskRepository(this._storageService);

  @override
  Future<Result<List<Task>>> getAll() async {
    final result = await _storageService.getAll<Task>(LocalStorageService.tasksBoxName);
    if (result is Success) {
      final tasks = (result as Success<List<Task>>).data;
      // AppLogger.debug('TaskRepository: getAll() returned ${tasks.length} tasks');
      
    }
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
        // Filter tasks by their source calendar (Calendar = Project model)
        final projectTasks = tasks.where((task) => task.sourceCalendarUid == projectUid).toList();
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
        // TODO: In Calendar = Project model, unregistered tasks would be tasks
        // not properly synced or belonging to unknown/deleted calendars
        // For now, return empty list during transition
        final unregisteredTasks = <Task>[];
        return Result.success(unregisteredTasks);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> save(Task task) async {
    return await _storageService.put(LocalStorageService.tasksBoxName, task.uid, task);
  }

  @override
  Future<Result<void>> delete(String uid) async {
    return await _storageService.delete(LocalStorageService.tasksBoxName, uid);
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
} 
