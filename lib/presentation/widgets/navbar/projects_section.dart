// Projects section widget for displaying synchronized calendar projects in sidebar
// Shows projects grouped by domain with expandable domain sections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/logger.dart';
import '../../../core/theme/chart_theme_usage.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/repositories/user_repository.dart';
import '../../viewmodels/project_list_viewmodel.dart';
import '../utils/popup/domain_rename_dialog.dart';
import '../utils/popup/project_creation_dialog.dart';
import 'project_item_widget.dart';
import 'reorder_drop_zone.dart';

class ProjectsSection extends ConsumerWidget {
  const ProjectsSection({
    super.key,
    this.isDesktop = true,
  });

  final bool isDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);
    final projectListState = ref.watch(projectListViewModelProvider);
    
    return projectsAsync.when(
      data: (projects) => _buildProjectsSection(context, ref, projects.cast<TaskCalendar>(), projectListState),
      loading: () => _buildLoadingState(context),
      error: (error, stackTrace) => _buildErrorState(context, error),
    );
  }

  Widget _buildProjectsSection(BuildContext context, WidgetRef ref, List<TaskCalendar> projects, dynamic projectListState) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(25),
            width: 1,
          ),
        ),
      ),
      child: _buildProjectsContent(context, ref, projects, projectListState),
    );
  }

  Widget _buildProjectsContent(BuildContext context, WidgetRef ref, List<TaskCalendar> projects, dynamic projectListState) {
    // Group projects by domain
    final projectsWithoutDomain = projects.where((project) => !project.hasDomain).toList();
    final domainGroups = <String, List<TaskCalendar>>{};
    
    for (final project in projects.where((project) => project.hasDomain)) {
      final domain = project.flowitDomain!;
      domainGroups.putIfAbsent(domain, () => []).add(project);
    }
    
    // Get all available domains (including empty ones) and sort them
    // Watch project list state but don't use it as key to prevent widget recreation
    final projectListState = ref.watch(projectListViewModelProvider);
    final availableDomainsAsync = ref.watch(availableDomainsProvider);
    
    final allDomains = availableDomainsAsync.when(
      data: (domains) {
        // Add empty domains to domainGroups
        for (final domain in domains) {
          domainGroups.putIfAbsent(domain, () => []);
        }
        return domains;
      },
      loading: () => domainGroups.keys.toList(), // Fallback to domains that have projects
      error: (error, stackTrace) => domainGroups.keys.toList(), // Fallback to domains that have projects
    );
    
    final sortedDomains = allDomains..sort();
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        // Projects list
        Expanded(
          child: projects.isEmpty && sortedDomains.isEmpty
              ? _buildEmptyProjectsState(context)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    // Projects without domain (with drop target)
                    // Always show this section to provide a drop target for removing projects from domains
                    _NoDomainSection(
                      projects: projectsWithoutDomain,
                      ref: ref,
                      showSeparator: sortedDomains.isNotEmpty,
                      isDesktop: isDesktop,
                    ),
                    
                    // Domain sections (including empty ones)
                    ...sortedDomains.map((domain) => 
                      _DomainSection(
                        domain: domain,
                        projects: domainGroups[domain]!,
                        ref: ref,
                        isDesktop: isDesktop,
                      )
                    ),
                  ],
                ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyProjectsState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_rounded,  
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Projects',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to CalDAV to sync your projects',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Settings'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load projects',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Domain section widget with expandable/collapsible functionality
class _DomainSection extends ConsumerStatefulWidget {
  final String domain;
  final List<TaskCalendar> projects;
  final WidgetRef ref;
  final bool isDesktop;

  const _DomainSection({
    required this.domain,
    required this.projects,
    required this.ref,
    required this.isDesktop,
  });

  @override
  ConsumerState<_DomainSection> createState() => _DomainSectionState();
}

class _DomainSectionState extends ConsumerState<_DomainSection> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false; // Domains start collapsed by default

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    } else {
      _animationController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _deleteDomain() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Domain'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the domain "${widget.domain}"?'),
            const SizedBox(height: 8),
            Text(
              widget.projects.isEmpty 
                  ? 'This domain is empty and will be removed.'
                  : 'The ${widget.projects.length} project(s) in this domain will be moved to "No domain".',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
        final domainService = ref.read(domainServiceProvider);

        // Move all projects in this domain to "no domain"
        for (final project in widget.projects) {
          await projectListViewModel.assignDomainToProject(project.path, null);
        }

        // Delete the domain from storage
        final result = await domainService.removeDomainFromStorage(widget.domain);
        
        result.when(
          success: (_) {
            // Refresh the project list
            projectListViewModel.refresh();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Domain "${widget.domain}" deleted successfully'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          },
          failure: (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete domain: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete domain: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _createProjectInDomain() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ProjectCreationDialog(
        initialDomain: widget.domain,
      ),
    );

    if (result != null) {
      // Project creation dialog already handles the creation and UI feedback
      // No additional logic needed here
    }
  }

  void _renameDomain() async {
    final newDomainName = await showDialog<String>(
      context: context,
      builder: (context) => DomainRenameDialog(
        currentDomainName: widget.domain,
      ),
    );

    if (newDomainName != null && newDomainName != widget.domain) {
      // The dialog already handles the rename operation and UI feedback
      // No additional logic needed here since it's all handled in the dialog
    }
  }

  /// Build project list for this domain with custom ordering support
  Widget _buildReorderableProjectList() {
    // Get projects in custom order, but always show all projects
    return FutureBuilder<List<TaskCalendar>>(
      future: _getCustomOrderedProjectsForDomain(),
      builder: (context, snapshot) {
        final orderedProjects = snapshot.data ?? widget.projects;
        
        return Column(
          children: _buildProjectListWithDropZones(orderedProjects),
        );
      },
    );
  }

  /// Build project list with reorder drop zones between projects
  List<Widget> _buildProjectListWithDropZones(List<TaskCalendar> projects) {
    final widgets = <Widget>[];
    
    // Add drop zone at the beginning for inserting at index 0
    widgets.add(ReorderDropZone(
      targetDomain: widget.domain,
      insertIndex: 0,
      onProjectReorder: _handleProjectReorder,
    ));
    
    // Add projects with drop zones between them
    for (int i = 0; i < projects.length; i++) {
      // Add project item
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: ProjectItemWidget(
            project: projects[i], 
            isDesktop: widget.isDesktop,
          ),
        ),
      );
      
      // Add drop zone after each project (except the last one)
      if (i < projects.length - 1) {
        widgets.add(ReorderDropZone(
          targetDomain: widget.domain,
          insertIndex: i + 1,
          onProjectReorder: _handleProjectReorder,
        ));
      }
    }
    
    // Add final drop zone at the end
    widgets.add(ReorderDropZone(
      targetDomain: widget.domain,
      insertIndex: projects.length,
      onProjectReorder: _handleProjectReorder,
    ));
    
    return widgets;
  }

  /// Handle reordering a project within this domain
  void _handleProjectReorder(ProjectDragData dragData, int insertIndex) async {
    try {
      AppLogger.info('DomainSection: Reordering project ${dragData.project.displayName} to index $insertIndex in domain ${widget.domain}');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.reorderProject(dragData.project.path, insertIndex);
      
      AppLogger.info('DomainSection: Successfully reordered project ${dragData.project.displayName}');
    } catch (e) {
      AppLogger.error('DomainSection: Failed to reorder project ${dragData.project.displayName}: $e');
      
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get projects in custom order for this specific domain
  Future<List<TaskCalendar>> _getCustomOrderedProjectsForDomain() async {
    final userRepository = ref.read(userRepositoryProvider);
    final preferencesResult = await userRepository.getUserPreferences();
    
    return preferencesResult.when(
      success: (preferences) {
        final projectOrder = preferences.projectOrder;
        final domainProjects = widget.projects;
        
        if (projectOrder.isEmpty) {
          // No custom order defined, return projects sorted by name
          final sorted = List<TaskCalendar>.from(domainProjects);
          sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
          return sorted;
        }
        
        // Apply user-defined ordering within this domain
        final orderedProjects = <TaskCalendar>[];
        final unorderedProjects = <TaskCalendar>[];
        
        // Add projects in user-defined order (only those in this domain)
        for (final projectPath in projectOrder) {
          final project = domainProjects.cast<TaskCalendar?>().firstWhere(
            (p) => p?.path == projectPath,
            orElse: () => null,
          );
          if (project != null) {
            orderedProjects.add(project);
          }
        }
        
        // Add any projects in this domain that aren't in the user order
        for (final project in domainProjects) {
          if (!projectOrder.contains(project.path)) {
            unorderedProjects.add(project);
          }
        }
        
        // Sort unordered projects by name and append to the end
        unorderedProjects.sort((a, b) => a.displayName.compareTo(b.displayName));
        
        return [...orderedProjects, ...unorderedProjects];
      },
      failure: (failure) {
        AppLogger.error('DomainSection: Failed to get user preferences for ordering', failure.exception, failure.stackTrace);
        // Fallback to name sorting
        final sorted = List<TaskCalendar>.from(widget.projects);
        sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
        return sorted;
      },
    );
  }

  /// Handle dropping a project onto this domain section
  void _handleProjectDrop(BuildContext context, ProjectDragData dragData) async {
    // Don't move project if it's already in this domain
    if (dragData.currentDomain == widget.domain) {
      AppLogger.info('DomainSection: Project ${dragData.project.displayName} already in domain ${widget.domain}');
      return;
    }

    try {
      AppLogger.info('DomainSection: Moving project ${dragData.project.displayName} to domain ${widget.domain}');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.assignDomainToProject(dragData.project.path, widget.domain);
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${dragData.project.displayName}" to "${widget.domain}" domain'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      
              AppLogger.info('DomainSection: Successfully moved project ${dragData.project.displayName} to domain ${widget.domain}');
    } catch (e) {
              AppLogger.error('DomainSection: Failed to move project ${dragData.project.displayName} to domain ${widget.domain}: $e');
      
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to move project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<ProjectDragData>(
      onWillAcceptWithDetails: (details) {
        // Only accept projects from different domains (for domain change, not reordering)
        final draggedFromDomain = details.data.currentDomain;
        return draggedFromDomain != widget.domain;
      },
      onAcceptWithDetails: (details) => _handleProjectDrop(context, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isHovering 
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isHovering 
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Domain header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      child: Row(
                        children: [
                          AnimatedRotation(
                            turns: _isExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.arrow_right,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.domain,
                              style: context.domainNameStyle.copyWith(
                                color: isHovering 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Drop indicator when hovering
                          if (isHovering) ...[
                            Icon(
                              Icons.add_circle_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                          ],
                          
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'create_project') {
                                _createProjectInDomain();
                              } else if (value == 'rename') {
                                _renameDomain();
                              } else if (value == 'delete') {
                                _deleteDomain();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'create_project',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Create project',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem<String>(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Rename domain',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete domain',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Domain projects (expandable)
              SizeTransition(
                sizeFactor: _animation,
                child: widget.projects.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(left: 32, top: 8, bottom: 8),
                        child: Text(
                          isHovering 
                              ? 'Drop project here to add to this domain'
                              : 'No projects in this domain',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isHovering
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : _buildReorderableProjectList(),
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// No domain section widget with drag target functionality
class _NoDomainSection extends ConsumerWidget {
  final List<TaskCalendar> projects;
  final WidgetRef ref;
  final bool showSeparator;
  final bool isDesktop;

  const _NoDomainSection({
    required this.projects,
    required this.ref,
    this.showSeparator = false,
    required this.isDesktop,
  });

  /// Build project list for projects without domain with custom ordering support
  Widget _buildReorderableProjectList(BuildContext context, WidgetRef ref) {
    // Get projects in custom order, but always show all projects
    return FutureBuilder<List<TaskCalendar>>(
      future: _getCustomOrderedProjectsWithoutDomain(ref),
      builder: (context, snapshot) {
        final orderedProjects = snapshot.data ?? projects;
        
        return Column(
          children: _buildProjectListWithDropZones(orderedProjects, context, ref),
        );
      },
    );
  }

  /// Build project list with reorder drop zones between projects
  List<Widget> _buildProjectListWithDropZones(List<TaskCalendar> projects, BuildContext context, WidgetRef ref) {
    final widgets = <Widget>[];
    
    // Add drop zone at the beginning for inserting at index 0
    widgets.add(ReorderDropZone(
      targetDomain: null, // No domain
      insertIndex: 0,
      onProjectReorder: (dragData, insertIndex) => _handleProjectReorder(context, ref, dragData, insertIndex),
    ));
    
    // Add projects with drop zones between them
    for (int i = 0; i < projects.length; i++) {
      // Add project item
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: ProjectItemWidget(
            project: projects[i], 
            isDesktop: isDesktop,
          ),
        ),
      );
      
      // Add drop zone after each project (except the last one)
      if (i < projects.length - 1) {
        widgets.add(ReorderDropZone(
          targetDomain: null, // No domain
          insertIndex: i + 1,
          onProjectReorder: (dragData, insertIndex) => _handleProjectReorder(context, ref, dragData, insertIndex),
        ));
      }
    }
    
    // Add final drop zone at the end
    widgets.add(ReorderDropZone(
      targetDomain: null, // No domain
      insertIndex: projects.length,
      onProjectReorder: (dragData, insertIndex) => _handleProjectReorder(context, ref, dragData, insertIndex),
    ));
    
    return widgets;
  }

  /// Handle reordering a project within the no-domain section
  void _handleProjectReorder(BuildContext context, WidgetRef ref, ProjectDragData dragData, int insertIndex) async {
    try {
      AppLogger.info('NoDomainSection: Reordering project ${dragData.project.displayName} to index $insertIndex');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.reorderProject(dragData.project.path, insertIndex);
      
      AppLogger.info('NoDomainSection: Successfully reordered project ${dragData.project.displayName}');
    } catch (e) {
      AppLogger.error('NoDomainSection: Failed to reorder project ${dragData.project.displayName}: $e');
      
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get projects in custom order for projects without domain
  Future<List<TaskCalendar>> _getCustomOrderedProjectsWithoutDomain(WidgetRef ref) async {
    final userRepository = ref.read(userRepositoryProvider);
    final preferencesResult = await userRepository.getUserPreferences();
    
    return preferencesResult.when(
      success: (preferences) {
        final projectOrder = preferences.projectOrder;
        final noDomainProjects = projects;
        
        if (projectOrder.isEmpty) {
          // No custom order defined, return projects sorted by name
          final sorted = List<TaskCalendar>.from(noDomainProjects);
          sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
          return sorted;
        }
        
        // Apply user-defined ordering for projects without domain
        final orderedProjects = <TaskCalendar>[];
        final unorderedProjects = <TaskCalendar>[];
        
        // Add projects in user-defined order (only those without domain)
        for (final projectPath in projectOrder) {
          final project = noDomainProjects.cast<TaskCalendar?>().firstWhere(
            (p) => p?.path == projectPath,
            orElse: () => null,
          );
          if (project != null) {
            orderedProjects.add(project);
          }
        }
        
        // Add any projects without domain that aren't in the user order
        for (final project in noDomainProjects) {
          if (!projectOrder.contains(project.path)) {
            unorderedProjects.add(project);
          }
        }
        
        // Sort unordered projects by name and append to the end
        unorderedProjects.sort((a, b) => a.displayName.compareTo(b.displayName));
        
        return [...orderedProjects, ...unorderedProjects];
      },
      failure: (failure) {
        AppLogger.error('NoDomainSection: Failed to get user preferences for ordering', failure.exception, failure.stackTrace);
        // Fallback to name sorting
        final sorted = List<TaskCalendar>.from(projects);
        sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
        return sorted;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<ProjectDragData>(
      onWillAcceptWithDetails: (details) {
        // Only accept projects from domains (for removing from domain, not reordering)
        final draggedFromDomain = details.data.currentDomain;
        return draggedFromDomain != null; // Only accept projects that have a domain
      },
      onAcceptWithDetails: (details) => _handleProjectDrop(context, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Projects without domain
            if (projects.isNotEmpty) ...[
              _buildReorderableProjectList(context, ref),
            ],
            
            // Drop zone for removing projects from domains - only show when dragging
            if (isHovering) 
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Drop here to remove from domain',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Separator
            if (showSeparator) 
              const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// Handle dropping a project to remove it from its current domain
  void _handleProjectDrop(BuildContext context, ProjectDragData dragData) async {
    // Don't move if project is already without domain
    if (dragData.currentDomain == null) {
      AppLogger.info('NoDomainSection: Project ${dragData.project.displayName} already has no domain');
      return;
    }

    try {
      AppLogger.info('NoDomainSection: Removing project ${dragData.project.displayName} from domain ${dragData.currentDomain}');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.assignDomainToProject(dragData.project.path, null);
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${dragData.project.displayName}" from "${dragData.currentDomain}" domain'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
      
      AppLogger.info('NoDomainSection: Successfully removed project ${dragData.project.displayName} from domain');
    } catch (e) {
      AppLogger.error('NoDomainSection: Failed to remove project ${dragData.project.displayName} from domain: $e');
      
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove project from domain: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}