// Task ViewModel for managing task operations
// Handles task creation, editing, completion, and deletion

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/sync_service.dart';
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
  final SyncService? _syncService;

  TaskViewModel(this._taskRepository, this._accountRepository, [this._syncService]) : super(TaskViewModelState());

  // Create a new task
  Future<void> createTask({
    required String summary,
    String description = '',
    DateTime? due,
    List<String> categories = const [],
    String? projectPath,
  }) async {
    AppLogger.debug('🔄 TaskViewModel: Creating task with summary: $summary');
    AppLogger.debug('🔄 TaskViewModel: SyncService available: ${_syncService != null}');
    
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
        categories: categories,
        projectPath: encodedProjectPath,
        organizer: organizer,
      );

      final result = await _taskRepository.save(task);
      
      await result.when(
        success: (_) async {
          AppLogger.debug('🔄 TaskViewModel: Task created successfully: ${task.uid}');
          
          // Queue sync operation to create on server
          if (_syncService != null) {
            // Only queue sync if task has a valid projectPath
            if (task.projectPath != null && task.projectPath!.isNotEmpty) {
              AppLogger.debug('🔄 TaskViewModel: Queuing CREATE operation for ${task.uid}');
              final syncData = <String, dynamic>{
                'calendarUid': task.projectPath,
                'taskUid': task.uid,
              };
              
              final syncResult = await _syncService!.queueSyncOperation(
                SyncOperation.create,
                task.uid,
                syncData,
              );
              
              await syncResult.when(
                success: (_) async {
                  AppLogger.debug('🔄 TaskViewModel: Successfully queued task creation for sync: ${task.uid}');
                },
                failure: (failure) async {
                  AppLogger.warning('TaskViewModel: Failed to queue sync creation for ${task.uid}: ${failure.message}');
                },
              );
            } else {
              AppLogger.warning('🔄 TaskViewModel: Task ${task.uid} has no projectPath - will not be synchronized');
            }
          } else {
            AppLogger.warning('🔄 TaskViewModel: No sync service available - creation will be local only');
          }
          
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
    AppLogger.debug('🔄 TaskViewModel: SyncService available: ${_syncService != null}');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedTask = task.copyWith(
        lastModified: DateTime.now(),
      );

      final result = await _taskRepository.save(updatedTask);
      
      await result.when(
        success: (_) async {
          AppLogger.debug('🔄 TaskViewModel: Task updated successfully: ${task.uid}');
          
          // Queue sync operation to update on server
          if (_syncService != null) {
            // Only queue sync if task has a valid projectPath
            if (updatedTask.projectPath != null && updatedTask.projectPath!.isNotEmpty) {
              AppLogger.debug('🔄 TaskViewModel: Queuing UPDATE operation for ${updatedTask.uid}');
              final syncData = <String, dynamic>{
                'calendarUid': updatedTask.projectPath,
                'taskUid': updatedTask.uid,
              };
              
              final syncResult = await _syncService!.queueSyncOperation(
                SyncOperation.update,
                updatedTask.uid,
                syncData,
              );
              
              await syncResult.when(
                success: (_) async {
                  AppLogger.debug('🔄 TaskViewModel: Successfully queued task update for sync: ${updatedTask.uid}');
                },
                failure: (failure) async {
                  AppLogger.warning('TaskViewModel: Failed to queue sync update for ${updatedTask.uid}: ${failure.message}');
                },
              );
            } else {
              AppLogger.warning('🔄 TaskViewModel: Task ${updatedTask.uid} has no projectPath - will not be synchronized');
            }
          } else {
            AppLogger.warning('🔄 TaskViewModel: No sync service available - update will be local only');
          }
          
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
    AppLogger.debug('🔄 TaskViewModel: SyncService available: ${_syncService != null}');
    
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
          
          // Queue sync operation to delete from server
          if (_syncService != null && taskToDelete != null) {
            // Only queue sync if task has a valid projectPath
            if (taskToDelete.projectPath != null && taskToDelete.projectPath!.isNotEmpty) {
              AppLogger.debug('🔄 TaskViewModel: Queuing DELETE operation for $taskUid');
              final syncData = <String, dynamic>{
                '_serverUrl': null, // Server URL will be resolved during sync
                'calendarUid': taskToDelete.projectPath,
                'taskUid': taskUid,
              };
              
              final syncResult = await _syncService!.queueSyncOperation(
                SyncOperation.delete,
                taskUid,
                syncData,
              );
              
              await syncResult.when(
                success: (_) async {
                  AppLogger.debug('🔄 TaskViewModel: Successfully queued task deletion for sync: $taskUid');
                },
                failure: (failure) async {
                  AppLogger.warning('TaskViewModel: Failed to queue sync deletion for $taskUid: ${failure.message}');
                  // Don't fail the local deletion - sync will retry later
                },
              );
            } else {
              AppLogger.warning('🔄 TaskViewModel: Task $taskUid has no projectPath - will not be synchronized');
            }
          } else {
            AppLogger.warning('🔄 TaskViewModel: No sync service available or task not found - deletion will be local only');
          }
          
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
    AppLogger.debug('🔄 TaskViewModel: SyncService available: ${_syncService != null}');
    
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
          
          // Queue sync operations if sync service is available
          if (_syncService != null) {
            await _queueMoveOperations(movedTask, oldCalendarUid, targetCalendarUid);
          } else {
            AppLogger.warning('🔄 TaskViewModel: No sync service available - move will be local only');
          }
          
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

  /// Queue sync operations for moving a task between calendars
  Future<void> _queueMoveOperations(Task movedTask, String? oldCalendarUid, String targetCalendarUid) async {
    try {
      // Only queue operations if both calendars are valid
      if (oldCalendarUid != null && oldCalendarUid.isNotEmpty && targetCalendarUid.isNotEmpty) {
        AppLogger.debug('🔄 TaskViewModel: Queuing move operations for ${movedTask.uid}');
        
        // Queue DELETE operation from source calendar
        final deleteData = <String, dynamic>{
          'calendarUid': oldCalendarUid,
          'taskUid': movedTask.uid,
        };
        
        final deleteResult = await _syncService!.queueSyncOperation(
          SyncOperation.delete,
          movedTask.uid,
          deleteData,
        );
        
        await deleteResult.when(
          success: (_) async {
            AppLogger.debug('🔄 TaskViewModel: Successfully queued DELETE operation for ${movedTask.uid} from $oldCalendarUid');
          },
          failure: (failure) async {
            AppLogger.warning('TaskViewModel: Failed to queue DELETE operation for ${movedTask.uid}: ${failure.message}');
          },
        );

        // Queue CREATE operation in target calendar
        final createData = <String, dynamic>{
          'calendarUid': targetCalendarUid,
          'taskUid': movedTask.uid,
        };
        
        final createResult = await _syncService!.queueSyncOperation(
          SyncOperation.create,
          movedTask.uid,
          createData,
        );
        
        await createResult.when(
          success: (_) async {
            AppLogger.debug('🔄 TaskViewModel: Successfully queued CREATE operation for ${movedTask.uid} in $targetCalendarUid');
          },
          failure: (failure) async {
            AppLogger.warning('TaskViewModel: Failed to queue CREATE operation for ${movedTask.uid}: ${failure.message}');
          },
        );
      } else {
        AppLogger.warning('🔄 TaskViewModel: Invalid calendar UIDs - oldCalendarUid: $oldCalendarUid, targetCalendarUid: $targetCalendarUid');
      }
    } catch (e, stackTrace) {
      AppLogger.error('TaskViewModel: Exception during move sync operations', e, stackTrace);
    }
  }

  // Clear selected task
  void clearSelectedTask() {
    state = state.copyWith(selectedTask: null);
  }
} 
