// Project task list view widget
// Displays tasks in a project organized by status (overdue, pending, completed)
// Supports responsive grid layout and task filtering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../task_item/task_item.dart';
import '../utils/overlay_draggable_task.dart';
import '../../viewmodels/project_task_search_viewmodel.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../core/theme/chart_theme.dart';
import '../../viewmodels/task_viewmodel.dart';

class ProjectTaskListView extends ConsumerWidget {
  final String projectUid;
  final AsyncValue<List<Task>> tasksAsync;
  final VoidCallback? onTasksRefresh;

  const ProjectTaskListView({
    super.key,
    required this.projectUid,
    required this.tasksAsync,
    this.onTasksRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return tasksAsync.when(
      data: (allTasks) {
        // Use filtered and sorted tasks instead of all tasks
        final filteredTasks = ref.watch(filteredProjectTasksProvider(projectUid));
        final searchState = ref.watch(projectTaskSearchProvider(projectUid));
        
        if (filteredTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  searchState.isSearchActive ? Icons.search_off : Icons.task_alt_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  searchState.isSearchActive ? 'No Matching Tasks' : 'No Tasks Yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  searchState.isSearchActive 
                    ? 'Try adjusting your search or filters'
                    : 'Add your first task to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        // Tasks are already filtered and sorted by the provider
        final tasks = filteredTasks;
        
        // Organize tasks by priority: overdue → to be done → done (if not using custom filter)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final overdueTasks = tasks.where((task) => 
          task.status != 'COMPLETED' && 
          task.due != null && 
          DateTime(task.due!.year, task.due!.month, task.due!.day).isBefore(today)
        ).toList();
        
        final pendingTasks = tasks.where((task) => 
          task.status != 'COMPLETED' && 
          (task.due == null || !DateTime(task.due!.year, task.due!.month, task.due!.day).isBefore(today))
        ).toList();
        
        final completedTasks = tasks.where((task) => 
          task.status == 'COMPLETED'
        ).toList();

        return Column(
          children: [
            
            // Tasks list with sections - Responsive layout
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overdue tasks section
                    if (overdueTasks.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Overdue', overdueTasks.length, context.chartTheme.colors.error),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, ref, overdueTasks),
                      if (pendingTasks.isNotEmpty || completedTasks.isNotEmpty)
                        const SizedBox(height: 24),
                    ],
                    
                    // Pending tasks section
                    if (pendingTasks.isNotEmpty) ...[
                      _buildSectionHeader(context, 'To Be Done', pendingTasks.length, context.chartTheme.colors.warning),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, ref, pendingTasks),
                      if (completedTasks.isNotEmpty)
                        const SizedBox(height: 24),
                    ],
                    
                    // Completed tasks section
                    if (completedTasks.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Done', completedTasks.length, context.chartTheme.colors.success),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, ref, completedTasks),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading tasks...'),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load tasks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onTasksRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$title ($count)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Builds a responsive grid layout for tasks that wraps to new rows when needed
  Widget _buildResponsiveTaskGrid(BuildContext context, WidgetRef ref, List<Task> tasks) {
    return Wrap(
      spacing: 12.0, // Horizontal spacing between tasks
      runSpacing: 12.0, // Vertical spacing between rows
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      children: tasks.map((task) {
        return ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
            minWidth: 300,
          ),
          child: OverlayDraggableTask(
            task: task,
            onDragStarted: () {
              AppLogger.info('ProjectTaskListView: Started dragging task ${task.summary}');
            },
            onDragEnd: () {
              AppLogger.info('ProjectTaskListView: Ended dragging task ${task.summary}');
            },
            child: TaskItem(
              task: task,
              onTap: () => _viewTask(context, task),
              onToggleComplete: () => _toggleTaskComplete(context, ref, task),
              onTaskUpdated: (updatedTask) async {
                await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
                onTasksRefresh?.call();
              },
              onTaskDeleted: () => _deleteTask(context, ref, task),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _viewTask(BuildContext context, Task task) {
    // Navigate to task detail
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('👁️ View task: ${task.summary}')),
    );
  }

  Future<void> _toggleTaskComplete(BuildContext context, WidgetRef ref, Task task) async {
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
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, Task task) async {
    // Handle task deletion
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.deleteTask(task.uid);
    
    // Refresh the tasks list
    onTasksRefresh?.call();
    
    // Show confirmation
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
  }
} 