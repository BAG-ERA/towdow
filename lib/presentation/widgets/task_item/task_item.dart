// Main task item widget with reduced complexity
// Orchestrates smaller components and maintains expansion state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../data/services/validator_service.dart';
import '../../../data/providers/providers_viewmodels.dart';
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
    
    // Set the selected task in the TaskViewModel to watch for updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskViewModelProvider.notifier).selectTask(widget.task);
    });
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

  @override
  Widget build(BuildContext context) {
    // Watch the TaskViewModel state to get the latest task data
    final taskState = ref.watch(taskViewModelProvider);
    
    // Use the selected task from the ViewModel if it matches our task, otherwise use the prop
    final currentTask = (taskState.selectedTask?.uid == widget.task.uid) 
        ? taskState.selectedTask! 
        : widget.task;
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
              onToggleComplete: () => _handleTaskCompletion(),
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

  void _handleTaskCompletion() {
    // Get the current task data from the reactive provider
    final taskState = ref.read(taskViewModelProvider);
    final currentTask = taskState.selectedTask ?? widget.task;
    
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