// Task item toolbar component
// Contains all action buttons with responsive behavior and dialog handling

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../data/models/task.dart';
import '../../../data/services/validator_service.dart';
import '../utils/popup/attendee_dialog.dart';
import '../utils/popup/due_date_dialog.dart';
import '../utils/popup/move_task_dialog.dart';

class TaskItemToolbar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
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
          _buildValidatorPopupButton(context),
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





  Widget _buildValidatorPopupButton(BuildContext context) {
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
      onSelected: (validatorType) => _addValidator(context, validatorType),
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

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _addValidator(BuildContext context, String validatorType) {
    // Create default validator based on type
    Map<String, dynamic> defaultValidator;
    
    switch (validatorType) {
      case 'checklist':
        defaultValidator = {
          'id': _generateId(),
          'type': 'checklist',
          'required': true,
          'title': 'Checklist',
          'items': [
            {'id': _generateId(), 'text': 'Item 1', 'checked': false},
            {'id': _generateId(), 'text': 'Item 2', 'checked': false},
            {'id': _generateId(), 'text': 'Item 3', 'checked': false},
          ],
        };
        break;
      case 'single_select':
        defaultValidator = {
          'id': _generateId(),
          'type': 'single_select',
          'required': true,
          'title': 'Choose an option',
          'options': [
            {'id': _generateId(), 'text': 'Option 1'},
            {'id': _generateId(), 'text': 'Option 2'},
            {'id': _generateId(), 'text': 'Option 3'},
          ],
          'selected': '',
        };
        break;
      case 'free_field':
        defaultValidator = {
          'id': _generateId(),
          'type': 'free_field',
          'required': true,
          'title': 'Text field',
          'value': '',
          'helper': '',
        };
        break;
      default:
        return;
    }
    
    // Add validator to task
    final currentValidators = ValidatorService.parseValidators(task.flowitValidator);
    currentValidators.add([defaultValidator]);
    
    final updatedTask = task.copyWith(
      flowitValidator: json.encode(currentValidators),
      lastModified: DateTime.now(),
    );
    
    // Notify parent
    if (onTaskUpdated != null) {
      onTaskUpdated!(updatedTask);
    }
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
    // TODO: Implement category dialog
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category dialog not implemented yet')),
      );
    }
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