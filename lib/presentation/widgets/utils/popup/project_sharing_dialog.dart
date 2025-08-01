// Project sharing dialog for managing project members
// Uses ProjectSharingViewModel to handle all sharing operations through proper MVVM pattern

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/models/task_calendar.dart';
import '../../../../data/providers/providers.dart';
import '../../../viewmodels/project_sharing_viewmodel.dart';

class ProjectSharingDialog extends ConsumerStatefulWidget {
  final TaskCalendar project;
  final List<String>? suggestedMembers;

  const ProjectSharingDialog({
    super.key,
    required this.project,
    this.suggestedMembers,
  });

  @override
  ConsumerState<ProjectSharingDialog> createState() => _ProjectSharingDialogState();
}

class _ProjectSharingDialogState extends ConsumerState<ProjectSharingDialog> {
  final _emailController = TextEditingController();
  bool _isInputActive = false;

  @override
  void initState() {
    super.initState();
    // Initialize the ViewModel with the project when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectSharingViewModelProvider.notifier).initializeForProject(widget.project);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sharingState = ref.watch(projectSharingViewModelProvider);
    final sharingNotifier = ref.read(projectSharingViewModelProvider.notifier);
    
    return PopScope(
      canPop: !sharingState.hasUnsavedChanges,
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('Share ${widget.project.displayName}'),
            ),
            if (sharingState.hasUnsavedChanges) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Unsaved',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: _buildContent(context, sharingState, sharingNotifier),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: sharingState.hasUnsavedChanges && !sharingState.isSaving 
                ? () => _saveChanges(sharingNotifier)
                : null,
            child: sharingState.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProjectSharingState state, ProjectSharingViewModel notifier) {
    // Show loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show error state if sharing is not supported
    if (!state.supportsSharing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Sharing not supported',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Sharing is only available for TowDow Cloud and self-hosted accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Debug section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Debug Info:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Current User: ${state.currentUserEmail ?? 'Unknown'}'),
                  Text('Project Path: ${state.projectPath}'),
                  if (state.currentProject != null) ...[
                    Text('Shared With Field: "${state.currentProject!.sharedWith}"'),
                    Text('Last Sync: ${state.currentProject!.lastSyncAt?.toString() ?? 'Never'}'),
                  ],
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Get the active account to show provider type
                      final accountRepo = ref.read(accountRepositoryProvider);
                      final result = await accountRepo.getActiveAccount();
                      result.when(
                        success: (account) {
                          AppLogger.debug('Account provider type: ${account?.providerType ?? 'Unknown'}');
                        },
                        failure: (failure) {
                          AppLogger.error('Failed to get account info: ${failure.message}');
                        },
                      );
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('Show Account Info'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Members list header
        Row(
          children: [
            Text(
              'Members (${state.editedMembers.length}):',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (state.hasUnsavedChanges) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Unsaved',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (!state.hasUnsavedChanges) ...[
              TextButton.icon(
                onPressed: state.isSaving ? null : () => notifier.refresh(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        
        // Members list (showing edited members) - fit content height
        state.editedMembers.isEmpty
            ? const Center(
                child: Text(
                  'No members yet.\nAdd an email address below to share this project.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.editedMembers.length,
                itemBuilder: (context, index) {
                  final member = state.editedMembers[index];
                  final isNew = !state.members.any((m) => m.targetUserEmail == member.targetUserEmail);
                  
                  return ListTile(
                    leading: Icon(
                      Icons.person,
                      color: isNew ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      member.targetUserEmail,
                      style: TextStyle(
                        fontSize: 13,
                        color: isNew ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: isNew ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    subtitle: isNew ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: state.isSaving ? null : () => notifier.removeMemberFromEdit(member),
                      tooltip: 'Remove from list',
                    ),
                  );
                },
              ),
        
        const SizedBox(height: 16),
        
        // Add member section
        _isInputActive
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        filled: false,
                      ),
                      enabled: !state.isSaving,
                      onSubmitted: (_) => _addMember(notifier),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: state.isSaving ? null : () => _addMember(notifier),
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: 'Add member',
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isInputActive = false;
                        _emailController.clear();
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Cancel',
                  ),
                ],
              )
            : GestureDetector(
                onTap: () {
                  setState(() {
                    _isInputActive = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_add,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add member',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        
        const SizedBox(height: 16),
        
        // Error display
        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => notifier.clearError(),
                  iconSize: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Suggested members section
        if (widget.suggestedMembers != null && widget.suggestedMembers!.isNotEmpty) ...[
          const SizedBox(height: 44),
          Row(
            children: [
              Text(
                'Suggested Members:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.suggestedMembers!.map((email) {
              final isAlreadyAdded = state.editedMembers.any((m) => m.targetUserEmail == email);
              return ActionChip(
                avatar: Icon(
                  isAlreadyAdded ? Icons.check : Icons.person_add,
                  size: 16,
                  color: isAlreadyAdded 
                      ? Theme.of(context).colorScheme.onSecondary 
                      : Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: isAlreadyAdded 
                        ? Theme.of(context).colorScheme.onSecondary 
                        : Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                backgroundColor: isAlreadyAdded 
                    ? Theme.of(context).colorScheme.secondary 
                    : Theme.of(context).colorScheme.primary,
                onPressed: isAlreadyAdded || state.isSaving 
                    ? null 
                    : () {
                        setState(() {
                          _isInputActive = true;
                        });
                        _emailController.text = email;
                        _addMember(notifier);
                      },
                tooltip: isAlreadyAdded 
                    ? 'Already added' 
                    : 'Click to add this member',
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _addMember(ProjectSharingViewModel notifier) {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) return;
    
    notifier.addMemberToEdit(email);
    
    // Clear the text field and reset input state if no error
    final state = ref.read(projectSharingViewModelProvider);
    if (state.error == null) {
      _emailController.clear();
      setState(() {
        _isInputActive = false;
      });
    }
  }

  void _saveChanges(ProjectSharingViewModel notifier) async {
    await notifier.saveChanges();
    
    // Check if save was successful and close dialog
    final state = ref.read(projectSharingViewModelProvider);
    if (state.error == null && mounted) {
      // Wait a brief moment for any background operations to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Invalidate related providers to ensure UI refresh
      // Note: These providers will be refreshed automatically by the repository updates
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
} 