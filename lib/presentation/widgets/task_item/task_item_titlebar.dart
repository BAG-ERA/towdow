// Task item titlebar component
// Contains checkbox, date badge, title, indicators, and expand button in a single row

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../../../data/services/validator_service.dart';
import 'task_item_date_badge.dart';

class TaskItemTitlebar extends StatelessWidget {
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
            value: isCompleted,
            onChanged: onToggleComplete != null 
                ? (_) => onToggleComplete!() 
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
        if (task.due != null) ...[
          TaskItemDateBadge(
            task: task,
          ),
          const SizedBox(width: 8),
        ],
        
        // Title (expandable to take available space)
        Expanded(
          child: Text(
            task.summary,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              decoration: isCompleted 
                  ? TextDecoration.lineThrough 
                  : null,
              color: isCompleted 
                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                  : colorScheme.onSurface,
              height: 1.3,
            ),
            maxLines: isExpanded ? null : 1,
            overflow: isExpanded ? null : TextOverflow.ellipsis,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Indicators
        _buildCompactIndicators(context),
        
        const SizedBox(width: 4),
        
        // Expand/Reduce button
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              isExpanded 
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
    if (task.attendees.isNotEmpty) {
      indicators.add(
        Icon(
          task.attendees.length == 1 ? Icons.person : Icons.group,
          size: 16,
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    
    // Categories indicator
    if (task.categories.isNotEmpty) {
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
    final validators = ValidatorService.parseValidators(task.flowitValidator);
    return validators.isNotEmpty && validators.any((list) => list.isNotEmpty);
  }
} 