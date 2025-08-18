// Reusable Kanban board component for different project views
// Supports dynamic columns with custom grouping logic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import 'task_item/task_item.dart';
import 'utils/mobile_delayed_draggable.dart';

class KanbanColumn {
  final String id;
  final String title;
  final String subtitle;
  final List<Task> tasks;
  final Color color;
  final IconData icon;
  final VoidCallback? onAddTask;

  const KanbanColumn({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.color,
    required this.icon,
    this.onAddTask,
  });
}

class KanbanBoard extends ConsumerWidget {
  final List<KanbanColumn> columns;
  final Function(Task, String)? onTaskMoved;
  final Function(Task)? onTaskTap;
  final Function(Task)? onTaskToggle;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;
  final Function(String)? onColumnHide;
  final double? height;
  final Widget? hiddenColumnsButton;
  final VoidCallback? onAddCategory;

  const KanbanBoard({
    super.key,
    required this.columns,
    this.onTaskMoved,
    this.onTaskTap,
    this.onTaskToggle,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onColumnHide,
    this.height,
    this.hiddenColumnsButton,
    this.onAddCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = ScrollController();
    
    return SizedBox(
      height: height ?? MediaQuery.of(context).size.height * 0.7,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const targetColumnWidth = 360.0;
          const columnSpacing = 16.0;
          
          // Calculate total width needed for all columns
          final totalColumns = columns.length + (hiddenColumnsButton != null ? 1 : 0) + (onAddCategory != null ? 1 : 0);
          final totalSpacing = (totalColumns - 1) * columnSpacing;
          final totalWidth = (totalColumns * targetColumnWidth) + totalSpacing;
          
          return ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.resolveWith((states) {
                final base = Theme.of(context).colorScheme.onSurface;
                if (states.contains(MaterialState.dragged)) {
                  return base.withOpacity(0.55);
                }
                if (states.contains(MaterialState.hovered)) {
                  return base.withOpacity(0.28);
                }
                return base.withOpacity(0.06);
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                final base = Theme.of(context).colorScheme.onSurface;
                if (states.contains(MaterialState.dragged)) {
                  return base.withOpacity(0.18);
                }
                if (states.contains(MaterialState.hovered)) {
                  return base.withOpacity(0.10);
                }
                return base.withOpacity(0.03);
              }),
              trackBorderColor: MaterialStateProperty.all(Colors.transparent),
              thickness: MaterialStateProperty.all(8.0),
              radius: const Radius.circular(4.0),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8.0,
              radius: const Radius.circular(4.0),
              controller: scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalWidth),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...columns.map((column) => Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: SizedBox(
                          width: targetColumnWidth,
                          child: KanbanColumnWidget(
                            column: column,
                            onTaskMoved: onTaskMoved,
                            onTaskTap: onTaskTap,
                            onTaskToggle: onTaskToggle,
                            onTaskUpdated: onTaskUpdated,
                            onTaskDeleted: onTaskDeleted,
                            onColumnHide: onColumnHide,
                          ),
                        ),
                      )),
                      if (hiddenColumnsButton != null) ...[
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 200,
                          child: hiddenColumnsButton!,
                        ),
                      ],
                      if (onAddCategory != null) ...[
                        const SizedBox(width: 16),
                        Container(
                          width: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onAddCategory,
                              borderRadius: BorderRadius.circular(12),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class KanbanColumnWidget extends ConsumerWidget {
  final KanbanColumn column;
  final Function(Task, String)? onTaskMoved;
  final Function(Task)? onTaskTap;
  final Function(Task)? onTaskToggle;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;
  final Function(String)? onColumnHide;

  const KanbanColumnWidget({
    super.key,
    required this.column,
    this.onTaskMoved,
    this.onTaskTap,
    this.onTaskToggle,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onColumnHide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: column.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: column.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    column.icon,
                    color: column.color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        column.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: column.color,
                        ),
                      ),
                      Text(
                        column.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: column.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${column.tasks.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: column.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onColumnHide != null && column.id != 'uncategorized')
                  IconButton(
                    onPressed: () => onColumnHide!(column.id),
                    icon: Icon(
                      Icons.visibility_off_rounded,
                      size: 16,
                      color: column.color.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Hide column',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
              ],
            ),
          ),
          
          // Tasks List
          Expanded(
            child: onTaskMoved != null
                ? DragTarget<Task>(
                    onAcceptWithDetails: (details) {
                      onTaskMoved!(details.data, column.id);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isHovering 
                              ? column.color.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: isHovering
                              ? Border.all(
                                  color: column.color.withValues(alpha: 0.5),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: column.tasks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isHovering ? Icons.move_to_inbox_rounded : column.icon,
                                      size: 32,
                                      color: isHovering 
                                          ? column.color
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isHovering ? 'Drop here to assign' : 'No tasks',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isHovering 
                                            ? column.color
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: column.tasks.length,
                                itemBuilder: (context, index) {
                                  final task = column.tasks[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: MobileDelayedDraggableTask(
                                      task: task,
                                      feedback: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 280,
                                          child: TaskItem(
                                            task: task,
                                            onTap: null, // Disable tap during drag
                                            onToggleComplete: null, // Disable toggle during drag
                                            onTaskUpdated: null, // Disable updates during drag
                                            onTaskDeleted: null, // Disable deletion during drag
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.5,
                                        child: TaskItem(
                                          task: task,
                                          onTap: null,
                                          onToggleComplete: null,
                                          onTaskUpdated: null,
                                          onTaskDeleted: null,
                                        ),
                                      ),
                                      child: TaskItem(
                                        task: task,
                                        onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                                        onToggleComplete: onTaskToggle != null ? () => onTaskToggle!(task) : null,
                                        onTaskUpdated: onTaskUpdated != null ? (updatedTask) => onTaskUpdated!(updatedTask) : null,
                                        onTaskDeleted: onTaskDeleted != null ? () => onTaskDeleted!(task) : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  )
                : column.tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              column.icon,
                              size: 32,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No tasks',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: column.tasks.length,
                        itemBuilder: (context, index) {
                          final task = column.tasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TaskItem(
                              task: task,
                              onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                              onToggleComplete: onTaskToggle != null ? () => onTaskToggle!(task) : null,
                              onTaskUpdated: onTaskUpdated != null ? (updatedTask) => onTaskUpdated!(updatedTask) : null,
                              onTaskDeleted: onTaskDeleted != null ? () => onTaskDeleted!(task) : null,
                            ),
                          );
                        },
                      ),
          ),
          
          // Add Task Button
          if (column.onAddTask != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: column.onAddTask,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Task'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: column.color,
                  side: BorderSide(color: column.color.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

 
