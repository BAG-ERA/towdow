// Single select validator component for task items
// Displays radio button options with selection interaction and edit capabilities for organizers

import 'package:flutter/material.dart';

class ValidatorSelect extends StatelessWidget {
  final Map<String, dynamic> validator;
  final bool isOrganizer;
  final Function(String validatorId, String selectedId) onSelectionChanged;
  final Function(String validatorId, String optionId, String text) onOptionEdited;

  const ValidatorSelect({
    super.key,
    required this.validator,
    required this.isOrganizer,
    required this.onSelectionChanged,
    required this.onOptionEdited,
  });

  @override
  Widget build(BuildContext context) {
    final options = validator['options'] as List<dynamic>? ?? [];
    final selected = validator['selected'] as String? ?? '';
    final validatorId = validator['id'] as String;
    
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value as Map<String, dynamic>;
        final optionId = option['id'] as String;
        final text = option['text'] as String;
        final isSelected = selected == optionId;
        
        return Padding(
          padding: EdgeInsets.only(bottom: index < options.length - 1 ? 4 : 0),
          child: Row(
            children: [
              InkWell(
                onTap: () => onSelectionChanged(validatorId, optionId),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: isOrganizer
                    ? InkWell(
                        onTap: () => _showEditDialog(context, optionId, text),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          ),
                        ),
                      )
                    : Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showEditDialog(BuildContext context, String optionId, String currentText) {
    final controller = TextEditingController(text: currentText);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Option'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Option text',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                onOptionEdited(validator['id'] as String, optionId, newText);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
} 