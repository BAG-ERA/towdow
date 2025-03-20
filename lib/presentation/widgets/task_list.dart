import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';

class TaskList extends StatelessWidget {
  final List<TaskModel> tasks;
  final Function(TaskModel)? onTaskTap;
  final Function(TaskModel)? onTaskComplete;

  const TaskList({
    super.key,
    required this.tasks,
    this.onTaskTap,
    this.onTaskComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new task to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskListItem(
          task: task,
          onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
          onComplete: onTaskComplete != null ? () => onTaskComplete!(task) : null,
        );
      },
    );
  }
}

class TaskListItem extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const TaskListItem({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.status == TaskStatus.completed,
          onChanged: onComplete != null
              ? (bool? value) {
                  if (value == true) {
                    onComplete!();
                  }
                }
              : null,
        ),
        title: Text(
          task.summary,
          style: TextStyle(
            decoration: task.status == TaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (task.dueDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: _getDueDateColor(task.dueDate!, colorScheme),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDueDate(task.dueDate!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getDueDateColor(task.dueDate!, colorScheme),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: task.type != FlowItType.task
            ? Icon(
                task.type == FlowItType.taskGroup
                    ? Icons.folder_outlined
                    : Icons.auto_awesome,
                color: colorScheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) {
      return 'Today';
    } else if (taskDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getDueDateColor(DateTime date, ColorScheme colorScheme) {
    final now = DateTime.now();
    if (date.isBefore(now)) {
      return colorScheme.error;
    }
    final difference = date.difference(now).inDays;
    if (difference <= 1) {
      return colorScheme.error;
    } else if (difference <= 3) {
      return colorScheme.errorContainer;
    }
    return colorScheme.outline;
  }
} 