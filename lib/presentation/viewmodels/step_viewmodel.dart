// Step ViewModel for managing project steps (MVVM)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/logger.dart';
import '../../data/models/step.dart';
import '../../data/repositories/step_repository.dart';

part 'step_viewmodel.freezed.dart';

@freezed
class StepViewModelState with _$StepViewModelState {
  const factory StepViewModelState({
    @Default([]) List<ProjectStep> steps,
    @Default(false) bool isLoading,
    @Default(false) bool isCreating,
    @Default(false) bool isUpdating,
    @Default(false) bool isDeleting,
    String? error,
    String? currentProjectPath,
  }) = _StepViewModelState;
}

class StepViewModel extends StateNotifier<StepViewModelState> {
  final StepRepository _stepRepository;
  StepViewModel(this._stepRepository) : super(const StepViewModelState());

  Future<void> initialize([String? projectPath]) async {
    // Normalize project path to match repository storage (encode special chars like '@')
    final normalizedPath = projectPath?.replaceAll('@', '%40');
    state = state.copyWith(isLoading: true, error: null, currentProjectPath: normalizedPath);
    try {
      await _stepRepository.initialize();
      await _loadSteps();
    } catch (e) {
      AppLogger.error('StepViewModel: initialize failed', e);
      state = state.copyWith(isLoading: false, error: 'Failed to initialize steps: $e');
    }
  }

  Future<void> _loadSteps() async {
    final projectPath = state.currentProjectPath;
    if (projectPath == null) {
      state = state.copyWith(steps: [], isLoading: false);
      return;
    }
    final res = await _stepRepository.getProjectSteps(projectPath);
    await res.when(
      success: (list) async => state = state.copyWith(steps: list, isLoading: false),
      failure: (f) async => state = state.copyWith(isLoading: false, error: f.message),
    );
  }

  Future<void> createStep({
    required String id,
    required String name,
    required int order,
    List<String> dependsOn = const [],
    bool endWorkflow = false,
  }) async {
    final projectPath = state.currentProjectPath;
    if (projectPath == null) {
      state = state.copyWith(error: 'No project selected for step creation');
      return;
    }
    state = state.copyWith(isCreating: true, error: null);
    final res = await _stepRepository.createStep(
      projectPath: projectPath,
      name: name,
      order: order,
      dependsOn: dependsOn,
      endWorkflow: endWorkflow,
    );
    await res.when(
      success: (_) async {
        await _loadSteps();
        state = state.copyWith(isCreating: false);
      },
      failure: (f) async => state = state.copyWith(isCreating: false, error: f.message),
    );
  }

  Future<void> updateStep(ProjectStep updated) async {
    state = state.copyWith(isUpdating: true, error: null);
    final res = await _stepRepository.updateStep(updated);
    await res.when(
      success: (_) async {
        await _loadSteps();
        state = state.copyWith(isUpdating: false);
      },
      failure: (f) async => state = state.copyWith(isUpdating: false, error: f.message),
    );
  }

  Future<void> deleteStep(String stepId) async {
    state = state.copyWith(isDeleting: true, error: null);
    final res = await _stepRepository.deleteStep(stepId);
    await res.when(
      success: (_) async {
        await _loadSteps();
        state = state.copyWith(isDeleting: false);
      },
      failure: (f) async => state = state.copyWith(isDeleting: false, error: f.message),
    );
  }

  Future<void> reorder(List<String> ids) async {
    final projectPath = state.currentProjectPath;
    if (projectPath == null) return;
    final res = await _stepRepository.reorderSteps(projectPath, ids);
    await res.when(
      success: (_) async => _loadSteps(),
      failure: (f) async => state = state.copyWith(error: f.message),
    );
  }

  Future<void> recompute() async {
    final projectPath = state.currentProjectPath;
    if (projectPath == null) return;
    await _stepRepository.recomputeProjectSteps(projectPath);
    await _loadSteps();
  }
}


