// StepContainer widget
// Combines a step header with a drop target area that renders a task list or an empty placeholder

import 'package:flutter/material.dart';
import '../../../data/models/task.dart';
import '../../../data/models/step.dart';
import 'step_header.dart';

class StepContainer extends StatelessWidget {
  final String stepId;
  final String title;
  final int? count;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;
  final Widget? trailing;
  final bool draggable;
  final Widget? dragHandle;
  final bool editable;
  final ValueChanged<String>? onTitleSubmitted;

  final bool isEmpty;
  final Widget child;
  final Widget? emptyChild;
  final Color? statusColor;
  final Future<void> Function(Task task, String? targetStepId)? onTaskDropped;
  final StepStatus? stepStatus;
  final bool disabled;

  // Optional built-in menu actions
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onMarkAsFinal;
  final VoidCallback? onDelete;
  final String? markAsFinalLabel;
  // Optional extra actions to display before the popup menu in the header
  final Widget? extraTrailing;

  const StepContainer({
    super.key,
    required this.stepId,
    required this.title,
    required this.onExpandAll,
    required this.onCollapseAll,
    required this.isEmpty,
    required this.child,
    this.count,
    this.trailing,
    this.draggable = false,
    this.dragHandle,
    this.editable = false,
    this.onTitleSubmitted,
    this.emptyChild,
    this.statusColor,
    this.onTaskDropped,
    this.stepStatus,
    this.disabled = false,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onMarkAsFinal,
    this.onDelete,
    this.markAsFinalLabel,
    this.extraTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final Color hoverColor = statusColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: title,
          count: count,
          onExpandAll: onExpandAll,
          onCollapseAll: onCollapseAll,
          trailing: trailing ?? _composeTrailing(context),
          draggable: draggable,
          dragHandle: dragHandle,
          editable: editable,
          onTitleSubmitted: onTitleSubmitted,
          stepStatus: stepStatus,
        ),
        const SizedBox(height: 8),
        DragTarget<Task>(
          onAcceptWithDetails: (details) async {
            final task = details.data;
            final targetStepId = stepId == 'unassigned' ? null : stepId;
            if (onTaskDropped != null) {
              await onTaskDropped!(task, targetStepId);
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            final effectiveOpacity = disabled ? 0.5 : 1.0;
            final isCompleted = stepStatus == StepStatus.completed;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isHovering ? hoverColor.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isHovering
                    ? Border.all(color: hoverColor.withValues(alpha: 0.5), width: 2)
                    : (isCompleted ? Border.all(color: Theme.of(context).colorScheme.secondary, width: 2) : null),
              ),
              child: Opacity(
                opacity: effectiveOpacity,
                child: isEmpty ? (emptyChild ?? const SizedBox.shrink()) : child,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget? _composeTrailing(BuildContext context) {
    final popup = _buildPopupMenu(context);
    if (extraTrailing == null && popup == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (extraTrailing != null) extraTrailing!,
        if (extraTrailing != null && popup != null) const SizedBox(width: 8),
        if (popup != null) popup,
      ],
    );
  }

  Widget? _buildPopupMenu(BuildContext context) {
    final hasAnyAction = onMoveUp != null || onMoveDown != null || onMarkAsFinal != null || onDelete != null;
    if (!hasAnyAction) return null;
    return PopupMenuButton<String>(
      tooltip: 'Step options',
      onSelected: (value) async {
        switch (value) {
          case 'move_up':
            if (onMoveUp != null) onMoveUp!();
            break;
          case 'move_down':
            if (onMoveDown != null) onMoveDown!();
            break;
          case 'set_end':
            if (onMarkAsFinal != null) onMarkAsFinal!();
            break;
          case 'delete':
            if (onDelete != null) onDelete!();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'move_up',
          enabled: canMoveUp,
          child: const Row(
            children: [
              Icon(Icons.keyboard_arrow_up_rounded, size: 18),
              SizedBox(width: 8),
              Text('Move up'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'move_down',
          enabled: canMoveDown,
          child: const Row(
            children: [
              Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              SizedBox(width: 8),
              Text('Move down'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'set_end',
          child: Row(
            children: [
              const Icon(Icons.flag_circle_outlined, size: 18),
              const SizedBox(width: 8),
              Text(markAsFinalLabel ?? 'Mark as final step'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18),
              SizedBox(width: 8),
              Text('Delete step'),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded, size: 18),
    );
  }
}



