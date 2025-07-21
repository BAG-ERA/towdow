// Project Sharing ViewModel for managing project member operations
// Handles loading, adding, and removing project members through TowDow sharing service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task_calendar.dart';
import '../../data/models/caldav_account.dart';
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
  final bool supportsSharing;
  final String? currentUserEmail;

  const ProjectSharingState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.currentProject,
    this.members = const [],
    this.supportsSharing = false,
    this.currentUserEmail,
  });

  ProjectSharingState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    TaskCalendar? currentProject,
    List<SharedProjectMember>? members,
    bool? supportsSharing,
    String? currentUserEmail,
  }) {
    return ProjectSharingState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      currentProject: currentProject ?? this.currentProject,
      members: members ?? this.members,
      supportsSharing: supportsSharing ?? this.supportsSharing,
      currentUserEmail: currentUserEmail ?? this.currentUserEmail,
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

  /// Add a member to the project
  Future<void> addMember(String email) async {
    if (_sharingService == null || state.projectPath.isEmpty) {
      state = state.copyWith(error: 'Cannot add member: sharing not available');
      return;
    }

    if (email.trim().isEmpty || !email.contains('@')) {
      state = state.copyWith(error: 'Please enter a valid email address');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Adding member $email to project ${state.projectPath}');
    
    state = state.copyWith(isSaving: true, error: null);

    try {
      final result = await _sharingService!.addProjectMember(
        projectPath: state.projectPath,
        targetUserEmail: email.trim(),
      );

      await result.when(
        success: (_) async {
          AppLogger.debug('ProjectSharingViewModel: Successfully added member $email');
          
          // Reload members to get updated list
          await _loadProjectMembers();
          
          state = state.copyWith(isSaving: false);
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to add member: ${failure.message}');
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to add member: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception adding member', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Error adding member: $e',
      );
    }
  }

  /// Remove a member from the project
  Future<void> removeMember(SharedProjectMember member) async {
    if (_sharingService == null || state.projectPath.isEmpty) {
      state = state.copyWith(error: 'Cannot remove member: sharing not available');
      return;
    }

    AppLogger.debug('ProjectSharingViewModel: Removing member ${member.targetUserEmail} from project ${state.projectPath}');
    
    state = state.copyWith(isSaving: true, error: null);

    try {
      final result = await _sharingService!.removeProjectMember(
        projectPath: state.projectPath,
        targetUserEmail: member.targetUserEmail,
      );

      await result.when(
        success: (_) async {
          AppLogger.debug('ProjectSharingViewModel: Successfully removed member ${member.targetUserEmail}');
          
          // Reload members to get updated list
          await _loadProjectMembers();
          
          state = state.copyWith(isSaving: false);
        },
        failure: (failure) async {
          AppLogger.error('ProjectSharingViewModel: Failed to remove member: ${failure.message}');
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to remove member: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectSharingViewModel: Exception removing member', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Error removing member: $e',
      );
    }
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

  /// Exit share for the current user
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