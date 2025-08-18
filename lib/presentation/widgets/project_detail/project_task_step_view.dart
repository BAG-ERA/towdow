// Project task step view widget
// Displays tasks in a project organized by workflow steps (from VCALENDAR)
// Mirrors the list view layout but groups by steps instead of status

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

import '../../../core/logger.dart';
import '../../../core/theme/chart_theme.dart';
import '../../../data/models/step.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../task_item/task_item.dart';
import '../step_item/step_container.dart';
import '../step_item/step_tasklist.dart';
import '../utils/popup/step_dialog.dart';
import '../utils/popup/task_creation_dialog.dart';
// projectProvider removed

class ProjectTaskStepView extends ConsumerStatefulWidget {
  final String projectPath;
  final AsyncValue<List<Task>> tasksAsync;
  final VoidCallback? onTasksRefresh;
  final bool workflowVariant;

  const ProjectTaskStepView({
    super.key,
    required this.projectPath,
    required this.tasksAsync,
    this.onTasksRefresh,
    this.workflowVariant = false,
  });

  @override
  ConsumerState<ProjectTaskStepView> createState() => _ProjectTaskStepViewState();
}

class _ProjectTaskStepViewState extends ConsumerState<ProjectTaskStepView> {
  final Map<String, Map<String, TaskItemController>> _sectionControllers = {};

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(projectStepsProvider(widget.projectPath));

