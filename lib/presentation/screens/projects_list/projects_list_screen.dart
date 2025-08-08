// Projects list screen for displaying all projects in a Material Design table
// Shows projects with title, status, start date, due date, completion progress, and actions
// Follows MVVM architecture using existing ProjectListViewModel

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/project_list_viewmodel.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../data/models/task_calendar.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/project-list/projects_table.dart';
import '../../widgets/utils/buttons/create_project_button.dart';
import '../../widgets/utils/popup/move_to_domain_dialog.dart';
import '../../widgets/utils/popup/project_sharing_dialog.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectListViewModelProvider.notifier).initialize();
      _applyFilter(); // Apply initial filter
    });
  }

  void _applyFilter() {
    switch (_selectedTabIndex) {
      case 0:
        ref.read(projectListViewModelProvider.notifier).setFilter(ProjectFilter.all);
        break;
      case 1:
        ref.read(projectListViewModelProvider.notifier).setFilter(ProjectFilter.active);
        break;
      case 2:
        ref.read(projectListViewModelProvider.notifier).setFilter(ProjectFilter.completed);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectListState = ref.watch(projectListViewModelProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;
    
    return Scaffold(
      appBar: isDesktop ? AppBar(
        title: const Text('All Projects'),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          _buildCreateProjectButton(),
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
      ) : null,
      body: _buildBody(projectListState),
    );
  }



  Widget _buildCreateProjectButton() {
    return CreateProjectButton.compact(
      onProjectCreated: (projectName) {
        ref.read(projectListViewModelProvider.notifier).refresh();
      },
    );
  }

  Widget _buildBody(ProjectListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load projects', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(state.error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(projectListViewModelProvider.notifier).loadProjects(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.filteredProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No projects found', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Create your first project to get started', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(projectListViewModelProvider.notifier).refresh(),
      child: ProjectsTable(
        state: state,
        onProjectTap: _navigateToProject,
        onProjectAction: _handleProjectAction,
        onSortChanged: (sortType) {
          ref.read(projectListViewModelProvider.notifier).setSortBy(sortType);
        },
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
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${project.displayName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
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
        content: Text('Project path copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToProject(TaskCalendar project) {
    final encodedPath = Uri.encodeComponent(project.path);
    context.go('/project/$encodedPath');
  }
}



