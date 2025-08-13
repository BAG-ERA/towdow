// Reusable editable title widget
// Used for both project titles and task titles with consistent styling and behavior

import 'package:flutter/material.dart';
import '../utils/enhanced_text_field.dart';

class EditableTitle extends StatefulWidget {
  final String title;
  final Function(String) onTitleUpdated;
  final bool isInAppBar;
  final TextStyle? textStyle;
  final Color? textColor;
  final String? hintText;
  final bool showActionButtons;
  final bool saveOnFocusLost;

  const EditableTitle({
    super.key,
    required this.title,
    required this.onTitleUpdated,
    this.isInAppBar = false,
    this.textStyle,
    this.textColor,
    this.hintText,
    this.showActionButtons = true,
    this.saveOnFocusLost = true,
  });

  @override
  State<EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<EditableTitle> {
  bool _isEditing = false;
  bool _isHovered = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing && widget.saveOnFocusLost) {
      _saveTitle();
    }
  }

  @override
  void didUpdateWidget(EditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the title changed externally, update controller if not editing
    if (oldWidget.title != widget.title && !_isEditing) {
      _controller.text = widget.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInAppBar = widget.isInAppBar;
    final primaryColor = widget.textColor ?? (isInAppBar 
        ? Theme.of(context).colorScheme.onSurface 
        : Theme.of(context).colorScheme.onPrimaryContainer);
    
    if (_isEditing) {
      if (isInAppBar) {
        // Simplified editing for AppBar
        return TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
            suffixIcon: widget.showActionButtons
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _cancelEdit,
                        tooltip: 'Cancel',
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 16),
                        onPressed: _saveTitle,
                        tooltip: 'Save',
                      ),
                    ],
                  )
                : null,
          ),
          style: widget.textStyle ?? Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
          onSubmitted: (_) => _saveTitle(),
        );
      }
      
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EnhancedTextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: widget.textStyle ?? Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              onSubmitted: (_) => _saveTitle(),
            ),
            if (widget.showActionButtons)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelEdit,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveTitle,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _startEditing,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: isInAppBar ? null : double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isInAppBar ? 4 : 4, 
            vertical: isInAppBar ? 4 : 8
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isInAppBar 
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.title,
            style: widget.textStyle ?? (isInAppBar 
                ? Theme.of(context).textTheme.titleLarge 
                : Theme.of(context).textTheme.headlineSmall)?.copyWith(
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.title;
    });
  }

  void _saveTitle() {
    if (_controller.text.trim().isNotEmpty) {
      final newTitle = _controller.text.trim();
      widget.onTitleUpdated(newTitle);
    }
    
    setState(() {
      _isEditing = false;
    });
  }
} 