    return stepsAsync.when(
      data: (steps) {
        final allTasks = ref.watch(filteredProjectTasksProvider(widget.projectPath));
        
        // Prepare sections: one per step (ordered), plus unassigned
        // Map tasks by stepId
        final Map<String, List<Task>> tasksByStep = {
          ...{for (final s in steps) s.id: <Task>[]},
          'unassigned': <Task>[],
        };
        for (final task in allTasks) {
          final sid = task.stepId;
          if (sid != null && sid.isNotEmpty && tasksByStep.containsKey(sid)) {
            tasksByStep[sid]!.add(task);
          } else {
            tasksByStep['unassigned']!.add(task);
          }
        }

        // Initialize controllers per section
        for (final s in steps) {
          _initializeControllers(s.id, tasksByStep[s.id] ?? const <Task>[]);
        }
        _initializeControllers('unassigned', tasksByStep['unassigned'] ?? const <Task>[]);

        // Determine flow state for gating edits
        final encoded = widget.projectPath.replaceAll('@', '%40');
        final project = ref.watch(calendarListProvider).maybeWhen(
          data: (cals) {
            try {
              return cals.firstWhere((c) => c.path == encoded);
            } catch (_) {
              return null;
            }
          },
          orElse: () => null,
        );
        final isFlow = project?.flowitAsFlow == true;
        final status = (project?.flowitStatus ?? 'ONGOING').toUpperCase();
        final isOngoingFlow = isFlow && status == 'ONGOING';
        final isStoppedFlow = isFlow && status == 'STOPPED';

        return Column(
          children: [
            if (stepsAsync.isLoading && !stepsAsync.hasValue)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unassigned section first if any
                    if ((tasksByStep['unassigned'] ?? const <Task>[]).isNotEmpty) ...[
                      StepContainer(
                        stepId: 'unassigned',
                        title: 'Unassigned',
                        count: tasksByStep['unassigned']!.length,
                        onExpandAll: _expandAllTasks,
                        onCollapseAll: _collapseAllTasks,
                        extraTrailing: widget.workflowVariant
                            ? TextButton.icon(
                                onPressed: () => _addTaskInStep(context, ref, null),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(AppLocalizations.of(context)!.addTask),
                              )
                            : null,
                        isEmpty: false,
                        child: StepTaskList(
                          sectionKey: 'unassigned',
                          tasks: tasksByStep['unassigned']!,
                          sectionControllers: _sectionControllers,
                          onTasksRefresh: widget.onTasksRefresh,
                          onToggleComplete: (task) async => _toggleTaskComplete(context, ref, task),
                          onTaskUpdated: (updated) async {
                            await ref.read(taskViewModelProvider.notifier).updateTask(updated);
                          },
                          onTaskDeleted: (task) async => _deleteTask(context, ref, task),
                        ),
                        onTaskDropped: (task, targetStepId) async {
                          if (task.stepId == targetStepId) return;
                          final taskViewModel = ref.read(taskViewModelProvider.notifier);
                          await taskViewModel.updateTask(task.copyWith(stepId: targetStepId));
                          widget.onTasksRefresh?.call();
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // If no steps are defined, show a soft placeholder
                    if (steps.isEmpty) ...[
                      _buildNoStepsPlaceholder(context),
                    ],

                    // Render steps in order
                      for (int idx = 0; idx < steps.length; idx++) ...[
                      _buildStepReorderTarget(context, steps, idx),
                      StepContainer(
                        stepId: steps[idx].id,
                        title: steps[idx].name,
                        count: tasksByStep[steps[idx].id]?.length ?? 0,
                        onExpandAll: _expandAllTasks,
                        onCollapseAll: _collapseAllTasks,
                        extraTrailing: widget.workflowVariant
                            ? TextButton.icon(
                                onPressed: () => _addTaskInStep(context, ref, steps[idx].id),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(AppLocalizations.of(context)!.addTask),
                              )
                            : null,
                        canMoveUp: (isStoppedFlow ? steps[idx].status != StepStatus.completed : !isOngoingFlow) && idx > 0,
                        canMoveDown: (isStoppedFlow ? steps[idx].status != StepStatus.completed : !isOngoingFlow) && idx < steps.length - 1,
                        onMoveUp: () async {
                          final stepRepository = ref.read(stepRepositoryProvider);
                          final encodedProjectPath = widget.projectPath.replaceAll('@', '%40');
                          await stepRepository.moveStepAndFixDependencies(encodedProjectPath, steps[idx].id, idx - 1);
                          if (mounted) ref.invalidate(projectStepsProvider(widget.projectPath));
                        },
                        onMoveDown: () async {
                          final stepRepository = ref.read(stepRepositoryProvider);
                          final encodedProjectPath = widget.projectPath.replaceAll('@', '%40');
                          await stepRepository.moveStepAndFixDependencies(encodedProjectPath, steps[idx].id, idx + 1);
                          if (mounted) ref.invalidate(projectStepsProvider(widget.projectPath));
                        },
                        onMarkAsFinal: () async {
                          final stepVm = ref.read(projectStepViewModelProvider(widget.projectPath).notifier);
                          await stepVm.updateStep(steps[idx].copyWith(endWorkflow: true));
                          if (mounted) ref.invalidate(projectStepsProvider(widget.projectPath));
                        },
                        markAsFinalLabel: (steps[idx].endWorkflow && steps[idx].status == StepStatus.completed)
                            ? 'Mark workflow as completed'
                            : null,
                        onDelete: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(AppLocalizations.of(context)!.areYouSureDelete(steps[idx].name)),
                              content: Text('Are you sure you want to delete "${steps[idx].name}"? Tasks assigned to this step will become unassigned.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text(AppLocalizations.of(context)!.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text(AppLocalizations.of(context)!.delete),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final stepVm = ref.read(projectStepViewModelProvider(widget.projectPath).notifier);
                            await stepVm.deleteStep(steps[idx].id);
                            if (mounted) {
                              ref.invalidate(projectStepsProvider(widget.projectPath));
                              widget.onTasksRefresh?.call();
                            }
                          }
                        },
                        draggable: isStoppedFlow ? steps[idx].status != StepStatus.completed : !isOngoingFlow,
                        dragHandle: (isStoppedFlow ? steps[idx].status != StepStatus.completed : !isOngoingFlow)
                            ? _buildStepDragHandle(context, steps[idx])
                            : null,
                        editable: isStoppedFlow ? steps[idx].status != StepStatus.completed : !isOngoingFlow,
                        onTitleSubmitted: (newTitle) async {
                          final stepVm = ref.read(projectStepViewModelProvider(widget.projectPath).notifier);
                          await stepVm.updateStep(steps[idx].copyWith(name: newTitle));
                          if (mounted) {
                            ref.invalidate(projectStepsProvider(widget.projectPath));
                          }
                        },
                        isEmpty: (tasksByStep[steps[idx].id] ?? const <Task>[]).isEmpty,
                        statusColor: _colorForStepStatus(context, steps[idx].status),
                        stepStatus: steps[idx].status,
                        disabled: isStoppedFlow
                            ? steps[idx].status == StepStatus.completed
                            : (isOngoingFlow && steps[idx].status == StepStatus.waiting),
                        emptyChild: _buildEmptyStepPlaceholder(
                          context,
                          _colorForStepStatus(context, steps[idx].status),
                        ),
                        child: StepTaskList(
                          sectionKey: steps[idx].id,
                          tasks: tasksByStep[steps[idx].id] ?? const <Task>[],
                          sectionControllers: _sectionControllers,
                          onTasksRefresh: widget.onTasksRefresh,
                          onToggleComplete: (task) async => _toggleTaskComplete(context, ref, task),
                          onTaskUpdated: (updated) async {
                            await ref.read(taskViewModelProvider.notifier).updateTask(updated);
                          },
                          onTaskDeleted: (task) async => _deleteTask(context, ref, task),
                        ),
                        onTaskDropped: isOngoingFlow
                            ? null
                            : (task, targetStepId) async {
                                if (task.stepId == targetStepId) return;
                                final taskViewModel = ref.read(taskViewModelProvider.notifier);
                                await taskViewModel.updateTask(task.copyWith(stepId: targetStepId));
                                widget.onTasksRefresh?.call();
                              },
                      ),
                      const SizedBox(height: 24),
                      if (idx == steps.length - 1) _buildStepReorderTarget(context, steps, steps.length),
                    ],

                    // Add Step button
                    _buildAddStepButton(context, steps),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.discoveringCalendars),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load tasks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onTasksRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }

  // Header extracted to StepHeader widget

  

  Widget _buildAddStepButton(BuildContext context, List<ProjectStep> steps) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final nextOrder = steps.isEmpty ? 0 : (steps.map((s) => s.order).fold<int>(0, (p, c) => c > p ? c : p) + 1);
          // Determine previous step id to set dependency
          String? previousStepId;
          if (steps.isNotEmpty) {
            // Get the last step by order
            final sorted = [...steps]..sort((a, b) => a.order.compareTo(b.order));
            previousStepId = sorted.last.id;
          }
          final created = await StepDialog.show(
            context,
            projectPath: widget.projectPath,
            initialOrder: nextOrder,
            previousStepId: previousStepId,
          );
          if (created == true && mounted) {
            ref.invalidate(projectStepsProvider(widget.projectPath));
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(AppLocalizations.of(context)!.addStep),
      ),
    );
  }

  

  // Drag handle for a step header
  Widget _buildStepDragHandle(BuildContext context, ProjectStep step) {
    return LongPressDraggable<ProjectStep>(
      data: step,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator_rounded, size: 18),
              const SizedBox(width: 6),
              Text(step.name, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      child: const Icon(Icons.drag_indicator_rounded, size: 18),
    );
  }

  // Drop target between steps at a given index
  Widget _buildStepReorderTarget(BuildContext context, List<ProjectStep> steps, int insertIndex) {
    return DragTarget<ProjectStep>(
      onAcceptWithDetails: (details) async {
        final moved = details.data;
        final stepRepository = ref.read(stepRepositoryProvider);
        final encodedProjectPath = widget.projectPath.replaceAll('@', '%40');
        await stepRepository.moveStepAndFixDependencies(encodedProjectPath, moved.id, insertIndex);
        // Refresh
        ref.invalidate(projectStepsProvider(widget.projectPath));
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 8,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: hovering ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  void _initializeControllers(String sectionKey, List<Task> tasks) {
    if (!_sectionControllers.containsKey(sectionKey)) {
      _sectionControllers[sectionKey] = {};
    }

    final currentControllers = _sectionControllers[sectionKey]!;

    for (final task in tasks) {
      if (!currentControllers.containsKey(task.uid)) {
        currentControllers[task.uid] = TaskItemController();
        AppLogger.debug('ProjectTaskStepView: Created controller for task ${task.summary} in section $sectionKey');
      }
    }

    final taskUids = tasks.map((t) => t.uid).toSet();
    currentControllers.removeWhere((uid, _) {
      final remove = !taskUids.contains(uid);
      if (remove) {
        AppLogger.debug('ProjectTaskStepView: Removed controller for task $uid in section $sectionKey');
      }
      return remove;
    });
  }

  void _expandAllTasks() {
    for (final entry in _sectionControllers.entries) {
      for (final controller in entry.value.values) {
        controller.expand();
      }
    }
    AppLogger.info('ProjectTaskStepView: Expanded all tasks');
  }

  void _collapseAllTasks() {
    for (final entry in _sectionControllers.entries) {
      for (final controller in entry.value.values) {
        controller.collapse();
      }
    }
    AppLogger.info('ProjectTaskStepView: Collapsed all tasks');
  }

  

  Widget _buildEmptyStepPlaceholder(BuildContext context, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 20, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            'No tasks',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStepsPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.stairs_outlined, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No steps defined yet',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create steps in your workflow to organize tasks by stages.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _toggleTaskComplete(BuildContext context, WidgetRef ref, Task task) async {
    // Enforce: in ONGOING workflows only tasks in AVAILABLE steps can be marked done
    final encoded = widget.projectPath.replaceAll('@', '%40');
    final project = ref.read(calendarListProvider).maybeWhen(
      data: (cals) {
        try {
          return cals.firstWhere((c) => c.path == encoded);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );
    final stepRepo = ref.read(stepRepositoryProvider);
    ProjectStep? step;
    if (task.stepId != null && task.stepId!.isNotEmpty) {
      final stepRes = await stepRepo.getStepById(task.stepId!);
      step = stepRes.when(success: (s) => s, failure: (_) => null);
    }

    final status = (project?.flowitStatus ?? 'ONGOING').toUpperCase();
    final isFlow = project?.flowitAsFlow == true;
    final stepIsAvailable = step?.status == StepStatus.available;

    if (isFlow && status == 'ONGOING' && !stepIsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.waitingStepCannotComplete)),
      );
      return;
    }

    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.toggleTaskCompletion(task);
    widget.onTasksRefresh?.call();
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, Task task) async {
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.deleteTask(task.uid);
    widget.onTasksRefresh?.call();
  }

  Future<void> _addTaskInStep(BuildContext context, WidgetRef ref, String? stepId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => TaskCreationDialog(
        projectPath: widget.projectPath,
        workflowVariant: true,
        stepId: stepId,
      ),
    );
  }

  Color _colorForStepStatus(BuildContext context, StepStatus status) {
    final colors = context.chartTheme.colors;
    switch (status) {
      case StepStatus.available:
        return colors.warning;
      case StepStatus.completed:
        return colors.success;
      case StepStatus.waiting:
        return colors.onSurfaceVariant;
      case StepStatus.paused:
        return colors.onSurfaceVariant;
      case StepStatus.aborted:
        return colors.error;
    }
  }
}


