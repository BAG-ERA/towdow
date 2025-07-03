// Reusable task creation dialog widget
// Used across the app for creating new tasks

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/models/task.dart';
import '../../../../data/providers/providers.dart';
import 'due_date_dialog.dart';

class TaskCreationDialog extends ConsumerStatefulWidget {
  final String? sourceCalendarUid; // Optional project to assign the task to

  const TaskCreationDialog({
    super.key,
    this.sourceCalendarUid,
  });

  @override
  ConsumerState<TaskCreationDialog> createState() => _TaskCreationDialogState();
}

class _TaskCreationDialogState extends ConsumerState<TaskCreationDialog> {
  final TextEditingController summaryController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime? selectedDue;
  bool isLoading = false;
  bool keepDialogOpen = false; // New checkbox state

  @override
  void dispose() {
    summaryController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Task'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new task to track work and progress.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: summaryController,
              decoration: const InputDecoration(
                labelText: 'Task summary *',
                hintText: 'e.g., Review client proposal, Write documentation',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _canCreate() ? _createTask() : null,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add details about what needs to be done',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            
            const SizedBox(height: 16),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(selectedDue == null 
                ? 'No due date' 
                : 'Due: ${selectedDue!.day}/${selectedDue!.month}/${selectedDue!.year}'
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () => _showDueDateDialog(),
            ),
            
            const SizedBox(height: 16),
            
            // Keep dialog open checkbox
            Row(
              children: [
                Checkbox(
                  value: keepDialogOpen,
                  onChanged: (value) {
                    setState(() {
                      keepDialogOpen = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keep dialog open for creating multiple tasks',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading || !_canCreate() ? null : _createTask,
          child: isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  bool _canCreate() {
    return summaryController.text.trim().isNotEmpty;
  }

  void _clearForm() {
    summaryController.clear();
    descriptionController.clear();
    selectedDue = null;
  }

  void _showDueDateDialog() {
    // Create a temporary task to pass to the DueDateDialog
    final tempTask = TaskFactory.createNew(
      summary: 'Temporary Task',
      description: '',
      due: selectedDue,
      categories: const [],
      sourceCalendarUid: widget.sourceCalendarUid,
    );

    DueDateDialog.show(
      context,
      task: tempTask,
      onTaskUpdated: (updatedTask) {
        setState(() {
          selectedDue = updatedTask.due;
        });
      },
    );
  }

  void _createTask() async {
    final taskSummary = summaryController.text.trim();
    final taskDescription = descriptionController.text.trim();
    
    if (taskSummary.isEmpty) {
      return;
    }

    setState(() => isLoading = true);

    try {
      AppLogger.info('TaskCreation: Creating task "$taskSummary"');
      
      // Use TaskViewModel to create the task with proper organizer
      final taskViewModel = ref.read(taskViewModelProvider.notifier);
      await taskViewModel.createTask(
        summary: taskSummary,
        description: taskDescription.isEmpty ? '' : taskDescription,
        due: selectedDue,
        categories: const [],
        sourceCalendarUid: widget.sourceCalendarUid,
      );

      // Check if there was an error during creation
      final currentState = ref.read(taskViewModelProvider);
      if (currentState.error != null) {
        // Task creation failed
        AppLogger.error('TaskCreation: Failed to create task: ${currentState.error}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: ${currentState.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        // Task creation succeeded
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "$taskSummary" created successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        
        // Refresh task providers to show the new task
        ref.invalidate(taskListProvider);
        ref.invalidate(todayTasksProvider);
        ref.invalidate(soonTasksProvider);
        ref.invalidate(laterTasksProvider);
        ref.invalidate(anytimeTasksProvider);
        
        // Handle dialog behavior based on checkbox
        if (keepDialogOpen) {
          // Clear form for next task but keep dialog open
          _clearForm();
          setState(() {}); // Refresh UI to show cleared form
        } else {
          // Close dialog as before
          Navigator.of(context).pop(taskSummary);
        }
      }
    } catch (e) {
      AppLogger.error('TaskCreation: Exception creating task: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create task: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
} 