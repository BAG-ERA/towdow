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
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../widgets/utils/buttons/create_workflow_button.dart';
import '../../widgets/navbar/workflow_popup_menu.dart';
import '../../widgets/utils/popup/move_to_domain_dialog.dart';
import '../../../core/theme/chart_theme_usage.dart';

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
        ref.read(workflowListViewModelProvider.notifier).setFilter(ProjectFilter.active);
        break;
      case 1:
        ref.read(workflowListViewModelProvider.notifier).setFilter(ProjectFilter.completed);
        break;
      case 2:
        ref.read(workflowListViewModelProvider.notifier).setFilter(ProjectFilter.all);
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
              title: Text(AppLocalizations.of(context)!.allWorkflows),
              scrolledUnderElevation: 0,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: StyledTabBar(
                  items: [
                    StyledTabItem(label: AppLocalizations.of(context)!.ongoing),
                    StyledTabItem(label: AppLocalizations.of(context)!.archived),
                    StyledTabItem(label: AppLocalizations.of(context)!.all),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: _buildCreateWorkflowButton(context),
      ),
    );
  }

  Widget _buildCreateWorkflowButton(BuildContext context) {
    return CreateWorkflowButton.prominent(
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
             Text(AppLocalizations.of(context)!.noneFound(AppLocalizations.of(context)!.workflows.toLowerCase()), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.workflowsExplainer,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(workflowListViewModelProvider.notifier).refresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Builder(
            builder: (context) {
              final state = ref.watch(workflowListViewModelProvider);
              final viewModel = ref.read(workflowListViewModelProvider.notifier);
              final groups = viewModel.filteredDomainGroups;
              
              return Column(
                children: [
                  for (final group in groups)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: InkWell(
                              onTap: () => group.isExpanded 
                                  ? viewModel.collapseDomain(group.domain)
                                  : viewModel.expandDomain(group.domain),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        group.domain,
                                        style: context.domainNameStyle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      group.isExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (group.isExpanded) ...[
                            const SizedBox(height: 8),
                            ProjectsTable(
                              state: state,
                              projectsOverride: group.projects,
                              onProjectTap: _navigateToWorkflow,
                              onProjectAction: _handleWorkflowAction,
                              onSortChanged: (sortType) {
                                ref.read(workflowListViewModelProvider.notifier).setSortBy(sortType);
                              },
                              menuBuilder: (context, ref, project) => WorkflowPopupMenu.getMenuItems(context, ref, project: project),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _WorkflowsExplanationHeader(),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  void _navigateToWorkflow(TaskCalendar workflow) {
    final encodedPath = Uri.encodeComponent(workflow.path);
    context.go('/workflow/$encodedPath');
  }

  void _handleWorkflowAction(String action, ProjectWithStats projectWithStats) {
    switch (action) {
      case 'see_details':
        _navigateToWorkflow(projectWithStats.project);
        break;
      case 'duplicate_workflow':
        _duplicateWorkflow(projectWithStats.project);
        break;
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

  Future<void> _duplicateWorkflow(TaskCalendar project) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: '${project.displayName} (copy)');
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.duplicateWorkflow),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.newWorkflowName),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context)!.cancel)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: Text(AppLocalizations.of(context)!.create)),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;

    final workflowService = ref.read(workflowServiceProvider);
    final result = await workflowService.duplicateWorkflow(
      sourceCalendarPath: project.path,
      newDisplayName: name,
    );
    await result.when(
      success: (newPath) async {
        final encoded = Uri.encodeComponent(newPath);
        if (mounted) context.go('/workflow/$encoded');
      },
      failure: (f) async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('${AppLocalizations.of(context)!.failedToLoad}: ${f.message}')),
          );
        }
      },
    );
  }

  void _copyWorkflowPath(TaskCalendar project) {
    Clipboard.setData(ClipboardData(text: project.path));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.workflowPathCopied), duration: const Duration(seconds: 2)),
    );
  }
}

class _WorkflowsExplanationHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflows define steps to move tasks through. \n'
            'Use them to standardize progress across tasks and teams. \n'
            'This table lets you browse, sort, and manage your workflows at a glance.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

