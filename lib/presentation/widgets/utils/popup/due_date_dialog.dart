// Due date picker dialog component
// Provides quick and custom date selection options for tasks

import 'package:flutter/material.dart';
import '../../../../data/models/task.dart';

class DueDateDialog extends StatelessWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const DueDateDialog({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  /// Shows the due date picker dialog
  static Future<void> show(
    BuildContext context, {
    required Task task,
    Function(Task)? onTaskUpdated,
  }) async {
    await showDialog<DateTime?>(
      context: context,
      builder: (context) => DueDateDialog(
        task: task,
        onTaskUpdated: onTaskUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDue = task.due;
    
    return AlertDialog(
      title: const Text('Due Date'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentDue != null) ...[
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: const Text('Remove due date'),
              onTap: () => _selectDate(context, null),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.today_rounded),
            title: const Text('Today'),
            onTap: () => _selectDate(context, DateTime.now()),
          ),
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: const Text('Tomorrow'),
            onTap: () => _selectDate(context, DateTime.now().add(const Duration(days: 1))),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_week_rounded),
            title: const Text('In 7 days'),
            onTap: () => _selectDate(context, DateTime.now().add(const Duration(days: 7))),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_today_rounded),
            title: const Text('Pick a date...'),
            onTap: () async {
              Navigator.of(context).pop(); // Close current dialog
              final picked = await showDatePicker(
                context: context,
                initialDate: currentDue ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (picked != null) {
                _updateTaskDueDate(context, picked);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Handles date selection from predefined options
  void _selectDate(BuildContext context, DateTime? selectedDate) {
    Navigator.of(context).pop();
    _updateTaskDueDate(context, selectedDate);
  }

  /// Updates the task with the new due date
  Future<void> _updateTaskDueDate(BuildContext context, DateTime? newDue) async {
    try {
      // Create updated task
      final updatedTask = task.copyWith(
        due: newDue,
        lastModified: DateTime.now(),
      );

      // Notify parent widget
      if (onTaskUpdated != null) {
        onTaskUpdated!(updatedTask);
      }

      // Show feedback
      if (context.mounted) {
        final message = newDue == null 
            ? 'Due date removed' 
            : 'Due date set to ${newDue.day}/${newDue.month}/${newDue.year}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating due date: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
} 