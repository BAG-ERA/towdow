// StepHeader widget
// Reusable header for sections in the Step view: title and actions (expand/collapse) with optional inline editing

import 'package:flutter/material.dart';
import '../../../data/models/step.dart';

class StepHeader extends StatefulWidget {
  final String title;
  final int? count;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;
  final Widget? trailing;
  final bool draggable;
  final Widget? dragHandle;
  final bool editable;
  final ValueChanged<String>? onTitleSubmitted;
  final StepStatus? stepStatus;

  const StepHeader({
    super.key,
    required this.title,
    required this.onExpandAll,
    required this.onCollapseAll,
    this.count,
    this.trailing,
    this.draggable = false,
    this.dragHandle,
    this.editable = false,
    this.onTitleSubmitted,
    this.stepStatus,
  });

  @override
  State<StepHeader> createState() => _StepHeaderState();
}

class _StepHeaderState extends State<StepHeader> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _submit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant StepHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title && !_isEditing) {
      _controller.text = widget.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!widget.editable) return;
    setState(() => _isEditing = true);
    // Delay focus to next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    });
  }

  void _cancel() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.title;
    });
  }

  void _submit() {
    final newTitle = _controller.text.trim();
    setState(() => _isEditing = false);
    if (newTitle.isNotEmpty && newTitle != widget.title) {
      widget.onTitleSubmitted?.call(newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.stepStatus == StepStatus.completed;
    final isWaiting = widget.stepStatus == StepStatus.waiting;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isWaiting
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
              : Theme.of(context).colorScheme.onSurface,
          decoration: isCompleted ? TextDecoration.lineThrough : null,
        );

    Widget titleWidget;
    if (widget.editable) {
      titleWidget = _isEditing
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: titleStyle,
              ),
            )
          : InkWell(
              onTap: _startEditing,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: titleStyle,
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ],
              ),
            );
    } else {
      titleWidget = Text(
        widget.title,
        style: titleStyle,
      );
    }

    final headerRow = Row(
      children: [
        if (widget.draggable) ...[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: widget.dragHandle ?? const Icon(Icons.drag_indicator_rounded, size: 18),
          ),
        ],
        titleWidget,
        const Spacer(),
        if (widget.editable && _isEditing) ...[
          IconButton(
            tooltip: 'Cancel',
            onPressed: _cancel,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded, size: 18),
          ),
        ],
        if (widget.trailing != null) widget.trailing!,
      ],
    );

    return headerRow;
  }
}


