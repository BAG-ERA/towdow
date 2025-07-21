// Project Sharing ViewModel for managing project member operations
// Handles loading, adding, and removing project members through TowDow sharing service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task_calendar.dart';
import '../../data/models/shared_project_member.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/calendar_repository.dart';
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
    
    // Use the TaskCalendar.uid getter which properly handles path extraction
    return currentProject!.uid;
  }

  /// Get list of emails from edited members for UI display
  List<String> get editedMemberEmails => editedMembers.map((m) => m.targetUserEmail).toList();
}

class ProjectSharingViewModel extends StateNotifier<ProjectSharingState> {
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;

  ProjectSharingViewModel(this._accountRepository, this._calendarRepository) : super(const ProjectSharingState());

  /// Initialize the view model for a specific project
  Future<void> initializeForProject(TaskCalendar project) async {
    AppLogger.debug('ProjectSharingViewModel: Initializing for project ${project.displayName}');
    AppLogger.debug('ProjectSharingViewModel: Project path: ${project.path}');
    
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentProject: project,
    );

    try {
      // Get active account to check if sharing is supported
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account != null) {
            AppLogger.debug('ProjectSharingViewModel: Found active account: ${account.username}@${account.serverUrl}');
            AppLogger.debug('ProjectSharingViewModel: Account provider type: ${account.providerType}');
            
            // Check if account supports sharing
            final supportsSharing = account.providerType == 'towdow_cloud' || account.providerType == 'towdow_selfhosted';
            AppLogger.debug('ProjectSharingViewModel: Supports sharing: $supportsSharing');
            
            state = state.copyWith(
              supportsSharing: supportsSharing,
              currentUserEmail: account.email ?? account.username,
            );
            
            if (supportsSharing) {
              // Load sharing data from the calendar (already fetched during sync)
              await _loadProjectMembers();
            } else {
              AppLogger.warning('ProjectSharingViewModel: Sharing not supported for provider type: ${account.providerType}');
              state = state.copyWith(
                isLoading: false,
                error: 'Sharing is only available for TowDow Cloud and self-hosted accounts',
              );
            }
          } else {
            AppLogger.warning('ProjectSharingViewModel: No active account found');
            state = state.copyWith(
              isLoading: false,
              error: 'No active account found',
            );
          }
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to get active account: ${failure.message}');
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to get account information: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception during initialization', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Error initializing sharing: $e',
      );
    }
  }

  /// Load project members from local calendar data
  Future<void> _loadProjectMembers() async {
    if (state.currentProject == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Cannot load members: no project selected',
      );
      return;
    }

    try {
      AppLogger.debug('ProjectSharingViewModel: Loading members from local calendar data for project ${state.projectPath}');
      AppLogger.debug('ProjectSharingViewModel: Project path: ${state.currentProject!.path}');
      AppLogger.debug('ProjectSharingViewModel: Raw sharedWith field: "${state.currentProject!.sharedWith}"');
      
      // Get shared members from local calendar data
      final members = state.currentProject!.sharedWithMembers.map((memberJson) {
        AppLogger.debug('ProjectSharingViewModel: Processing member JSON: $memberJson');
        return SharedProjectMember.fromJson(memberJson);
      }).toList();
      
      AppLogger.debug('ProjectSharingViewModel: Successfully loaded ${members.length} members from local data');
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        AppLogger.debug('ProjectSharingViewModel: Member $i: ${member.targetUserEmail} (${member.projectRight}) from ${member.sourceUserEmail}');
      }
      
      // Also log some debugging info about the calendar
      AppLogger.debug('ProjectSharingViewModel: Calendar display name: ${state.currentProject!.displayName}');
      AppLogger.debug('ProjectSharingViewModel: Calendar sync token: ${state.currentProject!.syncToken}');
      AppLogger.debug('ProjectSharingViewModel: Calendar last sync: ${state.currentProject!.lastSyncAt}');
      
      state = state.copyWith(
        isLoading: false,
        members: members,
        editedMembers: List.from(members), // Initialize edited list with current members
        hasUnsavedChanges: false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception loading members from local data', e, stackTrace);
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

  /// Save all changes using calendar repository + CalDAV service direct call
  Future<void> saveChanges() async {
    if (state.currentProject == null) {
      state = state.copyWith(error: 'Cannot save: no project selected');
      return;
    }

    if (!state.hasUnsavedChanges) {
      AppLogger.debug('ProjectSharingViewModel: No changes to save');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Saving ${state.editedMembers.length} members to project ${state.projectPath}');
    
    state = state.copyWith(isSaving: true, error: null);

    try {
      // Convert edited members to JSON format for TaskCalendar
      final membersJson = state.editedMembers.map((member) => member.toJson()).toList();

      // Update calendar with new sharing data (optimistic UI)
      final updatedCalendar = state.currentProject!.withSharedWith(membersJson);
      
      AppLogger.debug('ProjectSharingViewModel: Updating calendar properties via repository');
      
      // Use repository for proper MVVM architecture - it handles local save and sync queue
      final updateResult = await _calendarRepository.updateCalendarProperties(updatedCalendar);
      
      await updateResult.when(
        success: (_) async {
          AppLogger.debug('ProjectSharingViewModel: Successfully updated sharing data via repository');
          
          // Update state with success
          state = state.copyWith(
            isSaving: false,
            currentProject: updatedCalendar,
            members: List.from(state.editedMembers),
            hasUnsavedChanges: false,
          );
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to update calendar properties: ${failure.message}');
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to save sharing data: ${failure.message}',
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

  /// Refresh the member list from local calendar data
  Future<void> refresh() async {
    if (state.currentProject == null) return;
    
    AppLogger.debug('ProjectSharingViewModel: Refreshing member list');
    
    state = state.copyWith(error: null);
    
    try {
      // Reload calendar from repository to get latest sharing data
      final calendarResult = await _calendarRepository.getById(state.currentProject!.path);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar != null) {
            // Update current project and reload members
            state = state.copyWith(currentProject: calendar);
            await _loadProjectMembers();
          } else {
            state = state.copyWith(error: 'Project not found');
          }
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to reload calendar: ${failure.message}');
          state = state.copyWith(error: 'Failed to refresh: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception during refresh', e, stackTrace);
      state = state.copyWith(error: 'Error refreshing: $e');
    }
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Exit share for the current user (placeholder - not implemented yet)
  Future<void> exitShare() async {
    if (state.projectPath.isEmpty) {
      state = state.copyWith(error: 'Cannot exit share: project path is empty');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Exit share for project ${state.projectPath}');
    
    state = state.copyWith(isSaving: true, error: null);

    try {
      // TODO: Implement exit share functionality
      // This would require removing the current user from the sharing list
      // and potentially triggering a sync to update the server
      
      state = state.copyWith(isSaving: false);
      AppLogger.debug('ProjectSharingViewModel: Exit share functionality not yet implemented');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception exiting share', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Error exiting share: $e',
      );
    }
  }

  /// Compare two lists of members for equality
  bool _listsEqual(List<SharedProjectMember> list1, List<SharedProjectMember> list2) {
    if (list1.length != list2.length) return false;
    
    final emails1 = list1.map((m) => m.targetUserEmail).toSet();
    final emails2 = list2.map((m) => m.targetUserEmail).toSet();
    
    return emails1.containsAll(emails2) && emails2.containsAll(emails1);
  }
} 