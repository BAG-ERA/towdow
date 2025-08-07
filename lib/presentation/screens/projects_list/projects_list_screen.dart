// Projects list screen for displaying all projects in a Material Design table
// Shows projects with title, status, start date, due date, completion progress, and actions
// Follows MVVM architecture using existing ProjectListViewModel

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/project_list_viewmodel.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import '../../../data/models/task_calendar.dart';
import '../../widgets/utils/styled_tab_bar.dart';
import '../../widgets/project-list/projects_table.dart';
import '../../widgets/utils/buttons/create_project_button.dart';

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
      case 'move_to_domain':
        AppLogger.info('Move project to domain: ${projectWithStats.project.displayName}');
        break;
      case 'share_project':
        AppLogger.info('Share project: ${projectWithStats.project.displayName}');
        break;
      case 'archive_project':
        AppLogger.info('Archive project: ${projectWithStats.project.displayName}');
        break;
      case 'delete_project':
        AppLogger.info('Delete project: ${projectWithStats.project.displayName}');
        break;
      case 'copy_path':
        AppLogger.info('Copy project path: ${projectWithStats.project.path}');
        break;
    }
  }

  void _navigateToProject(TaskCalendar project) {
    final encodedPath = Uri.encodeComponent(project.path);
    context.go('/project/$encodedPath');
  }
}



