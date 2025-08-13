// Task item toolbar component
// Contains all action buttons with vertical layout (icon + text) and dialog handling

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';
import '../utils/popup/attendee_dialog.dart';
import '../utils/popup/category_dialog.dart';
import '../utils/popup/due_date_dialog.dart';
import '../utils/popup/move_task_dialog.dart';
import '../utils/popup/validator_type_picker_dialog.dart';
import '../../viewmodels/attendee_suggestions_viewmodel.dart';

class TaskItemToolbar extends ConsumerStatefulWidget {
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
  ConsumerState<TaskItemToolbar> createState() => _TaskItemToolbarState();
}

class _TaskItemToolbarState extends ConsumerState<TaskItemToolbar> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    // Always render vertical toolbar
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Column(
        crossAxisAlignment:
            widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVerticalAction(
            context: context,
            icon: Icons.calendar_today_rounded,
            label: AppLocalizations.of(context)!.dueDateTitle,
            onPressed: () => DueDateDialog.show(
              context,
              task: widget.task,
              onTaskUpdated: widget.onTaskUpdated,
            ),
          ),
          if (_isOrganizer())
            _buildVerticalAction(
              context: context,
              icon: Icons.fact_check,
              label: AppLocalizations.of(context)!.completionRequirement,
              onPressed: () => _openValidatorTypePicker(context, ref),
            ),
          _buildVerticalAction(
            context: context,
            icon: Icons.person_add_rounded,
            label: AppLocalizations.of(context)!.attendee,
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
    return Column(
      crossAxisAlignment:
          widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarTile(
          icon: _showMore ? Icons.expand_less_rounded : Icons.more_vert_rounded,
          label: _showMore ? AppLocalizations.of(context)!.less : AppLocalizations.of(context)!.more,
          onTap: () => setState(() => _showMore = !_showMore),
        ),
        if (_showMore) const SizedBox(height: 8),
        if (_showMore)
          _ToolbarTile(
            icon: Icons.label_rounded,
            label: AppLocalizations.of(context)!.addCategory,
            onTap: () => _showCategoryDialog(context),
          ),
        if (_showMore) const SizedBox(height: 8),
        if (_showMore)
          _ToolbarTile(
            icon: Icons.drive_file_move_rounded,
            label: AppLocalizations.of(context)!.moveTask,
            onTap: () => _showMoveDialog(context),
          ),
        if (_showMore) const SizedBox(height: 8),
        if (_showMore)
          _ToolbarTile(
            icon: Icons.delete_rounded,
            label: AppLocalizations.of(context)!.deleteTask,
            onTap: () => _showDeleteDialog(context),
          ),
      ],
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

  Future<void> _openValidatorTypePicker(BuildContext context, WidgetRef ref) async {
    final picked = await ValidatorTypePickerDialog.show(context);
    if (picked == null || picked.isEmpty) return;
    _addValidator(context, ref, picked);
  }
  
  // (validator menu replaced by dialog)

  bool _isOrganizer() {
    // TODO: Implement organizer check based on current user and task.organizer
    // For now, return true to allow testing
    return true;
  }

  void _addValidator(BuildContext context, WidgetRef ref, String validatorType) {
    // Use ValidatorViewModel to add validator properly
    final validatorViewModel =
        ref.read(validatorViewModelProvider(widget.task.uid).notifier);
    
    // Create default options based on type
    List<String> defaultOptions;
    String title;
    
    switch (validatorType) {
      case 'checklist':
        defaultOptions = ['Item 1', 'Item 2', 'Item 3'];
        title = AppLocalizations.of(context)!.checklist;
        break;
      case 'single_select':
        defaultOptions = ['Option 1', 'Option 2', 'Option 3'];
        title = AppLocalizations.of(context)!.chooseAnOption;
        break;
      case 'free_field':
        defaultOptions = [];
        title = AppLocalizations.of(context)!.textField;
        break;
      case 'file':
        defaultOptions = [];
        title = AppLocalizations.of(context)!.fileAttachment;
        break;
      case 'media':
        defaultOptions = [];
        title = AppLocalizations.of(context)!.mediaAttachment;
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
  Future<void> _showAttendeeDialog(BuildContext context) async {
    // Prepare suggestions via ViewModel (MVVM) just like in task creation
    List<String>? suggestedEmails;
    final projectPath = widget.task.projectPath;
    if (projectPath != null && projectPath.isNotEmpty) {
      await ref.read(attendeeSuggestionsProvider(projectPath).notifier).load();
      final state = ref.read(attendeeSuggestionsProvider(projectPath));
      suggestedEmails = state.suggestions.isEmpty ? null : state.suggestions;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AttendeeDialog(
        task: widget.task,
        onTaskUpdated: (updatedTask) {
          if (widget.onTaskUpdated != null) {
            widget.onTaskUpdated!(updatedTask);
          }
        },
        suggestedAttendees: suggestedEmails,
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        task: widget.task,
        projectPath: widget.task.projectPath,
        onTaskUpdated: (updatedTask) {
          if (widget.onTaskUpdated != null) {
            widget.onTaskUpdated!(updatedTask);
          }
        },
      ),
    );
  }

  void _showMoveDialog(BuildContext context) {
    showMoveTaskDialog(context, widget.task);
  }

  // Removed unused _showGpsDialog

  void _showDeleteDialog(BuildContext context) {
    if (widget.onTaskDeleted != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Are you sure you want to delete "${widget.task.summary}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onTaskDeleted!();
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

  // Removed unused _showUidDialog

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
