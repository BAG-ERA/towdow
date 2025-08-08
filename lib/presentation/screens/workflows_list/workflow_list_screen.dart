// Workflows list screen for displaying all workflows using the same table as projects
// Uses WorkflowListViewModel (ProjectListViewModel in workflows mode) and reuses ProjectsTable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/task_calendar.dart';
import '../../../data/providers/providers.dart';
import '../../viewmodels/project_list_viewmodel.dart';
import '../../widgets/project-list/projects_table.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/utils/buttons/create_workflow_button.dart';
import '../../widgets/navbar/workflow_popup_menu.dart';
import '../../widgets/utils/popup/move_to_domain_dialog.dart';

class WorkflowListScreen extends ConsumerStatefulWidget {
  const WorkflowListScreen({super.key});

  @override
  ConsumerState<WorkflowListScreen> createState() => _WorkflowListScreenState();
}

class _WorkflowListScreenState extends ConsumerState<WorkflowListScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workflowListViewModelProvider.notifier).initialize();
      _applyFilter();
    });
  }

  void _applyFilter() {
    switch (_selectedTabIndex) {
      case 0:
        ref.read(workflowListViewModelProvider.notifier).setFilter(ProjectFilter.all);
        break;
      case 1:
        ref.read(workflowListViewModelProvider.notifier).setFilter(ProjectFilter.active);
        break;
      case 2:
        ref.read(workflowListViewModelProvider.notifier).setFilter(ProjectFilter.completed);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowListViewModelProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    return Scaffold(
      appBar: isDesktop
          ? AppBar(
              title: const Text('All Workflows'),
              scrolledUnderElevation: 0,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              actions: [
                _buildCreateWorkflowButton(context),
                const SizedBox(width: 16),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: StyledTabBar(
                  items: const [
                    StyledTabItem(label: 'All'),
                    StyledTabItem(label: 'Ongoing'),
                    StyledTabItem(label: 'Archived'),
                  ],
                  selectedIndex: _selectedTabIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                    _applyFilter();
                  },
                ),
              ),
            )
          : null,
      body: _buildBody(state),
    );
  }

  Widget _buildCreateWorkflowButton(BuildContext context) {
    return CreateWorkflowButton.compact(
      onWorkflowCreated: () {
        ref.read(workflowListViewModelProvider.notifier).refresh();
      },
    );
  }

  Widget _buildBody(ProjectListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text(state.error!));
    }
    if (state.filteredProjects.isEmpty) {
      return const Center(child: Text('No workflows found'));
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(workflowListViewModelProvider.notifier).refresh(),
      child: ProjectsTable(
        state: state,
        onProjectTap: _navigateToWorkflow,
        onProjectAction: _handleWorkflowAction,
        onSortChanged: (sortType) {
          ref.read(workflowListViewModelProvider.notifier).setSortBy(sortType);
        },
        menuBuilder: (context, ref, project) => WorkflowPopupMenu.getMenuItems(context, ref, project: project),
      ),
    );
  }

  void _navigateToWorkflow(TaskCalendar workflow) {
    final encodedPath = Uri.encodeComponent(workflow.path);
    context.go('/workflow/$encodedPath');
  }

  void _handleWorkflowAction(String action, ProjectWithStats projectWithStats) {
    switch (action) {
      case 'convert_to_project':
        _convertWorkflowToProject(projectWithStats.project);
        break;
      case 'move_to_domain':
        _showMoveToDomainDialog(projectWithStats.project);
        break;
      case 'archive_project':
        if (projectWithStats.project.isArchived) {
          _handleUnarchive(projectWithStats.project);
        } else {
          _handleArchive(projectWithStats.project);
        }
        break;
      case 'delete_workflow':
        _deleteWorkflow(projectWithStats.project);
        break;
      case 'copy_path':
        _copyWorkflowPath(projectWithStats.project);
        break;
      default:
        break;
    }
  }

  Future<void> _convertWorkflowToProject(TaskCalendar project) async {
    await ref.read(workflowListViewModelProvider.notifier).convertWorkflowToProject(project.path);
  }

  void _showMoveToDomainDialog(TaskCalendar project) {
    showDialog(
      context: context,
      builder: (context) => MoveToDomainDialog(project: project),
    );
  }

  Future<void> _handleArchive(TaskCalendar project) async {
    await ref.read(workflowListViewModelProvider.notifier).archiveProject(project.path);
  }

  Future<void> _handleUnarchive(TaskCalendar project) async {
    await ref.read(workflowListViewModelProvider.notifier).unarchiveProject(project.path);
  }

  Future<void> _deleteWorkflow(TaskCalendar project) async {
    await ref.read(workflowListViewModelProvider.notifier).deleteProject(project.path);
    final currentRoute = GoRouterState.of(context).uri.path;
    if (currentRoute == '/project/${Uri.encodeComponent(project.path)}') {
      context.go('/workflows');
    }
  }

  void _copyWorkflowPath(TaskCalendar project) {
    Clipboard.setData(ClipboardData(text: project.path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workflow path copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }
}


