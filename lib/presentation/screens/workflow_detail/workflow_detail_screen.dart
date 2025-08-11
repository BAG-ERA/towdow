// Workflow detail screen - thin wrapper around ProjectDetailScreen for separate route and future specialization

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../../widgets/project_detail/project_infos_widget.dart';
import '../../widgets/project_detail/project_task_list_view.dart';
import '../../widgets/utils/tasklist_toolbar.dart';
import '../../widgets/utils/popup/requirement_mapping_dialog.dart';
import '../../widgets/project_detail/project_task_step_view.dart';
import '../project_detail/project_detail_screen.dart' show projectProvider;

class WorkflowDetailScreen extends ConsumerStatefulWidget {
  final String workflowPath;
  const WorkflowDetailScreen({super.key, required this.workflowPath});

  @override
  ConsumerState<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends ConsumerState<WorkflowDetailScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectProvider(widget.workflowPath));
    final tasksAsync = ref.watch(projectTasksProvider(widget.workflowPath));

    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: isDesktop ? _buildDesktopLayout(context, projectAsync, tasksAsync) : _buildMobileLayout(context, projectAsync, tasksAsync),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: _buildDesktopHeader(context, projectAsync, tasksAsync),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            children: [
              _buildTopActionRow(context, projectAsync),
              _buildViewTabs(context),
              Expanded(child: _buildTabContent(context, tasksAsync)),
              // Bottom toolbar with search and create task button (same as Project screen)
              TaskListToolbar(
                projectPath: widget.workflowPath,
                projectName: projectAsync.asData?.value?.displayName,
                workflowVariant: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Column(
      children: [
        projectAsync.when(
          data: (project) => project != null ? ProjectInfosWidget(project: project, tasksAsync: tasksAsync, onProjectUpdated: (p) {}) : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        Expanded(child: _buildTabContent(context, tasksAsync)),
        // Bottom toolbar with search and create task button (same as Project screen)
        TaskListToolbar(
          projectPath: widget.workflowPath,
          projectName: projectAsync.asData?.value?.displayName,
          workflowVariant: true,
        ),
      ],
    );
  }

  Widget _buildTopActionRow(BuildContext context, AsyncValue<TaskCalendar?> projectAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left side empty to naturally push actions to the right
          const Spacer(),
          projectAsync.when(
            data: (project) => project != null ? _buildWorkflowActions(context, project) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowActions(BuildContext context, TaskCalendar project) {
    final status = (project.flowitStatus ?? 'ONGOING').toUpperCase();
    final buttons = <Widget>[];

    if (status == 'DRAFT') {
      buttons.add(FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start workflow'),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => RequirementMappingDialog(projectPath: widget.workflowPath),
          );
          if (confirmed == true) {
            final statusService = ref.read(statusServiceProvider);
            await statusService.assignStatusToCalendar(widget.workflowPath, 'ONGOING');
            // After starting, propagate requirement attendees to tasks
            await ref.read(workflowServiceProvider).applyRequirementAttendeesToTasks(widget.workflowPath);
            // Force refresh of project status for UI buttons
            ref.invalidate(projectProvider(widget.workflowPath));
          }
        },
      ));
    } else if (status == 'ONGOING') {
      buttons.add(FilledButton.tonalIcon(
        icon: const Icon(Icons.pause_rounded),
        label: const Text('Pause workflow'),
        onPressed: () async {
          final statusService = ref.read(statusServiceProvider);
          await statusService.assignStatusToCalendar(widget.workflowPath, 'PAUSED');
          // Refresh UI to reflect PAUSED state
          ref.invalidate(projectProvider(widget.workflowPath));
        },
      ));
    } else if (status == 'COMPLETED') {
      buttons.add(FilledButton.tonalIcon(
        icon: const Icon(Icons.archive_rounded),
        label: const Text('Archive workflow'),
        onPressed: () async {
          final statusService = ref.read(statusServiceProvider);
          await statusService.archiveCalendar(widget.workflowPath);
          // Refresh UI to reflect ARCHIVE state
          ref.invalidate(projectProvider(widget.workflowPath));
        },
      ));
    }

    buttons.add(const SizedBox(width: 8));
    buttons.add(OutlinedButton.icon(
      icon: const Icon(Icons.content_copy_rounded),
      label: const Text('Duplicate workflow'),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicate workflow is not yet implemented.')),
        );
      },
    ));

    return Row(children: buttons);
  }

  Widget _buildDesktopHeader(BuildContext context, AsyncValue<TaskCalendar?> projectAsync, AsyncValue<List<Task>> tasksAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          projectAsync.when(
            data: (project) => project != null
                ? ProjectInfosWidget(project: project, tasksAsync: tasksAsync, onProjectUpdated: (_) {})
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
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
        onTabSelected: (index) => setState(() => _selectedTabIndex = index),
        items: const [
          StyledTabItem(label: 'List', icon: Icons.checklist_rounded),
          StyledTabItem(label: 'Steps', icon: Icons.stairs_outlined),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, AsyncValue<List<Task>> tasksAsync) {
    switch (_selectedTabIndex) {
      case 0:
        return ProjectTaskListView(
          projectPath: widget.workflowPath,
          tasksAsync: tasksAsync,
          onTasksRefresh: () {},
        );
      case 1:
        return ProjectTaskStepView(
          projectPath: widget.workflowPath,
          tasksAsync: tasksAsync,
          onTasksRefresh: () {},
        );
      default:
        return const SizedBox.shrink();
    }
  }
}


