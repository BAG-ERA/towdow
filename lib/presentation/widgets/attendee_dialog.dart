// Attendee management dialog for adding, editing, and removing task attendees
// Provides a comprehensive interface for attendee collaboration management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import '../../data/models/attendee.dart';
import '../../core/logger.dart';

/// Dialog for managing task attendees
class AttendeeDialog extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;

  const AttendeeDialog({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  ConsumerState<AttendeeDialog> createState() => _AttendeeDialogState();
}

class _AttendeeDialogState extends ConsumerState<AttendeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  AttendeeStatus _selectedStatus = AttendeeStatus.needsAction;
  AttendeeRole _selectedRole = AttendeeRole.requiredParticipant;
  CalendarUserType _selectedUserType = CalendarUserType.individual;
  bool _rsvpRequested = false;
  bool _isLoading = false;
  String? _emailWarning;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    _displayNameController.dispose();
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
      setState(() => _emailWarning = 'Invalid email format - this attendee may never receive notifications');
    } else {
      setState(() => _emailWarning = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add_rounded),
          SizedBox(width: 12),
          Text('Manage Attendees'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 500 : MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task: ${widget.task.summary}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              
              // Current attendees list
              if (widget.task.attendees.isNotEmpty) ...[
                Text(
                  'Current Attendees',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildAttendeesList(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],
              
              // Add new attendee form
              Text(
                'Add New Attendee',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildAddAttendeeForm(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildAttendeesList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.task.attendees.length,
        itemBuilder: (context, index) {
          final attendee = widget.task.attendees[index];
          return _buildAttendeeListItem(attendee);
        },
      ),
    );
  }

  Widget _buildAttendeeListItem(Attendee attendee) {
    // Status color
    Color statusColor;
    String statusText;
    
    switch (attendee.status) {
      case AttendeeStatus.accepted:
        statusColor = Colors.green;
        statusText = 'Accepted';
        break;
      case AttendeeStatus.declined:
        statusColor = Colors.red;
        statusText = 'Declined';
        break;
      case AttendeeStatus.tentative:
        statusColor = Colors.orange;
        statusText = 'Tentative';
        break;
      case AttendeeStatus.delegated:
        statusColor = Colors.purple;
        statusText = 'Delegated';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'No Response';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            attendee.userType == CalendarUserType.group 
                ? Icons.group
                : Icons.person,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          attendee.effectiveDisplayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attendee.email,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAttendeeAction(action, attendee),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Edit Status'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.remove_circle_rounded, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
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
              labelText: 'Email Address',
              hintText: 'attendee@example.com',
              prefixIcon: const Icon(Icons.email_rounded),
              border: const OutlineInputBorder(),
              errorText: _emailWarning,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              
              // Check for duplicates
              final email = value.trim().toLowerCase();
              final existingEmails = widget.task.attendees
                  .map((a) => a.email.toLowerCase())
                  .toList();
              if (existingEmails.contains(email)) {
                return 'This attendee is already added';
              }
              
              return null;
            },
          ),
          
          if (_emailWarning != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _emailWarning!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Display name field
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display Name (Optional)',
              hintText: 'John Doe',
              prefixIcon: Icon(Icons.badge_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status dropdown
          DropdownButtonFormField<AttendeeStatus>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: AttendeeStatus.values.map((status) {
              String displayText;
              switch (status) {
                case AttendeeStatus.needsAction:
                  displayText = 'No Response Yet';
                  break;
                case AttendeeStatus.accepted:
                  displayText = 'Accepted';
                  break;
                case AttendeeStatus.declined:
                  displayText = 'Declined';
                  break;
                case AttendeeStatus.tentative:
                  displayText = 'Tentative';
                  break;
                case AttendeeStatus.delegated:
                  displayText = 'Delegated';
                  break;
              }
              
              return DropdownMenuItem(
                value: status,
                child: Text(displayText),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedStatus = value ?? AttendeeStatus.needsAction);
            },
          ),
          
          const SizedBox(height: 16),
          
          // Role dropdown
          DropdownButtonFormField<AttendeeRole>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: AttendeeRole.values.map((role) {
              String displayText;
              switch (role) {
                case AttendeeRole.requiredParticipant:
                  displayText = 'Required Participant';
                  break;
                case AttendeeRole.optionalParticipant:
                  displayText = 'Optional Participant';
                  break;
                case AttendeeRole.nonParticipant:
                  displayText = 'Observer';
                  break;
                case AttendeeRole.chair:
                  displayText = 'Chair/Leader';
                  break;
              }
              
              return DropdownMenuItem(
                value: role,
                child: Text(displayText),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedRole = value ?? AttendeeRole.requiredParticipant);
            },
          ),
          
          const SizedBox(height: 16),
          
          // User type dropdown
          DropdownButtonFormField<CalendarUserType>(
            value: _selectedUserType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: CalendarUserType.values.map((type) {
              String displayText;
              switch (type) {
                case CalendarUserType.individual:
                  displayText = 'Person';
                  break;
                case CalendarUserType.group:
                  displayText = 'Group/Team';
                  break;
                case CalendarUserType.resource:
                  displayText = 'Resource/Equipment';
                  break;
                case CalendarUserType.room:
                  displayText = 'Room/Location';
                  break;
                case CalendarUserType.unknown:
                  displayText = 'Unknown';
                  break;
              }
              
              return DropdownMenuItem(
                value: type,
                child: Text(displayText),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedUserType = value ?? CalendarUserType.individual);
            },
          ),
          
          const SizedBox(height: 16),
          
          // RSVP checkbox
          CheckboxListTile(
            title: const Text('Request Response (RSVP)'),
            subtitle: const Text('Ask this attendee to respond to the invitation'),
            value: _rsvpRequested,
            onChanged: (value) {
              setState(() => _rsvpRequested = value ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          
          const SizedBox(height: 16),
          
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _addAttendee,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_rounded),
              label: Text(_isLoading ? 'Adding...' : 'Add Attendee'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAttendeeAction(String action, Attendee attendee) {
    switch (action) {
      case 'edit':
        _showEditAttendeeDialog(attendee);
        break;
      case 'remove':
        _removeAttendee(attendee);
        break;
    }
  }

  void _showEditAttendeeDialog(Attendee attendee) {
    showDialog(
      context: context,
      builder: (context) => AttendeeStatusDialog(
        attendee: attendee,
        onStatusUpdated: (updatedAttendee) {
          _updateAttendeeStatus(attendee, updatedAttendee.status);
        },
      ),
    );
  }

  void _addAttendee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newAttendee = Attendee(
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim().isNotEmpty 
            ? _displayNameController.text.trim() 
            : null,
        status: _selectedStatus,
        role: _selectedRole,
        userType: _selectedUserType,
        rsvpRequested: _rsvpRequested,
      );

      AppLogger.info('AttendeeDialog: Adding attendee ${newAttendee.email} to task ${widget.task.uid}');

      final updatedTask = widget.task.copyWith(
        attendees: [...widget.task.attendees, newAttendee],
        lastModified: DateTime.now(),
      );

      widget.onTaskUpdated(updatedTask);

      // Clear form
      _emailController.clear();
      _displayNameController.clear();
      setState(() {
        _selectedStatus = AttendeeStatus.needsAction;
        _selectedRole = AttendeeRole.requiredParticipant;
        _selectedUserType = CalendarUserType.individual;
        _rsvpRequested = false;
        _emailWarning = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('✅ Added ${newAttendee.effectiveDisplayName}')),
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
            content: Text('Failed to add attendee: $e'),
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
        title: const Text('Remove Attendee'),
        content: Text('Remove ${attendee.effectiveDisplayName} from this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      AppLogger.info('AttendeeDialog: Removing attendee ${attendee.email} from task ${widget.task.uid}');

      final updatedAttendees = widget.task.attendees
          .where((a) => a.email != attendee.email)
          .toList();

      final updatedTask = widget.task.copyWith(
        attendees: updatedAttendees,
        lastModified: DateTime.now(),
      );

      widget.onTaskUpdated(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.remove_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('🗑️ Removed ${attendee.effectiveDisplayName}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _updateAttendeeStatus(Attendee oldAttendee, AttendeeStatus newStatus) {
    AppLogger.info('AttendeeDialog: Updating attendee ${oldAttendee.email} status to $newStatus');

    final updatedAttendees = widget.task.attendees.map((attendee) {
      if (attendee.email == oldAttendee.email) {
        return attendee.copyWith(status: newStatus);
      }
      return attendee;
    }).toList();

    final updatedTask = widget.task.copyWith(
      attendees: updatedAttendees,
      lastModified: DateTime.now(),
    );

    widget.onTaskUpdated(updatedTask);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('✅ Updated ${oldAttendee.effectiveDisplayName} status')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Dialog for editing attendee status
class AttendeeStatusDialog extends StatefulWidget {
  final Attendee attendee;
  final Function(Attendee) onStatusUpdated;

  const AttendeeStatusDialog({
    super.key,
    required this.attendee,
    required this.onStatusUpdated,
  });

  @override
  State<AttendeeStatusDialog> createState() => _AttendeeStatusDialogState();
}

class _AttendeeStatusDialogState extends State<AttendeeStatusDialog> {
  late AttendeeStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.attendee.status;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_rounded),
          SizedBox(width: 12),
          Text('Edit Attendee Status'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendee: ${widget.attendee.effectiveDisplayName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            widget.attendee.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select new status:'),
          const SizedBox(height: 8),
          ...AttendeeStatus.values.map((status) {
            String displayText;
            switch (status) {
              case AttendeeStatus.needsAction:
                displayText = 'No Response Yet';
                break;
              case AttendeeStatus.accepted:
                displayText = 'Accepted';
                break;
              case AttendeeStatus.declined:
                displayText = 'Declined';
                break;
              case AttendeeStatus.tentative:
                displayText = 'Tentative';
                break;
              case AttendeeStatus.delegated:
                displayText = 'Delegated';
                break;
            }

            return RadioListTile<AttendeeStatus>(
              title: Text(displayText),
              value: status,
              groupValue: _selectedStatus,
              onChanged: (value) {
                setState(() => _selectedStatus = value ?? AttendeeStatus.needsAction);
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onStatusUpdated(widget.attendee.copyWith(status: _selectedStatus));
            Navigator.pop(context);
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}
