// Workflow-specific popup menu for workflow rows

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_calendar.dart';

typedef WorkflowMenuActionCallback = void Function(String action);

class WorkflowPopupMenu extends ConsumerWidget {
  final WorkflowMenuActionCallback onMenuAction;
  final TaskCalendar? project;

  const WorkflowPopupMenu({super.key, required this.onMenuAction, this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 16),
      tooltip: 'Workflow options',
      onSelected: onMenuAction,
      itemBuilder: (BuildContext context) => getMenuItems(context, ref, project: project),
    );
  }

  static List<PopupMenuEntry<String>> getMenuItems(BuildContext context, WidgetRef ref, {TaskCalendar? project}) {
    return [
      PopupMenuItem<String>(
        value: 'convert_to_project',
        child: Row(
          children: [
            Icon(Icons.transform_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('Convert to project'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'move_to_domain',
        child: Row(
          children: [
            Icon(Icons.folder_open, size: 16, color: Theme.of(context).colorScheme.onSurface),
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
              (project?.isArchived ?? false) ? Icons.unarchive : Icons.archive,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text((project?.isArchived ?? false) ? 'Unarchive' : 'Archive'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete_workflow',
        child: Row(
          children: [
            Icon(Icons.delete, size: 16, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      if (kDebugMode) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'copy_path',
          child: Builder(builder: (innerContext) {
            return Row(
              children: const [
                Icon(Icons.copy, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Text('Copy workflow path', style: TextStyle(color: Colors.orange)),
              ],
            );
          }),
        ),
      ],
    ];
  }
}


