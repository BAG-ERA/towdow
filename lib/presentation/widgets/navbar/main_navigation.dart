// Main navigation component for FlowIt
// Displays primary navigation destinations with proper highlighting

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../adaptive_app_layout.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:towdow_app/data/providers/providers_services_core.dart';
import 'package:towdow_app/data/providers/providers_project.dart';
import 'package:towdow_app/data/models/task_calendar.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({
    super.key,
    required this.currentDestination,
    required this.isDesktop,
  });

  final AppDestination? currentDestination;
  final bool isDesktop;

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
            child: ListTile(
              leading: Icon(
                item.icon,
                color: selected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.showBadge == true)
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
              onTap: () {
                context.go(item.route);
                if (!isDesktop) {
                  final closeDrawer = ref.read(drawerControllerProvider);
                  closeDrawer?.call();
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius,
              ),
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






