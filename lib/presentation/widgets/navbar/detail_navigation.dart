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
      data: (projects) => _buildProjectListContent(context, ref, projects.cast<TaskCalendar>(), isDesktop, isWorkflowDetail),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading projects: $error'),
      ),
    );
  }

  Widget _buildProjectListContent(BuildContext context, WidgetRef ref, List<TaskCalendar> projects, bool isDesktop, bool isWorkflowDetail) {
    // Filter based on whether we're on workflow or project detail
    final filteredProjects = isWorkflowDetail 
        ? projects.where((p) => p.flowitAsFlow == true || p.flowitType.toUpperCase() == 'WORKFLOW').toList()
        : projects.where((p) => !(p.flowitAsFlow == true || p.flowitType.toUpperCase() == 'WORKFLOW')).toList();
    
    if (filteredProjects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No items found'),
        ),
      );
    }

    // Group projects by domain
    final projectsWithoutDomain = filteredProjects.where((project) => !project.hasDomain).toList();
    final domainGroups = <String, List<TaskCalendar>>{};
    
    for (final project in filteredProjects.where((project) => project.hasDomain)) {
      final domain = project.flowitDomain!;
      domainGroups.putIfAbsent(domain, () => []).add(project);
    }
    
    // Get all available domains and sort them
    final availableDomainsAsync = ref.watch(availableDomainsProvider);
    final allDomains = availableDomainsAsync.when(
      data: (domains) => domains,
      loading: () => domainGroups.keys.toList(),
      error: (error, stackTrace) => domainGroups.keys.toList(),
    );
    
    final sortedDomains = allDomains..sort();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with return button (entire header is clickable)
            InkWell(
              onTap: onBackPressed,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Return icon (no longer a button)
                    Icon(
                      Icons.arrow_back_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    // Title
                    Expanded(
                      child: Text(
                        isWorkflowDetail ? 'Workflows' : 'Projects',
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
            
            // Projects without domain
            if (projectsWithoutDomain.isNotEmpty) ...[
              _DomainHeader(
                title: 'No Domain',
                isExpanded: true,
                onTap: null, // No toggle for no domain section
                isDesktop: isDesktop,
              ),
              ...projectsWithoutDomain.map((project) => _ProjectListItem(
                project: project,
                isDesktop: isDesktop,
                isWorkflowDetail: isWorkflowDetail,
              )),
              if (sortedDomains.isNotEmpty) const SizedBox(height: 8),
            ],
            
            // Projects grouped by domain
            ...sortedDomains.map((domain) => _DomainSection(
              domain: domain,
              projects: domainGroups[domain] ?? [],
              isDesktop: isDesktop,
              isWorkflowDetail: isWorkflowDetail,
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
  });

  final TaskCalendar project;
  final bool isDesktop;
  final bool isWorkflowDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = isDesktop ? BorderRadius.circular(8) : BorderRadius.zero;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              project.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _DomainHeader extends StatelessWidget {
  const _DomainHeader({
    required this.title,
    required this.isExpanded,
    this.onTap,
    required this.isDesktop,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback? onTap;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final borderRadius = isDesktop ? BorderRadius.circular(8) : BorderRadius.zero;
    
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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

class _DomainSectionState extends ConsumerState<_DomainSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Domain header with expand/collapse
        _DomainHeader(
          title: widget.domain,
          isExpanded: _isExpanded,
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          isDesktop: widget.isDesktop,
        ),
        
        // Projects in this domain (submenu)
        if (_isExpanded) ...[
          ...widget.projects.map((project) => _ProjectListItem(
            project: project,
            isDesktop: widget.isDesktop,
            isWorkflowDetail: widget.isWorkflowDetail,
          )),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}
