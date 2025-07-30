// Category management dialog for adding, editing, and removing task categories
// Provides an interface for managing task categorization with search and improved UX

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/category.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';
import '../../../../core/theme/chart_theme.dart';
import '../../../widgets/task_item/chips/category_chip.dart';

/// Dialog for managing task categories with enhanced search and editing capabilities
class CategoryDialog extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;
  final String? projectPath;

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
  final _searchController = TextEditingController();
  late List<String> _selectedCategoryIds;
  bool _isLoading = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = List.from(widget.task.categoryIds);
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isLoading) {
            Navigator.of(context).pop();
          }
          else if (event.logicalKey == LogicalKeyboardKey.enter && 
                   (HardwareKeyboard.instance.isControlPressed || 
                    HardwareKeyboard.instance.isMetaPressed) && !_isLoading) {
            _saveCategories();
          }
        }
      },
      child: AlertDialog(
        title: const Text('Manage Categories'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task: ${widget.task.summary}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              
              // Categories list with constrained height
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _buildCategoriesList(),
              ),
            ],
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

  Widget _buildCategoriesList() {
    if (widget.projectPath == null) {
      return const Center(
        child: Text('No project path provided'),
      );
    }

    return Consumer(
      builder: (context, ref, child) {
        final categoryViewModel = ref.watch(projectCategoryViewModelProvider(widget.projectPath!));
        final availableCategories = categoryViewModel.projectCategories;
        
        if (categoryViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter categories based on search query
        final filteredCategories = _searchQuery.isEmpty
            ? availableCategories
            : availableCategories
                .where((category) => category.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();

        // Separate selected and available categories
        final selectedCategories = filteredCategories
            .where((category) => _selectedCategoryIds.contains(category.id))
            .toList();
        final availableCategoriesFiltered = filteredCategories
            .where((category) => !_selectedCategoryIds.contains(category.id))
            .toList();

        // Check if we need to show "Create new category" button
        final exactMatch = availableCategoriesFiltered.any(
          (category) => category.name.toLowerCase() == _searchQuery.toLowerCase()
        );
        final showCreateButton = _searchQuery.isNotEmpty && !exactMatch;

        return ListView(
          shrinkWrap: true,
          children: [
            // Show create button if search doesn't match existing categories
            if (showCreateButton) ...[
              _buildCreateCategoryItem(),
              const SizedBox(height: 8),
            ],
            
            // Selected categories section
            if (selectedCategories.isNotEmpty) ...[
              _buildSectionHeader('Selected Categories', selectedCategories.length),
              const SizedBox(height: 4),
              ...selectedCategories.map((category) => _buildCategoryItem(category, isSelected: true)),
              const SizedBox(height: 16),
            ],
            
            // Available categories section
            if (availableCategoriesFiltered.isNotEmpty) ...[
              _buildSectionHeader('Available Categories', availableCategoriesFiltered.length),
              const SizedBox(height: 4),
              ...availableCategoriesFiltered.map((category) => _buildCategoryItem(category, isSelected: false)),
            ],
            
            // Empty state when no categories match search
            if (selectedCategories.isEmpty && availableCategoriesFiltered.isEmpty && !showCreateButton) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No categories found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting your search or create a new category',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCategoryItem() {
    return ListTile(
      leading: Icon(
        Icons.add_circle_outline,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      ),
      title: Text(
        'Create "$_searchQuery"',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Create new category',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      onTap: () => _showCreateCategoryDialog(_searchQuery),
    );
  }

  Widget _buildCategoryItem(Category category, {required bool isSelected}) {
    return ListTile(
      leading: CategoryChip(
        categoryId: category.id,
        projectPath: widget.projectPath,
      ),
      title: Text(
        isSelected ? 'Click to remove' : 'Click to add',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) => _handleCategoryAction(category, value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'remove_from_project',
            child: ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Remove from project'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'edit_name',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Change name'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'edit_color',
            child: ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Change color'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () => _toggleCategory(category.id),
    );
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _handleCategoryAction(Category category, String action) {
    switch (action) {
      case 'remove_from_project':
        _removeCategoryFromProject(category);
        break;
      case 'edit_name':
        _showEditNameDialog(category);
        break;
      case 'edit_color':
        _showEditColorDialog(category);
        break;
    }
  }

  void _removeCategoryFromProject(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Category'),
        content: Text(
          'Remove "${category.name}" from this project?\n\n'
          'This will also remove it from all tasks in this project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteCategoryFromProject(category);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategoryFromProject(Category category) async {
    if (widget.projectPath == null) return;

    try {
      final categoryViewModel = ref.read(projectCategoryViewModelProvider(widget.projectPath!).notifier);
      await categoryViewModel.deleteCategory(category.id);
      
      // Remove from selected categories if it was selected
      setState(() {
        _selectedCategoryIds.remove(category.id);
      });
      
      // Category removed from project - no notification needed
    } catch (e) {
      if (mounted) {
        AppLogger.error('Failed to remove category: $e');
      }
    }
  }

  void _showEditNameDialog(Category category) {
    final controller = TextEditingController(text: category.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category Name'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update the name for "${category.name}".',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Category name *',
                  hintText: 'Enter new category name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != category.name) {
                Navigator.of(context).pop();
                await _updateCategoryName(category, newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCategoryName(Category category, String newName) async {
    if (widget.projectPath == null) return;

    try {
      final categoryViewModel = ref.read(projectCategoryViewModelProvider(widget.projectPath!).notifier);
      final updatedCategory = category.copyWith(name: newName);
      await categoryViewModel.updateCategory(updatedCategory);
      
    } catch (e) {
      if (mounted) {
        AppLogger.error('Failed to update category: $e');
      }
    }
  }

  void _showEditColorDialog(Category category) {
    Color selectedColor = category.colorValue;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Category Color'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a color for "${category.name}".',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Color preview
                Center(
                  child: Container(
                    width: 80,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedColor),
                    ),
                    child: Center(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          color: selectedColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Color picker
                _buildColorPicker(selectedColor, (color) {
                  setDialogState(() {
                    selectedColor = color;
                  });
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _updateCategoryColor(category, selectedColor);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(Color selectedColor, Function(Color) onColorSelected) {
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
      spacing: 8,
      runSpacing: 8,
      children: [
        // Predefined colors
        ...colors.map((color) {
          final isSelected = selectedColor.value == color.value;
          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected 
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                    : Border.all(color: Colors.grey.shade300),
              ),
            ),
          );
        }),
        
        // Custom color button
        GestureDetector(
          onTap: () => _showCustomColorDialog(onColorSelected),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.grey.shade100,
            ),
            child: const Icon(Icons.add_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  void _showCustomColorDialog(Function(Color) onColorSelected) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Color'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a hex color code for your custom color.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Hex color *',
                  hintText: 'e.g., FF5733',
                  border: OutlineInputBorder(),
                  prefixText: '#',
                ),
                onChanged: (value) {
                  // Remove # if user adds it
                  if (value.startsWith('#')) {
                    controller.text = value.substring(1);
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final hexColor = controller.text.trim();
              if (hexColor.length == 6) {
                try {
                  final color = Color(int.parse('FF$hexColor', radix: 16));
                  Navigator.of(context).pop();
                  onColorSelected(color);
                } catch (e) {
                  AppLogger.error('Invalid hex color format: $e');
                }
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCategoryColor(Category category, Color newColor) async {
    if (widget.projectPath == null) return;

    try {
      final categoryViewModel = ref.read(projectCategoryViewModelProvider(widget.projectPath!).notifier);
      final updatedCategory = category.copyWith(color: newColor.value);
      await categoryViewModel.updateCategory(updatedCategory);
      
    } catch (e) {
      if (mounted) {
        AppLogger.error('Failed to update category: $e');
      }
    }
  }

  void _showCreateCategoryDialog(String initialName) {
    final nameController = TextEditingController(text: initialName);
    Color selectedColor = FlowItColors.primary;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Category'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a new category for organizing tasks.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category name *',
                    hintText: 'e.g., Urgent, In Progress, Review',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Color:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildColorPicker(selectedColor, (color) {
                  setDialogState(() {
                    selectedColor = color;
                  });
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _createCategory(name, selectedColor);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCategory(String name, Color color) async {
    if (widget.projectPath == null) return;

    try {
      setState(() => _isLoading = true);
      
      final categoryViewModel = ref.read(projectCategoryViewModelProvider(widget.projectPath!).notifier);
      await categoryViewModel.createCategory(
        name: name,
        color: color,
        projectPath: widget.projectPath,
      );
      
      // Clear search to show the new category
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppLogger.error('Failed to create category: $e');
      }
    }
  }

  Future<void> _saveCategories() async {
    try {
      setState(() => _isLoading = true);
      
      final updatedTask = widget.task.copyWith(
        categoryIds: _selectedCategoryIds,
        lastModified: DateTime.now(),
      );
      
      widget.onTaskUpdated(updatedTask);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppLogger.error('Failed to save categories: $e');
      }
    }
  }
} 