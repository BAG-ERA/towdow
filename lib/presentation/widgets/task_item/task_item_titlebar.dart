// Task item titlebar component
// Contains checkbox, date badge, title, indicators, and expand button in a single row

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../../../data/services/validator_service.dart';
import 'task_item_date_badge.dart';
import '../utils/enhanced_text_field.dart';

class TaskItemTitlebar extends StatefulWidget {
  final Task task;
  final bool isExpanded;
  final bool isCompleted;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onToggleExpanded;
  final Function(Task)? onTaskUpdated;

  const TaskItemTitlebar({
    super.key,
    required this.task,
    required this.isExpanded,
    required this.isCompleted,
    this.onToggleComplete,
    this.onToggleExpanded,
    this.onTaskUpdated,
  });

  @override
  State<TaskItemTitlebar> createState() => _TaskItemTitlebarState();
}

class _TaskItemTitlebarState extends State<TaskItemTitlebar> {
  bool _isEditing = false;
  bool _isHovered = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.summary);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Checkbox
        Transform.scale(
          scale: 0.9,
          child: Checkbox(
            value: widget.isCompleted,
            onChanged: widget.onToggleComplete != null 
                ? (_) => widget.onToggleComplete!() 
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Date badge
        if (widget.task.due != null) ...[
          TaskItemDateBadge(
            task: widget.task,
          ),
          const SizedBox(width: 8),
        ],
        
        // Title (expandable to take available space)
        Expanded(
          child: _buildTitleWidget(context, colorScheme),
        ),
        
        const SizedBox(width: 8),
        
        // Indicators
        _buildCompactIndicators(context),
        
        const SizedBox(width: 4),
        
        // Expand/Reduce button
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              widget.isExpanded 
                  ? Icons.expand_less_rounded 
                  : Icons.expand_more_rounded,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleWidget(BuildContext context, ColorScheme colorScheme) {
    if (_isEditing) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EnhancedTextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                height: 1.3,
              ),
              onSubmitted: (_) => _saveTitle(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveTitle,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          if (!widget.isExpanded) {
            // If collapsed, expand the task
            widget.onToggleExpanded?.call();
          } else if (widget.onTaskUpdated != null) {
            // If expanded, enter edit mode
            _startEditing();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isExpanded && _isHovered && widget.onTaskUpdated != null
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.task.summary,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              decoration: widget.isCompleted 
                  ? TextDecoration.lineThrough 
                  : null,
              color: widget.isCompleted 
                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                  : colorScheme.onSurface,
              height: 1.3,
            ),
            maxLines: widget.isExpanded ? null : 1,
            overflow: widget.isExpanded ? null : TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.task.summary;
    });
  }

  void _saveTitle() {
    if (widget.onTaskUpdated != null && _controller.text.trim().isNotEmpty) {
      final updatedTask = widget.task.copyWith(
        summary: _controller.text.trim(),
        lastModified: DateTime.now(),
      );
      widget.onTaskUpdated!(updatedTask);
    }
    
    setState(() {
      _isEditing = false;
    });
  }

  Widget _buildCompactIndicators(BuildContext context) {
    final indicators = <Widget>[];
    
    // Validator indicator (if not default)
    if (_hasNonDefaultValidator()) {
      indicators.add(
        Icon(
          Icons.fact_check,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    
    // Attendees indicator
    if (widget.task.attendees.isNotEmpty) {
      indicators.add(
        Icon(
          widget.task.attendees.length == 1 ? Icons.person : Icons.group,
          size: 16,
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    
    // Categories indicator
    if (widget.task.categories.isNotEmpty) {
      indicators.add(
        Icon(
          Icons.label_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      );
    }
    
    if (indicators.isEmpty) return const SizedBox.shrink();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: indicators
          .expand((widget) => [widget, const SizedBox(width: 6)])
          .take(indicators.length * 2 - 1)
          .toList(),
    );
  }

  bool _hasNonDefaultValidator() {
    final validators = ValidatorService.parseValidators(widget.task.flowitValidator);
    return validators.isNotEmpty && validators.any((list) => list.isNotEmpty);
  }
} 