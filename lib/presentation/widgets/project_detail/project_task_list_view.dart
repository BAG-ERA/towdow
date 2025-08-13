// Project task list view widget
// Displays tasks in a project organized by status (overdue, pending, completed)
// Supports responsive grid layout and task filtering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../task_item/task_item.dart';
import '../utils/overlay_draggable_task.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../core/theme/chart_theme.dart';

class ProjectTaskListView extends ConsumerStatefulWidget {
  final String projectPath;
  final AsyncValue<List<Task>> tasksAsync;
  final VoidCallback? onTasksRefresh;
  final String? initialFocusedTaskUid;

  const ProjectTaskListView({
    super.key,
    required this.projectPath,
    required this.tasksAsync,
    this.onTasksRefresh,
    this.initialFocusedTaskUid,
  });

  @override
  ConsumerState<ProjectTaskListView> createState() => _ProjectTaskListViewState();
}

class _ProjectTaskListViewState extends ConsumerState<ProjectTaskListView> {
  final Map<String, Map<String, TaskItemController>> _sectionControllers = {};

  @override
  Widget build(BuildContext context) {
    return widget.tasksAsync.when(
      data: (allTasks) {
        // Use filtered and sorted tasks instead of all tasks
        final filteredTasks = ref.watch(filteredProjectTasksProvider(widget.projectPath));
        final searchQuery = ref.watch(projectSearchQueryProvider(widget.projectPath));
        
                  if (filteredTasks.isEmpty) {
            final isSearchActive = searchQuery.trim().isNotEmpty;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSearchActive ? Icons.search_off : Icons.task_alt_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSearchActive ? 'No Matching Tasks' : 'No Tasks Yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSearchActive 
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

        // Initialize controllers for each section
        _initializeControllers('overdue', overdueTasks);
        _initializeControllers('pending', pendingTasks);
        _initializeControllers('completed', completedTasks);

        // If an initial focus UID is provided, expand the right section and scroll it into view
        if (widget.initialFocusedTaskUid != null) {
          final uid = widget.initialFocusedTaskUid!;
          final controller = _sectionControllers['overdue']?[uid] ??
              _sectionControllers['pending']?[uid] ??
              _sectionControllers['completed']?[uid];
          controller?.highlight();
        }

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
                      _buildSectionHeader(context, 'Overdue', 'overdue', overdueTasks.length, context.chartTheme.colors.error),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, 'overdue', overdueTasks),
                      if (pendingTasks.isNotEmpty || completedTasks.isNotEmpty)
                        const SizedBox(height: 24),
                    ],
                    
                    // Pending tasks section
                    if (pendingTasks.isNotEmpty) ...[
                      _buildSectionHeader(context, 'To Be Done', 'pending', pendingTasks.length, context.chartTheme.colors.warning),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, 'pending', pendingTasks),
                      if (completedTasks.isNotEmpty)
                        const SizedBox(height: 24),
                    ],
                    
                    // Completed tasks section
                    if (completedTasks.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Done', 'completed', completedTasks.length, context.chartTheme.colors.success),
                      const SizedBox(height: 8),
                      _buildResponsiveTaskGrid(context, 'completed', completedTasks),
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
              onPressed: widget.onTasksRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String sectionKey, int count, Color color) {
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
        const SizedBox(width: 16),
        TextButton(
          onPressed: () => _expandAllTasks(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Expand All', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => _collapseAllTasks(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Collapse All', style: TextStyle(fontSize: 12)),
        ),
              ],
      );
    }

    void _initializeControllers(String sectionKey, List<Task> tasks) {
      if (!_sectionControllers.containsKey(sectionKey)) {
        _sectionControllers[sectionKey] = {};
      }
      
      final currentControllers = _sectionControllers[sectionKey]!;
      
      // Preserve existing controllers and add new ones for new tasks
      for (final task in tasks) {
        if (!currentControllers.containsKey(task.uid)) {
          currentControllers[task.uid] = TaskItemController();
          AppLogger.debug('ProjectTaskListView: Created new controller for task ${task.summary} in section $sectionKey');
        }
      }
      
      // Remove controllers for tasks that no longer exist in this section
      final taskUids = tasks.map((task) => task.uid).toSet();
      currentControllers.removeWhere((uid, controller) {
        if (!taskUids.contains(uid)) {
          AppLogger.debug('ProjectTaskListView: Removed controller for task $uid in section $sectionKey');
          return true;
        }
        return false;
      });
      
      AppLogger.debug('ProjectTaskListView: Section $sectionKey now has ${currentControllers.length} controllers');
    }

    void _expandAllTasks() {
    // Force expand all tasks in all sections
    for (final sectionKey in ['overdue', 'pending', 'completed']) {
      final controllers = _sectionControllers[sectionKey];
      if (controllers != null) {
        for (final controller in controllers.values) {
          controller.expand();
        }
      }
    }
    AppLogger.info('ProjectTaskListView: Expanded all tasks');
  }

  void _collapseAllTasks() {
    // Force collapse all tasks in all sections
    for (final sectionKey in ['overdue', 'pending', 'completed']) {
      final controllers = _sectionControllers[sectionKey];
      if (controllers != null) {
        for (final controller in controllers.values) {
          controller.collapse();
        }
      }
    }
    AppLogger.info('ProjectTaskListView: Collapsed all tasks');
  }



  /// Builds a responsive grid layout for tasks that wraps to new rows when needed
  Widget _buildResponsiveTaskGrid(BuildContext context, String sectionKey, List<Task> tasks) {
    return Wrap(
      spacing: 12.0, // Horizontal spacing between tasks
      runSpacing: 12.0, // Vertical spacing between rows
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
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
              controller: _sectionControllers[sectionKey]?[task.uid],
              onTap: () => _viewTask(context, task),
                onToggleComplete: () => _toggleTaskComplete(context, ref, task),
              onTaskUpdated: (updatedTask) async {
                await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
                widget.onTasksRefresh?.call();
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
  }

  Future<void> _toggleTaskComplete(BuildContext context, WidgetRef ref, Task task) async {
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.toggleTaskCompletion(task);
    
    // Refresh the tasks list
    widget.onTasksRefresh?.call();
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, Task task) async {
    // Handle task deletion
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.deleteTask(task.uid);
    
    // Refresh the tasks list
    widget.onTasksRefresh?.call();
  }
} 