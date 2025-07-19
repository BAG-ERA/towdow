// Category management dialog for adding, editing, and removing task categories
// Provides an interface for managing task categorization with the new Category model

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/category.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';
import '../../../../core/theme/chart_theme.dart';

/// Dialog for managing task categories using the new Category model
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
  late List<String> _selectedCategoryIds;
  bool _isLoading = false;
  Color _selectedColor = Colors.blue;
  
  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = List.from(widget.task.categoryIds);
    
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
                
                // Create category form
                _buildAddCategoryForm(),
                
                const SizedBox(height: 16),
                
                // Project categories section
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
          FilledButton(
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

  Widget _buildAddCategoryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create New Category',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  hintText: 'Enter category name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Color: ', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  _buildColorPicker(),
                  const Spacer(),
                  if (_categoryController.text.trim().isNotEmpty)
                    ElevatedButton(
                      onPressed: _createCategory,
                      child: const Text('Create'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Selected categories display
        if (_selectedCategoryIds.isNotEmpty) ...[
          Text(
            'Selected Categories',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _buildSelectedCategoriesDisplay(),
        ],
      ],
    );
  }

  Widget _buildColorPicker() {
    // Use FlowIt chart color series for consistent branding
    final colors = [
      FlowItColors.primary,           // Blue Medium
      FlowItColors.waterGreen,        // Water Green
      FlowItColors.violet,            // Violet
      FlowItColors.greenApple,        // Green Apple
      FlowItColors.yellowDark,        // Yellow Dark
      FlowItColors.pink,              // Pink
      FlowItColors.coral,             // Coral
      FlowItColors.greenAnis,         // Green Anis
    ];
    
    return Wrap(
      spacing: 4,
      children: colors.map((color) {
        final isSelected = _selectedColor.value == color.value;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedCategoriesDisplay() {
    return Consumer(
      builder: (context, ref, child) {
        final viewModelState = ref.watch(projectCategoryViewModelProvider(widget.projectPath ?? ''));
        
        if (viewModelState.isLoading) {
          return const CircularProgressIndicator();
        }
        
        final selectedCategories = _selectedCategoryIds
            .map((categoryId) => viewModelState.projectCategories.where((cat) => cat.id == categoryId).firstOrNull)
            .where((category) => category != null)
            .cast<Category>()
            .toList();
        
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: selectedCategories.map((category) => 
            _buildCategoryChip(category, onRemove: () => _removeCategoryId(category.id))
          ).toList(),
        );
      },
    );
  }

  Widget _buildProjectCategoriesSection() {
    return Consumer(
      builder: (context, ref, child) {
        final viewModelState = ref.watch(projectCategoryViewModelProvider(widget.projectPath!));
        
        if (viewModelState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (viewModelState.error != null) {
          return Text('Error loading categories: ${viewModelState.error}');
        }
        
        // Filter out categories that are already selected
        final availableCategories = viewModelState.projectCategories
            .where((category) => !_selectedCategoryIds.contains(category.id))
            .toList();
        
        if (availableCategories.isEmpty) {
          return const Text('No additional categories available');
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Categories',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: availableCategories.map((category) =>
                _buildCategoryChip(
                  category,
                  onAdd: () => _addCategoryId(category.id),
                )
              ).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(Category category, {VoidCallback? onAdd, VoidCallback? onRemove}) {
    return Chip(
      label: Text(category.name),
      backgroundColor: category.colorValue.withValues(alpha: 0.3),
      labelStyle: TextStyle(color: category.colorValue),
      deleteIcon: onRemove != null ? const Icon(Icons.close, size: 16) : null,
      onDeleted: onRemove,
      avatar: onAdd != null 
          ? GestureDetector(
              onTap: onAdd,
              child: Icon(Icons.add, size: 16, color: category.colorValue),
            )
          : null,
    );
  }

  void _addCategoryId(String categoryId) {
    setState(() {
      if (!_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.add(categoryId);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _removeCategoryId(String categoryId) {
    setState(() {
      _selectedCategoryIds.remove(categoryId);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _createCategory() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.projectPath == null) {
      AppLogger.error('CategoryDialog: No project path provided for category creation');
      return;
    }

    final categoryName = _categoryController.text.trim();
    
    try {
      final categoryViewModel = ref.read(projectCategoryViewModelProvider(widget.projectPath!).notifier);
      
      setState(() => _isLoading = true);
      
      await categoryViewModel.createCategory(
        name: categoryName,
        color: _selectedColor,
        projectPath: widget.projectPath,
      );
      
      // Clear the form
      _categoryController.clear();
      
      // Refresh the categories
      await categoryViewModel.refresh();
      
      setState(() => _isLoading = false);
      
      AppLogger.info('CategoryDialog: Successfully created category "$categoryName"');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "$categoryName" created successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      AppLogger.error('CategoryDialog: Failed to create category', e);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create category: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _saveCategories() async {
    setState(() => _isLoading = true);
    
    try {
      final updatedTask = widget.task.copyWith(
        categoryIds: _selectedCategoryIds,
        lastModified: DateTime.now(),
      );
      
      widget.onTaskUpdated(updatedTask);
      AppLogger.info('CategoryDialog: Updated task categories to: $_selectedCategoryIds');
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedCategoryIds.isEmpty 
                ? 'All categories removed'
                : 'Categories updated successfully'
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('CategoryDialog: Error updating categories', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating categories: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
} 