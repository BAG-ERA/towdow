// Validator-specific commands for task validation management
// Implements optimistic UI updates and immediate sync for validator changes, additions, and completions

import '../../../core/command.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/services/sync_service.dart';
import '../../../data/services/validator_service.dart';
import '../../../core/logger.dart';
import '../../../core/result.dart';

/// Parameters for updating validator state
class UpdateValidatorStateParams {
  final String taskUid;
  final String validatorId;
  final dynamic newState;

  const UpdateValidatorStateParams({
    required this.taskUid,
    required this.validatorId,
    required this.newState,
  });
}

/// Parameters for adding a validator
class AddValidatorParams {
  final String taskUid;
  final String validatorType;
  final String title;
  final Map<String, dynamic> config;

  const AddValidatorParams({
    required this.taskUid,
    required this.validatorType,
    required this.title,
    required this.config,
  });
}

/// Parameters for validator template addition
class AddValidatorFromTemplateParams {
  final String taskUid;
  final String templateType;
  final String title;
  final List<String> options;
  final String? helper;
  final bool required;

  const AddValidatorFromTemplateParams({
    required this.taskUid,
    required this.templateType,
    required this.title,
    required this.options,
    this.helper,
    this.required = true,
  });
}

/// Parameters for completing a task with validators
class CompleteTaskWithValidatorsParams {
  final Task task;
  final String? currentUserEmail;

  const CompleteTaskWithValidatorsParams({
    required this.task,
    this.currentUserEmail,
  });
}

/// Command to update validator state (checklist item, selection, text field)
class UpdateValidatorStateCommand extends ParameterizedCommand<Task, UpdateValidatorStateParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  UpdateValidatorStateCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(UpdateValidatorStateParams params) async {
    AppLogger.debug('UpdateValidatorStateCommand: Updating validator ${params.validatorId} for task ${params.taskUid}');

    // Get current task
    final taskResult = await _taskRepository.getById(params.taskUid);
    
    return await taskResult.when(
      success: (task) async {
        if (task == null) {
          throw Exception('Task not found: ${params.taskUid}');
        }

        // Parse current validators
        final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
        
        // Update validator state
        final updatedValidatorLists = ValidatorService.updateValidatorState(
          validatorLists,
          params.validatorId,
          params.newState,
        );

        // Create updated task
        final updatedTask = task.copyWith(
          flowitValidator: ValidatorService.serializeValidators(updatedValidatorLists),
          lastModified: DateTime.now(),
        );

        // Save locally first (optimistic UI)
        final saveResult = await _taskRepository.save(updatedTask);
        
        return await saveResult.when(
          success: (_) async {
            AppLogger.debug('UpdateValidatorStateCommand: Validator state updated locally for ${params.taskUid}');
            
            // Queue immediate sync if available
            await _queueSyncOperation(updatedTask);
            
            return updatedTask;
          },
          failure: (failure) async {
            AppLogger.error('UpdateValidatorStateCommand: Failed to save validator state', failure.message);
            throw Exception(failure.message);
          },
        );
      },
      failure: (failure) async {
        AppLogger.error('UpdateValidatorStateCommand: Failed to get task', failure.message);
        throw Exception(failure.message);
      },
    );
  }

  Future<void> _queueSyncOperation(Task task) async {
    if (_syncService != null && task.sourceCalendarUid != null && task.sourceCalendarUid!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarUid': task.sourceCalendarUid,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        syncData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('UpdateValidatorStateCommand: Queued sync for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('UpdateValidatorStateCommand: Failed to queue sync: ${failure.message}');
        },
      );
    }
  }
}

