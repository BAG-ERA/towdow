// Free field validator component for task items
// Displays text input field with change detection

import 'package:flutter/material.dart';

class ValidatorFreeField extends StatelessWidget {
  final Map<String, dynamic> validator;
  final Function(String validatorId, String newValue) onValueChanged;

  const ValidatorFreeField({
    super.key,
    required this.validator,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final value = validator['value'] as String? ?? '';
    final validatorId = validator['id'] as String;
    
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: (newValue) => onValueChanged(validatorId, newValue),
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