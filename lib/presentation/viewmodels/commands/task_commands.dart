// Task-specific commands for the Home screen and task management
// Implements optimistic UI updates and error handling

import '../../../core/command.dart';
import '../../../data/models/task.dart';
import '../../../data/models/attendee.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/services/sync_service.dart';
import '../../../core/logger.dart';
import '../../../core/result.dart';

/// Command to add a new task
class AddTaskCommand extends ParameterizedCommand<Task, AddTaskParams> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final SyncService? _syncService;

  AddTaskCommand(this._taskRepository, this._accountRepository, [this._syncService]);

  @override
  Future<Task> runWith(AddTaskParams params) async {
    AppLogger.info('AddTaskCommand: Creating task with summary "${params.summary}"');

    // Get current user's email to set as organizer
    String? organizer;
    final accountResult = await _accountRepository.getActiveAccount();
    await accountResult.when(
      success: (account) async {
        if (account?.email != null) {
          organizer = account!.email;
        } else if (account?.username != null) {
          organizer = account!.username;
        }
      },
      failure: (failure) async {
        AppLogger.warning('AddTaskCommand: Could not get active account for organizer: ${failure.message}');
      },
    );

    final task = TaskFactory.createNew(
      summary: params.summary,
      description: params.description ?? '',
      due: params.due,
      categories: params.categories,
      projectPath: params.projectPath,
      organizer: organizer,
    );

    final result = await _taskRepository.save(task);
    
    if (result is Success) {
      AppLogger.info('AddTaskCommand: Task created successfully - ${task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null) {
        await _queueCreateSyncOperation(task);
      } else {
        AppLogger.warning('AddTaskCommand: No sync service available - creation will be local only');
      }
      
      return task;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('AddTaskCommand: Failed to create task', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operation for creating a task
  Future<void> _queueCreateSyncOperation(Task task) async {
    try {
      AppLogger.debug('AddTaskCommand: Queuing create operation for ${task.uid}');
      
      final createData = <String, dynamic>{
        'calendarUid': task.projectPath,
        'taskUid': task.uid,
      };
      
      final createResult = await _syncService!.queueSyncOperation(
        SyncOperation.create,
        task.uid,
        createData,
      );
      
      await createResult.when(
        success: (_) async {
          AppLogger.debug('AddTaskCommand: Successfully queued CREATE operation for ${task.uid} in ${task.projectPath}');
        },
        failure: (failure) async {
          AppLogger.warning('AddTaskCommand: Failed to queue CREATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('AddTaskCommand: Exception during create sync operation', e, stackTrace);
    }
  }
}

/// Command to toggle task completion
class ToggleTaskCommand extends ParameterizedCommand<Task, Task> {
  final TaskRepository _taskRepository;

  ToggleTaskCommand(this._taskRepository);

  @override
  Future<Task> runWith(Task task) async {
    // AppLogger.info('ToggleTaskCommand: Toggling completion for task: ${task.uid}');
    
    final newStatus = task.status == 'COMPLETED' ? 'NEEDS-ACTION' : 'COMPLETED';
    final newPercentComplete = newStatus == 'COMPLETED' ? 100 : 0;
    
    final updatedTask = task.copyWith(
      status: newStatus,
      percentComplete: newPercentComplete,
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      // AppLogger.info('ToggleTaskCommand: Task toggled successfully: ${task.uid}');
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('ToggleTaskCommand: Failed to toggle task', failure.message);
      throw Exception(failure.message);
    }
  }
}

/// Command to delete a task
class DeleteTaskCommand extends ParameterizedCommand<void, String> {
  final TaskRepository _taskRepository;

  DeleteTaskCommand(this._taskRepository);

  @override
  Future<void> runWith(String taskUid) async {
    // AppLogger.info('DeleteTaskCommand: Deleting task: $taskUid');

    final result = await _taskRepository.delete(taskUid);
    
    if (result is Success) {
      // AppLogger.info('DeleteTaskCommand: Task deleted successfully: $taskUid');
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('DeleteTaskCommand: Failed to delete task', failure.message);
      throw Exception(failure.message);
    }
  }
}

/// Command to update a task
class UpdateTaskCommand extends ParameterizedCommand<Task, Task> {
  final TaskRepository _taskRepository;

  UpdateTaskCommand(this._taskRepository);

  @override
  Future<Task> runWith(Task task) async {
    // AppLogger.info('UpdateTaskCommand: Updating task: ${task.uid}');
    
    final updatedTask = task.copyWith(
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      // AppLogger.info('UpdateTaskCommand: Task updated successfully: ${task.uid}');
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('UpdateTaskCommand: Failed to update task', failure.message);
      throw Exception(failure.message);
    }
  }
}

/// Command to move a task between calendars/projects
class MoveTaskCommand extends ParameterizedCommand<Task, MoveTaskParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  MoveTaskCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(MoveTaskParams params) async {
    AppLogger.info('MoveTaskCommand: Moving task ${params.task.uid} from ${params.task.projectPath} to ${params.targetCalendarUid}');

    // Check if task is already in the target calendar
    if (params.task.projectPath == params.targetCalendarUid) {
      AppLogger.warning('MoveTaskCommand: Task ${params.task.uid} is already in calendar ${params.targetCalendarUid}');
      return params.task;
    }

    final oldCalendarUid = params.task.projectPath;
    
    // Create updated task with new source calendar
    final movedTask = params.task.copyWith(
      projectPath: params.targetCalendarUid,
      lastModified: DateTime.now(),
    );

    // Save the updated task locally (optimistic UI)
    final result = await _taskRepository.save(movedTask);
    
    if (result is Success) {
      AppLogger.info('MoveTaskCommand: Task moved locally - ${movedTask.uid}');
      
      // Queue sync operations if sync service is available
      if (_syncService != null) {
        await _queueMoveOperations(movedTask, oldCalendarUid, params.targetCalendarUid);
      } else {
        AppLogger.warning('MoveTaskCommand: No sync service available - move will be local only');
      }
      
      return movedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('MoveTaskCommand: Failed to move task', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operations for moving a task between calendars
  Future<void> _queueMoveOperations(Task movedTask, String? oldCalendarUid, String targetCalendarUid) async {
    try {
      // Only queue operations if both calendars are valid
      if (oldCalendarUid != null && oldCalendarUid.isNotEmpty && targetCalendarUid.isNotEmpty) {
        AppLogger.debug('MoveTaskCommand: Queuing move operations for ${movedTask.uid}');
        
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
            AppLogger.debug('MoveTaskCommand: Successfully queued DELETE operation for ${movedTask.uid} from $oldCalendarUid');
          },
          failure: (failure) async {
            AppLogger.warning('MoveTaskCommand: Failed to queue DELETE operation for ${movedTask.uid}: ${failure.message}');
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
            AppLogger.debug('MoveTaskCommand: Successfully queued CREATE operation for ${movedTask.uid} in $targetCalendarUid');
          },
          failure: (failure) async {
            AppLogger.warning('MoveTaskCommand: Failed to queue CREATE operation for ${movedTask.uid}: ${failure.message}');
          },
        );
      } else {
        AppLogger.warning('MoveTaskCommand: Invalid calendar UIDs - oldCalendarUid: $oldCalendarUid, targetCalendarUid: $targetCalendarUid');
      }
    } catch (e, stackTrace) {
      AppLogger.error('MoveTaskCommand: Exception during move sync operations', e, stackTrace);
    }
  }
}

/// Parameters for adding a new task
class AddTaskParams {
  final String summary;
  final String? description;
  final DateTime? due;
  final List<String> categories;
  final String? projectPath;

  AddTaskParams({
    required this.summary,
    this.description,
    this.due,
    this.categories = const [],
    this.projectPath,
  });
}

/// Parameters for moving a task between calendars
class MoveTaskParams {
  final Task task;
  final String targetCalendarUid;

  MoveTaskParams({
    required this.task,
    required this.targetCalendarUid,
  });
} 
