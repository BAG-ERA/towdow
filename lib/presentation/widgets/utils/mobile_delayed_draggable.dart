// Mobile delayed draggable widget that waits 300ms before activating drag on mobile
// This improves scrolling experience by preventing accidental drag activation during scroll gestures

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/task.dart';
import '../../../core/logger.dart';

class MobileDelayedDraggableTask extends StatefulWidget {
  final Task task;
  final Widget child;
  final Widget? feedback;
  final Widget? childWhenDragging;
  final VoidCallback? onDragStarted;
  final Function(DraggableDetails)? onDragEnd;
  final Function(DragUpdateDetails)? onDragUpdate;
  final Function(DraggableDetails)? onDragCompleted;
  final bool enableDrag;

  const MobileDelayedDraggableTask({
    super.key,
    required this.task,
    required this.child,
    this.feedback,
    this.childWhenDragging,
    this.onDragStarted,
    this.onDragEnd,
    this.onDragUpdate,
    this.onDragCompleted,
    this.enableDrag = true,
  });

  @override
  State<MobileDelayedDraggableTask> createState() => _MobileDelayedDraggableTaskState();
}

class _MobileDelayedDraggableTaskState extends State<MobileDelayedDraggableTask> with TickerProviderStateMixin {
  Timer? _dragDelayTimer;
  bool _isDragging = false;
  bool _isDragDelayed = false;
  Offset? _dragStartPosition;
  bool _hasMoved = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final GlobalKey _draggableKey = GlobalKey();

  static const Duration _mobileDragDelay = Duration(milliseconds: 300);
  static const double _desktopBreakpoint = 800.0;
  static const double _moveThreshold = 8.0; // 8px threshold for movement detection

  bool get _isMobile => MediaQuery.of(context).size.width < _desktopBreakpoint;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _mobileDragDelay,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void deactivate() {
    // Reset all state when widget is deactivated
    _dragDelayTimer?.cancel();
    _animationController.reset();
    _isDragging = false;
    _isDragDelayed = false;
    _dragStartPosition = null;
    _hasMoved = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _dragDelayTimer?.cancel();
    _animationController.dispose();
    // Reset all state when disposing
    _isDragging = false;
    _isDragDelayed = false;
    _dragStartPosition = null;
    _hasMoved = false;
    super.dispose();
  }

  void _startDelayTimer() {
    if (!widget.enableDrag) return;

    _isDragDelayed = true;
    AppLogger.debug('MobileDelayedDraggable: Starting 300ms delay timer for drag on mobile');
    
    // Start the visual animation
    _animationController.forward();
    
    _dragDelayTimer = Timer(_mobileDragDelay, () {
      AppLogger.debug('MobileDelayedDraggable: Timer expired - mounted: $mounted, isDragDelayed: $_isDragDelayed, hasMoved: $_hasMoved');
      if (mounted && _isDragDelayed && !_hasMoved) {
        // Provide haptic feedback when timer completes
        HapticFeedback.mediumImpact();
        // Show draggable when timer ends
        setState(() {
          _isDragging = true;
          _isDragDelayed = false;
        });
        AppLogger.debug('MobileDelayedDraggable: Draggable shown after delay - _isDragging: $_isDragging');
      } else {
        AppLogger.debug('MobileDelayedDraggable: Timer expired but drag cancelled - mounted: $mounted, isDragDelayed: $_isDragDelayed, hasMoved: $_hasMoved');
      }
    });
    AppLogger.debug('MobileDelayedDraggable: Started 300ms delay for drag on mobile');
  }

  void _onDragStarted() {
    if (!widget.enableDrag) return;

    // On desktop, start immediately
    _startDrag();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enableDrag) return;

    // On mobile, track movement during delay period
    if (_isMobile && !_isDragging) {
      if (_dragStartPosition == null) {
        _dragStartPosition = details.globalPosition;
        AppLogger.debug('MobileDelayedDraggable: Set initial drag position: ${details.globalPosition}');
      } else {
        final distance = (details.globalPosition - _dragStartPosition!).distance;
        AppLogger.debug('MobileDelayedDraggable: Movement detected - distance: ${distance.toStringAsFixed(2)}px, threshold: ${_moveThreshold}px');
        if (distance > _moveThreshold) {
          _hasMoved = true;
          // Cancel drag if user moved during delay period
          _dragDelayTimer?.cancel();
          _isDragDelayed = false;
          AppLogger.debug('MobileDelayedDraggable: Cancelled drag due to movement during delay (distance: ${distance.toStringAsFixed(2)}px) - Timer cancelled');
          return;
        }
      }
      return;
    }

