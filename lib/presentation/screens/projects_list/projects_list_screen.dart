// Projects list screen for displaying all projects in a Material Design table
// Shows projects with title, status, start date, due date, completion progress, and actions
// Follows MVVM architecture using existing ProjectListViewModel

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/project_list_viewmodel.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../data/models/task_calendar.dart';
import '../../widgets/project-list/projects_table.dart';
import '../../widgets/utils/buttons/create_project_button.dart';
import '../../widgets/utils/popup/move_to_domain_dialog.dart';
import '../../widgets/utils/popup/project_sharing_dialog.dart';
import '../../widgets/list_screen/list_screen_scaffold.dart';
import '../../widgets/list_screen/list_screen_body.dart';
import '../../widgets/list_screen/explanation_header.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  int _selectedTabIndex = 0;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectListViewModelProvider.notifier).initialize();
      _applyFilter(); // Apply initial filter
    });
  }

  void _applyFilter() {
    final viewModel = ref.read(projectListViewModelProvider.notifier);
    final state = ref.read(projectListViewModelProvider);
    
    AppLogger.info('ProjectsListScreen: _applyFilter called with _selectedTabIndex: $_selectedTabIndex');
    
    // Apply domain filter based on selected tab
    if (_selectedTabIndex == 0) {
      AppLogger.info('ProjectsListScreen: Setting domain filter to null (All Domains)');
      viewModel.setDomainFilter(null);
    } else {
      final domains = state.availableDomains;
      AppLogger.info('ProjectsListScreen: Available domains: $domains');
      if (_selectedTabIndex - 1 < domains.length) {
        final selectedDomain = domains[_selectedTabIndex - 1];
        AppLogger.info('ProjectsListScreen: Setting domain filter to: $selectedDomain');
        viewModel.setDomainFilter(selectedDomain);
      } else {
        AppLogger.error('ProjectsListScreen: Index out of bounds! _selectedTabIndex: $_selectedTabIndex, domains length: ${domains.length}');
      }
    }
    
    // Apply archived filter
    if (_showArchived) {
      AppLogger.info('ProjectsListScreen: Setting filter to completed (archived)');
      viewModel.setFilter(ProjectFilter.completed);
    } else {
      AppLogger.info('ProjectsListScreen: Setting filter to active (not archived)');
      viewModel.setFilter(ProjectFilter.active);
    }
    
    // Check the state after applying filters
    final newState = ref.read(projectListViewModelProvider);
    AppLogger.info('ProjectsListScreen: After filter - selectedDomain: ${newState.selectedDomain}');
    AppLogger.info('ProjectsListScreen: After filter - filteredProjects count: ${newState.filteredProjects.length}');
  }

  void _toggleArchived() {
    _showArchived = !_showArchived;
    _applyFilter();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final projectListState = ref.watch(projectListViewModelProvider);
    
    final domains = projectListState.availableDomains;
    final domainTabs = ['All Domains', ...domains];
    
    return ListScreenScaffold(
      title: AppLocalizations.of(context)!.allProjects,
      selectedTabIndex: _selectedTabIndex,
      onTabSelected: (index) {
        _selectedTabIndex = index;
        _applyFilter();
        setState(() {});
      },
      domainTabs: domainTabs,
      showArchived: _showArchived,
      onToggleArchived: _toggleArchived,
      body: _buildBody(),
      floatingActionButton: _buildCreateProjectButton(),
      contentType: 'projects',
    );
  }

  Widget _buildCreateProjectButton() {
    return CreateProjectButton.compact(
      onProjectCreated: (projectName) {
        ref.read(projectListViewModelProvider.notifier).refresh();
      },
    );
  }

  Widget _buildBody() {
    final state = ref.watch(projectListViewModelProvider);
    
    return ListScreenBody(
      isLoading: state.isLoading,
      error: state.error,
      isEmpty: state.filteredProjects.isEmpty,
      emptyTitle: AppLocalizations.of(context)!.projects,
      emptyDescription: AppLocalizations.of(context)!.projectsExplainer,
      emptyIcon: Icons.folder_open_rounded,
      onRefresh: () => ref.read(projectListViewModelProvider.notifier).refresh(),
      child: ProjectsTable(
        state: state,
        onProjectTap: _navigateToProject,
        onProjectAction: _handleProjectAction,
        onSortChanged: (sortType) {
          ref.read(projectListViewModelProvider.notifier).setSortBy(sortType);
        },
      ),
      explanationHeader: ExplanationHeader(
        text: 'Projects are conventional containers that group related tasks. \n'
            'Use them to organize work like app development, event planning, or any multi-step initiative. \n'
            'This table lets you browse, sort, and manage your projects at a glance.',
      ),
    );
  }


  void _handleProjectAction(String action, ProjectWithStats projectWithStats) {
    switch (action) {
      case 'convert_to_workflow':
        _convertProjectToWorkflow(projectWithStats.project);
        break;
      case 'convert_to_project':
        _convertWorkflowToProject(projectWithStats.project);
        break;
      case 'move_to_domain':
        AppLogger.info('Move project to domain: ${projectWithStats.project.displayName}');
        _showMoveToDomainDialog(projectWithStats.project);
        break;
      case 'share_project':
        AppLogger.info('Share project: ${projectWithStats.project.displayName}');
        _showProjectSharingDialog(projectWithStats.project);
        break;
      case 'archive_project':
        if (projectWithStats.project.isArchived) {
          AppLogger.info('Unarchive project: ${projectWithStats.project.displayName}');
          _handleUnarchiveProject(projectWithStats.project);
        } else {
          AppLogger.info('Archive project: ${projectWithStats.project.displayName}');
          _handleArchiveProject(projectWithStats.project);
        }
        break;
      case 'delete_project':
        AppLogger.info('Delete project: ${projectWithStats.project.displayName}');
        _showDeleteConfirmation(projectWithStats.project);
        break;
      case 'copy_path':
        AppLogger.info('Copy project path: ${projectWithStats.project.path}');
        _copyProjectPath(projectWithStats.project);
        break;
      case 'see_details':
        _navigateToProject(projectWithStats.project);
        break;
    }
  }

  Future<void> _convertProjectToWorkflow(TaskCalendar project) async {
    await ref.read(projectListViewModelProvider.notifier).convertProjectToWorkflow(project.path);
  }

  Future<void> _convertWorkflowToProject(TaskCalendar project) async {
    await ref.read(projectListViewModelProvider.notifier).convertWorkflowToProject(project.path);
  }

  void _showMoveToDomainDialog(TaskCalendar project) {
    showDialog(
      context: context,
      builder: (context) => MoveToDomainDialog(project: project),
    );
  }

  void _showProjectSharingDialog(TaskCalendar project) {
    showDialog(
      context: context,
      builder: (context) => ProjectSharingDialog(project: project),
    );
  }

  void _handleArchiveProject(TaskCalendar project) async {
    await ref.read(projectListViewModelProvider.notifier).archiveProject(project.path);

  }

  void _handleUnarchiveProject(TaskCalendar project) async {
    await ref.read(projectListViewModelProvider.notifier).unarchiveProject(project.path);
  }

  void _showDeleteConfirmation(TaskCalendar project) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteProject),
        content: Text(
          AppLocalizations.of(context)!.areYouSureDelete(project.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteProject(project);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _deleteProject(TaskCalendar project) async {
    await ref.read(projectListViewModelProvider.notifier).deleteProject(project.path);
    final currentRoute = GoRouterState.of(context).uri.path;
    if (currentRoute == '/project/${Uri.encodeComponent(project.path)}') {
      context.go('/projects');
    }
  }

  void _copyProjectPath(TaskCalendar project) {
    // Copy the project path to clipboard
    Clipboard.setData(ClipboardData(text: project.path));
    
    // Show a brief snackbar to confirm the copy action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.projectPathCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToProject(TaskCalendar project) {
    final encodedPath = Uri.encodeComponent(project.path);
    context.go('/project/$encodedPath');
  }
}





