// Date badge component for task items
// Displays due date with color coding and formatting, handles date picker interaction

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';

class TaskItemDateBadge extends StatelessWidget {
  final Task task;

  const TaskItemDateBadge({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    if (task.due == null) return const SizedBox.shrink();
    
    final dueColor = _getDueDateColor(context);
    final dueText = _formatCompactDueDate(task.due!);
    final isOverdue = task.due!.isBefore(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dueColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dueColor.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOverdue)
            Icon(
              Icons.warning_rounded,
              size: 10,
              color: dueColor,
            ),
          if (isOverdue) const SizedBox(width: 2),
          Text(
            dueText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: dueColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDueDateColor(BuildContext context) {
    if (task.due == null) return Theme.of(context).colorScheme.onSurface;
    
    final now = DateTime.now();
    final due = task.due!;
    final daysUntilDue = due.difference(now).inDays;
    
    if (daysUntilDue < 0) {
      return Colors.red.shade600; // Overdue
    } else if (daysUntilDue == 0) {
      return Colors.orange.shade600; // Due today
    } else if (daysUntilDue <= 3) {
      return Colors.amber.shade600; // Due soon
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatCompactDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    
    if (difference.inDays < 0) {
      final daysOverdue = -difference.inDays;
      return daysOverdue == 1 ? '1d ago' : '${daysOverdue}d ago';
    } else if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays <= 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays <= 30) {
      return '${(difference.inDays / 7).round()}w';
    } else {
      return '${dueDate.day}/${dueDate.month}';
    }
  }


} 