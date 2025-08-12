// Reusable task creation dialog widget
// Used across the app for creating new tasks

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
// import '../../../../data/models/task_calendar.dart';
import '../../../viewmodels/attendee_suggestions_viewmodel.dart';
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

  final bool workflowVariant; // When true, show Profile/Attendee compact widgets
  final String? stepId; // Optional step to assign the task to

  const TaskCreationDialog({
    super.key,
    this.projectPath,
    this.initialCategories,
    this.workflowVariant = false,
    this.stepId,
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
  // Workflow variant: selected requirement ids (profiles)
  List<String> selectedRequirementIds = [];

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
          width: 480,
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

              if (widget.workflowVariant) ...[
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 12) / 2;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _ProfileSelector(
                            projectPath: widget.projectPath,
                            selectedIds: selectedRequirementIds,
                            onChanged: (ids) {
                              setState(() => selectedRequirementIds = ids);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: itemWidth,
                          child: _AssigneeQuickAdd(
                            selected: selectedAttendees,
                            onTapAdd: _showAttendeeDialog,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              
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
    if (summaryController.text.trim().isEmpty) return false;
    if (!widget.workflowVariant) return true;
    // In workflow variant, require either a profile (requirement) or an attendee
    final hasProfiles = selectedRequirementIds.isNotEmpty;
    final hasAttendees = selectedAttendees.isNotEmpty;
    return hasProfiles || hasAttendees;
  }

  void _clearForm() {
    summaryController.clear();
    descriptionController.clear();
    selectedDue = null;
    selectedCategories.clear();
    selectedAttendees.clear();
    selectedRequirementIds.clear();
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

    // Build suggested attendees via ViewModel (MVVM) - force load before showing dialog
    List<String>? suggestedEmails;
    if (widget.projectPath != null && widget.projectPath!.isNotEmpty) {
      // Always load to ensure suggestions are available immediately
      await ref.read(attendeeSuggestionsProvider(widget.projectPath!).notifier).load();
      final refreshed = ref.read(attendeeSuggestionsProvider(widget.projectPath!));
      suggestedEmails = refreshed.suggestions.isEmpty ? null : refreshed.suggestions;
    }

    final result = await showDialog<Task>(
      context: context,
      builder: (context) => AttendeeDialog(
        task: tempTask,
        onTaskUpdated: (updatedTask) {
          setState(() {
            selectedAttendees = updatedTask.attendees;
          });
        },
        suggestedAttendees: suggestedEmails,
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
      // For workflow variant, attach requirement ids into X-FLOWIT-REQUIREMENT on creation
      final flowitRequirement = widget.workflowVariant
          ? (selectedRequirementIds.isEmpty ? '[]' : '["' + selectedRequirementIds.join('\",\"') + '"]')
          : '{}';

      await taskViewModel.createTask(
        summary: taskSummary,
        description: taskDescription.isEmpty ? '' : taskDescription,
        due: selectedDue,
        categories: selectedCategories,
        attendees: selectedAttendees,
        projectPath: widget.projectPath,
        flowitRequirement: flowitRequirement,
        stepId: widget.stepId,
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

class _ProfileSelector extends ConsumerWidget {
  final String? projectPath;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  const _ProfileSelector({required this.projectPath, required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqsAsync = projectPath == null
        ? const AsyncValue<List<dynamic>>.data([])
        : ref.watch(projectRequirementsProvider(projectPath!));
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Profile', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('A profile is a skillset or responsibility needed for this task', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            reqsAsync.when(
              data: (reqs) {
                final items = reqs;
                if (items.isEmpty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCreateProfileDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Create profile'),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Select profile'),
                      items: [
                        ...items.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.name))).toList(),
                        // No direct widget item for button; provide separate inline action below
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final set = {...selectedIds};
                        set.add(value);
                        onChanged(set.toList());
                      },
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _showCreateProfileDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Create profile'),
                    ),
                    const SizedBox(height: 6),
                    if (selectedIds.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: selectedIds.map((id) {
                          final label = items.firstWhere((r) => r.id == id, orElse: () => null);
                          final name = label?.name ?? id;
                          return Chip(
                            label: Text(name),
                            onDeleted: () {
                              final next = [...selectedIds]..remove(id);
                              onChanged(next);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Text('Failed to load profiles: $e', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          ],
      ),
    );
  }

  void _showCreateProfileDialog(BuildContext context, WidgetRef ref) {
    if (projectPath == null) return;
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Profile'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create a new profile (requirement) for this workflow'),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Profile name *',
                  hintText: 'e.g., Lawyer, Sales, IT',
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              // Create requirement via repository
              final reqRepo = ref.read(requirementRepositoryProvider);
              final id = '${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}';
              await reqRepo.createRequirement(projectPath: projectPath!, id: id, name: name);
              // Refresh provider
              ref.invalidate(projectRequirementsProvider(projectPath!));
              // Preselect the newly created profile
              final next = {...selectedIds}..add(id);
              onChanged(next.toList());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
} 

class _AssigneeQuickAdd extends StatelessWidget {
  final List<Attendee> selected;
  final VoidCallback onTapAdd;
  const _AssigneeQuickAdd({required this.selected, required this.onTapAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attribute Task to someone', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('Every time we run this process this person will have this task (can be changed later)', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onTapAdd,
              icon: const Icon(Icons.person_add),
              label: const Text('Add person'),
            ),
            const SizedBox(height: 6),
            if (selected.isNotEmpty)
              Wrap(
                spacing: 6,
                children: selected
                    .map((a) => Chip(label: Text(a.displayName ?? a.email)))
                    .toList(),
              ),
          ],
        ),
    );
  }
}