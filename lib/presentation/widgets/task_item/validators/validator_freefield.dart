// Free field validator component for task items
// Displays text input field with change detection

import 'package:flutter/material.dart';
import '../../utils/enhanced_text_field.dart';

class ValidatorFreeField extends StatefulWidget {
  final Map<String, dynamic> validator;
  final Function(String validatorId, String newValue) onValueChanged;

  const ValidatorFreeField({
    super.key,
    required this.validator,
    required this.onValueChanged,
  });

  @override
  State<ValidatorFreeField> createState() => _ValidatorFreeFieldState();
}

class _ValidatorFreeFieldState extends State<ValidatorFreeField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final value = widget.validator['value'] as String? ?? '';
    _controller = TextEditingController(text: value);
  }

  @override
  void didUpdateWidget(ValidatorFreeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text when validator changes (e.g., when widget is reused for different validator)
    final oldValue = oldWidget.validator['value'] as String? ?? '';
    final newValue = widget.validator['value'] as String? ?? '';
    if (oldValue != newValue) {
      _controller.text = newValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validatorId = widget.validator['id'] as String;
    
    return EnhancedTextField(
      controller: _controller,
      onChanged: (newValue) => widget.onValueChanged(validatorId, newValue),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        hintText: 'Enter text...',
      ),
      style: const TextStyle(fontSize: 13),
      maxLines: null,
    );
  }
} 