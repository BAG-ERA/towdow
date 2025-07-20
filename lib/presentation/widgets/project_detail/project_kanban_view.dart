// Project Kanban View widget for displaying kanban boards
// Handles kanban board rendering with task management and category organization
// Supports both category-based and custom kanban configurations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../data/models/category.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../widgets/kanban_board.dart';

class ProjectKanbanView extends ConsumerWidget {
  final String projectPath;
  final AsyncValue<List<Task>> tasksAsync;
  final VoidCallback? onTasksRefresh;

  const ProjectKanbanView({
    super.key,
    required this.projectPath,
    required this.tasksAsync,
    this.onTasksRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return tasksAsync.when(
      data: (tasks) => _buildKanbanWithViewModel(context, ref, tasks),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
    );
  }

  // Kanban View with ViewModel - Uses the new ProjectKanbanViewModel
  Widget _buildKanbanWithViewModel(BuildContext context, WidgetRef ref, List<Task> tasks) {
    // Get the kanban view model for this project
    final kanbanViewModelState = ref.watch(projectKanbanViewModelProvider(projectPath));
    
    if (kanbanViewModelState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (kanbanViewModelState.error != null) {
      return Center(child: Text('Error loading kanban: ${kanbanViewModelState.error}'));
    }
    
    // For now, fall back to the original category-based kanban
    // This will be enhanced later to use the kanban configurations
    return _buildCategoryKanban(context, ref, tasks);
  }

  // Kanban View - Organized by categories
  Widget _buildCategoryKanban(BuildContext context, WidgetRef ref, List<Task> tasks) {
    // Get project categories from the category view model
    final categoryViewModelState = ref.watch(projectCategoryViewModelProvider(projectPath));
    
    if (categoryViewModelState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (categoryViewModelState.error != null) {
      return Center(child: Text('Error loading categories: ${categoryViewModelState.error}'));
    }
    
    final projectCategories = categoryViewModelState.projectCategories;
    
    // Get kanban regex to filter visible categories
    final kanbanViewModelState = ref.watch(projectKanbanViewModelProvider(projectPath));
    final kanbanRegex = kanbanViewModelState.selectedKanban?.regex ?? r'.*';
    
    // Apply regex filter to project categories to get visible categories
    final visibleCategories = _getVisibleCategoriesFromRegex(kanbanRegex, projectCategories);
    
    // Tasks without categories - sorted by status (done tasks last)
    final uncategorizedTasks = tasks.where((task) => task.categoryIds.isEmpty).toList();
    _sortTasksByStatus(uncategorizedTasks);
    
    final columns = <KanbanColumn>[];
    
    // Add uncategorized column first (never hidden)
    columns.add(
      KanbanColumn(
        id: 'uncategorized',
        title: 'Uncategorized',
        subtitle: '${uncategorizedTasks.length} tasks',
        tasks: uncategorizedTasks,
        color: Colors.grey,
        icon: Icons.inbox_rounded,
        onAddTask: () => _addTaskToCategory(context, ref, null),
      ),
    );
    
    // Add columns for each visible project category
    for (final category in visibleCategories) {
      
      final categoryTasks = tasks.where((task) => task.categoryIds.contains(category.id)).toList();
      _sortTasksByStatus(categoryTasks);
      
      columns.add(
        KanbanColumn(
          id: category.id,
          title: category.name,
          subtitle: '${categoryTasks.length} tasks',
          tasks: categoryTasks,
          color: category.colorValue,
          icon: Icons.label_rounded,
          onAddTask: () => _addTaskToCategory(context, ref, category.id),
        ),
      );
    }

    return KanbanBoard(
      columns: columns,
      onTaskTap: (task) {
        // Navigate to task detail
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('👁️ View task: ${task.summary}')),
        );
      },
      onTaskToggle: (task) async {
        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.toggleTaskCompletion(task);
        
        // Refresh the tasks list
        onTasksRefresh?.call();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                task.status == 'COMPLETED' 
                    ? '✅ Task marked as incomplete' 
                    : '✅ Task completed!',
              ),
            ),
          );
        }
      },
      onTaskUpdated: (task) async {
        await ref.read(taskViewModelProvider.notifier).updateTask(task);
        onTasksRefresh?.call();
      },
      onTaskDeleted: (task) async {
        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.deleteTask(task.uid);
        
        // Refresh the tasks list
        onTasksRefresh?.call();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task "${task.summary}" deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  // TODO: Implement undo functionality
                },
              ),
            ),
          );
        }
      },
      onTaskMoved: (task, columnId) => _handleTaskMove(context, ref, task, columnId),
      onColumnHide: (columnId) => _handleColumnHide(context, ref, columnId),
    );
  }

  /// Sort tasks by status with completed tasks appearing last
  void _sortTasksByStatus(List<Task> tasks) {
    tasks.sort((a, b) {
      // First, sort by completion status (incomplete tasks first)
      if (a.status == 'COMPLETED' && b.status != 'COMPLETED') {
        return 1; // a (completed) comes after b (incomplete)
      }
      if (a.status != 'COMPLETED' && b.status == 'COMPLETED') {
        return -1; // a (incomplete) comes before b (completed)
      }
      
      // If both have the same completion status, sort by priority/due date
      // Tasks with due dates come before tasks without due dates
      if (a.due != null && b.due == null) {
        return -1; // a (has due date) comes before b (no due date)
      }
      if (a.due == null && b.due != null) {
        return 1; // a (no due date) comes after b (has due date)
      }
      
      // If both have due dates, sort by due date (earliest first)
      if (a.due != null && b.due != null) {
        return a.due!.compareTo(b.due!);
      }
      
      // If neither has due dates, sort alphabetically by summary
      return a.summary.toLowerCase().compareTo(b.summary.toLowerCase());
    });
  }

  Future<void> _addTaskToCategory(BuildContext context, WidgetRef ref, String? category) async {
    final textController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category != null 
            ? 'Add Task to "$category"' 
            : 'Add Uncategorized Task'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter task summary',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final taskViewModel = ref.read(taskViewModelProvider.notifier);
      await taskViewModel.createTask(
        summary: result,
        projectPath: projectPath,
      );
      
      // TODO: After creation, we would need to update the task with the category
      // This would require additional API to update task categories
      
      onTasksRefresh?.call();
      
      if (context.mounted) {
        final categoryText = category != null ? ' in "$category"' : ' (uncategorized)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Task "$result" added$categoryText')),
        );
      }
    }
  }

  /// Handle task movement between columns (for category-based kanban)
  Future<void> _handleTaskMove(BuildContext context, WidgetRef ref, Task task, String columnId) async {
    try {
      AppLogger.info('ProjectKanbanView: Moving task "${task.summary}" to column "$columnId"');
      
      if (columnId == 'uncategorized') {
        // Remove all categories (move to uncategorized)
        final updatedTask = task.copyWith(
          categoryIds: [],
          lastModified: DateTime.now(),
        );
        await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
      } else {
        // Replace all categories with the new one (single category per task)
        final updatedTask = task.copyWith(
          categoryIds: [columnId],
          lastModified: DateTime.now(),
        );
        await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
      }
      
      // Refresh the UI
      onTasksRefresh?.call();
      
      if (context.mounted) {
        final columnName = columnId == 'uncategorized' ? 'Uncategorized' : columnId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${task.summary}" to "$columnName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      AppLogger.error('ProjectKanbanView: Error moving task', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error moving task: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle column hiding in kanban view
  Future<void> _handleColumnHide(BuildContext context, WidgetRef ref, String columnId) async {
    try {
      AppLogger.info('ProjectKanbanView: Hiding column "$columnId"');
      
      // Get the kanban view model
      final kanbanViewModel = ref.read(projectKanbanViewModelProvider(projectPath).notifier);
      
      // Hide the column by adding it to the filter
      await kanbanViewModel.hideColumn(columnId);
      
      // Refresh the UI
      onTasksRefresh?.call();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hidden column "$columnId"'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _handleColumnShow(context, ref, columnId),
            ),
          ),
        );
      }
    } catch (error) {
      AppLogger.error('ProjectKanbanView: Error hiding column', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error hiding column: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get visible categories by applying regex filter to project categories
  List<Category> _getVisibleCategoriesFromRegex(String regex, List<Category> categories) {
    try {
      final visibleCategories = <Category>[];
      
      // Test each category ID against the regex
      for (final category in categories) {
        final categoryId = category.id;
        
        // If the regex matches the category ID, it's visible
        final regexPattern = RegExp(regex);
        if (regexPattern.hasMatch(categoryId)) {
          visibleCategories.add(category);
        }
      }
      
      return visibleCategories;
    } catch (e) {
      AppLogger.warning('ProjectKanbanView: Error applying regex "$regex": $e');
      // If regex is invalid, show all categories
      return categories;
    }
  }

  /// Handle column showing in kanban view (undo functionality)
  Future<void> _handleColumnShow(BuildContext context, WidgetRef ref, String columnId) async {
    try {
      AppLogger.info('ProjectKanbanView: Showing column "$columnId"');
      
      // Get the kanban view model
      final kanbanViewModel = ref.read(projectKanbanViewModelProvider(projectPath).notifier);
      
      // Show the column by updating the regex
      await kanbanViewModel.showColumn(columnId);
      
      // Refresh the UI
      onTasksRefresh?.call();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shown column "$columnId"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      AppLogger.error('ProjectKanbanView: Error showing column', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing column: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 