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
import '../../widgets/task_item/task_item.dart';
import '../../widgets/utils/popup/category_dialog.dart';
import '../../viewmodels/commands/attendee_commands.dart';

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
    
    // Tasks without categories - sorted by status (done tasks last)
    final uncategorizedTasks = tasks.where((task) => task.categoryIds.isEmpty).toList();
    _sortTasksByStatus(uncategorizedTasks);
    
    final columns = <KanbanColumn>[];
    
    // Add uncategorized column first
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
    
    // Add columns for each project category
    for (final category in projectCategories) {
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

  /// Handle task movement between columns (for attendee-based kanban)
  Future<void> _handleTaskMove(BuildContext context, WidgetRef ref, Task task, String columnId) async {
    try {
      // This is currently used for attendee-based kanban
      // For category-based kanban, we would need to implement category assignment
      if (columnId == '__no_attendees__') {
        // Remove all attendees
        final updatedTask = task.copyWith(attendees: []);
        await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
      } else {
        // Add attendee to task
        final command = AssignAttendeeToTaskCommand(
          ref.read(taskRepositoryProvider),
          ref.read(syncServiceProvider),
        );
        final params = AssignAttendeeToTaskParams(task: task, attendeeEmail: columnId);
        await command.executeWith(params);
      }
      
      // Refresh the UI
      onTasksRefresh?.call();
      
      if (context.mounted) {
        final attendeeName = columnId == '__no_attendees__' ? 'No Attendees' : columnId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${task.summary}" to "$attendeeName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
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
} 