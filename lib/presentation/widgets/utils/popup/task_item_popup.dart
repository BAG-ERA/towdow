// Popup variant of the Task UI
// Shows the extended task view in a centered dialog with a dark overlay

import 'package:flutter/material.dart';
import 'dart:math' as math;
// no-op

import '../../../../data/models/task.dart';
import '../../../../data/services/validator_service.dart';
import '../../task_item/task_item_titlebar.dart';
import '../../task_item/task_item_description.dart';
import '../../task_item/task_item_validatorlist.dart';
import '../../task_item/task_item_toolbar.dart';

class TaskItemPopup extends StatelessWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onTaskDeleted;
  final VoidCallback? onToggleComplete;

  const TaskItemPopup({
    super.key,
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 'COMPLETED';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaskItemTitlebar(
                task: task,
                isExpanded: true,
                isCompleted: isCompleted,
                onToggleComplete: () => _handleTaskCompletion(context),
                onToggleExpanded: null,
                onTaskUpdated: onTaskUpdated,
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),

              const SizedBox(height: 8),

              TaskItemDescription(
                task: task,
                onTaskUpdated: onTaskUpdated,
              ),

              const SizedBox(height: 8),

              TaskItemValidatorList(
                task: task,
                onTaskUpdated: onTaskUpdated,
              ),

              const SizedBox(height: 8),

              TaskItemToolbar(
                task: task,
                onTaskUpdated: onTaskUpdated,
                onTaskDeleted: onTaskDeleted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTaskCompletion(BuildContext context) {
    // If no handler provided, do nothing
    if (onToggleComplete == null) return;

    final validators = ValidatorService.parseValidators(task.flowitValidator);
    if (validators.isNotEmpty && !ValidatorService.areValidatorsCompleted(validators)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all required completion requirements before marking the task as done'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    onToggleComplete!.call();
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required Task task,
    Function(Task)? onTaskUpdated,
    VoidCallback? onTaskDeleted,
    VoidCallback? onToggleComplete,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => TaskItemPopup(
        task: task,
        onTaskUpdated: onTaskUpdated,
        onTaskDeleted: onTaskDeleted,
        onToggleComplete: onToggleComplete,
      ),
    );
  }

  /// Shows the popup anchored at the same top-left as the source widget
  static Future<T?> showFromContext<T>(
    BuildContext context, {
    required BuildContext sourceContext,
    required Task task,
    Function(Task)? onTaskUpdated,
    VoidCallback? onTaskDeleted,
    VoidCallback? onToggleComplete,
  }) {
    final sourceBox = sourceContext.findRenderObject() as RenderBox?;
    if (sourceBox == null || !sourceBox.attached) {
      // Fallback to centered popup
      return show<T>(
        context,
        task: task,
        onTaskUpdated: onTaskUpdated,
        onTaskDeleted: onTaskDeleted,
        onToggleComplete: onToggleComplete,
      );
    }

    // Compute coordinates in the root overlay's coordinate space for exact positioning
    final overlayBox = Overlay.of(context, rootOverlay: true).context.findRenderObject() as RenderBox;
    final originGlobal = sourceBox.localToGlobal(Offset.zero);
    final origin = overlayBox.globalToLocal(originGlobal);
    final sourceSize = sourceBox.size;
    final screenSize = overlayBox.size;

    // Compute width: prefer at least a desktop-friendly width when space allows
    final maxWidth = 820.0;
    final availableWidth = screenSize.width - origin.dx - 16;
    const minSideBySideTotalWidth = 560.0; // enough for card + left toolbar
    final targetWidth = math
        .min(math.max(sourceSize.width, minSideBySideTotalWidth), availableWidth)
        .clamp(280.0, maxWidth);

    // Compute maxHeight below the origin, allow scrolling inside (computed later from 'top')

    // Adjust vertical position with min-top and near-bottom constraints to ensure visibility
    const margin = 16.0;
    const preferredHeightForPlacement = 480.0;
    final widgetHeightForPlacement = math.min(
      preferredHeightForPlacement,
      screenSize.height - margin * 2,
    );
    double top = origin.dy;
    if (top + widgetHeightForPlacement > screenSize.height - margin) {
      top = (origin.dy - widgetHeightForPlacement)
          .clamp(margin, screenSize.height - margin - widgetHeightForPlacement);
    }
    // Enforce minimum top position: cannot go higher than 15% of window height
    final double minTop = screenSize.height * 0.15;
    if (top < minTop) {
      top = minTop;
    }

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, a1, a2) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              _AnchoredPopupScaffold(
                left: origin.dx,
                startTop: origin.dy,
                endTop: top,
                width: targetWidth,
                // Cap max height to 80% of window height and available space below top
                finalMaxHeight: math.min(
                  (screenSize.height - top - 16).clamp(200.0, screenSize.height),
                  screenSize.height * 0.8,
                ),
                screenHeight: screenSize.height,
                margin: 16.0,
                task: task,
                onTaskUpdated: onTaskUpdated,
                onTaskDeleted: onTaskDeleted,
                onToggleComplete: onToggleComplete,
                approxSourceWidth: sourceSize.width,
                initialHeight: sourceSize.height,
              ),
            ],
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        // Subtle scale-in from the anchor with fade for the card; overlay fade is handled by barrierColor
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        );
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutQuad),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}

