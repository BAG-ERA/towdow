// Projects section widget for displaying synchronized calendar projects in sidebar
// Shows projects grouped by domain with expandable domain sections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/logger.dart';
import '../../../core/theme/chart_theme_usage.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task_calendar.dart';
import 'project_item_widget.dart';

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
    // Use projectListState as key to rebuild when state changes
    final projectListState = ref.watch(projectListViewModelProvider);
    return FutureBuilder<List<String>>(
      key: ValueKey(projectListState.hashCode),
      future: _getAllAvailableDomains(ref),
      builder: (context, domainsSnapshot) {
        List<String> allDomains = [];
        
        if (domainsSnapshot.hasData) {
          allDomains = domainsSnapshot.data!;
          // Add empty domains to domainGroups
          for (final domain in allDomains) {
            domainGroups.putIfAbsent(domain, () => []);
          }
        } else {
          // Fallback to domains that have projects
          allDomains = domainGroups.keys.toList();
        }
        
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
      },
    );
  }
  
  Future<List<String>> _getAllAvailableDomains(WidgetRef ref) async {
    try {
      final domainService = ref.read(domainServiceProvider);
      final result = await domainService.getAvailableDomains();
      return result.when(
        success: (domains) => domains,
        failure: (failure) => <String>[],
      );
    } catch (e) {
      return <String>[];
    }
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
  bool _isExpanded = true; // Domains start expanded by default

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
          await projectListViewModel.assignDomainToProject(project.uid, null);
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

  /// Handle dropping a project onto this domain section
  void _handleProjectDrop(BuildContext context, ProjectDragData dragData) async {
    // Don't move project if it's already in this domain
    if (dragData.currentDomain == widget.domain) {
      AppLogger.info('DomainSection: Project ${dragData.project.summary} already in domain ${widget.domain}');
      return;
    }

    try {
      AppLogger.info('DomainSection: Moving project ${dragData.project.summary} to domain ${widget.domain}');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.assignDomainToProject(dragData.project.uid, widget.domain);
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${dragData.project.summary}" to "${widget.domain}" domain'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      
      AppLogger.info('DomainSection: Successfully moved project ${dragData.project.summary} to domain ${widget.domain}');
    } catch (e) {
      AppLogger.error('DomainSection: Failed to move project ${dragData.project.summary} to domain ${widget.domain}: $e');
      
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
                              if (value == 'delete') {
                                _deleteDomain();
                              }
                            },
                            itemBuilder: (context) => [
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
                    : Column(
                        children: widget.projects.map((project) => 
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: ProjectItemWidget(project: project, isDesktop: widget.isDesktop),
                          )
                        ).toList(),
                      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<ProjectDragData>(
      onAcceptWithDetails: (details) => _handleProjectDrop(context, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Projects without domain
            if (projects.isNotEmpty) ...[
              ...projects.map((project) => 
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: ProjectItemWidget(project: project, isDesktop: this.isDesktop),
                )
              ),
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
      AppLogger.info('NoDomainSection: Project ${dragData.project.summary} already has no domain');
      return;
    }

    try {
      AppLogger.info('NoDomainSection: Removing project ${dragData.project.summary} from domain ${dragData.currentDomain}');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.assignDomainToProject(dragData.project.uid, null);
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${dragData.project.summary}" from "${dragData.currentDomain}" domain'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
      
      AppLogger.info('NoDomainSection: Successfully removed project ${dragData.project.summary} from domain');
    } catch (e) {
      AppLogger.error('NoDomainSection: Failed to remove project ${dragData.project.summary} from domain: $e');
      
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