/// Command to add a validator from template
class AddValidatorFromTemplateCommand extends ParameterizedCommand<Task, AddValidatorFromTemplateParams> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final SyncService? _syncService;

  AddValidatorFromTemplateCommand(this._taskRepository, this._accountRepository, [this._syncService]);

  @override
  Future<Task> runWith(AddValidatorFromTemplateParams params) async {
    AppLogger.debug('AddValidatorFromTemplateCommand: Adding ${params.templateType} validator to task ${params.taskUid}');

    // Get current user email to check permissions
    String? currentUserEmail;
    final accountResult = await _accountRepository.getActiveAccount();
    await accountResult.when(
      success: (account) async {
        currentUserEmail = account?.email ?? account?.username;
      },
      failure: (_) async {
        // Continue without user email - permission check will fail gracefully
      },
    );

    // Get current task
    final taskResult = await _taskRepository.getById(params.taskUid);
    
    return await taskResult.when(
      success: (task) async {
        if (task == null) {
          throw Exception('Task not found: ${params.taskUid}');
        }

        // Check permissions - only organizer can add validators
        if (!ValidatorService.canEditValidators(task.organizer, currentUserEmail)) {
          throw Exception('You do not have permission to add validators to this task');
        }

        // Create validator based on template type
        final validator = _createValidatorFromTemplate(params);
        
        // Parse current validators and add new one
        final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
        final updatedValidatorLists = ValidatorService.addValidator(validatorLists, validator);

        // Create updated task
        final updatedTask = task.copyWith(
          flowitValidator: ValidatorService.serializeValidators(updatedValidatorLists),
          lastModified: DateTime.now(),
        );

        // Save locally first (optimistic UI)
        final saveResult = await _taskRepository.save(updatedTask);
        
        return await saveResult.when(
          success: (_) async {
            AppLogger.debug('AddValidatorFromTemplateCommand: Validator added locally to ${params.taskUid}');
            
            // Queue immediate sync if available
            await _queueSyncOperation(updatedTask);
            
            return updatedTask;
          },
          failure: (failure) async {
            AppLogger.error('AddValidatorFromTemplateCommand: Failed to save validator', failure.message);
            throw Exception(failure.message);
          },
        );
      },
      failure: (failure) async {
        AppLogger.error('AddValidatorFromTemplateCommand: Failed to get task', failure.message);
        throw Exception(failure.message);
      },
    );
  }

  Map<String, dynamic> _createValidatorFromTemplate(AddValidatorFromTemplateParams params) {
    switch (params.templateType) {
      case 'checklist':
        return ValidatorService.createChecklistValidator(
          title: params.title,
          itemTexts: params.options,
          required: params.required,
        );
      case 'single_select':
        return ValidatorService.createSingleSelectValidator(
          title: params.title,
          optionTexts: params.options,
          required: params.required,
        );
      case 'free_field':
        return ValidatorService.createFreeFieldValidator(
          title: params.title,
          helper: params.helper,
          required: params.required,
        );
      default:
        throw Exception('Unknown validator template type: ${params.templateType}');
    }
  }

  Future<void> _queueSyncOperation(Task task) async {
    if (_syncService != null && task.sourceCalendarUid != null && task.sourceCalendarUid!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarUid': task.sourceCalendarUid,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        syncData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('AddValidatorFromTemplateCommand: Queued sync for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('AddValidatorFromTemplateCommand: Failed to queue sync: ${failure.message}');
        },
      );
    }
  }
}