class _AnchoredPopupScaffold extends StatefulWidget {
  final double left;
  final double startTop;
  final double endTop;
  final double width;
  final double finalMaxHeight;
  final double screenHeight;
  final double margin;
  final Task task;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onTaskDeleted;
  final VoidCallback? onToggleComplete;
  final double approxSourceWidth;
  final double initialHeight;

  const _AnchoredPopupScaffold({
    required this.left,
    required this.startTop,
    required this.endTop,
    required this.width,
    required this.finalMaxHeight,
    required this.screenHeight,
    required this.margin,
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onToggleComplete,
    required this.approxSourceWidth,
    required this.initialHeight,
  });

  @override
  State<_AnchoredPopupScaffold> createState() => _AnchoredPopupScaffoldState();
}

class _AnchoredPopupScaffoldState extends State<_AnchoredPopupScaffold> {
  late double _top;
  double _opacity = 0.0;
  double? _measuredContentHeight;

  @override
  void initState() {
    super.initState();
    _top = widget.startTop;
    // Start animations next frame to ensure initial layout is painted at source position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _top = _computeAnimatedEndTop();
        _opacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Align based on task card, not the whole container:
    // When using side-by-side layout (toolbar on the left), shift the container
    // so that the card's left aligns with the anchor (origin).
    final bool sideBySide = widget.width >= 560.0;
    const double toolbarWidth = 220.0;
    const double gap = 12.0;
    final double effectiveLeft = sideBySide ? (widget.left - (toolbarWidth + gap)) : widget.left;
    final double effectiveWidth = sideBySide ? (widget.width + toolbarWidth + gap) : widget.width;

    // Enforce max height on the whole container by pinning bottom bound
    final double bottomBound = math.max(0.0, widget.screenHeight - _top - widget.finalMaxHeight);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: effectiveLeft,
      top: _top,
      bottom: bottomBound,
      width: effectiveWidth,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutQuad,
        opacity: _opacity,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.finalMaxHeight,
          ),
          child: _buildPopupContent(),
        ),
      ),
    );
  }

  double _computeAnimatedEndTop() {
    final margin = widget.margin;
    final screenHeight = widget.screenHeight;
    final estHeight = _measuredContentHeight ?? math.min(480.0, screenHeight - margin * 2);
    var endTop = widget.endTop;
    if (endTop + estHeight > screenHeight - margin) {
      endTop = (widget.startTop - estHeight).clamp(margin, screenHeight - margin - estHeight);
    }
    return endTop;
  }

  Widget _buildPopupContent() {
    // Decide layout: side toolbar if enough width, else stacked
    final bool sideBySide = widget.width >= 560.0;

    final card = Expanded(
      child: _AnchoredTaskCard(
        task: widget.task,
        onTaskUpdated: widget.onTaskUpdated,
        onTaskDeleted: widget.onTaskDeleted,
        onToggleComplete: widget.onToggleComplete,
        approxSourceWidth: widget.approxSourceWidth,
        initialHeight: widget.initialHeight,
        targetMaxHeight: widget.finalMaxHeight,
        onMeasuredContentHeight: (h) {
          if (_measuredContentHeight == null) {
            _measuredContentHeight = h;
            setState(() {
              _top = _computeAnimatedEndTop();
            });
          }
        },
      ),
    );

    final toolbarContainerLeft = SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: TaskItemToolbar(
          task: widget.task,
          onTaskUpdated: widget.onTaskUpdated,
          onTaskDeleted: widget.onTaskDeleted,
          vertical: true,
          alignRight: true,
        ),
      ),
    );

    // Note: when stacked below, we render a clean toolbar without extra left padding

    if (sideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
          children: [toolbarContainerLeft, card],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnchoredTaskCard(
          task: widget.task,
          onTaskUpdated: widget.onTaskUpdated,
          onTaskDeleted: widget.onTaskDeleted,
          onToggleComplete: widget.onToggleComplete,
          approxSourceWidth: widget.approxSourceWidth,
          initialHeight: widget.initialHeight,
          targetMaxHeight: widget.finalMaxHeight,
          onMeasuredContentHeight: (h) {
            if (_measuredContentHeight == null) {
              _measuredContentHeight = h;
              setState(() {
                _top = _computeAnimatedEndTop();
              });
            }
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 220,
            child: TaskItemToolbar(
              task: widget.task,
              onTaskUpdated: widget.onTaskUpdated,
              onTaskDeleted: widget.onTaskDeleted,
              vertical: true,
              alignRight: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnchoredTaskCard extends StatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onTaskDeleted;
  final VoidCallback? onToggleComplete;
  final double approxSourceWidth;
  final double initialHeight;
  final double targetMaxHeight;
  final void Function(double height)? onMeasuredContentHeight;

  const _AnchoredTaskCard({
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.onToggleComplete,
    required this.approxSourceWidth,
    required this.initialHeight,
    required this.targetMaxHeight,
    this.onMeasuredContentHeight,
  });

  @override
  State<_AnchoredTaskCard> createState() => _AnchoredTaskCardState();
}

class _AnchoredTaskCardState extends State<_AnchoredTaskCard>
    with TickerProviderStateMixin {
  // AnimatedSize handles the height growth to content height
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Trigger the size animation on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _expanded = true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.task.status == 'COMPLETED';

    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskItemTitlebar(
          task: widget.task,
          isExpanded: true,
          isCompleted: isCompleted,
          onToggleComplete: () => _handleTaskCompletion(context),
          onToggleExpanded: null,
          onTaskUpdated: widget.onTaskUpdated,
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),

        const SizedBox(height: 8),

        TaskItemDescription(
          task: widget.task,
          onTaskUpdated: widget.onTaskUpdated,
        ),

        const SizedBox(height: 8),

        TaskItemValidatorList(
          task: widget.task,
          onTaskUpdated: widget.onTaskUpdated,
        ),

        const SizedBox(height: 8),

        // Toolbar removed from inside card; rendered externally in popup layout
      ],
    );

    final constrainedContent = ConstrainedBox(
      constraints: BoxConstraints(
        // Do not exceed available space below the anchor
        maxHeight: widget.targetMaxHeight,
        // Ensure a small minimal height for better visual feedback
        minHeight: widget.initialHeight,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _MeasureSize(
          onChange: (size) {
            if (widget.onMeasuredContentHeight != null) {
              widget.onMeasuredContentHeight!(size.height + 24 /* padding */);
            }
          },
          child: content,
        ),
      ),
    );

    final initialSized = SizedBox(
      height: widget.initialHeight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _MeasureSize(
          onChange: (size) {
            if (widget.onMeasuredContentHeight != null) {
              widget.onMeasuredContentHeight!(size.height + 24 /* padding */);
            }
          },
          child: content,
        ),
      ),
    );

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surface),
        child: ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: _expanded ? constrainedContent : initialSized,
          ),
        ),
      ),
    );
  }

  void _handleTaskCompletion(BuildContext context) {
    if (widget.onToggleComplete == null) return;
    final validators = ValidatorService.parseValidators(widget.task.flowitValidator);
    if (validators.isNotEmpty && !ValidatorService.areValidatorsCompleted(validators)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all required completion requirements before marking the task as done'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onToggleComplete!.call();
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final void Function(Size size) onChange;
  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contextSize = context.size;
      if (contextSize != null && _oldSize != contextSize) {
        _oldSize = contextSize;
        widget.onChange(contextSize);
      }
    });
    return widget.child;
  }
}


