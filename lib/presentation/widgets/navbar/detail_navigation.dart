// Detail navigation widget for sidebar
// Shows projects grouped by domain when on project/workflow detail screens
// Supports drag and drop of tasks from project detail views

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../core/logger.dart';
import '../../../core/theme/chart_theme_usage.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../viewmodels/project_list_viewmodel.dart';
import 'project_item_widget.dart';

class DetailNavigation extends ConsumerWidget {
  const DetailNavigation({
    super.key,
    required this.isDesktop,
    required this.onBackPressed,
    this.isIconOnly = false,
    this.isWorkflowDetail,
  });

  final bool isDesktop;
  final VoidCallback onBackPressed;
  final bool isIconOnly;
  final bool? isWorkflowDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine if we're on a workflow detail screen
    final location = GoRouterState.of(context).uri.path;
    final isWorkflowDetail = location.startsWith('/workflow/') || 
                            this.isWorkflowDetail == true;
    
    // Use the appropriate ProjectListViewModel based on context
    final projectListViewModel = ref.watch(
      isWorkflowDetail ? workflowListViewModelProvider.notifier : projectListViewModelProvider.notifier
    );
    final projectListState = ref.watch(
      isWorkflowDetail ? workflowListViewModelProvider : projectListViewModelProvider
    );
    
    // Initialize the ViewModel if needed
    if (projectListState.projects.isEmpty && !projectListState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        projectListViewModel.initialize();
      });
    }
    
    return _ProjectListContent(
      state: projectListState,
      isDesktop: isDesktop,
      isWorkflowDetail: isWorkflowDetail,
      onBackPressed: onBackPressed,
      isWorkflowDetailOverride: this.isWorkflowDetail,
    );
  }


}

class _ProjectListContent extends ConsumerStatefulWidget {
  const _ProjectListContent({
    required this.state,
    required this.isDesktop,
    required this.isWorkflowDetail,
    required this.onBackPressed,
    this.isWorkflowDetailOverride,
  });

  final ProjectListState state;
  final bool isDesktop;
  final bool isWorkflowDetail;
  final VoidCallback onBackPressed;
  final bool? isWorkflowDetailOverride;

  @override
  ConsumerState<_ProjectListContent> createState() => _ProjectListContentState();
}

class _ProjectListContentState extends ConsumerState<_ProjectListContent> {
  // Memoized domain groups to prevent unnecessary recalculations
  late Map<String, List<TaskCalendar>> _domainGroups;
  late List<String> _sortedDomains;
  
  @override
  void initState() {
    super.initState();
    _updateDomainGroups();
  }
  
  @override
  void didUpdateWidget(_ProjectListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only recalculate if state actually changed
    if (oldWidget.state != widget.state) {
      _updateDomainGroups();
    }
  }
  
