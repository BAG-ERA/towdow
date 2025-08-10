// Task ViewModel for managing task operations
// Handles task creation, editing, completion, and deletion

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import '../../data/models/attendee.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../core/logger.dart';

// Task ViewModel State
class TaskViewModelState {
  final bool isLoading;
  final String? error;
  final Task? selectedTask;

  TaskViewModelState({
    this.isLoading = false,
    this.error,
    this.selectedTask,
  });

  TaskViewModelState copyWith({
    bool? isLoading,
    String? error,
    Task? selectedTask,
  }) {
    return TaskViewModelState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedTask: selectedTask ?? this.selectedTask,
    );
  }
}

// Task ViewModel
class TaskViewModel extends StateNotifier<TaskViewModelState> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  // SyncService removed - sync now handled by repository

  TaskViewModel(this._taskRepository, this._accountRepository) : super(TaskViewModelState());

  // Create a new task
  Future<void> createTask({
    required String summary,
    String description = '',
    DateTime? due,
    List<String> categories = const [],
    List<Attendee> attendees = const [],
    String? projectPath,
    String? flowitRequirement,
  }) async {
    AppLogger.debug('🔄 TaskViewModel: Creating task with summary: $summary');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current user's email to set as organizer
      String? organizer;
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account?.email != null) {
            organizer = account!.email;
          } else if (account?.username != null) {
            // Fallback: use username as organizer if no email is set
            organizer = account!.username;
          }
        },
        failure: (failure) async {
          AppLogger.warning('TaskViewModel: Could not get active account for organizer: ${failure.message}');
        },
      );

      // Encode project path to match storage format (especially for @ characters)
      final encodedProjectPath = projectPath?.replaceAll('@', '%40');
      
      final task = TaskFactory.createNew(
        summary: summary,
        description: description,
        due: due,
        categoryIds: categories,
        attendees: attendees,
        projectPath: encodedProjectPath,
        organizer: organizer,
        flowitRequirement: flowitRequirement ?? '{}',
      );

      final result = await _taskRepository.save(task);
      
      await result.when(
        success: (_) async {
          AppLogger.debug('🔄 TaskViewModel: Task created successfully: ${task.uid}');
          // Sync is now handled by repository
          state = state.copyWith(isLoading: false);
        },
        failure: (failure) {
          AppLogger.error('TaskViewModel: Failed to create task', failure.message);
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskViewModel: Exception creating task', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create task: $e',
      );
    }
  }

  // Update an existing task
  Future<void> updateTask(Task task) async {
    AppLogger.debug('🔄 TaskViewModel: Updating task: ${task.uid}');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedTask = task.copyWith(
        lastModified: DateTime.now(),
      );

      final result = await _taskRepository.save(updatedTask);
      
      await result.when(
        success: (_) async {
          AppLogger.debug('🔄 TaskViewModel: Task updated successfully: ${task.uid}');
          // Sync is now handled by repository
          state = state.copyWith(
            isLoading: false,
            selectedTask: updatedTask,
          );
        },
        failure: (failure) {
          AppLogger.error('TaskViewModel: Failed to update task', failure.message);
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskViewModel: Exception updating task', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update task: $e',
      );
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(Task task) async {
    // AppLogger.info('TaskViewModel: Toggling completion for task: ${task.uid}');
    
    final newStatus = task.status == 'COMPLETED' ? 'NEEDS-ACTION' : 'COMPLETED';
    final newPercentComplete = newStatus == 'COMPLETED' ? 100 : 0;
    
    final updatedTask = task.copyWith(
      status: newStatus,
      percentComplete: newPercentComplete,
      lastModified: DateTime.now(),
    );

    await updateTask(updatedTask);
  }

  // Delete a task
  Future<void> deleteTask(String taskUid) async {
    AppLogger.debug('🔄 TaskViewModel: Deleting task: $taskUid');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get task before deletion for sync queue
      final taskResult = await _taskRepository.getById(taskUid);
      final taskToDelete = taskResult.when(
        success: (task) => task,
        failure: (_) => null,
      );

      // Delete from local storage first (offline-first approach)
      final result = await _taskRepository.delete(taskUid);
      
      await result.when(
        success: (_) async {
          AppLogger.debug('🔄 TaskViewModel: Task deleted locally: $taskUid');
          // Sync is now handled by repository
          state = state.copyWith(isLoading: false);
        },
        failure: (failure) async {
          AppLogger.error('TaskViewModel: Failed to delete task', failure.message);
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskViewModel: Exception deleting task', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete task: $e',
      );
    }
  }

  // Load a specific task
  Future<void> loadTask(String taskUid) async {
    // AppLogger.info('TaskViewModel: Loading task: $taskUid');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _taskRepository.getById(taskUid);
      
      result.when(
        success: (task) {
          // AppLogger.info('TaskViewModel: Task loaded successfully: $taskUid');
          state = state.copyWith(
            isLoading: false,
            selectedTask: task,
          );
        },
        failure: (failure) {
          AppLogger.error('TaskViewModel: Failed to load task', failure.message);
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskViewModel: Exception loading task', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load task: $e',
      );
    }
  }

  // Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Move a task to a different calendar/project
  Future<void> moveTask(Task task, String targetCalendarUid) async {
    AppLogger.debug('🔄 TaskViewModel: Moving task ${task.uid} to calendar $targetCalendarUid');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if task is already in the target calendar
      if (task.projectPath == targetCalendarUid) {
        AppLogger.warning('TaskViewModel: Task ${task.uid} is already in calendar $targetCalendarUid');
        state = state.copyWith(isLoading: false);
        return;
      }

      final oldCalendarUid = task.projectPath;
      
      // Create updated task with new source calendar
      final movedTask = task.copyWith(
        projectPath: targetCalendarUid,
        lastModified: DateTime.now(),
      );

      // Save the updated task locally (optimistic UI)
      final result = await _taskRepository.save(movedTask);
      
      await result.when(
        success: (_) async {
          AppLogger.debug('🔄 TaskViewModel: Task moved locally - ${movedTask.uid}');
          // Sync is now handled by repository
          state = state.copyWith(
            isLoading: false,
            selectedTask: movedTask,
          );
        },
        failure: (failure) {
          AppLogger.error('TaskViewModel: Failed to move task', failure.message);
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('TaskViewModel: Exception moving task', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to move task: $e',
      );
    }
  }



  // Clear selected task
  void clearSelectedTask() {
    state = state.copyWith(selectedTask: null);
  }
} 
