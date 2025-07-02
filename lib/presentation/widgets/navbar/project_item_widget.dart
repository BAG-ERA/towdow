// Project item widget for sidebar navigation with domain management menu and drag & drop support
// Displays individual project with options to move to domain, delete, archive, and drag to other domains

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/logger.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task_calendar.dart';
import '../utils/popup/move_to_domain_dialog.dart';

/// Data class for drag and drop operations
class ProjectDragData {
  final TaskCalendar project;
  final String? currentDomain;

  const ProjectDragData({
    required this.project,
    this.currentDomain,
  });
}

class ProjectItemWidget extends ConsumerStatefulWidget {
  final TaskCalendar project;
  final bool enableDragDrop;
  final bool isDesktop;

  const ProjectItemWidget({
    super.key,
    required this.project,
    this.enableDragDrop = true,
    this.isDesktop = true,
  });

  @override
  ConsumerState<ProjectItemWidget> createState() => _ProjectItemWidgetState();
}

class _ProjectItemWidgetState extends ConsumerState<ProjectItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = GoRouterState.of(context).uri.path == '/project/${widget.project.uid}';
    
    // Count remaining tasks for this project
    final taskListAsync = ref.watch(taskListProvider);
    final taskCount = taskListAsync.when(
      data: (tasks) => tasks.where((task) {
        return task.status != 'COMPLETED' && task.sourceCalendarUid == widget.project.uid;
      }).length,
      loading: () => 0,
      error: (_, _) => 0,
    );
    
    final projectWidget = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(context, details),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: isSelected 
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: widget.isDesktop ? BorderRadius.circular(8) : BorderRadius.zero,
            child: InkWell(
              borderRadius: widget.isDesktop ? BorderRadius.circular(8) : BorderRadius.zero,
              onTap: () {
                AppLogger.info('ProjectItem: Navigating to project ${widget.project.uid} (${widget.project.summary})');
                context.go('/project/${widget.project.uid}');
                // Close drawer on mobile
                if (Scaffold.of(context).hasDrawer) {
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Drag handle icon
                    if (widget.enableDragDrop)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    
                    Expanded(
                      child: Text(
                        widget.project.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                
                    const SizedBox(width: 8),
                    
                    // Task count badge
                    if (taskCount > 0) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$taskCount',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    
                    const SizedBox(width: 4),
                    
                    // Three-dot menu button - only show on hover
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          tooltip: 'Project options',
                          onSelected: (value) => _handleMenuAction(context, value),
                          itemBuilder: (BuildContext context) => _buildMenuItems(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with Draggable if drag & drop is enabled
    if (!widget.enableDragDrop) {
      return projectWidget;
    }

    return Draggable<ProjectDragData>(
      data: ProjectDragData(
        project: widget.project,
        currentDomain: widget.project.flowitDomain,
      ),
      feedback: _buildDragFeedback(context),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: projectWidget,
      ),
      onDragStarted: () {
        AppLogger.info('ProjectItem: Started dragging project ${widget.project.summary}');
        // Provide haptic feedback
        HapticFeedback.lightImpact();
      },
      onDragEnd: (details) {
        AppLogger.info('ProjectItem: Ended dragging project ${widget.project.summary}');
      },
      child: projectWidget,
    );
  }

  void _showContextMenu(BuildContext context, TapDownDetails details) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: _buildMenuItems(context),
    );
    
    if (result != null) {
      _handleMenuAction(context, result);
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    return [
      PopupMenuItem<String>(
        value: 'move_to_domain',
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            const Text('Move to domain'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'archive_project',
        child: Row(
          children: [
            Icon(
              Icons.archive,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            const Text('Archive project'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete_project',
        child: Row(
          children: [
            Icon(
              Icons.delete,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              'Delete project',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'move_to_domain':
        _showMoveToDomainDialog(context);
        break;
      case 'archive_project':
        _handleArchiveProject(context);
        break;
      case 'delete_project':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showMoveToDomainDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MoveToDomainDialog(project: widget.project),
    );
  }

  void _handleArchiveProject(BuildContext context) async {
    try {
      // Get the status service from providers
      final statusService = ref.read(statusServiceProvider);
      
      // Archive the project
      final result = await statusService.archiveCalendar(widget.project.uid);
      
      result.when(
        success: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${widget.project.summary}" archived successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => _handleUnarchiveProject(context),
              ),
            ),
          );
        },
        failure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive project: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () {},
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to archive project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _handleUnarchiveProject(BuildContext context) async {
    try {
      // Get the status service from providers
      final statusService = ref.read(statusServiceProvider);
      
      // Unarchive the project
      final result = await statusService.unarchiveCalendar(widget.project.uid);
      
      result.when(
        success: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${widget.project.summary}" unarchived successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
        failure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unarchive project: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unarchive project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${widget.project.summary}"? This action cannot be undone and will remove all associated tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteProject(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteProject(BuildContext context) async {
    try {
      AppLogger.info('ProjectItem: Deleting project ${widget.project.uid} (${widget.project.summary})');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.deleteProject(widget.project.uid);
      
      // Navigate away from project if currently viewing it
      final currentRoute = GoRouterState.of(context).uri.path;
      if (currentRoute == '/project/${widget.project.uid}') {
        AppLogger.info('ProjectItem: Navigating away from deleted project');
        context.go('/');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project "${widget.project.summary}" deleted successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
      
      AppLogger.info('ProjectItem: Successfully deleted project ${widget.project.uid}');
    } catch (e) {
      AppLogger.error('ProjectItem: Failed to delete project ${widget.project.uid}: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete project: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Build drag feedback widget that follows the cursor during drag
  Widget _buildDragFeedback(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.project.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

 