// Checklist validator component for task items
// Displays checklist items with checkbox interaction and edit capabilities for organizers

import 'package:flutter/material.dart';

class ValidatorChecklist extends StatelessWidget {
  final Map<String, dynamic> validator;
  final bool isOrganizer;
  final Function(String validatorId, String itemId, bool checked) onItemToggled;
  final Function(String validatorId, String itemId, String text) onItemEdited;
  final Function(String validatorId, String itemId) onItemRemoved;
  final Function(String validatorId) onItemAdded;

  const ValidatorChecklist({
    super.key,
    required this.validator,
    required this.isOrganizer,
    required this.onItemToggled,
    required this.onItemEdited,
    required this.onItemRemoved,
    required this.onItemAdded,
  });

  @override
  Widget build(BuildContext context) {
    final items = validator['items'] as List<dynamic>? ?? [];
    final validatorId = validator['id'] as String;
    
    return Column(
      children: [
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final itemId = item['id'] as String;
          final text = item['text'] as String;
          final checked = item['checked'] as bool? ?? false;
          
          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 4 : 0),
            child: Row(
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: Checkbox(
                    value: checked,
                    onChanged: (value) => onItemToggled(validatorId, itemId, value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isOrganizer
                      ? InkWell(
                          onTap: () => _showEditDialog(context, itemId, text),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: checked 
                                  ? TextDecoration.lineThrough 
                                  : TextDecoration.underline,
                              decorationStyle: checked 
                                  ? TextDecorationStyle.solid 
                                  : TextDecorationStyle.dotted,
                              color: checked 
                                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            decoration: checked ? TextDecoration.lineThrough : null,
                            color: checked 
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                ),
                if (isOrganizer) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => onItemRemoved(validatorId, itemId),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.remove_circle_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (isOrganizer) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => onItemAdded(validatorId),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add item',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showEditDialog(BuildContext context, String itemId, String currentText) {
    final controller = TextEditingController(text: currentText);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Item text',
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
                onItemEdited(validator['id'] as String, itemId, newText);
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