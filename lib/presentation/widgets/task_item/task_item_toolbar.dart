// Task item toolbar component
// Contains all action buttons with responsive behavior and dialog handling

import 'package:flutter/foundation.dart';
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

  const TaskItemToolbar({
    super.key,
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prevent toolbar clicks from bubbling up to parent task item widgets
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Absorb tap events to prevent them from reaching parent widgets
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
        // Primary actions - always visible
        _buildPrimaryAction(
          context: context,
          icon: Icons.calendar_today_rounded,
          tooltip: 'Set Due Date',
          onPressed: () => DueDateDialog.show(
            context,
            task: task,
            onTaskUpdated: onTaskUpdated,
          ),
        ),
        const SizedBox(width: 4),
        
        // Validator button (organizer only)
        if (_isOrganizer()) ...[
                      _buildValidatorPopupButton(context, ref),
          const SizedBox(width: 4),
        ],
        
        _buildPrimaryAction(
          context: context,
          icon: Icons.person_add_rounded,
          tooltip: 'Add Attendee',
          onPressed: () => _showAttendeeDialog(context),
        ),
        const SizedBox(width: 4),
        
        // Secondary actions menu
        _buildSecondaryActionsMenu(context),
        ],
      ),
    );
  }

  /// Builds a primary action button (always visible)
  Widget _buildPrimaryAction({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  /// Builds the secondary actions menu with vertical 3-dot icon
  Widget _buildSecondaryActionsMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      tooltip: 'More Actions',
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
          value: 'archive',
          child: ListTile(
            leading: Icon(Icons.archive),
            title: Text('Archive Task'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'gps',
          child: ListTile(
            leading: Icon(Icons.pin_drop),
            title: Text('Add GPS Location'),
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
        if (kDebugMode)
          const PopupMenuItem(
            value: 'debug',
            child: ListTile(
              leading: Icon(Icons.info_rounded),
              title: Text('Show UID'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }





  Widget _buildValidatorPopupButton(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.fact_check,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      tooltip: 'Add Validator',
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
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'category':
        _showCategoryDialog(context);
        break;
      case 'move':
        _showMoveDialog(context);
        break;
      case 'archive':
        _showArchiveDialog(context);
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
        projectUid: task.sourceCalendarUid,
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

  void _showArchiveDialog(BuildContext context) {
    // TODO: Implement archive dialog
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archive dialog not implemented yet')),
      );
    }
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