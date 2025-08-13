// Due date picker dialog component
// Provides quick and custom date selection options for tasks

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../../core/logger.dart';
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
      title: Text(AppLocalizations.of(context)!.dueDateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentDue != null) ...[
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: Text(AppLocalizations.of(context)!.removeDueDate),
              onTap: () => _selectDate(context, null),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.today_rounded),
            title: Text(AppLocalizations.of(context)!.today),
            onTap: () => _selectDate(context, _getToday()),
          ),
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: Text(AppLocalizations.of(context)!.tomorrow),
            onTap: () => _selectDate(context, _getTomorrow()),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_week_rounded),
            title: Text(AppLocalizations.of(context)!.nextWeek),
            onTap: () => _selectDate(context, _getInDays(7)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_today_rounded),
            title: Text(AppLocalizations.of(context)!.pickADate),
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
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
      ],
    );
  }

  /// Handles date selection from predefined options
  void _selectDate(BuildContext context, DateTime? selectedDate) {
    Navigator.of(context).pop();
    _updateTaskDueDate(context, selectedDate);
  }

  /// Helper methods for getting proper calendar dates
  DateTime _getToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _getTomorrow() {
    final today = _getToday();
    return today.add(const Duration(days: 1));
  }

  DateTime _getInDays(int days) {
    final today = _getToday();
    return today.add(Duration(days: days));
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

      if (context.mounted) {
        final message = newDue == null 
            ? 'Due date removed' 
            : 'Due date set to ${newDue.day}/${newDue.month}/${newDue.year}';
        AppLogger.info('DueDateDialog: $message');
      }
    } catch (e) {
      if (context.mounted) {
        AppLogger.error('Error updating due date: $e');
      }
    }
  }
} 