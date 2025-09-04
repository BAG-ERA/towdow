// Project item widget for sidebar navigation with domain management menu and drag & drop support
// Displays individual project with options to move to domain, delete, archive, and drag to other domains

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/logger.dart';
import '../../../core/result.dart';
import '../../../data/providers/providers.dart';
import '../adaptive_app_layout.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../utils/popup/move_to_domain_dialog.dart';
import '../utils/popup/project_sharing_dialog.dart';
import '../utils/mobile_delayed_draggable_project.dart';
import 'drag_state_provider.dart';
import 'project_popup_menu.dart';

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
    // Only show selected state on desktop, not on mobile
    final isSelected = widget.isDesktop && GoRouterState.of(context).uri.path == '/project/${Uri.encodeComponent(widget.project.path)}';
    
    // Calculate percentage completed for this project using project-specific provider
    final projectTasksAsync = ref.watch(projectTasksProvider(widget.project.path));
    final completionData = projectTasksAsync.when(
      data: (tasks) {
        final totalTasks = tasks.length;
        final completedTasks = tasks.where((task) => task.status == 'COMPLETED').length;
        final percentage = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;
        return {'total': totalTasks, 'percentage': percentage};
      },
      loading: () => {'total': 0, 'percentage': 0},
      error: (_, _) => {'total': 0, 'percentage': 0},
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
                AppLogger.info('ProjectItem: Navigating to project ${widget.project.path} (${widget.project.displayName})');
                context.go('/project/${Uri.encodeComponent(widget.project.path)}');
                // Close drawer on mobile using provided controller
                if (!widget.isDesktop) {
                  final closeDrawer = ref.read(drawerControllerProvider);
                  closeDrawer?.call();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    /* Not sure to use this, TODO decidehow we let user know object is draggable
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
                    */
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.project.displayName,
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
                          
                          // New shared project notification icon
                          Consumer(
                            builder: (context, ref, child) {
                              final notificationAsync = ref.watch(projectSharedNotificationProvider(widget.project.uid));
                              
                              return notificationAsync.when(
                                data: (hasNotification) {
                                  if (!hasNotification) return const SizedBox.shrink();
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                
                    const SizedBox(width: 8),
                    
                    // Completion percentage badge
                    if (completionData['total']! > 0) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${completionData['percentage']}%',
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
                        child: ProjectPopupMenu(
                          onMenuAction: (value) => _handleMenuAction(context, value),
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

    // Wrap with DragTarget to accept tasks, then Draggable for project drag
    return DragTarget<Task>(
      onAcceptWithDetails: (details) => _handleTaskDrop(context, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHoveringWithTask = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isHoveringWithTask 
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    width: 2,
                  )
                : null,
            color: isHoveringWithTask 
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: MobileDelayedDraggableProject(
            project: widget.project,
            feedback: _buildDragFeedback(context),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: projectWidget,
            ),
            onDragStarted: () {
              AppLogger.info('ProjectItem: Started dragging project ${widget.project.displayName}');
              // Notify global drag state
              ref.read(dragStateProvider.notifier).startDragging(widget.project.flowitDomain);
              // Provide haptic feedback
              HapticFeedback.lightImpact();
            },
            onDragEnd: (details) {
              AppLogger.info('ProjectItem: Ended dragging project ${widget.project.displayName}');
              // Stop global drag state
              ref.read(dragStateProvider.notifier).stopDragging();
            },
            child: projectWidget,
          ),
        );
      },
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
      items: ProjectPopupMenu.getMenuItems(context, ref),
    );
    
    if (result != null) {
      _handleMenuAction(context, result);
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'move_to_domain':
        _showMoveToDomainDialog(context);
        break;
      case 'share_project':
        _showProjectSharingDialog(context);
        break;
      case 'archive_project':
        _handleArchiveProject(context);
        break;
      case 'delete_project':
        _showDeleteConfirmation(context);
        break;
      case 'copy_path':
        _copyProjectPath(context);
        break;
    }
  }

  void _showMoveToDomainDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MoveToDomainDialog(project: widget.project),
    );
  }

  void _showProjectSharingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ProjectSharingDialog(project: widget.project),
    );
  }

  void _handleArchiveProject(BuildContext context) async {
    try {
      AppLogger.info('ProjectItem: Archiving project ${widget.project.path} (${widget.project.displayName})');
      
      // Get the status service from providers
      final statusService = ref.read(statusServiceProvider);
      
      // Archive the project
      final result = await statusService.archiveCalendar(widget.project.path);
      
      result.when(
        success: (_) {
          // Navigate away from project if currently viewing it
          final currentRoute = GoRouterState.of(context).uri.path;
          if (currentRoute == '/project/${Uri.encodeComponent(widget.project.path)}') {
            AppLogger.info('ProjectItem: Navigating away from archived project');
            context.go('/');
          }
          
          AppLogger.info('ProjectItem: Successfully archived project ${widget.project.path}');
        },
        failure: (failure) {
          AppLogger.error('ProjectItem: Failed to archive project: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('ProjectItem: Failed to archive project: $e');
    }
  }

  void _handleUnarchiveProject(BuildContext context) async {
    try {
      // Get the status service from providers
      final statusService = ref.read(statusServiceProvider);
      
      // Unarchive the project
      final result = await statusService.unarchiveCalendar(widget.project.path);
      
      result.when(
        success: (_) {
          // Project unarchived successfully - no notification needed
        },
        failure: (failure) {
          AppLogger.error('Failed to unarchive project: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Failed to unarchive project: $e');
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${widget.project.displayName}"? This action cannot be undone and will remove all associated tasks.',
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
      AppLogger.info('ProjectItem: Deleting project ${widget.project.path} (${widget.project.displayName})');
      
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      await projectListViewModel.deleteProject(widget.project.path);
      
      // Navigate away from project if currently viewing it
      final currentRoute = GoRouterState.of(context).uri.path;
      if (currentRoute == '/project/${Uri.encodeComponent(widget.project.path)}') {
        AppLogger.info('ProjectItem: Navigating away from deleted project');
        context.go('/');
      }
      
      // Project deleted successfully - no notification needed
      
      AppLogger.info('ProjectItem: Successfully deleted project ${widget.project.path}');
    } catch (e) {
      AppLogger.error('ProjectItem: Failed to delete project ${widget.project.path}: $e');
    }
  }

  /// Build drag feedback widget that follows the cursor during drag
  /// Handle dropping a task onto this project to move it
  void _handleTaskDrop(BuildContext context, Task task) async {
    // Encode project path to match task storage format
    final encodedProjectPath = widget.project.path.replaceAll('@', '%40');
    
    // Don't move if task is already in this project
    if (task.projectPath == encodedProjectPath) {
      AppLogger.info('ProjectItem: Task ${task.summary} is already in project ${widget.project.displayName}');
      return;
    }

    try {
      AppLogger.info('ProjectItem: Moving task ${task.summary} to project ${widget.project.displayName}');
      
      // Use the existing TaskViewModel moveTask functionality
      final taskViewModel = ref.read(taskViewModelProvider.notifier);
      await taskViewModel.moveTask(task, widget.project.path);
      
      // Task moved successfully - no notification needed
      
      AppLogger.info('ProjectItem: Successfully moved task ${task.summary} to project ${widget.project.displayName}');
    } catch (e) {
      AppLogger.error('ProjectItem: Failed to move task ${task.summary} to project ${widget.project.displayName}: $e');
    }
  }

  void _copyProjectPath(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.project.path));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Project path copied: ${widget.project.path}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                widget.project.displayName,
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

 