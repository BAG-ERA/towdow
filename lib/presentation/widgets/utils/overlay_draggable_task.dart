// Custom draggable widget that renders task feedback above sidebar using root overlay
// Solves the issue where regular Draggable feedback appears below navigation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/task.dart';
import '../task_item/task_item.dart';

class OverlayDraggableTask extends StatefulWidget {
  final Task task;
  final Widget child;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  const OverlayDraggableTask({
    super.key,
    required this.task,
    required this.child,
    this.onDragStarted,
    this.onDragEnd,
  });

  @override
  State<OverlayDraggableTask> createState() => _OverlayDraggableTaskState();
}

class _OverlayDraggableTaskState extends State<OverlayDraggableTask> {
  OverlayEntry? _overlayEntry;
  final ValueNotifier<Offset> _dragPosition = ValueNotifier<Offset>(Offset.zero);

  @override
  Widget build(BuildContext context) {
    return Draggable<Task>(
      data: widget.task,
      feedback: const SizedBox.shrink(), // KEY: Empty feedback to prevent double rendering
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: widget.child,
      ),
      child: widget.child,
    );
  }

  void _onDragStarted() {
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Call external callback
    widget.onDragStarted?.call();
    
    // Create overlay entry that renders above everything
    _overlayEntry = OverlayEntry(
      builder: (context) => ValueListenableBuilder<Offset>(
        valueListenable: _dragPosition,
        builder: (context, position, child) => _OverlayTaskFeedback(
          task: widget.task,
          offset: position,
        ),
      ),
    );
    
    // KEY: Use rootOverlay: true to render above sidebar and navbar
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Update position - this triggers ValueListenableBuilder rebuild
    _dragPosition.value = details.globalPosition;
  }

  void _onDragEnd(DraggableDetails details) {
    // Clean up overlay
    _overlayEntry?.remove();
    _overlayEntry = null;
    
    // Call external callback
    widget.onDragEnd?.call();
  }

  @override
  void dispose() {
    // Ensure overlay is cleaned up
    _overlayEntry?.remove();
    _dragPosition.dispose();
    super.dispose();
  }
}

/// Overlay widget that shows the task card above all UI elements
class _OverlayTaskFeedback extends StatelessWidget {
  final Task task;
  final Offset offset;

  const _OverlayTaskFeedback({
    required this.task,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Center the feedback on cursor with slight offset above
      left: offset.dx - 150, // Half of expected task width
      top: offset.dy - 40,   // Offset above cursor
      child: IgnorePointer( // KEY: Prevent blocking drop target interactions
        child: Material(
          elevation: 12, // Higher elevation for dramatic effect
          borderRadius: BorderRadius.circular(12),
          shadowColor: Colors.black.withValues(alpha: 0.3),
          child: Container(
            width: 300,
            constraints: const BoxConstraints(maxWidth: 300),
            child: TaskItem(
              task: task,
              onTap: null, // Disable all interactions during drag
              onToggleComplete: null,
              onTaskUpdated: null,
              onTaskDeleted: null,
            ),
          ),
        ),
      ),
    );
  }
} 