// Project popup menu widget for project item actions
// Provides menu items for moving to domain, sharing, archiving, and deleting projects

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import '../../../data/models/task_calendar.dart';

/// Callback function type for menu actions
typedef ProjectMenuActionCallback = void Function(String action);

class ProjectPopupMenu extends ConsumerWidget {
  final ProjectMenuActionCallback onMenuAction;

  const ProjectPopupMenu({
    super.key,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      tooltip: 'Project options',
      onSelected: onMenuAction,
      itemBuilder: (BuildContext context) => _buildMenuItems(context, ref),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context, WidgetRef ref) {
    return _buildMenuItemsStatic(context, ref, project: null);
  }

  /// Static method to build menu items for use in context menus
  static List<PopupMenuEntry<String>> _buildMenuItemsStatic(BuildContext context, WidgetRef ref, {TaskCalendar? project}) {
    // Check if current account supports sharing
    final accountAsync = ref.watch(activeAccountProvider);
    final supportsSharing = accountAsync.when(
      data: (account) => account?.providerType == 'towdow_cloud' || account?.providerType == 'towdow_selfhosted',
      loading: () => false,
      error: (_, __) => false,
    );

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
      // Share option - only for TowDow accounts
      if (supportsSharing) ...[
        PopupMenuItem<String>(
          value: 'share_project',
          child: Row(
            children: [
              Icon(
                Icons.share,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Share project',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      PopupMenuItem<String>(
        value: 'archive_project',
        child: Row(
          children: [
            Icon(
              project?.isArchived == true ? Icons.unarchive : Icons.archive,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(project?.isArchived == true ? 'Unarchive project' : 'Archive project'),
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
      // Debug option - only in debug mode
      if (kDebugMode) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'copy_path',
          child: Row(
            children: [
              Icon(
                Icons.copy,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text(
                'Copy project path',
                style: TextStyle(
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  /// Static method to get menu items for context menus
  static List<PopupMenuEntry<String>> getMenuItems(BuildContext context, WidgetRef ref, {TaskCalendar? project}) {
    return _buildMenuItemsStatic(context, ref, project: project);
  }
} 