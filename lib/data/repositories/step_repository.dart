// StepRepository for managing project steps
// Provides CRUD operations and status recomputation following repository pattern

import '../models/step.dart';
import '../models/task.dart';
import '../models/task_calendar.dart';
import 'calendar_repository.dart';
import 'task_repository.dart';
import '../services/sync/sync_service.dart';
import 'calendar_repository.dart' show SyncCommander;
import '../../core/result.dart';
import '../../core/logger.dart';

class StepRepository {
  final CalendarRepository _calendarRepository;
  final TaskRepository _taskRepository;
  final SyncCommander? _sync;

  final Map<String, ProjectStep> _stepCache = {};
  final Map<String, Set<String>> _projectStepsMap = {};
  String? _lastSignature;

  StepRepository(this._calendarRepository, this._taskRepository, {SyncCommander? sync}) : _sync = sync;

  Future<Result<void>> initialize() async {
    AppLogger.info('StepRepository: Initializing step cache');
    final calendarsResult = await _calendarRepository.getAll();
    return calendarsResult.when(
      success: (calendars) async {
        _initializeFromCalendars(calendars);
        return const Result.success(null);
      },
      failure: (f) async => Result.failure(f),
    );
  }

  /// Refresh cache only if the calendars' steps signature changed
  Future<void> refreshIfChanged(List<TaskCalendar> calendars) async {
    final newSignature = _computeSignature(calendars);
    if (newSignature != _lastSignature) {
      AppLogger.info('StepRepository: Detected steps change; rebuilding cache');
      _initializeFromCalendars(calendars);
      _lastSignature = newSignature;
    }
  }

  void _initializeFromCalendars(List<TaskCalendar> calendars) {
    _stepCache.clear();
    _projectStepsMap.clear();
    for (final calendar in calendars) {
      final steps = calendar.projectStepsList;
      final ids = <String>{};
      for (final step in steps) {
        _stepCache[step.id] = step;
        ids.add(step.id);
      }
      _projectStepsMap[calendar.path] = ids;
    }
  }

  String _computeSignature(List<TaskCalendar> calendars) {
    // Build a deterministic string from project path + projectSteps JSON
    final buffer = StringBuffer();
    final sorted = [...calendars]..sort((a, b) => a.path.compareTo(b.path));
    for (final cal in sorted) {
      buffer.write(cal.path);
      buffer.write('|');
      buffer.write(cal.projectSteps);
      buffer.write(';');
    }
    return buffer.toString();
  }

  Future<Result<List<ProjectStep>>> getProjectSteps(String projectPath) async {
    if (_stepCache.isEmpty) {
      await initialize();
    }
    final ids = _projectStepsMap[projectPath] ?? <String>{};
    final steps = ids
        .map((id) => _stepCache[id])
        .whereType<ProjectStep>()
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Result.success(steps);
  }

  Future<Result<ProjectStep?>> getStepById(String stepId) async {
    if (_stepCache.isEmpty) {
      await initialize();
    }
    return Result.success(_stepCache[stepId]);
  }

