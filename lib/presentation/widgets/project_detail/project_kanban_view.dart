// Project Kanban View widget for displaying kanban boards
// Handles kanban board rendering with task management and category organization
// Supports both category-based and custom kanban configurations

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../data/models/category.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../widgets/kanban_board.dart';
import '../utils/popup/task_creation_dialog.dart';
import '../../../data/models/step.dart';
// projectProvider removed; use calendarListProvider to read project state

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
      error: (error, _) => Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: $error')),
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
      return Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: ${kanbanViewModelState.error}'));
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
      return Center(child: Text('${AppLocalizations.of(context)!.failedToLoad}: ${categoryViewModelState.error}'));
    }
    
    final projectCategories = categoryViewModelState.projectCategories;
    
    // Get kanban regex to filter visible categories
    final kanbanViewModelState = ref.watch(projectKanbanViewModelProvider(projectPath));
    final kanbanRegex = kanbanViewModelState.selectedKanban?.regex ?? r'.*';
    
    // Apply regex filter to project categories to get visible categories
    final visibleCategories = _getVisibleCategoriesFromRegex(kanbanRegex, projectCategories);
    
    // Calculate hidden categories (categories that exist but are not visible)
    final hiddenCategories = projectCategories.where((category) => 
        !visibleCategories.any((visible) => visible.id == category.id)
    ).toList();
    
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
      hiddenColumnsButton: hiddenCategories.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_off_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                     Text(
                      AppLocalizations.of(context)!.hiddenCount(hiddenCategories.length),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showHiddenColumnsDialog(context, ref, hiddenCategories),
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: Text(AppLocalizations.of(context)!.show),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      onAddCategory: () => _showCreateCategoryDialog(context, ref),
      onTaskTap: (task) {
        // Navigate to task detail
      },
      onTaskToggle: (task) async {
        // Enforce: in ONGOING workflows only tasks in AVAILABLE steps can be marked done
        final encoded = projectPath.replaceAll('@', '%40');
        final project = ref.read(calendarListProvider).maybeWhen(
          data: (cals) {
            try {
              return cals.firstWhere((c) => c.path == encoded);
            } catch (_) {
              return null;
            }
          },
          orElse: () => null,
        );
        final stepRepo = ref.read(stepRepositoryProvider);
        ProjectStep? step;
        if (task.stepId != null && task.stepId!.isNotEmpty) {
          final stepRes = await stepRepo.getStepById(task.stepId!);
          step = stepRes.when(success: (s) => s, failure: (_) => null);
        }
        final isFlow = project?.flowitAsFlow == true;
        final status = (project?.flowitStatus ?? 'ONGOING').toUpperCase();
        final stepIsAvailable = step?.status == StepStatus.available;

        if (isFlow && status == 'ONGOING' && !stepIsAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.waitingStepCannotComplete)),
          );
          return;
        }

        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.toggleTaskCompletion(task);
        
        // Refresh the tasks list
        onTasksRefresh?.call();
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => TaskCreationDialog(
        projectPath: projectPath,
        initialCategories: category != null ? [category] : null,
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      onTasksRefresh?.call();
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
    } catch (error) {
      AppLogger.error('ProjectKanbanView: Error moving task', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToLoad}: $error'),
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
    } catch (error) {
      AppLogger.error('ProjectKanbanView: Error hiding column', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToLoad}: $error'),
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
    } catch (error) {
      AppLogger.error('ProjectKanbanView: Error showing column', error);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.failedToLoad}: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show dialog with hidden columns and allow unhiding them
  Future<void> _showHiddenColumnsDialog(BuildContext context, WidgetRef ref, List<Category> hiddenCategories) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Row(
          children: [
            Icon(
              Icons.visibility_off_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.hiddenColumns),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.hiddenColumnsExplainer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              ...hiddenCategories.map((category) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: category.colorValue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _handleColumnShow(context, ref, category.id);
                      },
                      child: Text(AppLocalizations.of(context)!.show),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  /// Show dialog to create a new category
  Future<void> _showCreateCategoryDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    Color selectedColor = Theme.of(context).colorScheme.primary;
    
    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.createNewCategory),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.categoryName,
                    hintText: 'e.g., Urgent, In Progress, Review',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.colorLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                    Colors.pink,
                    Colors.grey,
                  ].map((color) => GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color 
                              ? Theme.of(context).colorScheme.onSurface 
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selectedColor == color
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final categoryViewModel = ref.read(projectCategoryViewModelProvider(projectPath).notifier);
                  await categoryViewModel.createCategory(
                    name: name,
                    color: selectedColor,
                    projectPath: projectPath,
                  );
                  onTasksRefresh?.call();
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(AppLocalizations.of(context)!.create),
            ),
          ],
        ),
      ),
    );
  }
} 