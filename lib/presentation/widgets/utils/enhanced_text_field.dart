// Enhanced TextField widget with markdown support via EnhancedTextViewModel
// Supports real-time markdown parsing on space/return key events

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../viewmodels/enhanced_text_viewmodel.dart';

class EnhancedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? hintText;
  final String? labelText;
  final bool enabled;
  final bool readOnly;
  final EdgeInsets? contentPadding;
  final TextAlign textAlign;

  const EnhancedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.hintText,
    this.labelText,
    this.enabled = true,
    this.readOnly = false,
    this.contentPadding,
    this.textAlign = TextAlign.start,
  });

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

class _EnhancedTextFieldState extends State<EnhancedTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late EnhancedTextViewModel _markdownViewModel;
  bool _controllerCreated = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controllerCreated = widget.controller == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _markdownViewModel = EnhancedTextViewModel();
    
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_controllerCreated) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _markdownViewModel.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Focus change handling without rebuild
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(text);
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle character input and special keys
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _handleCharacterInput(' ');
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (HardwareKeyboard.instance.isControlPressed) {
          // Ctrl+Enter: Save description
          widget.onSubmitted?.call(_controller.text);
        } else {
          _handleCharacterInput('\n'); // Regular Enter
        }
      }
      // Handle regular character input for other keys
      else if (event.character != null && event.character!.isNotEmpty) {
        _handleCharacterInput(event.character!);
      }
      
      // Handle keyboard shortcuts
      if (HardwareKeyboard.instance.isControlPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyA:
            _handleSelectAll();
            break;
          case LogicalKeyboardKey.keyC:
            _handleCopy();
            break;
          case LogicalKeyboardKey.keyV:
            _handlePaste();
            break;
          case LogicalKeyboardKey.keyX:
            _handleCut();
            break;
        }
      }
    }
  }

  void _handleCharacterInput(String character) {
    // Add character to controller text
    final currentText = _controller.text;
    final newText = currentText + character;
    _controller.text = newText;
    
    // Trigger re-render with encode/decode cycle - only on keyboard input
    setState(() {
      widget.onChanged?.call(newText);
    });
  }

    @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.style ?? theme.textTheme.bodyMedium!;
    
    if (widget.readOnly) {
      // Display mode: Show formatted markdown text
      final spans = _markdownViewModel.decode(_controller.text, textStyle);
      
      return GestureDetector(
        onTap: () {
          if (widget.enabled) {
            widget.onTap?.call();
          }
        },
        child: Container(
          width: double.infinity,
          padding: widget.contentPadding ??
                   const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: _controller.text.isEmpty && widget.hintText != null
              ? Text(
                  widget.hintText!,
                  style: textStyle.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: widget.textAlign,
                )
              : RichText(
                  textAlign: widget.textAlign,
                  text: TextSpan(style: textStyle, children: spans),
                ),
        ),
      );
    } else {
      // Edit mode: Show editable TextField
      return KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: widget.decoration ?? const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          ),
          style: textStyle,
          maxLines: widget.maxLines,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          readOnly: false,
          textAlign: widget.textAlign,
          onChanged: _onTextChanged,
          onSubmitted: widget.onSubmitted,
          onTap: () => widget.onTap?.call(),
        ),
      );
    }
  }

  void _handleSelectAll() {
    if (_controller.text.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
  }

  void _handleCopy() {
    if (_controller.selection.isValid && !_controller.selection.isCollapsed) {
      final selectedText = _controller.text.substring(
        _controller.selection.start,
        _controller.selection.end,
      );
      Clipboard.setData(ClipboardData(text: selectedText));
    }
  }

  void _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      final text = clipboardData!.text!;
      final selection = _controller.selection;
      
      if (selection.isValid) {
        final newText = _controller.text.replaceRange(
          selection.start,
          selection.end,
          text,
        );
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + text.length),
        );
        _onTextChanged(newText);
      }
    }
  }

  void _handleCut() {
    if (_controller.selection.isValid && !_controller.selection.isCollapsed) {
      final selectedText = _controller.text.substring(
        _controller.selection.start,
        _controller.selection.end,
      );
      Clipboard.setData(ClipboardData(text: selectedText));
      
      final newText = _controller.text.replaceRange(
        _controller.selection.start,
        _controller.selection.end,
        '',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: _controller.selection.start),
      );
      _onTextChanged(newText);
    }
  }
}

// Simple TextFormField version for forms
class EnhancedTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final String? labelText;
  final bool enabled;
  final bool readOnly;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  const EnhancedTextFormField({
    super.key,
    this.controller,
    this.validator,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: decoration ?? InputDecoration(
        hintText: hintText,
        labelText: labelText,
      ),
      style: style,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
    );
  }
} 