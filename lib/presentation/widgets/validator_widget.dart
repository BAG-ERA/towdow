// Validator widget for displaying validators in expanded task state
// Shows validators with inline editing for organizers and state interaction for attendees

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/task.dart';
import '../../data/providers/providers.dart';
import '../../data/services/auth_token_provider.dart';
import '../../data/services/validator_service.dart';
import '../viewmodels/validator_viewmodel.dart';
import 'dart:convert';
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
      ref.read(validatorViewModelProvider.notifier).loadValidatorsForTask(widget.task);
    });
  }

  @override
  void didUpdateWidget(ValidatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.uid != widget.task.uid || 
        oldWidget.task.flowitValidator != widget.task.flowitValidator) {
      ref.read(validatorViewModelProvider.notifier).loadValidatorsForTask(widget.task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validatorState = ref.watch(validatorViewModelProvider);
    
    // Parse validators directly from task
    final validators = ValidatorService.parseValidators(widget.task.flowitValidator);
    
    if (validators.isEmpty) {
      return const SizedBox.shrink();
    }

    // Flatten all validators from all lists
    final allValidators = <Map<String, dynamic>>[];
    for (final validatorList in validators) {
      allValidators.addAll(validatorList.cast<Map<String, dynamic>>());
    }

    if (allValidators.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allValidators.asMap().entries.map((entry) {
        final index = entry.key;
        final validator = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < allValidators.length - 1 ? 12 : 0),
          child: _buildValidatorCard(validator),
        );
      }).toList(),
    );
  }

  Widget _buildValidatorCard(Map<String, dynamic> validator) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final type = validator['type'] as String;
    final title = validator['title'] as String? ?? 'Validator';
    final required = validator['required'] as bool? ?? true;
    final validatorId = validator['id'] as String;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
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
                child: _isOrganizer()
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
              if (_isOrganizer()) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _removeValidator(validatorId),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Validator content
          _buildValidatorContent(validator),
          
          // Helper text
          if (validator['helper'] != null && (validator['helper'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              validator['helper'] as String,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withOpacity(0.7),
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

  Widget _buildValidatorContent(Map<String, dynamic> validator) {
    final type = validator['type'] as String;
    
    switch (type) {
      case 'checklist':
        return _buildChecklistValidator(validator);
      case 'single_select':
        return _buildSingleSelectValidator(validator);
      case 'free_field':
        return _buildFreeFieldValidator(validator);
      case 'file':
      case 'media':
        return Consumer(
          builder: (context, ref, _) {
            final accountAsync = ref.watch(activeAccountProvider);
            return accountAsync.when(
              data: (account) {
                final accId = account?.id ?? '';
                return ValidatorFileWidget(
                  validator: validator,
                  accountId: accId,
                  jwtProvider: account != null
                      ? () => AuthTokenProvider.getValidToken(account)
                      : () async => '',
                  onValidatorChanged: (val) {},
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
        );
      default:
        return Text('Unknown validator type: $type');
    }
  }

  Widget _buildChecklistValidator(Map<String, dynamic> validator) {
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
                    onChanged: (value) => _updateChecklistItem(validatorId, itemId, value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isOrganizer()
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
                if (_isOrganizer()) ...[
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
        if (_isOrganizer()) ...[
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

  Widget _buildSingleSelectValidator(Map<String, dynamic> validator) {
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
                  onTap: () => _updateSelection(validatorId, optionId),
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
                  child: _isOrganizer()
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
                if (_isOrganizer()) ...[
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
        if (_isOrganizer()) ...[
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

  Widget _buildFreeFieldValidator(Map<String, dynamic> validator) {
    final value = validator['value'] as String? ?? '';
    final validatorId = validator['id'] as String;
    
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: (newValue) => _updateFreeField(validatorId, newValue),
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

  // Helper methods
  bool _isOrganizer() {
    // TODO: Implement organizer check based on current user and task.organizer
    // For now, return true to allow testing
    return true;
  }

  String _generateId() {
    return const Uuid().v4();
  }

  // State update methods
  void _updateChecklistItem(String validatorId, String itemId, bool checked) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            final items = validator['items'] as List<dynamic>? ?? [];
            for (final item in items) {
              if (item is Map<String, dynamic> && item['id'] == itemId) {
                item['checked'] = checked;
                return true; // Found and updated
              }
            }
          }
        }
      }
      return false;
    });
  }

  void _updateSelection(String validatorId, String selectedId) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            validator['selected'] = selectedId;
            return true; // Found and updated
          }
        }
      }
      return false;
    });
  }

  void _updateFreeField(String validatorId, String newValue) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            validator['value'] = newValue;
            return true; // Found and updated
          }
        }
      }
      return false;
    });
  }

  void _removeValidator(String validatorId) {
    _updateValidatorInTask((validators) {
      for (int i = 0; i < validators.length; i++) {
        final validatorList = validators[i];
        for (int j = 0; j < validatorList.length; j++) {
          final validator = validatorList[j];
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            validatorList.removeAt(j);
            // Remove empty lists
            if (validatorList.isEmpty) {
              validators.removeAt(i);
            }
            return true; // Found and removed
          }
        }
      }
      return false;
    });
  }

  // Edit methods for organizers
  void _editValidatorTitle(String validatorId, String currentTitle) {
    _showEditDialog(
      title: 'Edit Title',
      initialValue: currentTitle,
      onSave: (newTitle) {
        _updateValidatorInTask((validators) {
          for (final validatorList in validators) {
            for (final validator in validatorList) {
              if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
                validator['title'] = newTitle;
                return true;
              }
            }
          }
          return false;
        });
      },
    );
  }

  void _editChecklistItem(String validatorId, String itemId, String currentText) {
    _showEditDialog(
      title: 'Edit Item',
      initialValue: currentText,
      onSave: (newText) {
        _updateValidatorInTask((validators) {
          for (final validatorList in validators) {
            for (final validator in validatorList) {
              if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
                final items = validator['items'] as List<dynamic>? ?? [];
                for (final item in items) {
                  if (item is Map<String, dynamic> && item['id'] == itemId) {
                    item['text'] = newText;
                    return true;
                  }
                }
              }
            }
          }
          return false;
        });
      },
    );
  }

  void _editSelectOption(String validatorId, String optionId, String currentText) {
    _showEditDialog(
      title: 'Edit Option',
      initialValue: currentText,
      onSave: (newText) {
        _updateValidatorInTask((validators) {
          for (final validatorList in validators) {
            for (final validator in validatorList) {
              if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
                final options = validator['options'] as List<dynamic>? ?? [];
                for (final option in options) {
                  if (option is Map<String, dynamic> && option['id'] == optionId) {
                    option['text'] = newText;
                    return true;
                  }
                }
              }
            }
          }
          return false;
        });
      },
    );
  }

  void _addChecklistItem(String validatorId) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            final items = validator['items'] as List<dynamic>? ?? [];
            items.add({
              'id': _generateId(),
              'text': 'New item',
              'checked': false,
            });
            return true;
          }
        }
      }
      return false;
    });
  }

  void _removeChecklistItem(String validatorId, String itemId) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            final items = validator['items'] as List<dynamic>? ?? [];
            for (int i = 0; i < items.length; i++) {
              final item = items[i];
              if (item is Map<String, dynamic> && item['id'] == itemId) {
                items.removeAt(i);
                return true;
              }
            }
          }
        }
      }
      return false;
    });
  }

  void _removeSelectOption(String validatorId, String optionId) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            final options = validator['options'] as List<dynamic>? ?? [];
            for (int i = 0; i < options.length; i++) {
              final option = options[i];
              if (option is Map<String, dynamic> && option['id'] == optionId) {
                options.removeAt(i);
                return true;
              }
            }
          }
        }
      }
      return false;
    });
  }

  void _addSelectOption(String validatorId) {
    _updateValidatorInTask((validators) {
      for (final validatorList in validators) {
        for (final validator in validatorList) {
          if (validator is Map<String, dynamic> && validator['id'] == validatorId) {
            final options = validator['options'] as List<dynamic>? ?? [];
            options.add({
              'id': _generateId(),
              'text': 'New option',
            });
            return true;
          }
        }
      }
      return false;
    });
  }

  // Generic validator update method
  void _updateValidatorInTask(bool Function(List<dynamic>) updateFunction) {
    final validators = ValidatorService.parseValidators(widget.task.flowitValidator);
    
    if (updateFunction(validators)) {
      final updatedTask = widget.task.copyWith(
        flowitValidator: json.encode(validators),
        lastModified: DateTime.now(),
      );
      
      if (widget.onTaskUpdated != null) {
        widget.onTaskUpdated!(updatedTask);
      }
    }
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
} 