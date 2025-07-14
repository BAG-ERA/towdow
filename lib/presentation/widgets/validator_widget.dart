// Validator widget for displaying validators in expanded task state
// Shows validators with inline editing for organizers and state interaction for attendees

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import '../../data/providers/providers.dart';
import '../viewmodels/validator_viewmodel.dart';
import 'task_item/validators/validator_file.dart';

/// Widget that displays validators in the expanded task state
class ValidatorWidget extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const ValidatorWidget({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  ConsumerState<ValidatorWidget> createState() => _ValidatorWidgetState();
}

class _ValidatorWidgetState extends ConsumerState<ValidatorWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(validatorViewModelProvider(widget.task.uid).notifier).loadValidatorsForTask(widget.task);
    });
  }

  @override
  void didUpdateWidget(ValidatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // With family provider, each task UID gets its own ViewModel instance
    // No need to reload validators - the ViewModel manages its own state
    // Task content updates are handled automatically by validator operations
  }



  @override
  Widget build(BuildContext context) {
    final validatorState = ref.watch(validatorViewModelProvider(widget.task.uid));
    
    if (validatorState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (validatorState.error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  validatorState.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!validatorState.hasValidators) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: validatorState.allValidators.asMap().entries.map((entry) {
        final index = entry.key;
        final validator = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < validatorState.allValidators.length - 1 ? 12 : 0),
          child: _buildValidatorCard(validator, validatorState),
        );
      }).toList(),
    );
  }

  Widget _buildValidatorCard(Map<String, dynamic> validator, ValidatorViewModelState validatorState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final type = validator['type'] as String;
    final title = validator['title'] as String? ?? 'Validator';
    final required = validator['required'] as bool? ?? true;
    final validatorId = validator['id'] as String;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with edit capability
          Row(
            children: [
              Expanded(
                child: validatorState.canEdit
                    ? _buildEditableTitle(validatorId, title)
                    : Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
              ),
              if (required)
                Text(
                  ' *',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (validatorState.canEdit) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _removeValidator(validatorId),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Validator content
          _buildValidatorContent(validator, validatorState),
          
          // Helper text
          if (validator['helper'] != null && (validator['helper'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              validator['helper'] as String,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableTitle(String validatorId, String currentTitle) {
    return InkWell(
      onTap: () => _editValidatorTitle(validatorId, currentTitle),
      child: Text(
        currentTitle,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        ),
      ),
    );
  }

  Widget _buildValidatorContent(Map<String, dynamic> validator, ValidatorViewModelState validatorState) {
    final type = validator['type'] as String;
    
    switch (type) {
      case 'checklist':
        return _buildChecklistValidator(validator, validatorState);
      case 'file':
        return _buildFileValidator(validator, validatorState);
      case 'single_select':
        return _buildSingleSelectValidator(validator, validatorState);
      case 'free_field':
        return _buildFreeFieldValidator(validator, validatorState);
      default:
        return Text('Unknown validator type: $type');
    }
  }

  Widget _buildChecklistValidator(Map<String, dynamic> validator, ValidatorViewModelState validatorState) {
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
                    onChanged: validatorState.canInteract 
                        ? (value) => _updateChecklistItem(validatorId, itemId, value ?? false)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: validatorState.canEdit
                      ? InkWell(
                          onTap: () => _editChecklistItem(validatorId, itemId, text),
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
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
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
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                ),
                if (validatorState.canEdit) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _removeChecklistItem(validatorId, itemId),
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
        if (validatorState.canEdit) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _addChecklistItem(validatorId),
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

  Widget _buildSingleSelectValidator(Map<String, dynamic> validator, ValidatorViewModelState validatorState) {
    final options = validator['options'] as List<dynamic>? ?? [];
    final selected = validator['selected'] as String? ?? '';
    final validatorId = validator['id'] as String;
    
    return Column(
      children: [
        ...options.asMap().entries.map((entry) {
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
                  onTap: validatorState.canInteract 
                      ? () => _updateSelection(validatorId, optionId)
                      : null,
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
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: validatorState.canEdit
                      ? InkWell(
                          onTap: () => _editSelectOption(validatorId, optionId, text),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
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
                if (validatorState.canEdit) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _removeSelectOption(validatorId, optionId),
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
        if (validatorState.canEdit) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _addSelectOption(validatorId),
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
                  'Add option',
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

  Widget _buildFreeFieldValidator(Map<String, dynamic> validator, ValidatorViewModelState validatorState) {
    final value = validator['value'] as String? ?? '';
    final validatorId = validator['id'] as String;
    
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: validatorState.canInteract 
          ? (newValue) => _updateFreeField(validatorId, newValue)
          : null,
      enabled: validatorState.canInteract,
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

  // Action methods - delegate to ViewModel
  void _updateChecklistItem(String validatorId, String itemId, bool checked) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'checklist_item', 'itemId': itemId, 'checked': checked}
    );
  }

  void _updateSelection(String validatorId, String selectedId) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'selection', 'selected': selectedId}
    );
  }

  void _updateFreeField(String validatorId, String newValue) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'free_field', 'value': newValue}
    );
  }

  void _removeValidator(String validatorId) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).removeValidator(validatorId);
  }

  void _addChecklistItem(String validatorId) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'add_checklist_item'}
    );
  }

  void _removeChecklistItem(String validatorId, String itemId) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'remove_checklist_item', 'itemId': itemId}
    );
  }

  void _addSelectOption(String validatorId) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'add_select_option'}
    );
  }

  void _removeSelectOption(String validatorId, String optionId) {
    ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
      validatorId, 
      {'type': 'remove_select_option', 'optionId': optionId}
    );
  }

  // Edit methods using simple dialogs
  void _editValidatorTitle(String validatorId, String currentTitle) {
    _showEditDialog(
      title: 'Edit Title',
      initialValue: currentTitle,
      onSave: (newTitle) {
        ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
          validatorId, 
          {'type': 'edit_title', 'title': newTitle}
        );
      },
    );
  }

  void _editChecklistItem(String validatorId, String itemId, String currentText) {
    _showEditDialog(
      title: 'Edit Item',
      initialValue: currentText,
      onSave: (newText) {
        ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
          validatorId, 
          {'type': 'edit_checklist_item', 'itemId': itemId, 'text': newText}
        );
      },
    );
  }

  void _editSelectOption(String validatorId, String optionId, String currentText) {
    _showEditDialog(
      title: 'Edit Option',
      initialValue: currentText,
      onSave: (newText) {
        ref.read(validatorViewModelProvider(widget.task.uid).notifier).updateValidatorState(
          validatorId, 
          {'type': 'edit_select_option', 'optionId': optionId, 'text': newText}
        );
      },
    );
  }

  void _showEditDialog({
    required String title,
    required String initialValue,
    required Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
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
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                onSave(newValue);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileValidator(Map<String, dynamic> validator, ValidatorViewModelState validatorState) {
    // Import and use the ValidatorFile widget
    return ValidatorFile(
      validator: validator,
      taskUid: widget.task.uid,
      isOrganizer: validatorState.canEdit,
      onValidatorUpdated: (validatorId, updateData) {
        ref.read(validatorViewModelProvider(widget.task.uid).notifier)
            .updateValidatorState(validatorId, updateData);
      },
    );
  }
} 