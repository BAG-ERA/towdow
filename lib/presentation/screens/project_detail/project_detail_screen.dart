// Project detail screen for managing individual projects
// Shows tasks within a project, supports task management and project info
// Projects are represented by TaskCalendar objects (CalDAV calendars)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/task_item/task_item.dart';
import '../../widgets/utils/overlay_draggable_task.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/utils/buttons/create_task_button.dart';
import '../../widgets/kanban_board.dart';
import '../../widgets/agenda_calendar.dart';
import '../../widgets/utils/tasklist_toolbar.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../viewmodels/commands/attendee_commands.dart';
import '../../viewmodels/project_task_search_viewmodel.dart';
import '../../../core/theme/chart_theme.dart';
import '../../widgets/adaptive_app_layout.dart';

// Provider for a specific project/calendar
final projectProvider = FutureProvider.family<TaskCalendar?, String>((ref, projectUid) async {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final result = await calendarRepository.getById(projectUid);
  return result.when(
    success: (calendar) => calendar,
    failure: (failure) {
      AppLogger.error('ProjectDetailScreen: Failed to load project $projectUid: ${failure.message}');
      return null;
    },
  );
});

// Provider for tasks in a specific project
final projectTasksProvider = StreamProvider.family<List<Task>, String>((ref, projectUid) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  return taskRepository.watchTasks().map((allTasks) {
    // AppLogger.info('ProjectDetailScreen: Loaded ${allTasks.length} total tasks');
    
    // Filter tasks by their source calendar (Calendar = Project model)
    final projectTasks = allTasks
        .where((task) => task.sourceCalendarUid == projectUid)
        .toList();
    // AppLogger.info('ProjectDetailScreen: Found ${projectTasks.length} tasks for project $projectUid');
    
    if (projectTasks.isEmpty && allTasks.isNotEmpty) {
      AppLogger.warning('ProjectDetailScreen: No tasks found for project $projectUid. Available sourceCalendarUids: ${allTasks.map((t) => t.sourceCalendarUid).toSet()}');
    }
    
    return projectTasks;
  });
});

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectUid;

  const ProjectDetailScreen({
    super.key,
    required this.projectUid,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  int _selectedTabIndex = 0;

  @override
  void dispose() {
    // Clear mobile title when leaving the screen
    ref.read(mobileTitleProvider.notifier).state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppLogger.info('ProjectDetailScreen: Building screen for project UID: ${widget.projectUid}');
    final projectAsync = ref.watch(projectProvider(widget.projectUid));
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectUid));

    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    // Update mobile title when project data is available
    projectAsync.whenData((project) {
      if (project != null && !isDesktop) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(mobileTitleProvider.notifier).state = project.displayName;
        });
      }
    });

    return Scaffold(
      appBar: isDesktop ? AppBar(
        title: projectAsync.when(
          data: (project) => Text(project?.displayName ?? 'Unknown Project'),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Error'),
        ),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ) : null,
      body: Column(
        children: [
          // Project Info Card
          _buildProjectInfoCard(context, projectAsync, tasksAsync),
          
          // View Tabs - Updated labels for new views
          _buildViewTabs(context),
          
          // Content based on selected tab
          Expanded(
            child: _buildTabContent(context, ref, tasksAsync),
          ),
          
          // Bottom toolbar with search and create task button
          TaskListToolbar(
            projectUid: widget.projectUid,
            projectName: projectAsync.asData?.value?.displayName,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectInfoCard(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Project not found: ${widget.projectUid}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  project.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Dynamic stats based on actual tasks
              tasksAsync.when(
                data: (tasks) {
                  final stats = project.getStats(tasks);
                  return Row(
                    children: [
                      _buildProjectStat(context, 'Progress', '${stats.progressPercentage}%'),
                      const SizedBox(width: 16),
                      _buildProjectStat(context, 'Tasks', '${stats.completedTasks}/${stats.totalTasks}'),
                      const SizedBox(width: 16),
                      if (project.lastSyncAt != null)
                        _buildProjectStat(context, 'Last Update', _formatLastSync(project.lastSyncAt!)),
                    ],
                  );
                },
                loading: () => Row(
                  children: [
                    _buildProjectStat(context, 'Progress', '...'),
                    const SizedBox(width: 16),
                    _buildProjectStat(context, 'Tasks', '...'),
                    const SizedBox(width: 16),
                    if (project.lastSyncAt != null)
                      _buildProjectStat(context, 'Last Update', _formatLastSync(project.lastSyncAt!)),
                  ],
                ),
                error: (_, _) => Row(
                  children: [
                    _buildProjectStat(context, 'Progress', '0%'),
                    const SizedBox(width: 16),
                    _buildProjectStat(context, 'Status', project.status),
                    const SizedBox(width: 16),
                    if (project.lastSyncAt != null)
                      _buildProjectStat(context, 'Last Update', _formatLastSync(project.lastSyncAt!)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading project...'),
          ],
        ),
      ),
      error: (error, _) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to load project: $error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectStatusChip(BuildContext context, TaskCalendar project) {
    final status = project.status.toLowerCase();
    final color = switch (status) {
             'completed' => context.chartTheme.colors.success, // Water Green
       'needs-action' => context.chartTheme.colors.primary, // Blue Medium
       'in-process' => context.chartTheme.colors.warning, // Yellow Dark
       'cancelled' => context.chartTheme.colors.error, // Pink
       _ => context.chartTheme.colors.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProjectStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildViewTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: StyledTabBar(
        selectedIndex: _selectedTabIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        items: const [
          StyledTabItem(
            label: 'List',
            icon: Icons.checklist_rounded,
          ),
          StyledTabItem(
            label: 'Timing',
            icon: Icons.schedule_rounded,
          ),
          StyledTabItem(
            label: 'Attendee',
            icon: Icons.groups,
          ),
          StyledTabItem(
            label: 'Kanban',
            icon: Icons.view_kanban_rounded,
          ),
          StyledTabItem(
            label: 'Agenda',
            icon: Icons.calendar_month_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return switch (_selectedTabIndex) {
      0 => _buildListView(context, ref, tasksAsync),
      1 => _buildTimingView(context, ref, tasksAsync),
      2 => _buildAttendeeView(context, ref, tasksAsync),
      3 => _buildKanbanView(context, ref, tasksAsync),
      4 => _buildAgendaView(context, ref, tasksAsync),
      _ => _buildListView(context, ref, tasksAsync),
    };
  }

  Widget _buildListView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (allTasks) {
        // Use filtered and sorted tasks instead of all tasks
        final filteredTasks = ref.watch(filteredProjectTasksProvider(widget.projectUid));
        final searchState = ref.watch(projectTaskSearchProvider(widget.projectUid));
        
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
            // Header with task count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tasks (${tasks.length} of ${allTasks.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            
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
              onPressed: () => ref.invalidate(projectTasksProvider(widget.projectUid)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Timing View - Kanban organized by time periods
  Widget _buildTimingView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => _buildTimingKanban(context, ref, tasks),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
    );
  }

  Widget _buildTimingKanban(BuildContext context, WidgetRef ref, List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    // Group tasks by time periods
    final overdueTasks = tasks.where((task) => 
        task.due != null && 
        DateTime(task.due!.year, task.due!.month, task.due!.day).isBefore(today) &&
        task.status != 'COMPLETED').toList();
    
    final todayTasks = tasks.where((task) => 
        task.due != null && 
        DateTime(task.due!.year, task.due!.month, task.due!.day).isAtSameMomentAs(today)).toList();
    
    final soonTasks = tasks.where((task) => 
        task.due != null && 
        DateTime(task.due!.year, task.due!.month, task.due!.day).isAfter(today) &&
        DateTime(task.due!.year, task.due!.month, task.due!.day).isBefore(tomorrow.add(const Duration(days: 2)))).toList();
    
    final nextWeekTasks = tasks.where((task) => 
        task.due != null && 
        task.due!.isAfter(tomorrow.add(const Duration(days: 2))) &&
        task.due!.isBefore(nextWeek)).toList();
    
    final laterTasks = tasks.where((task) => 
        task.due != null && 
        task.due!.isAfter(nextWeek)).toList();
    
    final anytimeTasks = tasks.where((task) => task.due == null).toList();

    // Sort all task lists by status (completed tasks last)
    _sortTasksByStatus(overdueTasks);
    _sortTasksByStatus(todayTasks);
    _sortTasksByStatus(soonTasks);
    _sortTasksByStatus(nextWeekTasks);
    _sortTasksByStatus(laterTasks);
    _sortTasksByStatus(anytimeTasks);

    final columns = [
      KanbanColumn(
        id: 'overdue',
        title: 'Overdue',
        subtitle: '${overdueTasks.length} tasks',
        tasks: overdueTasks,
                 color: context.chartTheme.colors.error,
        icon: Icons.warning_rounded,
      ),
      KanbanColumn(
        id: 'today',
        title: 'Today',
        subtitle: _formatDate(today),
        tasks: todayTasks,
                 color: context.chartTheme.colors.success,
        icon: Icons.today_rounded,
      ),
      KanbanColumn(
        id: 'soon',
        title: 'Soon',
        subtitle: 'Next 2 days',
        tasks: soonTasks,
                 color: context.chartTheme.colors.warning,
        icon: Icons.schedule_rounded,
      ),
      KanbanColumn(
        id: 'next_week',
        title: 'Next Week',
        subtitle: '${nextWeekTasks.length} tasks',
        tasks: nextWeekTasks,
                 color: context.chartTheme.colors.primary,
        icon: Icons.date_range_rounded,
      ),
      KanbanColumn(
        id: 'later',
        title: 'Later',
        subtitle: '${laterTasks.length} tasks',
        tasks: laterTasks,
                 color: context.chartTheme.colors.tertiary,
        icon: Icons.event_rounded,
      ),
      KanbanColumn(
        id: 'anytime',
        title: 'Anytime',
        subtitle: '${anytimeTasks.length} tasks',
        tasks: anytimeTasks,
        color: Colors.grey,
        icon: Icons.inbox_rounded,
      ),
    ];

    return KanbanBoard(
      columns: columns,
      onTaskTap: (task) => _viewTask(context, task),
      onTaskToggle: (task) => _toggleTaskComplete(context, ref, task),
      onTaskUpdated: (task) async {
        await ref.read(taskViewModelProvider.notifier).updateTask(task);
        _refreshProjectTasks(ref);
      },
      onTaskDeleted: (task) => _deleteTask(context, ref, task),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  Color _getAttendeeColor(String attendee) {
    // Simple hash to get consistent colors for attendees
    final hash = attendee.hashCode;
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.teal, Colors.pink];
    return colors[hash.abs() % colors.length];
  }

  Future<void> _addTaskForAttendee(BuildContext context, WidgetRef ref, String attendee) async {
    final textController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Task for ${_formatAttendeeEmail(attendee)}'),
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
        sourceCalendarUid: widget.projectUid,
      );
      
      ref.invalidate(projectTasksProvider(widget.projectUid));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Task "$result" added for ${_formatAttendeeEmail(attendee)}')),
        );
      }
    }
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

  // Attendee View - Kanban organized by attendees
  Widget _buildAttendeeView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    final projectAsync = ref.watch(projectProvider(widget.projectUid));
    
    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return const Center(child: Text('Project not found'));
        }

        return tasksAsync.when(
          data: (tasks) => _buildAttendeeKanban(context, ref, project, tasks),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error loading tasks: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading project: $error')),
    );
  }

  Widget _buildAttendeeKanban(BuildContext context, WidgetRef ref, TaskCalendar project, List<Task> tasks) {
    // Collect all unique ACTUAL attendees from project and tasks
    // Note: We're NOT including organizers here - only people who are attendees
    final Set<String> allAttendees = {};
    
    // Add project attendees (convert Attendee objects to emails)
    for (final attendee in project.attendees) {
      allAttendees.add(attendee.email);
    }
    
    // Add task attendees (but NOT organizers - only actual attendees)
    for (final task in tasks) {
      // Convert Attendee objects to email strings
      for (final attendee in task.attendees) {
        allAttendees.add(attendee.email);
      }
    }

    final attendeesList = allAttendees.toList()..sort();
    
    // Tasks without attendees - sorted by status (done tasks last)
    final unassignedTasks = tasks.where((task) => task.attendees.isEmpty).toList();
    _sortTasksByStatus(unassignedTasks);
    
    final columns = <KanbanColumn>[];
    
    // Add "No Attendees" column first
    columns.add(
      KanbanColumn(
        id: '__no_attendees__',
        title: 'No Attendees',
        subtitle: '${unassignedTasks.length} tasks',
        tasks: unassignedTasks,
        color: Colors.grey,
        icon: Icons.person_off_rounded,
        onAddTask: () => _addUnassignedTask(context, ref),
      ),
    );

    // Add columns for each attendee
    for (final attendee in attendeesList) {
      final attendeeTasks = _getTasksForAttendee(tasks, attendee);
      _sortTasksByStatus(attendeeTasks);
      final completedTasks = attendeeTasks.where((task) => task.status == 'COMPLETED').length;
      final progressPercentage = attendeeTasks.isNotEmpty 
          ? (completedTasks * 100 / attendeeTasks.length).round() 
          : 0;

      columns.add(
        KanbanColumn(
          id: attendee,
          title: _formatAttendeeEmail(attendee),
          subtitle: '$progressPercentage% complete',
          tasks: attendeeTasks,
          color: _getAttendeeColor(attendee),
          icon: Icons.person_rounded,
          onAddTask: () => _addTaskForAttendee(context, ref, attendee),
        ),
      );
    }

    return KanbanBoard(
      columns: columns,
      onTaskTap: (task) => _viewTask(context, task),
      onTaskToggle: (task) => _toggleTaskComplete(context, ref, task),
      onTaskMoved: (task, columnId) => _handleAttendeeTaskMove(context, ref, task, columnId),
    );
  }

  List<Task> _getTasksForAttendee(List<Task> tasks, String attendee) {
    // Only return tasks where the person is an actual attendee (not just organizer)
    return tasks.where((task) => 
      task.attendees.any((a) => a.email == attendee)
    ).toList();
  }

  String _formatAttendeeEmail(String email) {
    // Show just the name part if it's an email, otherwise show as-is
    if (email.contains('@')) {
      final namePart = email.split('@').first;
      // Capitalize and replace separators with spaces
      return namePart
          .replaceAll(RegExp(r'[.\-_]'), ' ')
          .split(' ')
          .map((word) => word.isNotEmpty 
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : word)
          .join(' ');
    }
    return email;
  }

  Future<void> _addUnassignedTask(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Unassigned Task'),
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
        sourceCalendarUid: widget.projectUid,
      );
      
      ref.invalidate(projectTasksProvider(widget.projectUid));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Unassigned task "$result" added')),
        );
      }
    }
  }

  Future<void> _handleAttendeeTaskMove(BuildContext context, WidgetRef ref, Task task, String columnId) async {
    try {
      if (columnId == '__no_attendees__') {
        // Remove all attendees from task
        final command = UnassignAllAttendeesCommand(
          ref.read(taskRepositoryProvider),
          ref.read(syncServiceProvider),
        );
        final params = UnassignAllAttendeesParams(task: task);
        await command.executeWith(params);
        
        // Refresh the UI
        ref.invalidate(projectTasksProvider(widget.projectUid));
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed all attendees from "${task.summary}"'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Assign attendee to task
        final command = AssignAttendeeToTaskCommand(
          ref.read(taskRepositoryProvider),
          ref.read(syncServiceProvider),
        );
        final params = AssignAttendeeToTaskParams(task: task, attendeeEmail: columnId);
        await command.executeWith(params);
        
        // Refresh the UI
        ref.invalidate(projectTasksProvider(widget.projectUid));
        
        final attendeeName = _formatAttendeeEmail(columnId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assigned "$attendeeName" to "${task.summary}"'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  // Kanban View - Organized by categories
  Widget _buildKanbanView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => _buildCategoryKanban(context, ref, tasks),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
    );
  }

  Widget _buildCategoryKanban(BuildContext context, WidgetRef ref, List<Task> tasks) {
    // Get all unique categories from tasks
    final Set<String> allCategories = {};
    for (final task in tasks) {
      allCategories.addAll(task.categories);
    }
    
    final categoriesList = allCategories.toList()..sort();
    
    // Tasks without categories - sorted by status (done tasks last)
    final uncategorizedTasks = tasks.where((task) => task.categories.isEmpty).toList();
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
    
    // Add columns for each category
    for (final category in categoriesList) {
      final categoryTasks = tasks.where((task) => task.categories.contains(category)).toList();
      _sortTasksByStatus(categoryTasks);
      
      columns.add(
        KanbanColumn(
          id: category,
          title: category,
          subtitle: '${categoryTasks.length} tasks',
          tasks: categoryTasks,
          color: _getCategoryColor(category),
          icon: Icons.label_rounded,
          onAddTask: () => _addTaskToCategory(context, ref, category),
        ),
      );
    }

    return KanbanBoard(
      columns: columns,
      onTaskTap: (task) => _viewTask(context, task),
      onTaskToggle: (task) => _toggleTaskComplete(context, ref, task),
    );
  }

  Color _getCategoryColor(String category) {
    // Simple hash to get consistent colors for categories
    final hash = category.hashCode;
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.indigo, Colors.red];
    return colors[hash.abs() % colors.length];
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
        sourceCalendarUid: widget.projectUid,
      );
      
      // TODO: After creation, we would need to update the task with the category
      // This would require additional API to update task categories
      
      ref.invalidate(projectTasksProvider(widget.projectUid));
      
      if (context.mounted) {
        final categoryText = category != null ? ' in "$category"' : ' (uncategorized)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Task "$result" added$categoryText')),
        );
      }
    }
  }

  // Agenda View - Calendar with tasks positioned by due date
  Widget _buildAgendaView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => AgendaCalendar(
        tasks: tasks,
        onTaskTap: (task) => _viewTask(context, task),
        onTaskToggle: (task) => _toggleTaskComplete(context, ref, task),
        onTaskUpdated: (task) async {
          await ref.read(taskViewModelProvider.notifier).updateTask(task);
          _refreshProjectTasks(ref);
        },
        onTaskDeleted: (task) => _deleteTask(context, ref, task),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
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
    ref.invalidate(projectTasksProvider(widget.projectUid));
    
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

  void _refreshProjectTasks(WidgetRef ref) {
    // Refresh the project tasks list
    ref.invalidate(projectTasksProvider(widget.projectUid));
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
              AppLogger.info('ProjectDetail: Started dragging task ${task.summary}');
            },
            onDragEnd: () {
              AppLogger.info('ProjectDetail: Ended dragging task ${task.summary}');
            },
          child: TaskItem(
            task: task,
            onTap: () => _viewTask(context, task),
            onToggleComplete: () => _toggleTaskComplete(context, ref, task),
            onTaskUpdated: (updatedTask) async {
              await ref.read(taskViewModelProvider.notifier).updateTask(updatedTask);
              _refreshProjectTasks(ref);
            },
            onTaskDeleted: () => _deleteTask(context, ref, task),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, Task task) async {
    // Handle task deletion
    final taskViewModel = ref.read(taskViewModelProvider.notifier);
    await taskViewModel.deleteTask(task.uid);
    
    // Refresh the tasks list
    ref.invalidate(projectTasksProvider(widget.projectUid));
    
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
