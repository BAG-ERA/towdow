// Reusable task creation dialog widget
// Used across the app for creating new tasks

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/attendee.dart';
import '../../../../data/providers/providers.dart';
import 'due_date_dialog.dart';
import 'category_dialog.dart';
import 'attendee_dialog.dart';
import '../enhanced_text_field.dart';

class TaskCreationDialog extends ConsumerStatefulWidget {
  final String? projectPath; // Optional project to assign the task to
  final List<String>? initialCategories; // Optional initial categories to assign

  const TaskCreationDialog({
    super.key,
    this.projectPath,
    this.initialCategories,
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
  bool showAdvancedFields = false; // Toggle for showing additional fields
  
  // Advanced fields
  List<String> selectedCategories = [];
  List<Attendee> selectedAttendees = [];

  @override
  void initState() {
    super.initState();
    selectedCategories = widget.initialCategories ?? [];
  }

  @override
  void dispose() {
    summaryController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Escape to close dialog
          if (event.logicalKey == LogicalKeyboardKey.escape && !isLoading) {
            Navigator.of(context).pop();
          }
          // Handle Ctrl+Enter or Cmd+Enter to submit
          else if (event.logicalKey == LogicalKeyboardKey.enter && 
                   (HardwareKeyboard.instance.isControlPressed || 
                    HardwareKeyboard.instance.isMetaPressed) &&
                   _canCreate() && !isLoading) {
            _createTask();
          }
        }
      },
      child: AlertDialog(
        title: const Text('Create Task'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Keep dialog open checkbox at the top
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
              
              const SizedBox(height: 16),
              
              EnhancedTextField(
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
              
              // Toggle button for advanced fields
              if (!showAdvancedFields) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      showAdvancedFields = true;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Show more options'),
                ),
              ],
              
              // Advanced fields (initially hidden)
              if (showAdvancedFields) ...[
                const SizedBox(height: 16),
                
                EnhancedTextField(
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
                
                // Categories field
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_rounded),
                  title: Text(selectedCategories.isEmpty 
                    ? 'No categories' 
                    : '${selectedCategories.length} categor${selectedCategories.length == 1 ? 'y' : 'ies'} selected'
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () => _showCategoryDialog(),
                ),
                
                const SizedBox(height: 16),
                
                // Attendees field
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_rounded),
                  title: Text(selectedAttendees.isEmpty 
                    ? 'No attendees' 
                    : '${selectedAttendees.length} attendee${selectedAttendees.length == 1 ? '' : 's'} selected'
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () => _showAttendeeDialog(),
                ),
                
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      showAdvancedFields = false;
                    });
                  },
                  icon: const Icon(Icons.expand_less),
                  label: const Text('Show fewer options'),
                ),
              ],
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
      ),
    );
  }

  bool _canCreate() {
    return summaryController.text.trim().isNotEmpty;
  }

  void _clearForm() {
    summaryController.clear();
    descriptionController.clear();
    selectedDue = null;
    selectedCategories.clear();
    selectedAttendees.clear();
  }

  void _showDueDateDialog() {
    // Create a temporary task to pass to the DueDateDialog
    final tempTask = TaskFactory.createNew(
      summary: 'Temporary Task',
      description: '',
      due: selectedDue,
      categoryIds: const [],
      projectPath: widget.projectPath,
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

  void _showCategoryDialog() async {
    // Create a temporary task with current selections
    final tempTask = TaskFactory.createNew(
      summary: summaryController.text.trim(),
      description: descriptionController.text.trim(),
      due: selectedDue,
      categoryIds: selectedCategories,
      projectPath: widget.projectPath,
    );

    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CategoryDialog(
        task: tempTask,
        onTaskUpdated: (updatedTask) {
          setState(() {
            selectedCategories = updatedTask.categoryIds;
          });
        },
        projectPath: widget.projectPath,
      ),
    );

    if (result != null) {
      setState(() {
        selectedCategories = result.categoryIds;
      });
    }
  }

  void _showAttendeeDialog() async {
    // Create a temporary task with current selections including attendees
    final tempTask = TaskFactory.createNew(
      summary: summaryController.text.trim(),
      description: descriptionController.text.trim(),
      due: selectedDue,
      categoryIds: selectedCategories,
      attendees: selectedAttendees,
      projectPath: widget.projectPath,
    );

    final result = await showDialog<Task>(
      context: context,
      builder: (context) => AttendeeDialog(
        task: tempTask,
        onTaskUpdated: (updatedTask) {
          setState(() {
            selectedAttendees = updatedTask.attendees;
          });
        },
        // Example: Add some suggested attendees based on project context
        suggestedAttendees: [
          'john.doe@example.com',
          'jane.smith@example.com',
          'team@example.com',
        ],
      ),
    );

    if (result != null) {
      setState(() {
        selectedAttendees = result.attendees;
      });
    }
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
        categories: selectedCategories,
        attendees: selectedAttendees,
        projectPath: widget.projectPath,
      );

              // Check if there was an error during creation
        final currentState = ref.read(taskViewModelProvider);
        if (currentState.error != null) {
          // Task creation failed
          AppLogger.error('TaskCreation: Failed to create task: ${currentState.error}');
          
          // Even on error, respect the keepDialogOpen setting
          if (!keepDialogOpen) {
            Navigator.of(context).pop();
          }
        } else {
          // Task creation succeeded
          
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
      
      // Even on exception, respect the keepDialogOpen setting
      if (!keepDialogOpen) {
        Navigator.of(context).pop();
      }
    } finally {
      setState(() => isLoading = false);
    }
  }
} 