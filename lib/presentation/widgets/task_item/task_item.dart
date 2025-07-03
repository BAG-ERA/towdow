// Main task item widget with reduced complexity
// Orchestrates smaller components and maintains expansion state

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../../../data/services/validator_service.dart';
import 'task_item_titlebar.dart';
import 'task_item_description.dart';
import 'task_item_validatorlist.dart';
import 'task_item_toolbar.dart';

class TaskItemController {
  _TaskItemState? _state;
  
  void _attach(_TaskItemState state) => _state = state;
  void _detach() => _state = null;
  
  void expand() => _state?.expandTask();
  void collapse() => _state?.collapseTask();
}

class TaskItem extends StatefulWidget {
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
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _isExpanded = false;

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

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.task.status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titlebar with checkbox, date, title, indicators, and expand button
            TaskItemTitlebar(
              task: widget.task,
              isExpanded: _isExpanded,
              isCompleted: isCompleted,
              onToggleComplete: () => _handleTaskCompletion(),
              onToggleExpanded: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              onTaskUpdated: widget.onTaskUpdated,
            ),
            
            // Extended state content
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              
              // Description, attendees, and categories
              TaskItemDescription(
                task: widget.task,
                onTaskUpdated: widget.onTaskUpdated,
              ),
              
              // Validators
              const SizedBox(height: 8),
              TaskItemValidatorList(
                task: widget.task,
                onTaskUpdated: widget.onTaskUpdated,
              ),
              
              // Action buttons toolbar
              const SizedBox(height: 8),
              TaskItemToolbar(
                task: widget.task,
                onTaskUpdated: widget.onTaskUpdated,
                onTaskDeleted: widget.onTaskDeleted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTaskCompletion() {
    // Check if task has validators and if they're completed
    final validators = ValidatorService.parseValidators(widget.task.flowitValidator);
    
    if (validators.isNotEmpty && !ValidatorService.areValidatorsCompleted(validators)) {
      // Task has validators that aren't completed - expand to show them
      setState(() {
        _isExpanded = true;
      });
      
      // Show validation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all required validators before marking the task as done'),
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