// Draggable column header widget for kanban board column reordering
// Provides visual feedback during drag operations and handles column drag events
// Follows MVVM architecture by delegating business logic to ViewModel

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';

class DraggableColumnHeader extends ConsumerWidget {
  final String columnId;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final int taskCount;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final Function(String)? onColumnHide;
  final bool isDragging;
  final bool isReorderingColumns;
  final Function(String)? onDragStarted;
  final VoidCallback? onDragEnded;

  const DraggableColumnHeader({
    super.key,
    required this.columnId,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.taskCount,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.onColumnHide,
    this.isDragging = false,
    this.isReorderingColumns = false,
    this.onDragStarted,
    this.onDragEnded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isCollapsed) {
      return _buildCollapsedHeader(context);
    }

    return Draggable<String>(
      data: columnId,
      feedback: _buildDragFeedback(context),
      childWhenDragging: _buildDraggingPlaceholder(context),
      onDragStarted: () {
        AppLogger.info('DraggableColumnHeader: Started dragging column "$columnId"');
        onDragStarted?.call(columnId);
      },
      onDragEnd: (details) {
        AppLogger.info('DraggableColumnHeader: Ended dragging column "$columnId" - wasAccepted: ${details.wasAccepted}');
        onDragEnded?.call();
      },
      child: _buildNormalHeader(context),
    );
  }

  /// Build the normal header (not being dragged)
  Widget _buildNormalHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Drag handle icon
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              //color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.drag_indicator,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          
          // Category icon
          /** TODO: Think about it (either add custom icon feature or remove it)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          */

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Task count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$taskCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Action buttons
          if (columnId == 'uncategorized' && onToggleCollapse != null)
            IconButton(
              onPressed: onToggleCollapse,
              icon: Icon(
                Icons.keyboard_double_arrow_left,
                size: 16,
                color: color.withValues(alpha: 0.7),
              ),
              tooltip: 'Collapse column',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            )
          else if (onColumnHide != null && columnId != 'uncategorized')
            IconButton(
              onPressed: () => onColumnHide?.call(columnId),
              icon: Icon(
                Icons.visibility_off_rounded,
                size: 16,
                color: color.withValues(alpha: 0.7),
              ),
              tooltip: 'Hide column',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
        ],
      ),
    );
  }

  /// Build the drag feedback (what user sees while dragging)
  Widget _buildDragFeedback(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Drag handle icon
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.drag_indicator,
                color: color,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            
            // Category icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            // Task count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$taskCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the placeholder shown when this column is being dragged
  Widget _buildDraggingPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          // Drag handle icon (dimmed)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.drag_indicator,
              color: color.withValues(alpha: 0.3),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          
          // Category icon (dimmed)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color.withValues(alpha: 0.3),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          
          // Title and subtitle (dimmed)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          
          // Task count (dimmed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$taskCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build collapsed header (60px width with icon and expand button)
  Widget _buildCollapsedHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: color,
          size: 16,
        ),
      ),
    );
  }
}