    widget.onDragUpdate?.call(details);
  }

  void _startDrag() {
    if (!mounted) return;

    setState(() {
      _isDragging = true;
      _isDragDelayed = false;
    });

    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Call external callback
    widget.onDragStarted?.call();
    
    AppLogger.debug('MobileDelayedDraggable: Drag started${_isMobile ? ' after delay' : ''} - isDragging: $_isDragging, isDragDelayed: $_isDragDelayed, hasMoved: $_hasMoved');
  }



  void _onDragEnd(DraggableDetails details) {
    if (!widget.enableDrag) return;

    // Cancel any pending delay timer
    if (_dragDelayTimer != null) {
      _dragDelayTimer?.cancel();
      _dragDelayTimer = null;
      AppLogger.debug('MobileDelayedDraggable: Timer cancelled in drag end');
    }

    setState(() {
      _isDragging = false;
      _isDragDelayed = false;
      _dragStartPosition = null;
      _hasMoved = false;
    });

    // Reset animation
    _animationController.reset();

    // Call external callback
    widget.onDragEnd?.call(details);
    widget.onDragCompleted?.call(details);
    
    AppLogger.debug('MobileDelayedDraggable: Drag ended - wasDragging: $_isDragging, wasDelayed: $_isDragDelayed, hadMoved: $_hasMoved');
  }



  @override
  Widget build(BuildContext context) {
    if (!widget.enableDrag) {
      return widget.child;
    }

    // On mobile, use simple approach: show draggable when timer ends
    if (_isMobile) {
      return GestureDetector(
        onTapDown: (details) {
          AppLogger.debug('MobileDelayedDraggable: Touch started on mobile');
          _dragStartPosition = details.globalPosition;
          _hasMoved = false;
          _startDelayTimer();
        },
        onPanUpdate: (details) {
          if (_dragStartPosition != null && !_isDragging) {
            final distance = (details.globalPosition - _dragStartPosition!).distance;
            AppLogger.debug('MobileDelayedDraggable: Touch movement - distance: ${distance.toStringAsFixed(2)}px, threshold: ${_moveThreshold}px');
            if (distance > _moveThreshold) {
              _hasMoved = true;
              // Cancel drag if user moved during delay period
              _dragDelayTimer?.cancel();
              _isDragDelayed = false;
              _animationController.reset();
              AppLogger.debug('MobileDelayedDraggable: Cancelled drag due to movement during delay (distance: ${distance.toStringAsFixed(2)}px) - Timer cancelled');
            }
          }
        },
        onPanEnd: (details) {
          AppLogger.debug('MobileDelayedDraggable: Touch ended on mobile');
          // Destroy draggable when touch ends
          _dragDelayTimer?.cancel();
          _animationController.reset();
          setState(() {
            _isDragging = false;
            _isDragDelayed = false;
            _dragStartPosition = null;
            _hasMoved = false;
          });
        },
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: _isDragDelayed 
                  ? Colors.blue.withOpacity(0.1 * _animation.value)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isDragging ? Draggable<Task>(
                data: widget.task,
                feedback: widget.feedback ?? widget.child,
                childWhenDragging: widget.childWhenDragging ?? Opacity(
                  opacity: 0.5,
                  child: widget.child,
                ),
                onDragStarted: () {
                  widget.onDragStarted?.call();
                  AppLogger.debug('MobileDelayedDraggable: Draggable started after delay');
                },
                onDragUpdate: widget.onDragUpdate,
                onDragEnd: _onDragEnd,
                child: widget.child,
              ) : widget.child,
            );
          },
        ),
      );
    }

    // On desktop, use regular Draggable
    return Draggable<Task>(
      data: widget.task,
      feedback: widget.feedback ?? widget.child,
      childWhenDragging: widget.childWhenDragging ?? Opacity(
        opacity: 0.5,
        child: widget.child,
      ),
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      child: widget.child,
    );
  }
} 