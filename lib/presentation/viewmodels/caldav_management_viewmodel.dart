// CalDAV Management ViewModel
// Handles calendar discovery, selection, and synchronization management
//
// This ViewModel encapsulates:
// - CalDAV calendar discovery via PROPFIND
// - Calendar selection state management
// - User preferences sync with project order
// - Local storage operations for selected calendars
// - User sync upload triggering for cloud accounts
//
// Follows MVVM architecture with proper dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import '../../data/models/caldav_account.dart';
import '../../data/models/task_calendar.dart';

import '../../data/services/caldav_service.dart';
import '../../data/services/status_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/user_sync_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/providers/providers.dart';
import '../viewmodels/commands/status_commands.dart';

// CalDAV Management state for calendar discovery and selection
class CalDAVManagementState {
  final bool isLoading;
  final String? error;
  final CaldavAccount? currentAccount;
  final CalDAVCapabilities? capabilities;
  final Set<TaskCalendar> selectedCalendars;
  final bool hasChanges;
  final String searchQuery;

  const CalDAVManagementState({
    this.isLoading = false,
    this.error,
    this.currentAccount,
    this.capabilities,
    this.selectedCalendars = const {},
    this.hasChanges = false,
    this.searchQuery = '',
  });

  CalDAVManagementState copyWith({
    bool? isLoading,
    String? error,
    CaldavAccount? currentAccount,
    CalDAVCapabilities? capabilities,
    Set<TaskCalendar>? selectedCalendars,
    bool? hasChanges,
    String? searchQuery,
  }) => CalDAVManagementState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        currentAccount: currentAccount ?? this.currentAccount,
        capabilities: capabilities ?? this.capabilities,
        selectedCalendars: selectedCalendars ?? this.selectedCalendars,
        hasChanges: hasChanges ?? this.hasChanges,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

// CalDAV Management ViewModel
class CalDAVManagementViewModel extends StateNotifier<CalDAVManagementState> {
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final UserRepository _userRepository;
  final UserSyncService _userSyncService;
  final void Function()? _onInvalidateProjectList;

  CalDAVManagementViewModel({
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required UserRepository userRepository,
    required UserSyncService userSyncService,
    void Function()? onInvalidateProjectList,
  })  : _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _userRepository = userRepository,
        _userSyncService = userSyncService,
        _onInvalidateProjectList = onInvalidateProjectList,
        super(const CalDAVManagementState());

