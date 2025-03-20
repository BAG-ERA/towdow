import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task_model.dart';

class LocalStorageService {
  static const String _tasksBoxName = 'tasks';
  late Box _tasksBox;

  /// Initialize Hive and open the tasks box
  Future<void> init() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    _tasksBox = await Hive.openBox(_tasksBoxName);
  }

  /// Add or update a task in local storage
  Future<void> saveTask(TaskModel task) async {
    await _tasksBox.put(task.uid, task.toJson());
  }

  Map<String, dynamic> _castMap(dynamic map) {
    if (map is Map<String, dynamic>) return map;
    return Map<String, dynamic>.from(map as Map);
  }

  /// Get a task by its UID
  TaskModel? getTask(String uid) {
    final taskMap = _tasksBox.get(uid);
    if (taskMap == null) return null;
    return TaskModel.fromJson(_castMap(taskMap));
  }

  /// Get all tasks
  List<TaskModel> getAllTasks() {
    return _tasksBox.values
        .map((taskMap) => TaskModel.fromJson(_castMap(taskMap)))
        .toList();
  }

  /// Delete a task by its UID
  Future<void> deleteTask(String uid) async {
    await _tasksBox.delete(uid);
  }

  /// Get tasks by their type
  List<TaskModel> getTasksByType(FlowItType type) {
    return _tasksBox.values
        .map((taskMap) => TaskModel.fromJson(_castMap(taskMap)))
        .where((task) => task.type == type)
        .toList();
  }

  /// Get tasks due today
  List<TaskModel> getTasksDueToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return _tasksBox.values
        .map((taskMap) => TaskModel.fromJson(_castMap(taskMap)))
        .where((task) => task.dueDate != null &&
            task.dueDate!.isAfter(today.subtract(const Duration(days: 1))) && // Include overdue tasks from yesterday
            task.dueDate!.isBefore(tomorrow) &&
            task.status != TaskStatus.completed &&
            task.status != TaskStatus.cancelled)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!)); // Sort by due date
  }

  /// Get tasks due soon (within the next 5 days, excluding today)
  List<TaskModel> getTasksDueSoon() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final fiveDaysLater = today.add(const Duration(days: 6)); // +6 because we want to include the 5th day fully

    return _tasksBox.values
        .map((taskMap) => TaskModel.fromJson(_castMap(taskMap)))
        .where((task) => task.dueDate != null &&
            task.dueDate!.isAfter(today) &&
            task.dueDate!.isBefore(fiveDaysLater) &&
            task.status != TaskStatus.completed &&
            task.status != TaskStatus.cancelled)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!)); // Sort by due date
  }

  /// Get unregistered tasks (no due date or project)
  List<TaskModel> getUnregisteredTasks() {
    return _tasksBox.values
        .map((taskMap) => TaskModel.fromJson(_castMap(taskMap)))
        .where((task) => task.dueDate == null && task.processUid == null)
        .toList();
  }

  /// Close the Hive box
  Future<void> close() async {
    await _tasksBox.close();
  }
} 