  void _updateDomainGroups() {
    // Use the ViewModel's domain groups instead of recalculating
    final domainGroups = <String, List<TaskCalendar>>{};
    
    // Convert ProjectWithStats to TaskCalendar and group by domain
    for (final domainGroup in widget.state.domainGroups) {
      final projects = domainGroup.projects.map((p) => p.project).toList();
      domainGroups[domainGroup.domain] = projects;
    }
    
    _domainGroups = domainGroups;
    _sortedDomains = widget.state.domainGroups.map((dg) => dg.domain).toList();
    
    // Debug logging to help troubleshoot
    AppLogger.info('Domain groups updated: ${domainGroups.keys.toList()}');
    AppLogger.info('Sorted domains: $_sortedDomains');
    AppLogger.info('Projects without domain: ${domainGroups['No Domain']?.length ?? 0}');
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging to help troubleshoot
    AppLogger.info('Building ProjectListContent with ${_domainGroups.length} domain groups');
    AppLogger.info('Domain groups: ${_domainGroups.keys.toList()}');
    AppLogger.info('Sorted domains: $_sortedDomains');
    
    if (_domainGroups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No items found'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with return button (entire header is clickable)
            InkWell(
              onTap: widget.onBackPressed,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Return icon (no longer a button)
                    Icon(
                      Icons.chevron_left,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    // Title
                    Expanded(
                      child: Text(
                        widget.isWorkflowDetail 
                            ? AppLocalizations.of(context)!.workflows 
                            : AppLocalizations.of(context)!.projects,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // All projects grouped by domain (including "No Domain")
            ..._sortedDomains.map((domain) => RepaintBoundary(
              child: _DomainSection(
                key: ValueKey('domain_$domain'), // Stable key to preserve widget identity
                domain: domain,
                projects: _domainGroups[domain] ?? [],
                isDesktop: widget.isDesktop,
                isWorkflowDetail: widget.isWorkflowDetail,
                isWorkflowDetailOverride: widget.isWorkflowDetailOverride,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ProjectListItem extends ConsumerWidget {
  const _ProjectListItem({
    required this.project,
    required this.isDesktop,
    required this.isWorkflowDetail,
    this.isIndented = true,
  });

  final TaskCalendar project;
  final bool isDesktop;
  final bool isWorkflowDetail;
  final bool isIndented;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the ProjectItemWidget which includes draggable functionality
    return ProjectItemWidget(
      project: project,
      enableDragDrop: true,
      isDesktop: isDesktop,
    );
  }


}

class _DomainHeader extends ConsumerWidget {
  const _DomainHeader({
    required this.title,
    required this.isExpanded,
    this.onTap,
    required this.isDesktop,
    this.projects = const [],
    this.isWorkflowDetail = false,
    this.isWorkflowDetailOverride,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback? onTap;
  final bool isDesktop;
  final List<TaskCalendar> projects;
  final bool isWorkflowDetail;
  final bool? isWorkflowDetailOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = isDesktop ? BorderRadius.circular(8) : BorderRadius.zero;
    
    // Check if any project in this domain is active
    final hasActiveProject = projects.any((project) {
      final currentLocation = GoRouterState.of(context).uri.path;
      final projectRoute = isWorkflowDetail 
          ? '/workflow/${Uri.encodeComponent(project.path)}'
          : '/project/${Uri.encodeComponent(project.path)}';
      return currentLocation == projectRoute;
    });
    
    final domainWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.domainNameStyle.copyWith(
                      color: hasActiveProject 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: hasActiveProject ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (onTap != null) Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap with DragTarget to accept both task and project drops
    return DragTarget<Object>(
      onAcceptWithDetails: (details) {
        if (details.data is Task) {
          _handleTaskDrop(context, ref, details.data as Task);
        } else if (details.data is TaskCalendar) {
          _handleProjectDrop(context, ref, details.data as TaskCalendar);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHoveringWithTask = candidateData.any((data) => data is Task);
        final isHoveringWithProject = candidateData.any((data) => data is TaskCalendar);
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: isHoveringWithTask 
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    width: 2,
                  )
                : isHoveringWithProject
                    ? Border.all(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                        width: 2,
                      )
                    : null,
            color: isHoveringWithTask 
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : isHoveringWithProject
                    ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
          ),
          child: domainWidget,
        );
      },
    );
  }

  /// Handle dropping a task onto this domain header
  void _handleTaskDrop(BuildContext context, WidgetRef ref, Task task) async {
    // Do nothing when dropping on domain header
    AppLogger.info('DomainHeader: Task ${task.summary} dropped on domain $title - no action taken');
  }

  /// Handle dropping a project onto this domain header
  void _handleProjectDrop(BuildContext context, WidgetRef ref, TaskCalendar project) async {
    // Don't move if project is already in this domain
    if (project.flowitDomain == title) {
      AppLogger.info('DomainHeader: Project ${project.displayName} is already in domain $title');
      return;
    }

    try {
      AppLogger.info('DomainHeader: Moving project ${project.displayName} to domain $title');
      
      // Use the existing ProjectListViewModel assignDomainToProject functionality
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.assignDomainToProject(project.path, title);
      
      AppLogger.info('DomainHeader: Successfully moved project ${project.displayName} to domain $title');
    } catch (e) {
      AppLogger.error('DomainHeader: Failed to move project ${project.displayName} to domain $title: $e');
      
      // Show error feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move project: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }




}

class _DomainSection extends ConsumerStatefulWidget {
  const _DomainSection({
    super.key,
    required this.domain,
    required this.projects,
    required this.isDesktop,
    required this.isWorkflowDetail,
    this.isWorkflowDetailOverride,
  });

  final String domain;
  final List<TaskCalendar> projects;
  final bool isDesktop;
  final bool isWorkflowDetail;
  final bool? isWorkflowDetailOverride;

  @override
  ConsumerState<_DomainSection> createState() => _DomainSectionState();
}

class _DomainSectionState extends ConsumerState<_DomainSection> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isExpanded = true;
  bool _isAnimating = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  
  @override
  bool get wantKeepAlive => true; // Preserve widget state during rebuilds

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start expanded
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    if (_isAnimating) return; // Prevent multiple animations
    
    setState(() {
      _isExpanded = !_isExpanded;
      _isAnimating = true;
      
      if (_isExpanded) {
        _animationController.forward().then((_) => _isAnimating = false);
      } else {
        _animationController.reverse().then((_) => _isAnimating = false);
      }
    });
  }

  bool _isProjectActive(TaskCalendar project) {
    final currentLocation = GoRouterState.of(context).uri.path;
    final projectRoute = widget.isWorkflowDetail 
        ? '/workflow/${Uri.encodeComponent(project.path)}'
        : '/project/${Uri.encodeComponent(project.path)}';
    final isActive = currentLocation == projectRoute;
    
    // Debug logging
    if (isActive) {
      AppLogger.info('Project ${project.displayName} is ACTIVE. Current: $currentLocation, Route: $projectRoute');
    }
    
    return isActive;
  }

    /// Handle dropping a project onto this domain section
  void _handleProjectDrop(BuildContext context, WidgetRef ref, TaskCalendar project) async {
    // Don't move if project is already in this domain
    if (project.flowitDomain == widget.domain) {
      AppLogger.info('DomainSection: Project ${project.displayName} is already in domain ${widget.domain}');
      return;
    }

    try {
      AppLogger.info('DomainSection: Moving project ${project.displayName} to domain ${widget.domain}');
      
      // Use the existing ProjectListViewModel assignDomainToProject functionality
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.assignDomainToProject(project.path, widget.domain);
      
      AppLogger.info('DomainSection: Successfully moved project ${project.displayName} to domain ${widget.domain}');
    } catch (e) {
      AppLogger.error('DomainSection: Failed to move project ${project.displayName} to domain ${widget.domain}: $e');
      
      // Show error feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move project: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Wrap the entire domain section with DragTarget for project drops
    return DragTarget<ProjectDragData>(
      onAcceptWithDetails: (details) => _handleProjectDrop(context, ref, details.data.project),
      builder: (context, candidateData, rejectedData) {
        final isHoveringWithProject = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isHoveringWithProject 
                ? Border.all(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                    width: 2,
                  )
                : null,
            color: isHoveringWithProject 
                ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Domain header with expand/collapse
              _DomainHeader(
                title: widget.domain,
                isExpanded: _isExpanded,
                onTap: _toggleExpanded,
                isDesktop: widget.isDesktop,
                projects: widget.projects,
                isWorkflowDetail: widget.isWorkflowDetail,
                isWorkflowDetailOverride: widget.isWorkflowDetailOverride,
              ),
              
              // Projects list with conditional animation
              if (_isExpanded) ...[
                // Use AnimatedBuilder only when needed to reduce rebuilds
                AnimatedBuilder(
                  animation: _heightAnimation,
                  builder: (context, child) {
                    return SizeTransition(
                      sizeFactor: _heightAnimation,
                      child: Stack(
                        children: [
                          // Continuous vertical line
                          if (widget.projects.isNotEmpty)
                            Positioned(
                              left: 24.0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          // Project items with active line segments
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...widget.projects.asMap().entries.map((entry) {
                                final project = entry.value;
                                final isActive = _isProjectActive(project);
                                
                                return Stack(
                                  key: ValueKey(project.path), // Stable key for Flutter optimization
                                  children: [
                                    // Active line segment overlay
                                    if (isActive)
                                      Positioned(
                                        left: 24.0, // Align with the main line
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 2,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(1),
                                          ),
                                        ),
                                      ),
                                    // Project item
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0),
                                      child: _ProjectListItem(
                                        project: project,
                                        isDesktop: widget.isDesktop,
                                        isWorkflowDetail: widget.isWorkflowDetail,
                                        isIndented: false, // No individual indentation since we have the line
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
