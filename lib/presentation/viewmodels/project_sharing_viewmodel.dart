// Project Sharing ViewModel for managing project member operations
// Handles loading, adding, and removing project members through TowDow sharing service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/services/towdow_sharing_service.dart';
import '../../core/logger.dart';

// Project Sharing ViewModel State
class ProjectSharingState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final TaskCalendar? currentProject;
  final List<SharedProjectMember> members;
  final List<SharedProjectMember> editedMembers; // Local editing list
  final bool supportsSharing;
  final String? currentUserEmail;
  final bool hasUnsavedChanges;

  const ProjectSharingState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.currentProject,
    this.members = const [],
    this.editedMembers = const [],
    this.supportsSharing = false,
    this.currentUserEmail,
    this.hasUnsavedChanges = false,
  });

  ProjectSharingState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    TaskCalendar? currentProject,
    List<SharedProjectMember>? members,
    List<SharedProjectMember>? editedMembers,
    bool? supportsSharing,
    String? currentUserEmail,
    bool? hasUnsavedChanges,
  }) {
    return ProjectSharingState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      currentProject: currentProject ?? this.currentProject,
      members: members ?? this.members,
      editedMembers: editedMembers ?? this.editedMembers,
      supportsSharing: supportsSharing ?? this.supportsSharing,
      currentUserEmail: currentUserEmail ?? this.currentUserEmail,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }

  /// Check if sharing operations are available for the current project
  bool get canShare => supportsSharing && currentProject != null;

  /// Extract project UUID from calendar path
  String get projectPath {
    if (currentProject == null) return '';
    
    // Calendar paths typically look like: /calendars/username/uuid/ or /user-uuid/project-uuid/
    // Extract the UUID part - we want the last UUID in the path (same as test screen)
    final segments = currentProject!.path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : '';
  }

  /// Get list of emails from edited members for UI display
  List<String> get editedMemberEmails => editedMembers.map((m) => m.targetUserEmail).toList();
}

// Project Sharing ViewModel
class ProjectSharingViewModel extends StateNotifier<ProjectSharingState> {
  final AccountRepository _accountRepository;
  TowDowSharingService? _sharingService;

  ProjectSharingViewModel(this._accountRepository) : super(const ProjectSharingState());

  /// Initialize the view model for a specific project
  Future<void> initializeForProject(TaskCalendar project) async {
    AppLogger.debug('ProjectSharingViewModel: Initializing for project ${project.displayName}');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            state = state.copyWith(
              isLoading: false,
              error: 'No active account found',
            );
            return;
          }

          // Initialize sharing service
          _sharingService = TowDowSharingService(account: account);
          
          state = state.copyWith(
            currentProject: project,
            supportsSharing: _sharingService!.supportsSharing,
            currentUserEmail: account.email ?? account.username,
          );

