// Simplified attendee management dialog for adding attendees to tasks
// Provides a clean interface for adding attendees by email address

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/attendee.dart';
import '../../../../core/logger.dart';

/// Simplified dialog for managing task attendees
class AttendeeDialog extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;
  final List<String>? suggestedAttendees;

  const AttendeeDialog({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    this.suggestedAttendees,
  });

  @override
  ConsumerState<AttendeeDialog> createState() => _AttendeeDialogState();
}

class _AttendeeDialogState extends ConsumerState<AttendeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  String? _emailWarning;
  late Task _task; // local, live-updating copy for dialog rendering

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailWarning = null);
      return;
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailWarning = AppLocalizations.of(context)!.invalidEmailFormat);
    } else {
      setState(() => _emailWarning = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Escape to close dialog
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isLoading) {
            Navigator.of(context).pop();
          }
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add_rounded),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                AppLocalizations.of(context)!.addAttendee,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 600 ? 400 : MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppLocalizations.of(context)!.taskLabel}: ${_task.summary}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              
              // Current attendees list
              if (_task.attendees.isNotEmpty) ...[
                Text(
                  AppLocalizations.of(context)!.currentAttendees,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._task.attendees.map((attendee) => _buildAttendeeItem(attendee)),
                const SizedBox(height: 16),
              ],
              
              // Suggested attendees
              if (widget.suggestedAttendees != null && widget.suggestedAttendees!.isNotEmpty) ...[
                Text(
                  AppLocalizations.of(context)!.suggestedAttendees,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSuggestedAttendeesList(),
                const SizedBox(height: 16),
              ],
              
              // Add new attendee form
              _buildAddAttendeeForm(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

    Widget _buildAttendeeItem(Attendee attendee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attendee.effectiveDisplayName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            onPressed: () => _removeAttendee(attendee),
            icon: const Icon(Icons.remove_circle_rounded, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: AppLocalizations.of(context)!.removeAttendeeTooltip,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedAttendeesList() {
    // Filter out suggested attendees that are already added
    final availableSuggestions = widget.suggestedAttendees!
        .where((email) => !_task.attendees.any((a) => a.email.toLowerCase() == email.toLowerCase()))
        .toList();

    if (availableSuggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          AppLocalizations.of(context)!.allSuggestedAttendeesAdded,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: availableSuggestions.map((email) => _buildSuggestedAttendeeChip(email)).toList(),
    );
  }

  Widget _buildSuggestedAttendeeChip(String email) {
    final displayName = _extractDisplayName(email);
    
    return ActionChip(
      avatar: const Icon(Icons.person_add_rounded, size: 16),
      label: Text(
        displayName ?? email,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onPressed: () => _addSuggestedAttendee(email),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        width: 1,
      ),
    );
  }

  Widget _buildAddAttendeeForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.emailAddress,
              hintText: AppLocalizations.of(context)!.emailAddressHint,
              prefixIcon: const Icon(Icons.email_rounded),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              errorText: _emailWarning,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AppLocalizations.of(context)!.emailRequired;
              }
              
              // Check for duplicates
              final email = value.trim().toLowerCase();
              final isDuplicate = widget.task.attendees.any((a) => a.email.toLowerCase() == email);
              if (isDuplicate) {
                return AppLocalizations.of(context)!.alreadyAddedAttendee;
              }
              
              // Basic email validation
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(email)) {
                return AppLocalizations.of(context)!.pleaseEnterValidEmail;
              }
              
              return null;
            },
            onFieldSubmitted: (_) => _addAttendee(),
          ),
          
          const SizedBox(height: 16),
          
          // Add button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _addAttendee,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_rounded),
              label: Text(_isLoading ? AppLocalizations.of(context)!.addingAttendee : AppLocalizations.of(context)!.addAttendeeButton),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addAttendee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newAttendee = Attendee(
        email: _emailController.text.trim(),
        displayName: _extractDisplayName(_emailController.text.trim()),
        status: AttendeeStatus.needsAction,
        role: AttendeeRole.requiredParticipant,
        userType: CalendarUserType.individual,
        rsvpRequested: false,
      );

      AppLogger.info('AttendeeDialog: Adding attendee ${newAttendee.email} to task ${widget.task.uid}');

      final updatedTask = _task.copyWith(
        attendees: [..._task.attendees, newAttendee],
        lastModified: DateTime.now(),
      );

      // Update local dialog view and notify parent
      setState(() {
        _task = updatedTask;
      });
      widget.onTaskUpdated(updatedTask);

      // Clear form
      _emailController.clear();
      setState(() {
        _emailWarning = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(AppLocalizations.of(context)!.attendeeAddedSuccess(newAttendee.effectiveDisplayName))),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('AttendeeDialog: Failed to add attendee', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToAddAttendee(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _extractDisplayName(String email) {
    if (email.contains('@')) {
      final namePart = email.split('@').first;
      // Capitalize and replace separators with spaces
      return namePart
          .replaceAll(RegExp(r'[.\-_]'), ' ')
          .split(' ')
          .map((word) => word.isNotEmpty 
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : word)
          .join(' ');
    }
    return null;
  }

  void _addSuggestedAttendee(String email) async {
    setState(() => _isLoading = true);

    try {
      final newAttendee = Attendee(
        email: email,
        displayName: _extractDisplayName(email),
        status: AttendeeStatus.needsAction,
        role: AttendeeRole.requiredParticipant,
        userType: CalendarUserType.individual,
        rsvpRequested: false,
      );

      AppLogger.info('AttendeeDialog: Adding suggested attendee ${newAttendee.email} to task ${widget.task.uid}');

      final updatedTask = _task.copyWith(
        attendees: [..._task.attendees, newAttendee],
        lastModified: DateTime.now(),
      );

      // Update local dialog view and notify parent
      setState(() {
        _task = updatedTask;
      });
      widget.onTaskUpdated(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(AppLocalizations.of(context)!.attendeeAddedSuccess(newAttendee.effectiveDisplayName))),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('AttendeeDialog: Failed to add suggested attendee', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToAddSuggestedAttendee(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeAttendee(Attendee attendee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeAttendeeDialogTitle),
        content: Text(AppLocalizations.of(context)!.removeAttendeeDialogContent(attendee.effectiveDisplayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.removeAttendeeButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      AppLogger.info('AttendeeDialog: Removing attendee ${attendee.email} from task ${widget.task.uid}');

      final updatedAttendees = _task.attendees
          .where((a) => a.email != attendee.email)
          .toList();

      final updatedTask = _task.copyWith(
        attendees: updatedAttendees,
        lastModified: DateTime.now(),
      );

      // Update local dialog view and notify parent
      setState(() {
        _task = updatedTask;
      });
      widget.onTaskUpdated(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(AppLocalizations.of(context)!.attendeeRemovedSuccess(attendee.effectiveDisplayName))),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
