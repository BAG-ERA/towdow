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
import '../../widgets/project_detail/project_info_card.dart';
import '../../widgets/project_detail/project_task_list_view.dart';
import '../../../data/services/caldav_service.dart';

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
    // Clear mobile providers when leaving the screen
    ref.read(mobileTitleProvider.notifier).state = null;
    ref.read(mobileProjectProvider.notifier).state = null;
    ref.read(mobileProjectUpdateProvider.notifier).state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppLogger.info('ProjectDetailScreen: Building screen for project UID: ${widget.projectUid}');
    final projectAsync = ref.watch(projectProvider(widget.projectUid));
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectUid));

    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    // Update mobile providers when project data is available
    projectAsync.whenData((project) {
      if (project != null && !isDesktop) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(mobileTitleProvider.notifier).state = project.displayName;
          ref.read(mobileProjectProvider.notifier).state = project;
          ref.read(mobileProjectUpdateProvider.notifier).state = _updateProject;
        });
      }
    });

    return Scaffold(
      appBar: isDesktop ? AppBar(
        title: projectAsync.when(
          data: (project) => project != null 
              ? _EditableProjectTitle(
                  project: project,
                  onProjectUpdated: (updatedProject) => _updateProject(updatedProject),
                  isInAppBar: true,
                )
              : const Text('Unknown Project'),
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
          projectAsync.when(
            data: (project) => ProjectInfoCard(
              project: project,
              tasksAsync: tasksAsync,
              projectUid: widget.projectUid,
              onProjectUpdated: (updatedProject) => _updateProject(updatedProject),
            ),
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
          ),
          
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
      0 => ProjectTaskListView(
        projectUid: widget.projectUid,
        tasksAsync: tasksAsync,
        onTasksRefresh: () => _refreshProjectTasks(ref),
      ),
      1 => _buildTimingView(context, ref, tasksAsync),
      2 => _buildAttendeeView(context, ref, tasksAsync),
      3 => _buildKanbanView(context, ref, tasksAsync),
      4 => _buildAgendaView(context, ref, tasksAsync),
      _ => ProjectTaskListView(
        projectUid: widget.projectUid,
        tasksAsync: tasksAsync,
        onTasksRefresh: () => _refreshProjectTasks(ref),
      ),
    };
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
        _refreshProjectTasks(ref);
        
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
        _refreshProjectTasks(ref);
      },
      onTaskDeleted: (task) async {
        // Handle task deletion
        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.deleteTask(task.uid);
        
        // Refresh the tasks list
        _refreshProjectTasks(ref);
        
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
      },
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
        _refreshProjectTasks(ref);
        
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
        _refreshProjectTasks(ref);
      },
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
        _refreshProjectTasks(ref);
        
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
        _refreshProjectTasks(ref);
      },
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
          _refreshProjectTasks(ref);
          
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
          _refreshProjectTasks(ref);
        },
        onTaskDeleted: (task) async {
          // Handle task deletion
          final taskViewModel = ref.read(taskViewModelProvider.notifier);
          await taskViewModel.deleteTask(task.uid);
          
          // Refresh the tasks list
          _refreshProjectTasks(ref);
          
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
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
    );
  }



  void _refreshProjectTasks(WidgetRef ref) {
    // Refresh the project tasks list
    ref.invalidate(projectTasksProvider(widget.projectUid));
  }





  Future<void> _updateProject(TaskCalendar updatedProject) async {
    try {
      AppLogger.info('ProjectDetail: _updateProject called for project: ${updatedProject.displayName}');
      
      final calendarRepository = ref.read(calendarRepositoryProvider);
      
      // Save locally first
      AppLogger.info('ProjectDetail: Saving project locally...');
      final result = await calendarRepository.save(updatedProject);
      
      await result.when(
        success: (data) async {
          // Refresh the project data immediately
          ref.invalidate(projectProvider(widget.projectUid));
          
          // Also invalidate the project list provider so navbar updates
          ref.invalidate(projectListProvider);
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Project updated successfully')),
            );
          }
          
          // Sync changes to CalDAV server (don't wait for this)
          AppLogger.info('ProjectDetail: About to call _syncProjectToServer...');
          _syncProjectToServer(updatedProject);
          AppLogger.info('ProjectDetail: _syncProjectToServer call initiated (running in background)');
        },
        failure: (failure) async {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Failed to update project: ${failure.message}')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error updating project: $e')),
        );
      }
    }
  }

  /// Sync project metadata changes to CalDAV server
  Future<void> _syncProjectToServer(TaskCalendar project) async {
    AppLogger.info('ProjectDetail: _syncProjectToServer method entered for project: ${project.displayName}');
    
    try {
      AppLogger.info('ProjectDetail: Starting server sync for project: ${project.displayName}');
      
      // Get active account
      final accountRepository = ref.read(accountRepositoryProvider);
      AppLogger.info('ProjectDetail: Getting active account from repository...');
      final accountResult = await accountRepository.getActiveAccount();
      AppLogger.info('ProjectDetail: Account result obtained, processing...');
      
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.warning('ProjectDetail: No active account found, skipping server sync');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ No CalDAV account found - changes saved locally only'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          
          AppLogger.info('ProjectDetail: Found active account: ${account.username}@${account.serverUrl}');
          
          // Create CalDAV service and sync to server
          final caldavService = CalDAVService(account: account);
          AppLogger.info('ProjectDetail: Calling CalDAV updateCalendarProperties...');
          final syncResult = await caldavService.updateCalendarProperties(project);
          
          await syncResult.when(
            success: (_) {
              AppLogger.info('ProjectDetail: Successfully synced project metadata to server');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('☁️ Project synced to server'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            failure: (failure) {
              AppLogger.error('ProjectDetail: Failed to sync project metadata to server: ${failure.message}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Server sync failed: ${failure.message}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () => _syncProjectToServer(project),
                    ),
                  ),
                );
              }
            },
          );
        },
        failure: (failure) {
          AppLogger.warning('ProjectDetail: No active account found, skipping server sync: ${failure.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Account error: ${failure.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectDetail: Exception during server sync', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

// Editable Project Title Widget
class _EditableProjectTitle extends StatefulWidget {
  final TaskCalendar project;
  final Function(TaskCalendar) onProjectUpdated;
  final bool isInAppBar;

  const _EditableProjectTitle({
    required this.project,
    required this.onProjectUpdated,
    this.isInAppBar = false,
  });

  @override
  State<_EditableProjectTitle> createState() => _EditableProjectTitleState();
}

class _EditableProjectTitleState extends State<_EditableProjectTitle> {
  bool _isEditing = false;
  bool _isHovered = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.project.displayName);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_EditableProjectTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the project changed while we were editing, we need to handle it
    if (oldWidget.project.uid != widget.project.uid) {
      // Different project - reset editing state and update controller
      setState(() {
        _isEditing = false;
        _isHovered = false;
      });
      _controller.text = widget.project.displayName;
    } else if (oldWidget.project.displayName != widget.project.displayName) {
      // Same project but title changed externally - update controller if not editing
      if (!_isEditing) {
        _controller.text = widget.project.displayName;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInAppBar = widget.isInAppBar;
    final primaryColor = isInAppBar 
        ? Theme.of(context).colorScheme.onSurface 
        : Theme.of(context).colorScheme.onPrimaryContainer;
    
    if (_isEditing) {
      if (isInAppBar) {
        // Simplified editing for AppBar
        return TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _cancelEdit,
                  tooltip: 'Cancel',
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 16),
                  onPressed: _saveTitle,
                  tooltip: 'Save',
                ),
              ],
            ),
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
          onSubmitted: (_) => _saveTitle(),
        );
      }
      
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              onSubmitted: (_) => _saveTitle(),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveTitle,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _startEditing,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: isInAppBar ? null : double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isInAppBar ? 4 : 4, 
            vertical: isInAppBar ? 4 : 8
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isInAppBar 
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.project.displayName,
            style: (isInAppBar 
                ? Theme.of(context).textTheme.titleLarge 
                : Theme.of(context).textTheme.headlineSmall)?.copyWith(
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.project.displayName;
    });
  }

  void _saveTitle() {
    if (_controller.text.trim().isNotEmpty) {
      final newTitle = _controller.text.trim();
      AppLogger.info('ProjectDetail: Saving new title: "$newTitle" (was: "${widget.project.displayName}")');
      
      final updatedProject = widget.project.copyWith(
        displayName: newTitle,
        lastModified: DateTime.now(),
      );
      
      AppLogger.info('ProjectDetail: Calling onProjectUpdated callback...');
      widget.onProjectUpdated(updatedProject);
    }
    
    setState(() {
      _isEditing = false;
    });
  }
} 
