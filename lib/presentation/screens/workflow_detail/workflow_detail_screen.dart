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
              _buildViewTabs(context),
              Expanded(child: _buildTabContent(context, tasksAsync)),
              // Bottom toolbar with search and create task button (same as Project screen)
              TaskListToolbar(
                projectPath: widget.workflowPath,
                projectName: projectAsync.asData?.value?.displayName,
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
        ),
      ],
    );
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