          // Load project members if sharing is supported
          if (_sharingService!.supportsSharing) {
            await _loadProjectMembers();
          } else {
            state = state.copyWith(
              isLoading: false,
              error: 'Sharing not supported for ${account.providerType} accounts',
            );
          }
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to get active account', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to get account: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception during initialization', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize sharing: $e',
      );
    }
  }

  /// Load project members from the server
  Future<void> _loadProjectMembers() async {
    if (_sharingService == null || state.projectPath.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Cannot load members: invalid project path',
      );
      return;
    }

    try {
      AppLogger.debug('ProjectSharingViewModel: Loading members for project ${state.projectPath}');
      AppLogger.debug('ProjectSharingViewModel: Using sharing service: ${_sharingService.runtimeType}');
      
      final result = await _sharingService!.getProjectMembers(state.projectPath);

      result.when(
        success: (members) {
          AppLogger.debug('ProjectSharingViewModel: Successfully parsed ${members.length} members');
          for (int i = 0; i < members.length; i++) {
            final member = members[i];
            AppLogger.debug('ProjectSharingViewModel: Member $i: ${member.targetUserEmail} (${member.projectRight}) from ${member.sourceUserEmail}');
          }
          
          state = state.copyWith(
            isLoading: false,
            members: members,
            editedMembers: List.from(members), // Initialize edited list with current members
            hasUnsavedChanges: false,
          );
        },
        failure: (failure) {
          AppLogger.error('ProjectSharingViewModel: Failed to load members: ${failure.message}');
          AppLogger.error('ProjectSharingViewModel: Failure exception: ${failure.exception}');
          if (failure.stackTrace != null) {
            AppLogger.error('ProjectSharingViewModel: Stack trace: ${failure.stackTrace}');
          }
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load members: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception loading members', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Error loading members: $e',
      );
    }
  }

  /// Add a member to the local edited list (does not save immediately)
  void addMemberToEdit(String email) {
    if (email.trim().isEmpty || !email.contains('@')) {
      state = state.copyWith(error: 'Please enter a valid email address');
      return;
    }

    final trimmedEmail = email.trim();
    
    // Check if member already exists
    if (state.editedMembers.any((m) => m.targetUserEmail == trimmedEmail)) {
      state = state.copyWith(error: 'Member $trimmedEmail is already in the list');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Adding member $trimmedEmail to edit list');
    
    // Create new member (we'll use current user as source for consistency)
    final newMember = SharedProjectMember(
      projectPath: state.projectPath,
      allTasks: true,
      projectRight: 'W', // Default write access
      sourceUserEmail: state.currentUserEmail ?? '',
      targetUserEmail: trimmedEmail,
    );

    final updatedEditedMembers = [...state.editedMembers, newMember];
    
    state = state.copyWith(
      editedMembers: updatedEditedMembers,
      hasUnsavedChanges: !_listsEqual(state.members, updatedEditedMembers),
      error: null,
    );
  }

  /// Remove a member from the local edited list (does not save immediately)
  void removeMemberFromEdit(SharedProjectMember member) {
    AppLogger.debug('ProjectSharingViewModel: Removing member ${member.targetUserEmail} from edit list');
    
    final updatedEditedMembers = state.editedMembers.where((m) => m.targetUserEmail != member.targetUserEmail).toList();
    
    state = state.copyWith(
      editedMembers: updatedEditedMembers,
      hasUnsavedChanges: !_listsEqual(state.members, updatedEditedMembers),
      error: null,
    );
  }

  /// Save all changes to the server using setProjectMembers
  Future<void> saveChanges() async {
    if (_sharingService == null || state.projectPath.isEmpty) {
      state = state.copyWith(error: 'Cannot save: sharing not available');
      return;
    }

    if (!state.hasUnsavedChanges) {
      AppLogger.debug('ProjectSharingViewModel: No changes to save');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Saving ${state.editedMembers.length} members to project ${state.projectPath}');
    
    state = state.copyWith(isSaving: true, error: null);

    try {
      // Get list of target emails for the API
      final memberEmails = state.editedMembers.map((m) => m.targetUserEmail).toList();
      
      final result = await _sharingService!.setProjectMembers(
        projectPath: state.projectPath,
        memberEmails: memberEmails,
      );

      await result.when(
        success: (_) async {
          AppLogger.debug('ProjectSharingViewModel: Successfully saved member changes');
          
          // Reload from server to get the latest state
          await _loadProjectMembers();
          
          state = state.copyWith(isSaving: false);
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to save changes: ${failure.message}');
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to save changes: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception saving changes', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Error saving changes: $e',
      );
    }
  }

  /// Discard local changes and revert to server state
  void discardChanges() {
    AppLogger.debug('ProjectSharingViewModel: Discarding local changes');
    
    state = state.copyWith(
      editedMembers: List.from(state.members),
      hasUnsavedChanges: false,
      error: null,
    );
  }

  /// Compare two lists of members for equality
  bool _listsEqual(List<SharedProjectMember> list1, List<SharedProjectMember> list2) {
    if (list1.length != list2.length) return false;
    
    final emails1 = list1.map((m) => m.targetUserEmail).toSet();
    final emails2 = list2.map((m) => m.targetUserEmail).toSet();
    
    return emails1.containsAll(emails2) && emails2.containsAll(emails1);
  }

  /// Refresh the member list
  Future<void> refresh() async {
    if (state.currentProject == null) return;
    
    AppLogger.debug('ProjectSharingViewModel: Refreshing member list');
    
    state = state.copyWith(error: null);
    await _loadProjectMembers();
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Exit share for the current user (kept for future use)
  Future<void> exitShare() async {
    if (_sharingService == null || state.projectPath.isEmpty) {
      state = state.copyWith(error: 'Cannot exit share: sharing not available');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Exiting share for project ${state.projectPath}');
    
    state = state.copyWith(isSaving: true, error: null);

    try {
      final result = await _sharingService!.exitShare(state.projectPath);

      await result.when(
        success: (_) async {
          AppLogger.debug('ProjectSharingViewModel: Successfully exited share');
          state = state.copyWith(isSaving: false);
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to exit share: ${failure.message}');
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to exit share: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception exiting share', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Error exiting share: $e',
      );
    }
  }
} 