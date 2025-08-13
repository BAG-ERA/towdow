// Date badge component for task items
// Displays due date with color coding and formatting, handles date picker interaction

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../../../core/theme/chart_theme.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

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
    final dueText = _formatCompactDueDate(context, task.due!);
    final isOverdue = _dateOnly(task.due!).isBefore(_dateOnly(DateTime.now()));
    
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
    
    final today = _dateOnly(DateTime.now());
    final dueDay = _dateOnly(task.due!);
    final daysDifference = dueDay.difference(today).inDays;
    
    if (daysDifference < 0) {
      return context.chartTheme.colors.error; // Overdue - FlowIt Pink
    } else if (daysDifference == 0) {
      return context.chartTheme.colors.warning; // Due today - FlowIt Yellow Dark
    } else if (daysDifference <= 3) {
      return FlowItColors.coral; // Due soon - FlowIt Coral
    } else {
      return context.chartTheme.colors.primary; // FlowIt Blue Medium
    }
  }

  String _formatCompactDueDate(BuildContext context, DateTime dueDate) {
    final today = _dateOnly(DateTime.now());
    final dueDay = _dateOnly(dueDate);
    final daysDifference = dueDay.difference(today).inDays;
    
    if (daysDifference < 0) {
      final daysOverdue = -daysDifference;
      final l10n = AppLocalizations.of(context)!;
      if (daysOverdue == 1) return l10n.oneDayAgo;
      return l10n.nDaysAgo(daysOverdue);
    } else if (daysDifference == 0) {
      return AppLocalizations.of(context)!.today;
    } else if (daysDifference == 1) {
      return AppLocalizations.of(context)!.tomorrow;
    } else if (daysDifference <= 7) {
      return '${daysDifference}d';
    } else if (daysDifference <= 30) {
      return '${(daysDifference / 7).round()}w';
    } else {
      return '${dueDate.day}/${dueDate.month}';
    }
  }

  /// Helper method to get date-only (year, month, day) without time component
  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }


} 