/// Attendee management commands for FlowIt tasks
/// 
/// This file contains commands for managing attendees in tasks, including
/// adding, removing, updating attendees and their status. All commands follow
/// the command pattern and integrate with the sync service to ensure changes
/// are pushed to the CalDAV server.

import '../../../core/command.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../../data/models/task.dart';
import '../../../data/models/attendee.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/sync_service.dart';

/// Command to add an attendee to a task
class AddAttendeeCommand extends ParameterizedCommand<Task, AddAttendeeParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  AddAttendeeCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(AddAttendeeParams params) async {
    AppLogger.info('AddAttendeeCommand: Adding attendee ${params.attendee.email} to task ${params.task.uid}');

    // Check if attendee already exists
    final existingAttendees = params.task.attendees.toList();
    final existingIndex = existingAttendees.indexWhere((a) => a.email == params.attendee.email);
    
    if (existingIndex != -1) {
      // Update existing attendee
      existingAttendees[existingIndex] = params.attendee;
      AppLogger.info('AddAttendeeCommand: Updated existing attendee ${params.attendee.email}');
    } else {
      // Add new attendee
      existingAttendees.add(params.attendee);
      AppLogger.info('AddAttendeeCommand: Added new attendee ${params.attendee.email}');
    }

    final updatedTask = params.task.copyWith(
      attendees: existingAttendees,
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      AppLogger.info('AddAttendeeCommand: Successfully saved task with attendee ${params.task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null && updatedTask.projectPath != null) {
        await _queueUpdateOperation(updatedTask);
      }
      
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('AddAttendeeCommand: Failed to add attendee', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operation for task update
  Future<void> _queueUpdateOperation(Task task) async {
    try {
      final updateData = <String, dynamic>{
        'calendarPath': task.projectPath!,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        updateData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('AddAttendeeCommand: Successfully queued UPDATE operation for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('AddAttendeeCommand: Failed to queue UPDATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('AddAttendeeCommand: Exception during sync operation', e, stackTrace);
    }
  }
}

/// Command to remove an attendee from a task
class RemoveAttendeeCommand extends ParameterizedCommand<Task, RemoveAttendeeParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  RemoveAttendeeCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(RemoveAttendeeParams params) async {
    AppLogger.info('RemoveAttendeeCommand: Removing attendee ${params.attendeeEmail} from task ${params.task.uid}');

    final existingAttendees = params.task.attendees.toList();
    final attendeeIndex = existingAttendees.indexWhere((a) => a.email == params.attendeeEmail);
    
    if (attendeeIndex == -1) {
      AppLogger.warning('RemoveAttendeeCommand: Attendee ${params.attendeeEmail} not found in task ${params.task.uid}');
      return params.task; // No changes needed
    }

    // Remove attendee
    existingAttendees.removeAt(attendeeIndex);
    
    final updatedTask = params.task.copyWith(
      attendees: existingAttendees,
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      AppLogger.info('RemoveAttendeeCommand: Successfully removed attendee from task ${params.task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null && updatedTask.projectPath != null) {
        await _queueUpdateOperation(updatedTask);
      }
      
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('RemoveAttendeeCommand: Failed to remove attendee', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operation for task update
  Future<void> _queueUpdateOperation(Task task) async {
    try {
      final updateData = <String, dynamic>{
        'calendarPath': task.projectPath!,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        updateData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('RemoveAttendeeCommand: Successfully queued UPDATE operation for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('RemoveAttendeeCommand: Failed to queue UPDATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('RemoveAttendeeCommand: Exception during sync operation', e, stackTrace);
    }
  }
}

/// Command to update an attendee's status or other properties
class UpdateAttendeeCommand extends ParameterizedCommand<Task, UpdateAttendeeParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  UpdateAttendeeCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(UpdateAttendeeParams params) async {
    AppLogger.info('UpdateAttendeeCommand: Updating attendee ${params.attendee.email} in task ${params.task.uid}');

    final existingAttendees = params.task.attendees;
    final attendeeIndex = existingAttendees.indexWhere((a) => a.email == params.attendee.email);
    
    if (attendeeIndex == -1) {
      AppLogger.error('UpdateAttendeeCommand: Attendee ${params.attendee.email} not found in task ${params.task.uid}');
      throw Exception('Attendee not found in task');
    }

    // Update attendee
    final updatedAttendees = List<Attendee>.from(existingAttendees);
    updatedAttendees[attendeeIndex] = params.attendee;
    
    final updatedTask = params.task.copyWith(
      attendees: updatedAttendees,
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      AppLogger.info('UpdateAttendeeCommand: Successfully updated attendee in task ${params.task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null && updatedTask.projectPath != null) {
        await _queueUpdateOperation(updatedTask);
      }
      
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('UpdateAttendeeCommand: Failed to update attendee', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operation for task update
  Future<void> _queueUpdateOperation(Task task) async {
    try {
      final updateData = <String, dynamic>{
        'calendarPath': task.projectPath!,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        updateData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('UpdateAttendeeCommand: Successfully queued UPDATE operation for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('UpdateAttendeeCommand: Failed to queue UPDATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UpdateAttendeeCommand: Exception during sync operation', e, stackTrace);
    }
  }
}

/// Command to update attendee response status (accept/decline/tentative)
class UpdateAttendeeStatusCommand extends ParameterizedCommand<Task, UpdateAttendeeStatusParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  UpdateAttendeeStatusCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(UpdateAttendeeStatusParams params) async {
    AppLogger.info('UpdateAttendeeStatusCommand: Updating status for attendee ${params.attendeeEmail} to ${params.status.value} in task ${params.task.uid}');

    final existingAttendees = params.task.attendees;
    final attendeeIndex = existingAttendees.indexWhere((a) => a.email == params.attendeeEmail);
    
    if (attendeeIndex == -1) {
      AppLogger.error('UpdateAttendeeStatusCommand: Attendee ${params.attendeeEmail} not found in task ${params.task.uid}');
      throw Exception('Attendee not found in task');
    }

    // Update attendee status
    final existingAttendee = existingAttendees[attendeeIndex];
    final updatedAttendee = existingAttendee.copyWith(status: params.status);
    
    final updatedAttendees = List<Attendee>.from(existingAttendees);
    updatedAttendees[attendeeIndex] = updatedAttendee;
    
    final updatedTask = params.task.copyWith(
      attendees: updatedAttendees,
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      AppLogger.info('UpdateAttendeeStatusCommand: Successfully updated attendee status in task ${params.task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null && updatedTask.projectPath != null) {
        await _queueUpdateOperation(updatedTask);
      }
      
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('UpdateAttendeeStatusCommand: Failed to update attendee status', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operation for task update
  Future<void> _queueUpdateOperation(Task task) async {
    try {
      final updateData = <String, dynamic>{
        'calendarPath': task.projectPath!,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        updateData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('UpdateAttendeeStatusCommand: Successfully queued UPDATE operation for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('UpdateAttendeeStatusCommand: Failed to queue UPDATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UpdateAttendeeStatusCommand: Exception during sync operation', e, stackTrace);
    }
  }
}

/// Parameters for AddAttendeeCommand
class AddAttendeeParams {
  final Task task;
  final Attendee attendee;

  const AddAttendeeParams({
    required this.task,
    required this.attendee,
  });
}

/// Parameters for RemoveAttendeeCommand  
class RemoveAttendeeParams {
  final Task task;
  final String attendeeEmail;

  const RemoveAttendeeParams({
    required this.task,
    required this.attendeeEmail,
  });
}

/// Parameters for UpdateAttendeeCommand
class UpdateAttendeeParams {
  final Task task;
  final Attendee attendee;

  const UpdateAttendeeParams({
    required this.task,
    required this.attendee,
  });
}

/// Parameters for UpdateAttendeeStatusCommand
class UpdateAttendeeStatusParams {
  final Task task;
  final String attendeeEmail;
  final AttendeeStatus status;

  const UpdateAttendeeStatusParams({
    required this.task,
    required this.attendeeEmail,
    required this.status,
  });
}

/// Command to assign attendee to task via drag and drop
class AssignAttendeeToTaskCommand extends ParameterizedCommand<Task, AssignAttendeeToTaskParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  AssignAttendeeToTaskCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(AssignAttendeeToTaskParams params) async {
    AppLogger.info('AssignAttendeeToTaskCommand: Assigning attendee ${params.attendeeEmail} to task ${params.task.uid}');

    // Check if this attendee is already the only attendee
    final existingAttendees = params.task.attendees.toList();
    if (existingAttendees.length == 1 && existingAttendees.first.email == params.attendeeEmail) {
      // Attendee is already the only attendee, no changes needed
      AppLogger.info('AssignAttendeeToTaskCommand: Attendee is already the only attendee, no changes needed');
      return params.task;
    }

    // Create new attendee with default settings
    final newAttendee = Attendee(
      email: params.attendeeEmail,
      displayName: _extractDisplayName(params.attendeeEmail),
      status: AttendeeStatus.needsAction,
      role: AttendeeRole.requiredParticipant,
      userType: CalendarUserType.individual,
      rsvpRequested: false,
    );

    // Replace all existing attendees with the new one (drag-and-drop behavior)
    final updatedAttendees = [newAttendee];
    
    if (existingAttendees.isEmpty) {
      AppLogger.info('AssignAttendeeToTaskCommand: Adding first attendee ${params.attendeeEmail}');
    } else if (existingAttendees.length == 1) {
      AppLogger.info('AssignAttendeeToTaskCommand: Replacing attendee ${existingAttendees.first.email} with ${params.attendeeEmail}');
    } else {
      AppLogger.info('AssignAttendeeToTaskCommand: Replacing ${existingAttendees.length} attendees with ${params.attendeeEmail}');
    }

    final updatedTask = params.task.copyWith(
      attendees: updatedAttendees,
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      AppLogger.info('AssignAttendeeToTaskCommand: Successfully assigned attendee to task ${params.task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null && updatedTask.projectPath != null) {
        await _queueUpdateOperation(updatedTask);
      }
      
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('AssignAttendeeToTaskCommand: Failed to assign attendee', failure.message);
      throw Exception(failure.message);
    }
  }

  String? _extractDisplayName(String email) {
    if (email.contains('@')) {
      final namePart = email.split('@').first;
      // Capitalize and replace separators with spaces
      return namePart
          .replaceAll(RegExp(r'[.\-_]'), ' ')
          .split(' ')
          .map((word) => word.isNotEmpty 
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : word)
          .join(' ');
    }
    return null;
  }

  /// Queue sync operation for task update
  Future<void> _queueUpdateOperation(Task task) async {
    try {
      final updateData = <String, dynamic>{
        'calendarUid': task.projectPath!,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        updateData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('AssignAttendeeToTaskCommand: Successfully queued UPDATE operation for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('AssignAttendeeToTaskCommand: Failed to queue UPDATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('AssignAttendeeToTaskCommand: Exception during sync operation', e, stackTrace);
    }
  }
}

/// Command to remove all attendees from task (unassign)
class UnassignAllAttendeesCommand extends ParameterizedCommand<Task, UnassignAllAttendeesParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  UnassignAllAttendeesCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(UnassignAllAttendeesParams params) async {
    AppLogger.info('UnassignAllAttendeesCommand: Removing all attendees from task ${params.task.uid}');

    final updatedTask = params.task.copyWith(
      attendees: <Attendee>[],
      lastModified: DateTime.now(),
    );

    final result = await _taskRepository.save(updatedTask);
    
    if (result is Success) {
      AppLogger.info('UnassignAllAttendeesCommand: Successfully unassigned all attendees from task ${params.task.uid}');
      
      // Queue sync operation if sync service is available
      if (_syncService != null && updatedTask.projectPath != null) {
        await _queueUpdateOperation(updatedTask);
      }
      
      return updatedTask;
    } else {
      final failure = (result as Error<void>).failure;
      AppLogger.error('UnassignAllAttendeesCommand: Failed to unassign attendees', failure.message);
      throw Exception(failure.message);
    }
  }

  /// Queue sync operation for task update
  Future<void> _queueUpdateOperation(Task task) async {
    try {
      final updateData = <String, dynamic>{
        'calendarUid': task.projectPath!,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        updateData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('UnassignAllAttendeesCommand: Successfully queued UPDATE operation for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('UnassignAllAttendeesCommand: Failed to queue UPDATE operation for ${task.uid}: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UnassignAllAttendeesCommand: Exception during sync operation', e, stackTrace);
    }
  }
}

/// Parameters for AssignAttendeeToTaskCommand
class AssignAttendeeToTaskParams {
  final Task task;
  final String attendeeEmail;

  const AssignAttendeeToTaskParams({
    required this.task,
    required this.attendeeEmail,
  });
}

/// Parameters for UnassignAllAttendeesCommand  
class UnassignAllAttendeesParams {
  final Task task;

  const UnassignAllAttendeesParams({
    required this.task,
  });
} 