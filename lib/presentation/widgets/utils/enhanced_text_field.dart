// Enhanced TextField widget with proper keyboard shortcuts support
// Provides standard text editing shortcuts like Ctrl+A, Ctrl+C, Ctrl+V, etc.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EnhancedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? hintText;
  final String? labelText;
  final bool enabled;
  final bool readOnly;
  final EdgeInsets? contentPadding;
  final InputBorder? border;
  final bool isDense;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? minLines;
  final int? maxLength;
  final bool expands;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;

  const EnhancedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.hintText,
    this.labelText,
    this.enabled = true,
    this.readOnly = false,
    this.contentPadding,
    this.border,
    this.isDense = false,
    this.prefixIcon,
    this.suffixIcon,
    this.minLines,
    this.maxLength,
    this.expands = false,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
  });

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

class _EnhancedTextFieldState extends State<EnhancedTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _controllerCreated = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();
    _controllerCreated = widget.controller == null;
  }

  @override
  void dispose() {
    if (_controllerCreated) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create proper input decoration
    final decoration = widget.decoration ?? InputDecoration(
      hintText: widget.hintText,
      labelText: widget.labelText,
      contentPadding: widget.contentPadding,
      border: widget.border,
      isDense: widget.isDense,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
    );

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Ctrl+A for select all
          if (event.logicalKey == LogicalKeyboardKey.keyA && 
              HardwareKeyboard.instance.isControlPressed) {
            _handleSelectAll();
          }
          // Handle Ctrl+C for copy
          else if (event.logicalKey == LogicalKeyboardKey.keyC && 
                   HardwareKeyboard.instance.isControlPressed) {
            _handleCopy();
          }
          // Handle Ctrl+V for paste
          else if (event.logicalKey == LogicalKeyboardKey.keyV && 
                   HardwareKeyboard.instance.isControlPressed) {
            _handlePaste();
          }
          // Handle Ctrl+X for cut
          else if (event.logicalKey == LogicalKeyboardKey.keyX && 
                   HardwareKeyboard.instance.isControlPressed) {
            _handleCut();
          }
        }
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: decoration,
        style: widget.style,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        maxLength: widget.maxLength,
        expands: widget.expands,
        textAlign: widget.textAlign,
        textAlignVertical: widget.textAlignVertical,
        enableInteractiveSelection: true,
        contextMenuBuilder: (context, editableTextState) {
          return AdaptiveTextSelectionToolbar.editableText(
            editableTextState: editableTextState,
          );
        },
      ),
    );
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
        
        // Notify listeners
        if (widget.onChanged != null) {
          widget.onChanged!(newText);
        }
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
      
      // Notify listeners
      if (widget.onChanged != null) {
        widget.onChanged!(newText);
      }
    }
  }
}

// Companion widget for TextFormField
class EnhancedTextFormField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool autofocus;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final String? hintText;
  final String? labelText;
  final bool enabled;
  final bool readOnly;
  final EdgeInsets? contentPadding;
  final InputBorder? border;
  final bool isDense;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? minLines;
  final int? maxLength;
  final bool expands;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  const EnhancedTextFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.hintText,
    this.labelText,
    this.enabled = true,
    this.readOnly = false,
    this.contentPadding,
    this.border,
    this.isDense = false,
    this.prefixIcon,
    this.suffixIcon,
    this.minLines,
    this.maxLength,
    this.expands = false,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.validator,
    this.autovalidateMode,
  });

  @override
  State<EnhancedTextFormField> createState() => _EnhancedTextFormFieldState();
}

class _EnhancedTextFormFieldState extends State<EnhancedTextFormField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _controllerCreated = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();
    _controllerCreated = widget.controller == null;
  }

  @override
  void dispose() {
    if (_controllerCreated) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create proper input decoration
    final decoration = widget.decoration ?? InputDecoration(
      hintText: widget.hintText,
      labelText: widget.labelText,
      contentPadding: widget.contentPadding,
      border: widget.border,
      isDense: widget.isDense,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
    );

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Ctrl+A for select all
          if (event.logicalKey == LogicalKeyboardKey.keyA && 
              HardwareKeyboard.instance.isControlPressed) {
            _handleSelectAll();
          }
          // Handle Ctrl+C for copy
          else if (event.logicalKey == LogicalKeyboardKey.keyC && 
                   HardwareKeyboard.instance.isControlPressed) {
            _handleCopy();
          }
          // Handle Ctrl+V for paste
          else if (event.logicalKey == LogicalKeyboardKey.keyV && 
                   HardwareKeyboard.instance.isControlPressed) {
            _handlePaste();
          }
          // Handle Ctrl+X for cut
          else if (event.logicalKey == LogicalKeyboardKey.keyX && 
                   HardwareKeyboard.instance.isControlPressed) {
            _handleCut();
          }
        }
      },
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: decoration,
        style: widget.style,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        onTap: widget.onTap,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        maxLength: widget.maxLength,
        expands: widget.expands,
        textAlign: widget.textAlign,
        textAlignVertical: widget.textAlignVertical,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        enableInteractiveSelection: true,
        contextMenuBuilder: (context, editableTextState) {
          return AdaptiveTextSelectionToolbar.editableText(
            editableTextState: editableTextState,
          );
        },
      ),
    );
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
        
        // Notify listeners
        if (widget.onChanged != null) {
          widget.onChanged!(newText);
        }
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
      
      // Notify listeners
      if (widget.onChanged != null) {
        widget.onChanged!(newText);
      }
    }
  }
} 