  Future<Result<ProjectStep>> createStep({
    required String projectPath,
    required String name,
    int order = 0,
    List<String> dependsOn = const [],
    bool endWorkflow = false,
    StepStatus status = StepStatus.waiting,
  }) async {
    // Always generate id via model factory
    final step = ProjectStep.create(
      name: name,
      order: order,
      dependsOn: dependsOn,
      endWorkflow: endWorkflow,
      status: status,
    );
    final calRes = await _calendarRepository.getByPath(projectPath);
    return calRes.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(Failure(message: 'Project not found: $projectPath'));
        }
        final updated = calendar.addOrUpdateStep(step);
        final saveRes = await _calendarRepository.save(updated);
        return saveRes.when(
          success: (_) async {
            _stepCache[step.id] = step;
            _projectStepsMap[projectPath] ??= <String>{};
            _projectStepsMap[projectPath]!.add(step.id);
            await _queueCalendarUpdate(updated.path);
            return Result.success(step);
          },
          failure: (f) async => Result.failure(f),
        );
      },
      failure: (f) async => Result.failure(f),
    );
  }

  /// Ensure a default first step exists for the project (id auto-generated)
  Future<Result<void>> ensureDefaultStep(String projectPath) async {
    final calRes = await _calendarRepository.getByPath(projectPath);
    return calRes.when(
      success: (calendar) async {
        if (calendar == null) return const Result.success(null);
        if (calendar.projectStepsList.isNotEmpty) return const Result.success(null);
        final createRes = await createStep(
          projectPath: projectPath,
          name: 'Step 1',
          order: 0,
        );
        return createRes.when(
          success: (_) async => const Result.success(null),
          failure: (f) async => Result.failure(f),
        );
      },
      failure: (f) async => Result.failure(f),
    );
  }

  Future<Result<ProjectStep>> updateStep(ProjectStep updatedStep) async {
    if (!_stepCache.containsKey(updatedStep.id)) {
      return Result.failure(Failure(message: 'Step not found: ${updatedStep.id}'));
    }
    // Update all calendars containing the step
    final affected = _projectStepsMap.entries
        .where((e) => e.value.contains(updatedStep.id))
        .map((e) => e.key)
        .toList();
    for (final projectPath in affected) {
      final calRes = await _calendarRepository.getByPath(projectPath);
      await calRes.when(
        success: (calendar) async {
          if (calendar != null) {
            final updatedCal = calendar.addOrUpdateStep(updatedStep);
            await _calendarRepository.save(updatedCal);
            await _queueCalendarUpdate(updatedCal.path);
          }
        },
        failure: (_) async {},
      );
    }
    _stepCache[updatedStep.id] = updatedStep;
    return Result.success(updatedStep);
  }

  Future<Result<void>> deleteStep(String stepId) async {
    if (!_stepCache.containsKey(stepId)) {
      return Result.failure(Failure(message: 'Step not found: $stepId'));
    }
    final affected = _projectStepsMap.entries
        .where((e) => e.value.contains(stepId))
        .map((e) => e.key)
        .toList();
    for (final projectPath in affected) {
      final calRes = await _calendarRepository.getByPath(projectPath);
      await calRes.when(
        success: (calendar) async {
          if (calendar != null) {
            // Update dependencies of other steps: any step depending on the deleted step
            // should inherit the deleted step's dependencies (flatten one level)
            final steps = calendar.projectStepsList;
            final deletedStep = steps.firstWhere((s) => s.id == stepId, orElse: () => ProjectStep(
              id: stepId,
              name: 'deleted',
            ));

            final updatedSteps = <ProjectStep>[];
            for (final s in steps) {
              if (s.id == stepId) {
                continue; // Removed later by removeStep
              }
              if (s.dependsOn.contains(stepId)) {
                final filtered = s.dependsOn.where((id) => id != stepId).toSet();
                // Merge in deleted step's dependencies
                for (final dep in deletedStep.dependsOn) {
                  if (dep != s.id) {
                    filtered.add(dep);
                  }
                }
                updatedSteps.add(s.copyWith(dependsOn: filtered.toList()));
              } else {
                updatedSteps.add(s);
              }
            }

            // Apply dependency updates, then remove the step
            var intermediateCal = calendar.withProjectSteps(updatedSteps);
            final updatedCal = intermediateCal.removeStep(stepId);
            await _calendarRepository.save(updatedCal);
            await _queueCalendarUpdate(updatedCal.path);
          }
        },
        failure: (_) async {},
      );
    }
    _stepCache.remove(stepId);
    for (final ids in _projectStepsMap.values) {
      ids.remove(stepId);
    }
    return const Result.success(null);
  }

  Future<Result<void>> reorderSteps(String projectPath, List<String> orderedIds) async {
    final calRes = await _calendarRepository.getByPath(projectPath);
    return calRes.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(Failure(message: 'Project not found: $projectPath'));
        }
        final updated = calendar.reorderSteps(orderedIds);
        final saveRes = await _calendarRepository.save(updated);
        return saveRes.when(
          success: (_) async {
            // Update cache orders
            for (int i = 0; i < orderedIds.length; i++) {
              final id = orderedIds[i];
              final s = _stepCache[id];
              if (s != null) _stepCache[id] = s.copyWith(order: i);
            }
            await _queueCalendarUpdate(updated.path);
            return const Result.success(null);
          },
          failure: (f) async => Result.failure(f),
        );
      },
      failure: (f) async => Result.failure(f),
    );
  }

  /// Recompute step statuses based on dependencies and task completion
  Future<Result<void>> recomputeProjectSteps(String projectPath) async {
    final calRes = await _calendarRepository.getByPath(projectPath);
    return calRes.when(
      success: (calendar) async {
        if (calendar == null) return const Result.success(null);
        final steps = calendar.projectStepsList;
        if (steps.isEmpty) return const Result.success(null);

        // Fetch tasks for this project
        final tasksRes = await _taskRepository.getByProject(projectPath);
        final tasks = tasksRes.when(
          success: (t) => t,
          failure: (_) => <Task>[],
        );

        // Precompute completion per step
    final tasksByStep = <String, List<Task>>{};
        for (final task in tasks) {
          final sid = task.stepId;
          if (sid == null || sid.isEmpty) continue;
          (tasksByStep[sid] ??= <Task>[]).add(task);
        }

        final completedByStep = <String, bool>{};
        for (final s in steps) {
          final related = tasksByStep[s.id] ?? const <Task>[];
          completedByStep[s.id] = related.isNotEmpty && related.every((t) => t.status == 'COMPLETED');
        }

        bool dependenciesCompleted(ProjectStep s) {
          if (s.dependsOn.isEmpty) return true;
          return s.dependsOn.every((id) => completedByStep[id] == true);
        }

        final now = DateTime.now();
        final updatedSteps = <ProjectStep>[];
        for (final s in steps) {
          var newStatus = s.status;
          DateTime? newAvailableDate = s.availableDate;
          DateTime? newCompletionDate = s.completionDate;

          final depsMet = dependenciesCompleted(s);
          final allTasksCompleted = completedByStep[s.id] == true;

          // Preserve explicitly paused/aborted status regardless of computed conditions
          if (s.status == StepStatus.paused || s.status == StepStatus.aborted) {
            // keep status and dates as-is
          } else if (allTasksCompleted) {
            newStatus = StepStatus.completed;
            newCompletionDate ??= now;
          } else if (depsMet) {
            newStatus = StepStatus.available;
            newAvailableDate ??= now;
          } else {
            newStatus = StepStatus.waiting;
          }

          final changed = s.copyWith(
            status: newStatus,
            availableDate: newAvailableDate,
            completionDate: newCompletionDate,
          );
          updatedSteps.add(changed);
          _stepCache[changed.id] = changed;
        }

        // Detect if any step data changed
        bool anyChanged = false;
        for (int i = 0; i < steps.length; i++) {
          if (steps[i].status != updatedSteps[i].status ||
              steps[i].availableDate != updatedSteps[i].availableDate ||
              steps[i].completionDate != updatedSteps[i].completionDate) {
            anyChanged = true;
            break;
          }
        }

        // If a step marked as end of workflow is completed, mark the workflow as COMPLETED
        final bool finalStepCompleted = updatedSteps.any((s) => s.endWorkflow && s.status == StepStatus.completed);
        final String currentProjectStatus = (calendar.flowitStatus ?? 'ONGOING').toUpperCase();
        final bool shouldCompleteWorkflow = finalStepCompleted && currentProjectStatus != 'COMPLETED';

        // If neither steps nor workflow status need update, short-circuit
        if (!anyChanged && !shouldCompleteWorkflow) {
          return const Result.success(null);
        }

        // Build updated calendar with new steps and possibly updated status/end date
        var updatedCal = calendar.withProjectSteps(updatedSteps);
        if (shouldCompleteWorkflow) {
          AppLogger.info('StepRepository: Final step completed; marking workflow as COMPLETED for project ${calendar.path}');
          updatedCal = updatedCal.withStatus('COMPLETED').markAsEnded();
        }

        final saveRes = await _calendarRepository.save(updatedCal);
        return saveRes.when(
          success: (_) async {
            await _queueCalendarUpdate(updatedCal.path);
            return const Result.success(null);
          },
          failure: (f) async => Result.failure(f),
        );
      },
      failure: (f) async => Result.failure(f),
    );
  }

  /// Move a step to a new index and adjust dependencies according to rules:
  /// - Clear moved step dependsOn
  /// - Remove moved step id from all other steps' dependsOn
  /// - If there is a previous step, add it to moved step dependsOn
  /// - If there is a next step, add moved step id to next step dependsOn
  /// - Finally, reorder and persist
  Future<Result<void>> moveStepAndFixDependencies(String projectPath, String movedStepId, int insertIndex) async {
    final calRes = await _calendarRepository.getByPath(projectPath);
    return calRes.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(Failure(message: 'Project not found: $projectPath'));
        }
        final original = [...calendar.projectStepsList]..sort((a, b) => a.order.compareTo(b.order));
        final currentIndex = original.indexWhere((s) => s.id == movedStepId);
        if (currentIndex == -1) {
          return Result.failure(Failure(message: 'Step not in project: $movedStepId'));
        }

        // Remove moved step and compute bounded target index
        final moved = original.removeAt(currentIndex);
        int targetIndex = insertIndex.clamp(0, original.length);
        original.insert(targetIndex, moved);

        // Identify neighbors after insertion
        final ProjectStep? prev = targetIndex > 0 ? original[targetIndex - 1] : null;
        final ProjectStep? next = targetIndex < original.length - 1 ? original[targetIndex + 1] : null;

        // Adjust dependencies
        final updated = <ProjectStep>[];
        for (final s in original) {
          if (s.id == moved.id) {
            final newDeps = <String>[];
            if (prev != null) newDeps.add(prev.id);
            updated.add(s.copyWith(dependsOn: newDeps));
          } else {
            // Remove moved id from all others
            final newDeps = s.dependsOn.where((id) => id != moved.id).toList();
            // If this is the next step, add moved id
            if (next != null && s.id == next.id) {
              if (!newDeps.contains(moved.id)) newDeps.add(moved.id);
            }
            updated.add(s.copyWith(dependsOn: newDeps));
          }
        }

        // Apply new order indices
        final withOrder = <ProjectStep>[];
        for (int i = 0; i < updated.length; i++) {
          final s = updated[i];
          withOrder.add(s.copyWith(order: i));
        }

        final updatedCal = calendar.withProjectSteps(withOrder);
        final saveRes = await _calendarRepository.save(updatedCal);
        return await saveRes.when(
          success: (_) async {
            // Update cache
            _projectStepsMap[projectPath] = withOrder.map((s) => s.id).toSet();
            for (final s in withOrder) {
              _stepCache[s.id] = s;
            }
            await _queueCalendarUpdate(updatedCal.path);
            return const Result.success(null);
          },
          failure: (f) async => Result.failure(f),
        );
      },
      failure: (f) async => Result.failure(f),
    );
  }
  
  static String generateId(String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$name-$timestamp';
  }

  Future<void> _queueCalendarUpdate(String path) async {
    final sync = _sync ?? SyncService.instance;
    if (sync != null) {
      await sync.queueCalendarUpdate(path);
    }
  }
}


