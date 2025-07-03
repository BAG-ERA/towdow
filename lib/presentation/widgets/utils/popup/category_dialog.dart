// Category management dialog for adding, editing, and removing task categories
// Provides an interface for managing task categorization

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/models/task.dart';
import '../../../../core/logger.dart';

/// Dialog for managing task categories
class CategoryDialog extends StatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;

  const CategoryDialog({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  late List<String> _categories;
  bool _isLoading = false;

  // Common category suggestions
  static const List<String> _commonCategories = [
    'Work',
    'Personal',
    'Important',
    'Urgent',
    'Meeting',
    'Research',
    'Documentation',
    'Development',
    'Review',
    'Testing',
    'Bug Fix',
    'Feature',
    'Planning',
    'Design',
    'Finance',
    'Health',
    'Learning',
    'Travel',
    'Home',
    'Shopping',
  ];

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.task.categories);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
              
              // Current categories
              if (_categories.isNotEmpty) ...[
                Text(
                  'Current Categories',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCurrentCategories(),
                const SizedBox(height: 16),
              ],
              
              // Add new category form
              Text(
                'Add Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildAddCategoryForm(),
              
              const SizedBox(height: 16),
              
              // Common category suggestions
              Text(
                'Quick Add',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildCategorySuggestions(),
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
    );
  }

  Widget _buildCurrentCategories() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _categories.map((category) => _buildCategoryChip(category)).toList(),
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

  Widget _buildAddCategoryForm() {
    return Form(
      key: _formKey,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                hintText: 'Enter category name',
                border: OutlineInputBorder(),
                isDense: true,
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            tooltip: 'Add category',
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySuggestions() {
    // Filter out categories that are already added
    final availableCategories = _commonCategories
        .where((category) => !_categories.contains(category))
        .toList();

    if (availableCategories.isEmpty) {
      return Text(
        'All common categories are already added',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: availableCategories.take(10).map((category) => 
        ActionChip(
          label: Text(
            category,
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () => _addCategoryDirectly(category),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ).toList(),
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