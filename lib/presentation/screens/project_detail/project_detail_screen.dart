// Project detail screen for managing individual projects
// Shows tasks within a project, supports task management and project info
// Projects are represented by TaskCalendar objects (CalDAV calendars)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/kanban_board.dart';
import '../../widgets/agenda_calendar.dart';
import '../../widgets/utils/tasklist_toolbar.dart';
import '../../widgets/utils/buttons/archive_project_button.dart';
import '../../widgets/utils/buttons/exit_share_button.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/models/step.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../viewmodels/commands/attendee_commands.dart';

import '../../../core/theme/chart_theme.dart';
import '../../widgets/adaptive_app_layout.dart';
import '../../widgets/project_detail/project_task_list_view.dart';
import '../../widgets/project_detail/project_kanban_view.dart';
import '../../widgets/project_detail/project_infos_widget.dart';
import '../../widgets/project_detail/project_bottleneck_view.dart';

// Provider for a specific project/calendar that watches only this specific calendar
final projectProvider = StreamProvider.family<TaskCalendar?, String>((ref, projectPath) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  
  // Encode special characters in the project path to match storage format
  final encodedProjectPath = projectPath.replaceAll('@', '%40');
  
  // Watch all calendars and filter for just this one
  return calendarRepository.watchCalendars().asyncMap((calendars) async {
    // Find the specific calendar by path
    try {
      final calendar = calendars.cast<TaskCalendar?>().firstWhere(
        (cal) => cal?.path == encodedProjectPath,
        orElse: () => null,
      );
      
      if (calendar != null) {
        AppLogger.debug('ProjectDetailScreen: Found project for path $projectPath: ${calendar.displayName}');
      } else {
        AppLogger.debug('ProjectDetailScreen: Project not found for path $projectPath (encoded: $encodedProjectPath)');
      }
      
      return calendar;
    } catch (e) {
      AppLogger.error('ProjectDetailScreen: Error finding project $projectPath: $e');
      return null;
    }
  });
});

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectPath;

  const ProjectDetailScreen({
    super.key,
    required this.projectPath,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  int _selectedTabIndex = 0;

  @override
  void dispose() {
    // Note: Mobile providers are automatically cleaned up when the widget tree is disposed
    // No need to manually clear them here as it can cause disposal errors
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppLogger.info('ProjectDetailScreen: Building screen for project path: ${widget.projectPath}');
    final projectAsync = ref.watch(projectProvider(widget.projectPath));
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectPath));

    // Check if we're on desktop (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    // Update mobile providers when project data is available
    projectAsync.whenData((project) {
      if (project != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Update mobile providers if on mobile
          if (!isDesktop) {
            ref.read(mobileTitleProvider.notifier).state = project.displayName;
            ref.read(mobileProjectProvider.notifier).state = project;
            ref.read(mobileProjectUpdateProvider.notifier).state = _updateProject;
          }
          
          // Auto-acknowledge shared project when viewing project detail
          _acknowledgeSharedProjectIfNeeded(project);
        });
      }
    });

    if (isDesktop) {
      // Desktop 3-column layout: Nav bar | Title/Header | View content
      return _buildDesktopLayout(context, projectAsync, tasksAsync);
    } else {
      // Mobile single-column layout (existing)
      return _buildMobileLayout(context, projectAsync, tasksAsync);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Row(
        children: [
          // Column 1: Title/Header area (fixed width) with full project info
          Container(
            width: 320,
            child: Column(
              children: [
                // Project title and full project info
                _buildDesktopHeader(context, projectAsync, tasksAsync),
              ],
            ),
          ),
          
          // Gap between columns
          const SizedBox(width: 48),
          
          // Column 2: View content (expanded) with tabs and content
          Expanded(
            child: Column(
              children: [
                // Archive button row at the top
                _buildArchiveButtonRow(context, projectAsync),
                
                // View tabs moved to right column
                _buildViewTabs(context),
                
                // Content based on selected tab
                Expanded(
                  child: _buildTabContent(context, ref, tasksAsync),
                ),
                
                // Bottom toolbar with search and create task button
                TaskListToolbar(
                  projectPath: widget.projectPath,
                  projectName: projectAsync.asData?.value?.displayName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project details layout
          projectAsync.when(
            data: (project) => project != null 
                ? ProjectInfosWidget(
                    project: project,
                    tasksAsync: tasksAsync,
                    onProjectUpdated: _updateProject,
                  )
                : const SizedBox.shrink(),
            loading: () => Container(
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
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Project Details Widget (replacing ProjectInfoCard)
                  projectAsync.when(
                    data: (project) => project != null 
                        ? ProjectInfosWidget(
                            project: project,
                            tasksAsync: tasksAsync,
                            onProjectUpdated: (updatedProject) => _updateProject(updatedProject),
                          )
                        : Container(
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
                                    'Project not found: ${widget.projectPath}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7, // Give content a reasonable height
                    child: _buildTabContent(context, ref, tasksAsync),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom toolbar with search and create task button (fixed at bottom)
          TaskListToolbar(
            projectPath: widget.projectPath,
            projectName: projectAsync.asData?.value?.displayName,
          ),
        ],
      ),
    );
  }



  Widget _buildArchiveButtonRow(BuildContext context, AsyncValue<TaskCalendar?> projectAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          projectAsync.when(
            data: (project) => project != null
                ? _buildProjectActionButton(context, project)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectActionButton(BuildContext context, TaskCalendar project) {
    // Check if this project is shared with the current user using the same logic as _acknowledgeSharedProjectIfNeeded
    final userPreferencesAsync = ref.watch(userPreferencesProvider);
    
    return userPreferencesAsync.when(
      data: (preferences) {
        final sharedProject = preferences.getSharedProject(project.uid);
        final isSharedWithMe = sharedProject != null;
        
        if (isSharedWithMe) {
          // Show exit share button for shared projects
          return ExitShareButton.compact(
            projectPath: project.path,
            projectDisplayName: project.displayName,
            // Navigation is handled internally by ExitShareButton
          );
        } else {
          // Show archive button for owned projects
          return ArchiveProjectButton.compact(
            projectPath: project.path,
            projectDisplayName: project.displayName,
            onProjectArchived: () {
              // Navigate back to home after archiving
              Navigator.of(context).pop();
            },
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
            label: 'Bottleneck',
            icon: Icons.timeline,
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
        projectPath: widget.projectPath,
        tasksAsync: tasksAsync,
        onTasksRefresh: () => _refreshProjectTasks(ref),
      ),
      1 => _buildBottleneckView(context, ref, tasksAsync),
      2 => _buildTimingView(context, ref, tasksAsync),
      3 => _buildAttendeeView(context, ref, tasksAsync),
      4 => _buildKanbanView(context, ref, tasksAsync),
      5 => _buildAgendaView(context, ref, tasksAsync),
      _ => ProjectTaskListView(
        projectPath: widget.projectPath,
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
      },
      onTaskToggle: (task) async {
        // Enforce: in ONGOING workflows only tasks in AVAILABLE steps can be marked done
        final project = ref.read(projectProvider(widget.projectPath)).asData?.value;
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
            const SnackBar(content: Text('This task belongs to a waiting step and cannot be completed yet.')),
          );
          return;
        }

        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.toggleTaskCompletion(task);
        
        // Refresh the tasks list
        _refreshProjectTasks(ref);
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
        projectPath: widget.projectPath,
      );
      
      ref.invalidate(projectTasksProvider(widget.projectPath));
    }
  }



  // Attendee View - Kanban organized by attendees
  Widget _buildAttendeeView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    final projectAsync = ref.watch(projectProvider(widget.projectPath));
    
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
      },
      onTaskToggle: (task) async {
        final taskViewModel = ref.read(taskViewModelProvider.notifier);
        await taskViewModel.toggleTaskCompletion(task);
        
        // Refresh the tasks list
        _refreshProjectTasks(ref);
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
        projectPath: widget.projectPath,
      );
      
      ref.invalidate(projectTasksProvider(widget.projectPath));
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
        ref.invalidate(projectTasksProvider(widget.projectPath));
      } else {
        // Assign attendee to task
        final command = AssignAttendeeToTaskCommand(
          ref.read(taskRepositoryProvider),
          ref.read(syncServiceProvider),
        );
        final params = AssignAttendeeToTaskParams(task: task, attendeeEmail: columnId);
        await command.executeWith(params);
        
        // Refresh the UI
        ref.invalidate(projectTasksProvider(widget.projectPath));
      }
    } catch (error) {
      if (context.mounted) {
        AppLogger.error('Error moving task: $error');
      }
    }
  }

  // Kanban View - Organized by categories
  Widget _buildKanbanView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return ProjectKanbanView(
      projectPath: widget.projectPath,
      tasksAsync: tasksAsync,
      onTasksRefresh: () => _refreshProjectTasks(ref),
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

  // Agenda View - Calendar with tasks positioned by due date
  Widget _buildAgendaView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => AgendaCalendar(
        tasks: tasks,
        onTaskTap: (task) {
          // Navigate to task detail
        },
        onTaskToggle: (task) async {
          final taskViewModel = ref.read(taskViewModelProvider.notifier);
          await taskViewModel.toggleTaskCompletion(task);
          
          // Refresh the tasks list
          _refreshProjectTasks(ref);
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
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
    );
  }

  void _refreshProjectTasks(WidgetRef ref) {
    // Refresh the project tasks list
    ref.invalidate(projectTasksProvider(widget.projectPath));
  }

  // Bottleneck View
  Widget _buildBottleneckView(BuildContext context, WidgetRef ref, AsyncValue<List<Task>> tasksAsync) {
    return tasksAsync.when(
      data: (tasks) => ProjectBottleneckView(
        projectPath: widget.projectPath,
        tasks: tasks,
        onTasksRefresh: () => _refreshProjectTasks(ref),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading tasks: $error')),
    );
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
          ref.invalidate(projectProvider(widget.projectPath));
          
          // Also invalidate the project list provider so navbar updates
          ref.invalidate(projectListProvider);
          
          // Sync changes to CalDAV server (don't wait for this)
          AppLogger.info('ProjectDetail: About to call _syncProjectToServer...');
          _syncProjectToServer(updatedProject);
          AppLogger.info('ProjectDetail: _syncProjectToServer call initiated (running in background)');
        },
        failure: (failure) async {
          if (mounted) {
            AppLogger.error('Failed to update project: ${failure.message}');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AppLogger.error('Error updating project: $e');
      }
    }
  }

  /// Sync project metadata changes to server via repository
  Future<void> _syncProjectToServer(TaskCalendar project) async {
    AppLogger.info('ProjectDetail: _syncProjectToServer method entered for project: ${project.displayName}');
    
    try {
      AppLogger.info('ProjectDetail: Starting server sync for project: ${project.displayName}');
      
      // Use repository for proper MVVM architecture - it handles account management internally
      final calendarRepository = ref.read(calendarRepositoryProvider);
      AppLogger.info('ProjectDetail: Calling repository updateCalendarProperties...');
      final syncResult = await calendarRepository.updateCalendarProperties(project);
      
      await syncResult.when(
        success: (_) {
          AppLogger.info('ProjectDetail: Successfully synced project metadata to server');
        },
        failure: (failure) {
          AppLogger.error('ProjectDetail: Failed to sync project metadata to server: ${failure.message}');
          if (mounted) {
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectDetail: Exception during server sync', e, stackTrace);
      if (mounted) {
        // Sync error - no user notification needed
      }
    }
  }

  /// Auto-acknowledge shared project when user views project detail
  Future<void> _acknowledgeSharedProjectIfNeeded(TaskCalendar project) async {
    try {
      final userRepository = ref.read(userRepositoryProvider);
      final preferencesResult = await userRepository.getUserPreferences();
      
      await preferencesResult.when(
        success: (preferences) async {
          final sharedProject = preferences.getSharedProject(project.uid);
          
          // Only acknowledge if project is shared with me and not yet acknowledged
          if (sharedProject != null && !sharedProject.ack) {
            AppLogger.info('ProjectDetailScreen: Auto-acknowledging shared project ${project.displayName}');
            
            final acknowledgeResult = await userRepository.acknowledgeSharedProject(project.uid);
            await acknowledgeResult.when(
              success: (_) {
                AppLogger.info('ProjectDetailScreen: Successfully acknowledged shared project ${project.displayName}');
              },
              failure: (failure) {
                AppLogger.warning('ProjectDetailScreen: Failed to acknowledge shared project ${project.displayName}: ${failure.message}');
              },
            );
          }
        },
        failure: (failure) async {
          AppLogger.warning('ProjectDetailScreen: Failed to get user preferences for acknowledgment: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('ProjectDetailScreen: Exception during shared project acknowledgment: $e');
    }
  }
} 
