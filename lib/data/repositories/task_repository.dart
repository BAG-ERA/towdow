import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

class TaskRepository {
  final LocalStorageService _storage;
  final SyncService _sync;
  final _uuid = const Uuid();

  TaskRepository(this._storage, this._sync);

  /// Create a new task
  Future<TaskModel> createTask({
    required String summary,
    String description = '',
    DateTime? dueDate,
    FlowItType type = FlowItType.task,
    Map<String, dynamic>? validator,
    Map<String, dynamic>? requirement,
    String? templateUid,
    String? processUid,
  }) async {
    final task = TaskModel(
      uid: _uuid.v4(),
      summary: summary,
      description: description,
      dueDate: dueDate,
      type: type,
      validator: validator,
      requirement: requirement,
      templateUid: templateUid,
      processUid: processUid,
    );

    await _sync.queueTaskForSync(task);
    return task;
  }

  /// Get a task by its UID
  TaskModel? getTask(String uid) {
    return _storage.getTask(uid);
  }

  /// Update an existing task
  Future<void> updateTask(TaskModel task) async {
    await _sync.queueTaskForSync(task);
  }

  /// Delete a task
  Future<void> deleteTask(String uid) async {
    await _sync.queueTaskDeletionForSync(uid);
  }

  /// Get all tasks
  List<TaskModel> getAllTasks() {
    return _storage.getAllTasks();
  }

  /// Get tasks by type
  List<TaskModel> getTasksByType(FlowItType type) {
    return _storage.getTasksByType(type);
  }

  /// Get tasks due today
  List<TaskModel> getTasksDueToday() {
    return _storage.getTasksDueToday()
        .where((task) => task.type == FlowItType.task)
        .toList();
  }

  /// Get tasks due soon
  List<TaskModel> getTasksDueSoon() {
    return _storage.getTasksDueSoon()
        .where((task) => task.type == FlowItType.task)
        .toList();
  }

  /// Get unregistered tasks (no due date or project)
  List<TaskModel> getUnregisteredTasks() {
    return _storage.getUnregisteredTasks()
        .where((task) => task.type == FlowItType.task)
        .toList();
  }

  /// Mark a task as complete
  Future<void> completeTask(String uid) async {
    final task = getTask(uid);
    if (task != null) {
      final updatedTask = task.copyWith(
        status: TaskStatus.completed,
        lastModified: DateTime.now(),
      );
      await updateTask(updatedTask);
    }
  }

  /// Mark a task as cancelled
  Future<void> cancelTask(String uid) async {
    final task = getTask(uid);
    if (task != null) {
      final updatedTask = task.copyWith(
        status: TaskStatus.cancelled,
        lastModified: DateTime.now(),
      );
      await updateTask(updatedTask);
    }
  }

  /// Trigger a manual sync
  Future<void> sync() async {
    await _sync.sync();
  }
} 