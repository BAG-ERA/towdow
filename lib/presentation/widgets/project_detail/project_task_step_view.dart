// Project task step view widget
// Displays tasks in a project organized by workflow steps (from VCALENDAR)
// Mirrors the list view layout but groups by steps instead of status

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger.dart';
import '../../../core/theme/chart_theme.dart';
import '../../../data/models/step.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../task_item/task_item.dart';
import '../utils/overlay_draggable_task.dart';
import 'step_header.dart';

class ProjectTaskStepView extends ConsumerStatefulWidget {
  final String projectPath;
  final AsyncValue<List<Task>> tasksAsync;
  final VoidCallback? onTasksRefresh;

  const ProjectTaskStepView({
    super.key,
    required this.projectPath,
    required this.tasksAsync,
    this.onTasksRefresh,
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

        return Column(
          children: [
            if (stepsAsync.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unassigned section first if any
                    if ((tasksByStep['unassigned'] ?? const <Task>[]).isNotEmpty) ...[
                      StepHeader(
                        title: 'Unassigned',
                        count: tasksByStep['unassigned']!.length,
                        onExpandAll: _expandAllTasks,
                        onCollapseAll: _collapseAllTasks,
                      ),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, 'unassigned', tasksByStep['unassigned']!),
                      const SizedBox(height: 24),
                    ],

                    // If no steps are defined, show a soft placeholder
                    if (steps.isEmpty) ...[
                      _buildNoStepsPlaceholder(context),
                    ],

                    // Render steps in order
                    for (final s in steps) ...[
                      StepHeader(
                        title: s.name,
                        count: tasksByStep[s.id]?.length ?? 0,
                        onExpandAll: _expandAllTasks,
                        onCollapseAll: _collapseAllTasks,
                      ),
                      const SizedBox(height: 8),
                      if ((tasksByStep[s.id] ?? const <Task>[]).isEmpty)
                        _buildEmptyStepPlaceholder(
                          context,
                          _colorForStepStatus(context, s.status),
                        )
                      else
                        _buildResponsiveTaskGrid(context, s.id, tasksByStep[s.id] ?? const <Task>[]),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading tasks...'),
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
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Header extracted to StepHeader widget

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

  Widget _buildResponsiveTaskGrid(BuildContext context, String sectionKey, List<Task> tasks) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      children: tasks.map((task) {
        return ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
            minWidth: 300,
          ),
          child: OverlayDraggableTask(
            task: task,
            onDragStarted: () {
              AppLogger.info('ProjectTaskStepView: Started dragging task ${task.summary}');
            },
            onDragEnd: () {
              AppLogger.info('ProjectTaskStepView: Ended dragging task ${task.summary}');
            },
            child: TaskItem(
              task: task,
              controller: _sectionControllers[sectionKey]?[task.uid],
              onTap: () => _viewTask(context, task),
              onToggleComplete: () => _toggleTaskComplete(context, ref, task),
              onTaskUpdated: (updatedTask) async {
                await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
                widget.onTasksRefresh?.call();
              },
              onTaskDeleted: () => _deleteTask(context, ref, task),
            ),
          ),
        );
      }).toList(),
    );
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

  void _viewTask(BuildContext context, Task task) {
    // Navigate to task detail (future)
  }

  Future<void> _toggleTaskComplete(BuildContext context, WidgetRef ref, Task task) async {
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.toggleTaskCompletion(task);
    widget.onTasksRefresh?.call();
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, Task task) async {
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.deleteTask(task.uid);
    widget.onTasksRefresh?.call();
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


