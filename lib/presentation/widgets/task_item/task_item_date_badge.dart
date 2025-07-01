// Date badge component for task items
// Displays due date with color coding and formatting, handles date picker interaction

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../../../core/theme/chart_theme.dart';

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
    if (task.due == null) return context.chartTheme.colors.onSurfaceVariant;
    
    final now = DateTime.now();
    final due = task.due!;
    final daysUntilDue = due.difference(now).inDays;
    
    if (daysUntilDue < 0) {
      return context.chartTheme.colors.error; // Overdue - FlowIt Pink
    } else if (daysUntilDue == 0) {
      return context.chartTheme.colors.warning; // Due today - FlowIt Yellow Dark
    } else if (daysUntilDue <= 3) {
      return FlowItColors.coral; // Due soon - FlowIt Coral
    } else {
      return context.chartTheme.colors.primary; // FlowIt Blue Medium
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