// Detail navigation widget for sidebar
// Shows projects grouped by domain when on project/workflow detail screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/logger.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task_calendar.dart';
import '../adaptive_app_layout.dart';

class DetailNavigation extends ConsumerWidget {
  const DetailNavigation({
    super.key,
    required this.isDesktop,
    required this.onBackPressed,
  });

  final bool isDesktop;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine if we're on a workflow detail screen
    final location = GoRouterState.of(context).uri.path;
    final isWorkflowDetail = location.startsWith('/workflow/');
    
    final projectsAsync = ref.watch(projectListProvider);
    
    return projectsAsync.when(
      data: (projects) => _ProjectListContent(
        projects: projects.cast<TaskCalendar>(),
        isDesktop: isDesktop,
        isWorkflowDetail: isWorkflowDetail,
        onBackPressed: onBackPressed,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading projects: $error'),
      ),
    );
  }


}

class _ProjectListContent extends ConsumerStatefulWidget {
  const _ProjectListContent({
    required this.projects,
    required this.isDesktop,
    required this.isWorkflowDetail,
    required this.onBackPressed,
  });

  final List<TaskCalendar> projects;
  final bool isDesktop;
  final bool isWorkflowDetail;
  final VoidCallback onBackPressed;

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
    // Only recalculate if projects actually changed
    if (oldWidget.projects != widget.projects) {
      _updateDomainGroups();
    }
  }
  
  void _updateDomainGroups() {
    // Filter based on whether we're on workflow or project detail
    final filteredProjects = widget.isWorkflowDetail 
        ? widget.projects.where((p) => p.flowitAsFlow == true || p.flowitType.toUpperCase() == 'WORKFLOW').toList()
        : widget.projects.where((p) => !(p.flowitAsFlow == true || p.flowitType.toUpperCase() == 'WORKFLOW')).toList();
    
    // Group projects by domain (including "No Domain" as a special domain)
    final domainGroups = <String, List<TaskCalendar>>{};
    
    for (final project in filteredProjects) {
      final domain = project.hasDomain ? project.flowitDomain! : 'No Domain';
      domainGroups.putIfAbsent(domain, () => []).add(project);
    }
    
    // Get all available domains and sort them, ensuring "No Domain" appears first
    final availableDomainsAsync = ref.read(availableDomainsProvider);
    final allDomains = availableDomainsAsync.when(
      data: (domains) => domains,
      loading: () => domainGroups.keys.toList(),
      error: (error, stackTrace) => domainGroups.keys.toList(),
    );
    
    // Always start with the domains we actually have projects for
    final domainsToShow = <String>{...domainGroups.keys};
    
    // Add any additional domains from the provider that we don't have projects for yet
    for (final domain in allDomains) {
      if (!domainsToShow.contains(domain)) {
        domainsToShow.add(domain);
      }
    }
    
    // Sort domains with "No Domain" first, then alphabetically
    final sortedDomains = domainsToShow.toList()..sort((a, b) {
      if (a == 'No Domain') return -1;
      if (b == 'No Domain') return 1;
      return a.compareTo(b);
    });
    
    _domainGroups = domainGroups;
    _sortedDomains = sortedDomains;
    
    // Debug logging to help troubleshoot
    AppLogger.info('Domain groups updated: ${domainGroups.keys.toList()}');
    AppLogger.info('Sorted domains: $sortedDomains');
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
                        widget.isWorkflowDetail ? 'Workflows' : 'Projects',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
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
    final borderRadius = isDesktop ? BorderRadius.circular(8) : BorderRadius.zero;
    
    // Check if this item is currently active
    final currentLocation = GoRouterState.of(context).uri.path;
    final projectRoute = isWorkflowDetail 
        ? '/workflow/${Uri.encodeComponent(project.path)}'
        : '/project/${Uri.encodeComponent(project.path)}';
    final isActive = currentLocation == projectRoute;
    
    return Material(
      color: isActive 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          AppLogger.info('ProjectItem: Navigating to project ${project.path} (${project.displayName})');
          final route = isWorkflowDetail 
              ? '/workflow/${Uri.encodeComponent(project.path)}'
              : '/project/${Uri.encodeComponent(project.path)}';
          context.go(route);
          if (!isDesktop) {
            final closeDrawer = ref.read(drawerControllerProvider);
            closeDrawer?.call();
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: isIndented ? 32.0 : 16.0,
            right: 16.0,
            top: 4.0,
            bottom: 4.0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  project.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            ],
          ),
        ),
      ),
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
  });

  final String title;
  final bool isExpanded;
  final VoidCallback? onTap;
  final bool isDesktop;
  final List<TaskCalendar> projects;
  final bool isWorkflowDetail;

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
    
    return Padding(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
  }
}

class _DomainSection extends ConsumerStatefulWidget {
  const _DomainSection({
    super.key,
    required this.domain,
    required this.projects,
    required this.isDesktop,
    required this.isWorkflowDetail,
  });

  final String domain;
  final List<TaskCalendar> projects;
  final bool isDesktop;
  final bool isWorkflowDetail;

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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Column(
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
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
    );
  }
}