  /// Initialize by loading account and discovering calendars
  Future<void> initialize() async {
    AppLogger.debug('CalDAVManagement: Starting initialization');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load current account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account != null) {
            AppLogger.debug('CalDAVManagement: Account loaded, starting calendar discovery');
            state = state.copyWith(currentAccount: account);
            
            // Load currently selected calendars from repository
            await _loadSelectedCalendars();
            
            // Discover calendars via PROPFIND
            await _discoverCalendars(account);
          } else {
            AppLogger.warning('CalDAVManagement: No active CalDAV account found');
            state = state.copyWith(error: 'No active CalDAV account found');
          }
        },
        failure: (failure) async {
          AppLogger.error('CalDAVManagement: Failed to load account: ${failure.message}');
          state = state.copyWith(error: 'Failed to load account: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Unexpected error during initialization', e, stackTrace);
      state = state.copyWith(error: 'Unexpected error: $e');
    } finally {
      AppLogger.debug('CalDAVManagement: Setting loading to false. Capabilities: ${state.capabilities?.taskCalendars.length ?? 0} calendars');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadSelectedCalendars() async {
    // First try to load from repository (existing calendars)
    final result = await _calendarRepository.getProjectCalendars();
    
    result.when(
      success: (calendars) {
        state = state.copyWith(selectedCalendars: Set.from(calendars));
        AppLogger.info('CalDAVManagement: Loaded ${calendars.length} selected calendars from repository');
      },
      failure: (failure) {
        AppLogger.warning('CalDAVManagement: Failed to load selected calendars: ${failure.message}');
        state = state.copyWith(selectedCalendars: {});
      },
    );
    
    // Also check user preferences for project order (in case of sync from cloud)
    final preferencesResult = await _userRepository.getUserPreferences();
    await preferencesResult.when(
      success: (preferences) async {
        if (preferences.projectOrder.isNotEmpty) {
          AppLogger.info('CalDAVManagement: Found ${preferences.projectOrder.length} projects in user preferences order');
          
          // If we have project order but no selected calendars, we might need to discover and select those calendars
          if (state.selectedCalendars.isEmpty && state.capabilities != null) {
            final discoveredCalendars = state.capabilities!.taskCalendars;
            final calendarsToSelect = <TaskCalendar>[];
            
            for (final projectPath in preferences.projectOrder) {
              final matchingCalendar = discoveredCalendars.where((cal) => cal.path == projectPath).firstOrNull;
              if (matchingCalendar != null) {
                calendarsToSelect.add(matchingCalendar);
              }
            }
            
            if (calendarsToSelect.isNotEmpty) {
              state = state.copyWith(
                selectedCalendars: Set.from(calendarsToSelect),
                hasChanges: true, // Mark as having changes to trigger save
              );
              AppLogger.info('CalDAVManagement: Auto-selected ${calendarsToSelect.length} calendars from user preferences');
            }
          }
        }
      },
      failure: (failure) {
        AppLogger.debug('CalDAVManagement: No user preferences found or failed to load: ${failure.message}');
      },
    );
  }

  Future<void> _discoverCalendars(CaldavAccount account) async {
    AppLogger.info('CalDAVManagement: Starting calendar discovery for ${account.serverUrl}');
    
    try {
      final caldavService = CalDAVService(account: account);
      final capabilitiesResult = await caldavService.discoverCapabilities();
      
      await capabilitiesResult.when(
        success: (capabilities) async {
          AppLogger.info('CalDAVManagement: Successfully discovered ${capabilities.taskCalendars.length} calendars');
          state = state.copyWith(capabilities: capabilities);
        },
        failure: (failure) async {
          AppLogger.error('CalDAVManagement: Failed to discover calendars: ${failure.message}');
          state = state.copyWith(error: 'Failed to discover calendars: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Discovery error', e, stackTrace);
      state = state.copyWith(error: 'Discovery error: $e');
    }
  }

  /// Refresh calendar discovery
  Future<void> refreshCalendars() async {
    if (state.currentAccount != null) {
      state = state.copyWith(isLoading: true, error: null);
      
      try {
        await _discoverCalendars(state.currentAccount!);
      } catch (e, stackTrace) {
        AppLogger.error('CalDAVManagement: Refresh error', e, stackTrace);
        state = state.copyWith(error: 'Refresh error: $e');
      } finally {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Toggle calendar selection
  void toggleCalendarSelection(TaskCalendar calendar) {
    final selectedCalendars = Set<TaskCalendar>.from(state.selectedCalendars);
    
    // Find existing calendar with same path and replace/remove it
    final existingCalendar = selectedCalendars.where((c) => c.path == calendar.path).firstOrNull;
    
    if (existingCalendar != null) {
      selectedCalendars.remove(existingCalendar);
    } else {
      selectedCalendars.add(calendar);
    }
    
    state = state.copyWith(
      selectedCalendars: selectedCalendars,
      hasChanges: true,
    );
    
    // Update user preferences with new project order
    _updateUserPreferencesProjectOrder();
    
    // Trigger immediate sync for calendar selection change
    _triggerImmediateSync();
  }

  /// Check if a calendar is selected
  bool isCalendarSelected(TaskCalendar calendar) {
    return state.selectedCalendars.any((c) => c.path == calendar.path);
  }

  /// Select all available calendars
  void selectAllCalendars() {
    if (state.capabilities == null) return;
    
    final allCalendars = Set<TaskCalendar>.from(state.capabilities!.taskCalendars);
    state = state.copyWith(
      selectedCalendars: allCalendars,
      hasChanges: true,
    );
    
    // Update user preferences with new project order
    _updateUserPreferencesProjectOrder();
    
    // Trigger immediate sync for calendar selection change
    _triggerImmediateSync();
  }

  /// Deselect all calendars
  void deselectAllCalendars() {
    state = state.copyWith(
      selectedCalendars: {},
      hasChanges: true,
    );
    
    // Update user preferences with new project order
    _updateUserPreferencesProjectOrder();
    
    // Trigger immediate sync for calendar selection change  
    _triggerImmediateSync();
  }

  /// Delete a calendar from the server and local storage
  Future<void> deleteCalendar(TaskCalendar calendar) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Delete through repository (handles both server and local deletion)
      // Use path for consistent storage key handling
      final deleteResult = await _calendarRepository.delete(calendar.path);
      deleteResult.when(
        success: (_) {
          AppLogger.info('CalDAVManagement: Successfully deleted calendar: ${calendar.displayName}');
        },
        failure: (failure) {
          AppLogger.error('CalDAVManagement: Failed to delete calendar: ${failure.message}');
          state = state.copyWith(error: 'Failed to delete calendar: ${failure.message}');
        },
      );

      // Remove from selected calendars if it was selected
      final updatedSelectedCalendars = Set<TaskCalendar>.from(state.selectedCalendars);
      updatedSelectedCalendars.removeWhere((c) => c.path == calendar.path);
      
      state = state.copyWith(
        selectedCalendars: updatedSelectedCalendars,
        hasChanges: true,
      );

      // Update user preferences with new project order
      _updateUserPreferencesProjectOrder();

      // Refresh calendar discovery to update the list
      await refreshCalendars();

    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error deleting calendar', e, stackTrace);
      state = state.copyWith(error: 'Error deleting calendar: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Archive a calendar (set status to ARCHIVE)
  Future<void> archiveCalendar(TaskCalendar calendar) async {
    if (state.currentAccount == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use command pattern for archiving
      // TODO: Inject StatusService through dependency injection instead of creating it here
      final statusService = StatusService(_calendarRepository, LocalStorageService());
      final archiveCommand = ArchiveCalendarCommand(
        statusService,
        calendar.path,
      );
      
      await archiveCommand.run();
      AppLogger.info('CalDAVManagement: Successfully archived calendar: ${calendar.displayName}');

      // Refresh calendar discovery to update the list
      await refreshCalendars();

    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error archiving calendar', e, stackTrace);
      state = state.copyWith(error: 'Error archiving calendar: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Reset changes by reloading from repository
  Future<void> resetChanges() async {
    await _loadSelectedCalendars();
    state = state.copyWith(hasChanges: false);
  }

  /// Save changes to repository and trigger sync
  Future<void> saveChanges() async {
    if (state.currentAccount == null || !state.hasChanges) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Save account (no longer stores selectedCalendars - just use current account)
      final updatedAccount = state.currentAccount!;
      final saveResult = await _accountRepository.save(updatedAccount);

      await saveResult.when(
        success: (_) async {
          // Create projects for selected calendars
          await _createProjectsForSelectedCalendars();
          
          state = state.copyWith(
            currentAccount: updatedAccount,
            hasChanges: false,
          );

          // Trigger user sync upload after saving changes
          await _triggerUserSyncUpload();

          if (_onInvalidateProjectList != null) {
            _onInvalidateProjectList();
          }
        },
        failure: (failure) async {
          state = state.copyWith(error: 'Failed to save changes: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Save error', e, stackTrace);
      state = state.copyWith(error: 'Save error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Update user preferences with current project order and sync status
  Future<void> _updateUserPreferencesProjectOrder() async {
    try {
      // Get current preferences
      final preferencesResult = await _userRepository.getUserPreferences();
      await preferencesResult.when(
        success: (preferences) async {
          // Create project order from selected calendars (using calendar path as project UID)
          final projectOrder = state.selectedCalendars.map((c) => c.path).toList();
          
          // Update preferences with new project order and excluded projects
          // In new architecture: sync all available projects except excluded ones
          final availableCalendarPaths = state.capabilities?.taskCalendars.map((c) => c.path).toSet() ?? <String>{};
          final excludedProjects = availableCalendarPaths.where((path) => !projectOrder.contains(path)).toList();
          
          final updatedPreferences = preferences.copyWith(
            projectOrder: projectOrder,
            excludedProjects: excludedProjects, // Exclude unselected calendars from sync
          );
          
          // Save updated preferences
          await _userRepository.saveUserPreferences(updatedPreferences);
          AppLogger.info('CalDAVManagement: Updated user preferences with ${projectOrder.length} projects');
        },
        failure: (failure) {
          AppLogger.warning('CalDAVManagement: Failed to update user preferences: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error updating user preferences', e, stackTrace);
    }
  }

  /// Trigger user sync upload for cloud/self-hosted users
  Future<void> _triggerUserSyncUpload() async {
    try {
      if (state.currentAccount == null) return;
      
      // For now, just log that sync would be triggered
      // TODO: Implement proper user sync through repository when available
      AppLogger.info('CalDAVManagement: User sync upload would be triggered here');
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error triggering user sync upload', e, stackTrace);
    }
  }

  /// Trigger immediate user preferences sync when selections change
  Future<void> _triggerImmediateSync() async {
    try {
      if (state.currentAccount == null) return;
      
      AppLogger.info('CalDAVManagement: User preferences changes will be synced via queue system');
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVManagement: Error during immediate sync', e, stackTrace);
    }
  }

  /// Clear existing calendars and save selected calendars as local projects
  Future<void> _createProjectsForSelectedCalendars() async {
    // First, clear all existing calendars using repository
    final allCalendarsResult = await _calendarRepository.getAll();
    await allCalendarsResult.when(
      success: (calendars) async {
        for (final calendar in calendars) {
          await _calendarRepository.delete(calendar.path);
        }
      },
      failure: (failure) {
        AppLogger.warning('CalDAVManagement: Failed to get calendars for clearing: ${failure.message}');
      },
    );
    
    // Now save only the selected calendars
    for (final calendar in state.selectedCalendars) {
      final saveResult = await _calendarRepository.save(calendar);
      saveResult.when(
        success: (_) {
          // Successfully saved calendar
        },
        failure: (failure) {
          AppLogger.error('CalDAVManagement: Failed to save calendar ${calendar.displayName}: ${failure.message}');
        },
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Update the search query for filtering calendars
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Get filtered calendars based on search query
  List<TaskCalendar> get filteredCalendars {
    if (state.capabilities == null || state.searchQuery.isEmpty) {
      return state.capabilities?.taskCalendars ?? [];
    }
    
    final query = state.searchQuery.toLowerCase();
    return state.capabilities!.taskCalendars.where((calendar) {
      return calendar.displayName.toLowerCase().contains(query);
    }).toList();
  }
}

// Provider
final caldavManagementViewModelProvider = StateNotifierProvider.autoDispose<CalDAVManagementViewModel, CalDAVManagementState>(
  (ref) => CalDAVManagementViewModel(
    accountRepository: ref.read(accountRepositoryProvider),
    calendarRepository: ref.read(calendarRepositoryProvider),
    userRepository: ref.read(userRepositoryProvider),
    userSyncService: ref.read(userSyncServiceProvider),
    onInvalidateProjectList: () => ref.invalidate(projectListProvider),
  ),
); 