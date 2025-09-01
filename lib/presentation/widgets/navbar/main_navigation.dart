// Main navigation component for FlowIt
// Displays primary navigation destinations with proper highlighting
// Supports drag and drop of tasks from project detail views

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../adaptive_app_layout.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:towdow_app/data/providers/providers_services_core.dart';
import 'package:towdow_app/data/providers/providers_project.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/models/task.dart';
import '../../../core/logger.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({
    super.key,
    required this.currentDestination,
    required this.isDesktop,
    required this.onDetailPressed,
    this.isIconOnly = false,
  });

  final AppDestination? currentDestination;
  final bool isDesktop;
  final void Function({bool? isWorkflow}) onDetailPressed;
  final bool isIconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    // Compute notifications for Projects/Workflows tabs
    final calendarsAsync = ref.watch(activeCalendarListProvider);
    final hasProjectAck = calendarsAsync.maybeWhen(
      data: (cals) {
        for (final cal in cals) {
          final notif = ref.watch(projectSharedNotificationProvider(cal.uid));
          if (notif.maybeWhen(data: (v) => v, orElse: () => false)) {
            return true;
          }
        }
        return false;
      },
      orElse: () => false,
    );
    final hasWorkflowAck = calendarsAsync.maybeWhen(
      data: (cals) {
        for (final cal in cals) {
          final isWorkflow = (cal.flowitType.toUpperCase() == 'WORKFLOW') || cal.flowitAsFlow;
          if (!isWorkflow) continue;
          final notif = ref.watch(projectSharedNotificationProvider(cal.uid));
          if (notif.maybeWhen(data: (v) => v, orElse: () => false)) {
            return true;
          }
        }
        return false;
      },
      orElse: () => false,
    );

    final List<_NavItem> items = [
      _NavItem(
        label: l10n.myTasks,
        icon: Icons.task_alt_rounded,
        route: '/today',
        isSelected: (d) => isDesktop && (d == AppDestination.today || d == AppDestination.soon || d == AppDestination.anytime),
      ),
      _NavItem(
        label: l10n.myWorkflows,
        icon: Icons.route_rounded,
        route: '/workflows',
        isSelected: (d) => isDesktop && d == AppDestination.workflows,
        showBadge: hasWorkflowAck,
      ),
      _NavItem(
        label: l10n.myProjects,
        icon: Icons.folder_rounded,
        route: '/projects',
        isSelected: (d) => isDesktop && d == AppDestination.projects,
        showBadge: hasProjectAck,
      ),
    ];

    return Center(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
        final item = items[index];
        final bool selected = item.isSelected(currentDestination);
        final borderRadius = isDesktop ? BorderRadius.circular(12) : BorderRadius.zero;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: borderRadius,
              child: _HoverableNavItem(
              item: item,
              selected: selected,
              borderRadius: borderRadius,
              onDetailPressed: onDetailPressed,
              onTap: () {
                context.go(item.route);
                if (!isDesktop) {
                  final closeDrawer = ref.read(drawerControllerProvider);
                  closeDrawer?.call();
                }
              },
              isIconOnly: isIconOnly,
            ),
          ),
        );
      },
      ),
    );
  }
} 

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isSelected,
    this.showBadge,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool Function(AppDestination?) isSelected;
  final bool? showBadge;
}

class _HoverableNavItem extends StatefulWidget {
  const _HoverableNavItem({
    required this.item,
    required this.selected,
    required this.borderRadius,
    required this.onDetailPressed,
    required this.onTap,
    this.isIconOnly = false,
  });

  final _NavItem item;
  final bool selected;
  final BorderRadius borderRadius;
  final void Function({bool? isWorkflow}) onDetailPressed;
  final VoidCallback onTap;
  final bool isIconOnly;

  @override
  State<_HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<_HoverableNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Check if this item supports task drops (Projects or Workflows)
    final supportsTaskDrops = widget.item.route == '/projects' || widget.item.route == '/workflows';
    
    Widget navItem = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: ListTile(
        leading: Icon(
          widget.item.icon,
          color: widget.selected
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: widget.isIconOnly ? null : Row(
          children: [
            Expanded(
              child: Text(
                widget.item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: widget.selected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.item.showBadge == true)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        trailing: widget.isIconOnly ? null : (supportsTaskDrops && _isHovered
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    // Pass the context based on which navigation item this is
                    final isWorkflow = widget.item.route == '/workflows';
                    widget.onDetailPressed(isWorkflow: isWorkflow);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: widget.selected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : null),
        onTap: widget.onTap,
        contentPadding: widget.isIconOnly ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: widget.isIconOnly ? 0 : null,
        visualDensity: widget.isIconOnly ? VisualDensity.compact : VisualDensity.standard,
        shape: RoundedRectangleBorder(
          borderRadius: widget.borderRadius,
        ),
      ),
    );

    // Wrap with DragTarget if this item supports task drops
    if (supportsTaskDrops) {
      return DragTarget<Task>(
        onAcceptWithDetails: (details) => _handleTaskDrop(context, details.data),
        builder: (context, candidateData, rejectedData) {
          final isHoveringWithTask = candidateData.isNotEmpty;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
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
            child: navItem,
          );
        },
      );
    }

    return navItem;
  }

  /// Handle dropping a task onto this navigation item
  void _handleTaskDrop(BuildContext context, Task task) async {
    try {
      // Navigate to the detail view for this section
      if (widget.item.route == '/projects') {
        // Navigate to projects detail view
        widget.onDetailPressed(isWorkflow: false);
      } else if (widget.item.route == '/workflows') {
        // Navigate to workflows detail view
        widget.onDetailPressed(isWorkflow: true);
      }
      
      // Show feedback that user should select a specific project/workflow
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Select a specific ${widget.item.label.toLowerCase().replaceAll('my', '')} to move the task'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('MainNavigation: Error handling task drop: $e');
    }
  }
}






