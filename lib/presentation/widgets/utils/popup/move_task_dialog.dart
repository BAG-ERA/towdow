// Move task dialog widget for selecting target calendar
// Provides a clean interface for moving tasks between calendars/projects

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/task_calendar.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';

/// Dialog for selecting target calendar when moving a task
class MoveTaskDialog extends ConsumerWidget {
  final Task task;

  const MoveTaskDialog({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(calendarListProvider);
    
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.move_to_inbox_rounded),
          SizedBox(width: 12),
          Text('Move Task'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moving: ${task.summary}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select destination calendar:'),
            const SizedBox(height: 12),
            calendarsAsync.when(
              data: (calendars) => _buildCalendarList(context, ref, calendars),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading calendars: $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildCalendarList(BuildContext context, WidgetRef ref, List<TaskCalendar> calendars) {
    // Filter out the current calendar and only show calendars that support todos
    final availableCalendars = calendars
        .where((calendar) => 
            calendar.supportsTodos && 
            calendar.uid != task.sourceCalendarUid)
        .toList();

    if (availableCalendars.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No other calendars available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: availableCalendars.length,
        itemBuilder: (context, index) {
          final calendar = availableCalendars[index];
          return _buildCalendarListItem(context, ref, calendar);
        },
      ),
    );
  }

  Widget _buildCalendarListItem(BuildContext context, WidgetRef ref, TaskCalendar calendar) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: calendar.color != null 
            ? Color(int.parse(calendar.color!.replaceFirst('#', '0xff')))
            : Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.calendar_today_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        calendar.displayName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: calendar.description.isNotEmpty 
          ? Text(
              calendar.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      onTap: () => _onCalendarSelected(context, ref, calendar),
    );
  }

  void _onCalendarSelected(BuildContext context, WidgetRef ref, TaskCalendar targetCalendar) async {
    try {
      AppLogger.info('MoveTaskDialog: Moving task ${task.uid} to calendar ${targetCalendar.uid}');
      
      // Close the dialog first
      Navigator.of(context).pop();
      
      // Show a loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Moving "${task.summary}" to ${targetCalendar.displayName}...'),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Execute the move operation via TaskViewModel
      final taskViewModel = ref.read(taskViewModelProvider.notifier);
      await taskViewModel.moveTask(task, targetCalendar.uid);
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('✅ Moved "${task.summary}" to ${targetCalendar.displayName}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
             // Invalidate providers to refresh task lists
       ref.invalidate(taskListProvider);
       // Note: projectTasksProvider is defined locally in ProjectDetailScreen
       // Task lists will be refreshed when navigating to project screens
      
    } catch (e, stackTrace) {
      AppLogger.error('MoveTaskDialog: Failed to move task', e, stackTrace);
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('❌ Failed to move task: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

/// Helper function to show the move task dialog
Future<void> showMoveTaskDialog(BuildContext context, Task task) async {
  await showDialog(
    context: context,
    builder: (context) => MoveTaskDialog(task: task),
  );
} 