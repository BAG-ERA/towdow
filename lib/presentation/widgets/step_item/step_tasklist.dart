// StepTaskList widget
// Responsive grid/wrap of TaskItem cards with drag overlay wiring

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../core/logger.dart';
import '../../widgets/utils/overlay_draggable_task.dart';
import '../../widgets/task_item/task_item.dart';

class StepTaskList extends ConsumerWidget {
  final String sectionKey;
  final List<Task> tasks;
  final Map<String, Map<String, TaskItemController>> sectionControllers;
  final VoidCallback? onTasksRefresh;
  final VoidCallback? onTaskTap;
  final Future<void> Function(Task task)? onToggleComplete;
  final Future<void> Function(Task updated)? onTaskUpdated;
  final Future<void> Function(Task task)? onTaskDeleted;

  const StepTaskList({
    super.key,
    required this.sectionKey,
    required this.tasks,
    required this.sectionControllers,
    this.onTasksRefresh,
    this.onTaskTap,
    this.onToggleComplete,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              AppLogger.info('StepTaskList: Started dragging task ${task.summary}');
            },
            onDragEnd: () {
              AppLogger.info('StepTaskList: Ended dragging task ${task.summary}');
            },
            child: TaskItem(
              task: task,
              controller: sectionControllers[sectionKey]?[task.uid],
              onTap: onTaskTap,
              onToggleComplete: () async {
                if (onToggleComplete != null) await onToggleComplete!(task);
              },
              onTaskUpdated: (updatedTask) async {
                if (onTaskUpdated != null) await onTaskUpdated!(updatedTask);
                onTasksRefresh?.call();
              },
              onTaskDeleted: () async {
                if (onTaskDeleted != null) await onTaskDeleted!(task);
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}