/// Command to remove a validator
class RemoveValidatorCommand extends ParameterizedCommand<Task, UpdateValidatorStateParams> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final SyncService? _syncService;

  RemoveValidatorCommand(this._taskRepository, this._accountRepository, [this._syncService]);

  @override
  Future<Task> runWith(UpdateValidatorStateParams params) async {
    AppLogger.debug('RemoveValidatorCommand: Removing validator ${params.validatorId} from task ${params.taskUid}');

    // Get current user email to check permissions
    String? currentUserEmail;
    final accountResult = await _accountRepository.getActiveAccount();
    await accountResult.when(
      success: (account) async {
        currentUserEmail = account?.email ?? account?.username;
      },
      failure: (_) async {
        // Continue without user email - permission check will fail gracefully
      },
    );

    // Get current task
    final taskResult = await _taskRepository.getById(params.taskUid);
    
    return await taskResult.when(
      success: (task) async {
        if (task == null) {
          throw Exception('Task not found: ${params.taskUid}');
        }

        // Check permissions - only organizer can remove validators
        if (!ValidatorService.canEditValidators(task.organizer, currentUserEmail)) {
          throw Exception('You do not have permission to remove validators from this task');
        }

        // Parse current validators and remove the specified one
        final validatorLists = ValidatorService.parseValidators(task.flowitValidator);
        final updatedValidatorLists = ValidatorService.removeValidator(validatorLists, params.validatorId);

        // Create updated task
        final updatedTask = task.copyWith(
          flowitValidator: ValidatorService.serializeValidators(updatedValidatorLists),
          lastModified: DateTime.now(),
        );

        // Save locally first (optimistic UI)
        final saveResult = await _taskRepository.save(updatedTask);
        
        return await saveResult.when(
          success: (_) async {
            AppLogger.debug('RemoveValidatorCommand: Validator removed locally from ${params.taskUid}');
            
            // Queue immediate sync if available
            await _queueSyncOperation(updatedTask);
            
            return updatedTask;
          },
          failure: (failure) async {
            AppLogger.error('RemoveValidatorCommand: Failed to save validator removal', failure.message);
            throw Exception(failure.message);
          },
        );
      },
      failure: (failure) async {
        AppLogger.error('RemoveValidatorCommand: Failed to get task', failure.message);
        throw Exception(failure.message);
      },
    );
  }

  Future<void> _queueSyncOperation(Task task) async {
    if (_syncService != null && task.sourceCalendarUid != null && task.sourceCalendarUid!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarUid': task.sourceCalendarUid,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        syncData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('RemoveValidatorCommand: Queued sync for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('RemoveValidatorCommand: Failed to queue sync: ${failure.message}');
        },
      );
    }
  }
}

/// Command to complete a task with validator validation
class CompleteTaskWithValidatorsCommand extends ParameterizedCommand<Task, CompleteTaskWithValidatorsParams> {
  final TaskRepository _taskRepository;
  final SyncService? _syncService;

  CompleteTaskWithValidatorsCommand(this._taskRepository, [this._syncService]);

  @override
  Future<Task> runWith(CompleteTaskWithValidatorsParams params) async {
    AppLogger.debug('CompleteTaskWithValidatorsCommand: Attempting to complete task ${params.task.uid}');

    // Parse validators and check completion
    final validatorLists = ValidatorService.parseValidators(params.task.flowitValidator);
    
    // Check if all required validators are completed
    if (!ValidatorService.areValidatorsCompleted(validatorLists)) {
      throw Exception('All required validators must be completed before marking the task as done');
    }

    // Create completed task
    final completedTask = params.task.copyWith(
      status: 'COMPLETED',
      percentComplete: 100,
      lastModified: DateTime.now(),
    );

    // Save locally first (optimistic UI)
    final saveResult = await _taskRepository.save(completedTask);
    
    return await saveResult.when(
      success: (_) async {
        AppLogger.debug('CompleteTaskWithValidatorsCommand: Task completed locally ${params.task.uid}');
        
        // Queue immediate sync if available
        await _queueSyncOperation(completedTask);
        
        return completedTask;
      },
      failure: (failure) async {
        AppLogger.error('CompleteTaskWithValidatorsCommand: Failed to save completion', failure.message);
        throw Exception(failure.message);
      },
    );
  }

  Future<void> _queueSyncOperation(Task task) async {
    if (_syncService != null && task.sourceCalendarUid != null && task.sourceCalendarUid!.isNotEmpty) {
      final syncData = <String, dynamic>{
        'calendarUid': task.sourceCalendarUid,
        'taskUid': task.uid,
      };
      
      final syncResult = await _syncService!.queueSyncOperation(
        SyncOperation.update,
        task.uid,
        syncData,
      );
      
      await syncResult.when(
        success: (_) async {
          AppLogger.debug('CompleteTaskWithValidatorsCommand: Queued sync for ${task.uid}');
        },
        failure: (failure) async {
          AppLogger.warning('CompleteTaskWithValidatorsCommand: Failed to queue sync: ${failure.message}');
        },
      );
    }
  }
} 