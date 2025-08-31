// Main task item widget with reduced complexity
// Orchestrates smaller components and maintains expansion state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../data/services/validator_service.dart';
import '../../../data/providers/providers_viewmodels.dart';
import '../../../data/providers/providers_project.dart';
import 'task_item_titlebar.dart';
import 'task_item_description.dart';
import 'task_item_validatorlist.dart';
import '../utils/popup/task_item_popup.dart';

class TaskItemController {
  _TaskItemState? _state;
  
  void _attach(_TaskItemState state) => _state = state;
  void _detach() => _state = null;
  
  void expand() => _state?.expandTask();
  void collapse() => _state?.collapseTask();
  void highlight() => _state?.highlightTask();
}

class TaskItem extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onTaskDeleted;
  final TaskItemController? controller;

  const TaskItem({
    super.key,
    required this.task,
    this.onTap,
    this.onToggleComplete,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.controller,
  });

  @override
  ConsumerState<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends ConsumerState<TaskItem> {
  bool _isExpanded = false;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  void expandTask() {
    if (!_isExpanded) {
      setState(() {
        _isExpanded = true;
      });
    }
  }

  void collapseTask() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
    }
  }

  void highlightTask() async {
    // Ensure the task is visible and expanded for emphasis
    expandTask();
    final context = _cardKey.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the reactive task data from the repository
    final taskListAsync = ref.watch(taskListProvider);
    
    // Find the current task in the reactive data
    final currentTask = taskListAsync.when(
      data: (tasks) {
        // Find the task with matching UID in the reactive data
        final updatedTask = tasks.firstWhere(
          (task) => task.uid == widget.task.uid,
          orElse: () => widget.task, // Fallback to prop if not found
        );
        return updatedTask;
      },
      loading: () => widget.task, // Use prop while loading
      error: (error, stack) => widget.task, // Use prop on error
    );
    
    final isCompleted = currentTask.status == 'COMPLETED';

    return Container(
      key: _cardKey,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: _isExpanded ? Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titlebar with checkbox, date, title, indicators, and expand button
            TaskItemTitlebar(
              task: currentTask,
              isExpanded: _isExpanded,
              isCompleted: isCompleted,
              onToggleComplete: () => _handleTaskCompletion(currentTask),
              onToggleExpanded: () async {
                if (!_isExpanded) {
                  final sourceContext = _cardKey.currentContext;
                  if (sourceContext != null) {
                    await TaskItemPopup.showFromContext(
                      context,
                      sourceContext: sourceContext,
                      task: currentTask,
                      onTaskUpdated: widget.onTaskUpdated,
                      onTaskDeleted: widget.onTaskDeleted,
                      onToggleComplete: widget.onToggleComplete,
                    );
                  } else {
                    await TaskItemPopup.show(
                      context,
                      task: currentTask,
                      onTaskUpdated: widget.onTaskUpdated,
                      onTaskDeleted: widget.onTaskDeleted,
                      onToggleComplete: widget.onToggleComplete,
                    );
                  }
                } else {
                  setState(() {
                    _isExpanded = false;
                  });
                }
              },
              onTaskUpdated: widget.onTaskUpdated,
            ),
            
            // Extended state content
            if (_isExpanded) ...[
              const SizedBox(height: 4),
              
              // Description, attendees, and categories
              TaskItemDescription(
                task: currentTask,
                onTaskUpdated: widget.onTaskUpdated,
              ),
              
              // Validators
              const SizedBox(height: 4),
              TaskItemValidatorList(
                task: currentTask,
                onTaskUpdated: widget.onTaskUpdated,
              ),
              
              // Toolbar removed from extended item; shown externally in popup layout
            ],
          ],
        ),
      ),
    );
  }

  void _handleTaskCompletion(Task currentTask) {
    // Check if task has validators and if they're completed
    final validators = ValidatorService.parseValidators(currentTask.flowitValidator);
    
    if (validators.isNotEmpty && !ValidatorService.areValidatorsCompleted(validators)) {
      // Task has validators that aren't completed - expand to show them
      setState(() {
        _isExpanded = true;
      });
      
      // Show validation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all required completion requirements before marking the task as done'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // No validators or all completed - proceed with normal toggle
    if (widget.onToggleComplete != null) {
      widget.onToggleComplete!();
    }
  }
} 