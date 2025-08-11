// Task item toolbar component
// Contains all action buttons with vertical layout (icon + text) and dialog handling

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../utils/popup/attendee_dialog.dart';
import '../utils/popup/category_dialog.dart';
import '../utils/popup/due_date_dialog.dart';
import '../utils/popup/move_task_dialog.dart';

class TaskItemToolbar extends ConsumerWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onTaskDeleted;
  // If true, shows a vertical toolbar with icon + text entries.
  final bool vertical;
  // If true in vertical mode, align tiles to the right edge (used when toolbar is on the left side of the card)
  final bool alignRight;

  const TaskItemToolbar({
    super.key,
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
    this.vertical = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always render vertical toolbar
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVerticalAction(
            context: context,
            icon: Icons.calendar_today_rounded,
            label: 'Due date',
            onPressed: () => DueDateDialog.show(
              context,
              task: task,
              onTaskUpdated: onTaskUpdated,
            ),
          ),
          if (_isOrganizer()) _buildVerticalValidatorAction(context, ref),
          _buildVerticalAction(
            context: context,
            icon: Icons.person_add_rounded,
            label: 'Attendee',
            onPressed: () => _showAttendeeDialog(context),
          ),
          _buildVerticalMenu(context),
        ].expand<Widget>((w) => [w, const SizedBox(height: 8)]).toList(),
      ),
    );
  }

  // Secondary actions menu trigger for vertical layout (internal helper)
  // Note: kept for future API parity if needed

  // Vertical variant of 3-dots menu rendered as a labeled row
  Widget _buildVerticalMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: (action) => _handleMenuAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'category',
          child: ListTile(
            leading: Icon(Icons.label_rounded),
            title: Text('Add Category'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.drive_file_move_rounded),
            title: Text('Move Task'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_rounded, color: Colors.red),
            title: Text('Delete Task', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: const _ToolbarTile(icon: Icons.more_vert_rounded, label: 'More'),
    );
  }

  Widget _buildVerticalAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _ToolbarTile(icon: icon, label: label, onTap: onPressed);
  }

  Widget _buildVerticalValidatorAction(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      tooltip: '',
      onSelected: (validatorType) => _addValidator(context, ref, validatorType),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'checklist',
          child: ListTile(
            leading: Icon(Icons.checklist),
            title: Text('Checklist'),
            subtitle: Text('Multiple checkable items'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'single_select',
          child: ListTile(
            leading: Icon(Icons.radio_button_checked),
            title: Text('Single Select'),
            subtitle: Text('Choose one option'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'free_field',
          child: ListTile(
            leading: Icon(Icons.text_fields),
            title: Text('Free Field'),
            subtitle: Text('Text input'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'file',
          child: ListTile(
            leading: Icon(Icons.attach_file),
            title: Text('File'),
            subtitle: Text('File attachments'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'media',
          child: ListTile(
            leading: Icon(Icons.perm_media),
            title: Text('Media'),
            subtitle: Text('Photos and videos'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: const _ToolbarTile(icon: Icons.fact_check, label: 'Validator'),
    );
  }
  
  // (removed old horizontal validator trigger)

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'category':
        _showCategoryDialog(context);
        break;
      case 'move':
        _showMoveDialog(context);
        break;
      case 'gps':
        _showGpsDialog(context);
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
      case 'debug':
        _showUidDialog(context);
        break;
    }
  }

  bool _isOrganizer() {
    // TODO: Implement organizer check based on current user and task.organizer
    // For now, return true to allow testing
    return true;
  }

  void _addValidator(BuildContext context, WidgetRef ref, String validatorType) {
    // Use ValidatorViewModel to add validator properly
    final validatorViewModel = ref.read(validatorViewModelProvider(task.uid).notifier);
    
    // Create default options based on type
    List<String> defaultOptions;
    String title;
    
    switch (validatorType) {
      case 'checklist':
        defaultOptions = ['Item 1', 'Item 2', 'Item 3'];
        title = 'Checklist';
        break;
      case 'single_select':
        defaultOptions = ['Option 1', 'Option 2', 'Option 3'];
        title = 'Choose an option';
        break;
      case 'free_field':
        defaultOptions = [];
        title = 'Text field';
        break;
      case 'file':
        defaultOptions = [];
        title = 'File attachment';
        break;
      case 'media':
        defaultOptions = [];
        title = 'Media attachment';
        break;
      default:
        return;
    }
    
    // Add validator using ViewModel
    validatorViewModel.addValidatorFromTemplate(
      templateType: validatorType,
      title: title,
      options: defaultOptions,
      required: true,
    );
  }

  // Dialog methods
  void _showAttendeeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AttendeeDialog(
        task: task,
        onTaskUpdated: (updatedTask) {
          if (onTaskUpdated != null) {
            onTaskUpdated!(updatedTask);
          }
        },
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        task: task,
        projectPath: task.projectPath,
        onTaskUpdated: (updatedTask) {
          if (onTaskUpdated != null) {
            onTaskUpdated!(updatedTask);
          }
        },
      ),
    );
  }

  void _showMoveDialog(BuildContext context) {
    showMoveTaskDialog(context, task);
  }

  void _showGpsDialog(BuildContext context) {
    // TODO: Implement GPS coordinate dialog
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS dialog not implemented yet')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context) {
    if (onTaskDeleted != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Are you sure you want to delete "${task.summary}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onTaskDeleted!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }

  void _showUidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task UID'),
        content: SelectableText(task.uid),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}

class _ToolbarTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolbarTile({required this.icon, required this.label, this.onTap});

  @override
  State<_ToolbarTile> createState() => _ToolbarTileState();
}

class _ToolbarTileState extends State<_ToolbarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color base = Colors.white;
    final Color bg = _hovered ? base.withValues(alpha: 1.0) : base.withValues(alpha: 0.7);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onTap,
                child: content,
              ),
            )
          : content,
    );

    return tile;
  }
}
