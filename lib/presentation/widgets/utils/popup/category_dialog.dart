// Category management dialog for adding, editing, and removing task categories
// Provides an interface for managing task categorization

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';

/// Dialog for managing task categories
class CategoryDialog extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;
  final String? projectPath; // Optional project path to get all categories from the project

  const CategoryDialog({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    this.projectPath,
  });

  @override
  ConsumerState<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  late List<String> _categories;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.task.categories);
    
    // Add listener to update UI when text changes
    _categoryController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Escape to close dialog
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isLoading) {
            Navigator.of(context).pop();
          }
          // Handle Ctrl+Enter or Cmd+Enter to save
          else if (event.logicalKey == LogicalKeyboardKey.enter && 
                   (HardwareKeyboard.instance.isControlPressed || 
                    HardwareKeyboard.instance.isMetaPressed) && !_isLoading) {
            _saveCategories();
          }
        }
      },
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.label_rounded),
            SizedBox(width: 12),
            Text('Manage Categories'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 600 ? 400 : MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task: ${widget.task.summary}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Create category form at the top
                _buildAddCategoryForm(),
                
                const SizedBox(height: 16),
                
                // Project categories section (if projectPath is provided)
                if (widget.projectPath != null) ...[
                  _buildProjectCategoriesSection(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveCategories,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Chip(
      label: Text(
        category,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: Icon(
        Icons.close,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      onDeleted: () => _removeCategory(category),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildProjectCategoriesSection() {
    return Consumer(
      builder: (context, ref, child) {
        final tasksAsync = ref.watch(projectTasksProvider(widget.projectPath!));
        
        return tasksAsync.when(
          data: (tasks) {
            // Get all unique categories from tasks in the project
            final Set<String> allCategories = {};
            for (final task in tasks) {
              allCategories.addAll(task.categories);
            }
            
            final categoriesList = allCategories.toList()..sort();
            
            // Filter out categories that are already added to current task
            final availableCategories = categoriesList
                .where((category) => !_categories.contains(category))
                .toList();
            
            // Filter categories based on input field content
            final searchQuery = _categoryController.text.trim().toLowerCase();
            final filteredCategories = searchQuery.isEmpty 
                ? availableCategories 
                : availableCategories
                    .where((category) => category.toLowerCase().contains(searchQuery))
                    .toList();
            
            if (filteredCategories.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  searchQuery.isEmpty 
                      ? 'Categories used in this project:'
                      : 'Matching categories:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: filteredCategories.map((category) => 
                    ActionChip(
                      label: Text(
                        category,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _addCategoryDirectly(category),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ).toList(),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildAddCategoryForm() {
    return Form(
      key: _formKey,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                hintText: 'Enter category name',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: _categories.isNotEmpty 
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: _categories.map((category) => _buildCategoryChip(category)).toList(),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category cannot be empty';
                }
                if (_categories.contains(value.trim())) {
                  return 'Category already exists';
                }
                return null;
              },
              onFieldSubmitted: (_) => _addCategory(),
            ),
          ),
          if (!_isExactMatch() && _categoryController.text.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _addCategory,
              child: Text(_getButtonText()),
            ),
          ],
        ],
      ),
    );
  }

  void _addCategory() {
    if (_formKey.currentState?.validate() == true) {
      final category = _categoryController.text.trim();
      setState(() {
        _categories.add(category);
        _categoryController.clear();
      });
      AppLogger.info('CategoryDialog: Added category "$category"');
      HapticFeedback.lightImpact();
    }
  }

  void _addCategoryDirectly(String category) {
    setState(() {
      _categories.add(category);
    });
    AppLogger.info('CategoryDialog: Added category "$category" directly');
    HapticFeedback.lightImpact();
  }

  bool _isExactMatch() {
    final inputText = _categoryController.text.trim();
    if (inputText.isEmpty) return false;
    
    // Check if the input exactly matches any existing category in current task (case-insensitive)
    final isMatch = _categories.any((category) => 
        category.toLowerCase() == inputText.toLowerCase());
    
    AppLogger.debug('CategoryDialog: Input "$inputText" exact match: $isMatch (categories: $_categories)');
    return isMatch;
  }

  String _getButtonText() {
    final inputText = _categoryController.text.trim();
    if (inputText.isEmpty) {
      return 'Add new';
    }
    return 'Create "$inputText"';
  }

  void _removeCategory(String category) {
    setState(() {
      _categories.remove(category);
    });
    AppLogger.info('CategoryDialog: Removed category "$category"');
    HapticFeedback.lightImpact();
  }

  void _saveCategories() async {
    setState(() => _isLoading = true);
    
    try {
      final updatedTask = widget.task.copyWith(
        categories: _categories,
        lastModified: DateTime.now(),
      );
      
      widget.onTaskUpdated(updatedTask);
      AppLogger.info('CategoryDialog: Updated task categories to: $_categories');
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_categories.isEmpty 
                ? 'All categories removed'
                : 'Categories updated: ${_categories.join(', ')}'
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('CategoryDialog: Error updating categories', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating categories: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
} 