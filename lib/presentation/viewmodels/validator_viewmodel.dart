// Validator ViewModel for managing task validation
// Handles validator state updates, additions, and task completion with validation

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/validator_service.dart';
import '../../core/logger.dart';
import './commands/validator_commands.dart';

/// Validator ViewModel State
class ValidatorViewModelState {
  final bool isLoading;
  final String? error;
  final String? currentTaskUid;
  final List<List<Map<String, dynamic>>> validators;
  final bool canEdit;
  final bool canInteract;

  const ValidatorViewModelState({
    this.isLoading = false,
    this.error,
    this.currentTaskUid,
    this.validators = const [],
    this.canEdit = false,
    this.canInteract = false,
  });

  ValidatorViewModelState copyWith({
    bool? isLoading,
    String? error,
    String? currentTaskUid,
    List<List<Map<String, dynamic>>>? validators,
    bool? canEdit,
    bool? canInteract,
  }) {
    return ValidatorViewModelState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      currentTaskUid: currentTaskUid ?? this.currentTaskUid,
      validators: validators ?? this.validators,
      canEdit: canEdit ?? this.canEdit,
      canInteract: canInteract ?? this.canInteract,
    );
  }

  /// Check if all required validators are completed
  bool get areValidatorsCompleted => ValidatorService.areValidatorsCompleted(validators);

  /// Check if task has any validators
  bool get hasValidators => validators.isNotEmpty && validators.any((list) => list.isNotEmpty);

  /// Get all validators flattened for easier UI rendering
  List<Map<String, dynamic>> get allValidators => validators.expand((list) => list).toList();
}

/// Validator ViewModel
class ValidatorViewModel extends StateNotifier<ValidatorViewModelState> {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final SyncService? _syncService;
  
  // Commands
  late final UpdateValidatorStateCommand _updateValidatorCommand;
  late final AddValidatorFromTemplateCommand _addValidatorCommand;
  late final RemoveValidatorCommand _removeValidatorCommand;

  ValidatorViewModel(this._taskRepository, this._accountRepository, [this._syncService]) 
      : super(const ValidatorViewModelState()) {
    
    // Initialize commands
    _updateValidatorCommand = UpdateValidatorStateCommand(_taskRepository, _syncService);
    _addValidatorCommand = AddValidatorFromTemplateCommand(_taskRepository, _accountRepository, _syncService);
    _removeValidatorCommand = RemoveValidatorCommand(_taskRepository, _accountRepository, _syncService);
  }

  /// Load validators for a specific task
  Future<void> loadValidatorsForTask(Task task) async {
    AppLogger.debug('ValidatorViewModel: Loading validators for task ${task.uid}');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current user email for permission checks
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

      // Parse validators from task
      final validators = ValidatorService.parseValidators(task.flowitValidator);
      
      // Check permissions
      final canEdit = ValidatorService.canEditValidators(task.organizer, currentUserEmail);
      final canInteract = ValidatorService.canInteractWithValidators(
        task.organizer,
        task.attendees.map((a) => {'email': a.email}).toList(),
        currentUserEmail,
      );

      state = state.copyWith(
        isLoading: false,
        currentTaskUid: task.uid,
        validators: validators,
        canEdit: canEdit,
        canInteract: canInteract,
      );

      AppLogger.debug('ValidatorViewModel: Loaded ${validators.length} validator lists for task ${task.uid}');
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorViewModel: Failed to load validators', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load validators: $e',
      );
    }
  }

  /// Update validator state (checkbox, selection, text input)
  Future<void> updateValidatorState(String validatorId, dynamic newState) async {
    if (state.currentTaskUid == null) return;
    
    AppLogger.debug('ValidatorViewModel: Updating validator $validatorId with state: $newState');
    
    if (!state.canInteract) {
      state = state.copyWith(error: 'You do not have permission to interact with this task\'s validators');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = UpdateValidatorStateParams(
        taskUid: state.currentTaskUid!,
        validatorId: validatorId,
        newState: newState,
      );

      final updatedTask = await _updateValidatorCommand.executeWith(params);
      
      if (updatedTask != null) {
        // Reload validators from updated task
        await loadValidatorsForTask(updatedTask);
        AppLogger.debug('ValidatorViewModel: Validator state updated successfully');
      } else {
        throw Exception(_updateValidatorCommand.error ?? 'Failed to update validator state');
      }
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorViewModel: Failed to update validator state', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update validator: $e',
      );
    }
  }

  /// Add a validator from template
  Future<void> addValidatorFromTemplate({
    required String templateType,
    required String title,
    required List<String> options,
    String? helper,
    bool required = true,
  }) async {
    if (state.currentTaskUid == null) return;
    
    AppLogger.debug('ValidatorViewModel: Adding $templateType validator: $title');
    
    if (!state.canEdit) {
      state = state.copyWith(error: 'You do not have permission to add validators to this task');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = AddValidatorFromTemplateParams(
        taskUid: state.currentTaskUid!,
        templateType: templateType,
        title: title,
        options: options,
        helper: helper,
        required: required,
      );

      final updatedTask = await _addValidatorCommand.executeWith(params);
      
      if (updatedTask != null) {
        // Reload validators from updated task
        await loadValidatorsForTask(updatedTask);
        AppLogger.debug('ValidatorViewModel: Validator added successfully');
      } else {
        throw Exception(_addValidatorCommand.error ?? 'Failed to add validator');
      }
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorViewModel: Failed to add validator', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add validator: $e',
      );
    }
  }

  /// Remove a validator
  Future<void> removeValidator(String validatorId) async {
    if (state.currentTaskUid == null) return;
    
    AppLogger.debug('ValidatorViewModel: Removing validator $validatorId');
    
    if (!state.canEdit) {
      state = state.copyWith(error: 'You do not have permission to remove validators from this task');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final params = UpdateValidatorStateParams(
        taskUid: state.currentTaskUid!,
        validatorId: validatorId,
        newState: null, // Not used for removal
      );

      final updatedTask = await _removeValidatorCommand.executeWith(params);
      
      if (updatedTask != null) {
        // Reload validators from updated task
        await loadValidatorsForTask(updatedTask);
        AppLogger.debug('ValidatorViewModel: Validator removed successfully');
      } else {
        throw Exception(_removeValidatorCommand.error ?? 'Failed to remove validator');
      }
    } catch (e, stackTrace) {
      AppLogger.error('ValidatorViewModel: Failed to remove validator', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to remove validator: $e',
      );
    }
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear validator state
  void clearState() {
    state = const ValidatorViewModelState();
  }

  @override
  void dispose() {
    _updateValidatorCommand.dispose();
    _addValidatorCommand.dispose();
    _removeValidatorCommand.dispose();
    super.dispose();
  }
} 