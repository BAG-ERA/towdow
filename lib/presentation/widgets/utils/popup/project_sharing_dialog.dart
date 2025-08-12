// Project sharing dialog for managing project members
// Uses ProjectSharingViewModel to handle all sharing operations through proper MVVM pattern

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/models/task_calendar.dart';
import '../../../../data/providers/providers.dart';
import '../../../viewmodels/project_sharing_viewmodel.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

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
              child: Text(AppLocalizations.of(context)!.shareProject(widget.project.displayName)),
            ),
            if (sharingState.hasUnsavedChanges) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context)!.unsaved,
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
            child: Text(AppLocalizations.of(context)!.cancel),
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
                : Text(AppLocalizations.of(context)!.save),
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
            Text(
              AppLocalizations.of(context)!.sharingNotSupportedTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? AppLocalizations.of(context)!.sharingNotSupportedBody,
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
                  Text(AppLocalizations.of(context)!.debugInfo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${AppLocalizations.of(context)!.currentUser}: ${state.currentUserEmail ?? AppLocalizations.of(context)!.unknown}'),
                  Text('${AppLocalizations.of(context)!.projectPath}: ${state.projectPath}'),
                  if (state.currentProject != null) ...[
                    Text('${AppLocalizations.of(context)!.sharedWithField}: "${state.currentProject!.sharedWith}"'),
                    Text('${AppLocalizations.of(context)!.lastSync}: ${state.currentProject!.lastSyncAt?.toString() ?? 'Never'}'),
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
                    label: Text(AppLocalizations.of(context)!.showAccountInfo),
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
              AppLocalizations.of(context)!.membersCount(state.editedMembers.length),
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
                  AppLocalizations.of(context)!.unsaved,
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
                label: Text(AppLocalizations.of(context)!.refresh),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        
        // Members list (showing edited members) - fit content height
        state.editedMembers.isEmpty
            ? Center(
                child: Text(
                  AppLocalizations.of(context)!.noMembersYet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            : SizedBox(
                height: 240,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
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
                    subtitle: isNew
                        ? Container(
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
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: state.isSaving ? null : () => notifier.removeMemberFromEdit(member),
                      tooltip: AppLocalizations.of(context)!.removeFromList,
                    ),
                  );
                },
              ),
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
                      hintText: AppLocalizations.of(context)!.enterEmailAddress,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    tooltip: AppLocalizations.of(context)!.addMember,
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isInputActive = false;
                        _emailController.clear();
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: AppLocalizations.of(context)!.cancel,
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
                        AppLocalizations.of(context)!.addMember,
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
        (state.error != null)
          ? Container(
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
          )
          : const SizedBox.shrink(),
        SizedBox(height: state.error != null ? 16 : 0),
        
        // Suggested members section
        (widget.suggestedMembers != null && widget.suggestedMembers!.isNotEmpty)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 44),
                  Row(
                    children: [
                      const Text(
                        'Suggested Members:',
                        style: TextStyle(fontWeight: FontWeight.w500),
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
                        tooltip: isAlreadyAdded ? AppLocalizations.of(context)!.alreadyAdded : AppLocalizations.of(context)!.clickToAddMember,
                      );
                    }).toList(),
                  ),
                ],
              )
            : const SizedBox.shrink(),
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