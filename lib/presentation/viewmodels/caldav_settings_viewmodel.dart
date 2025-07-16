// CalDAV Settings ViewModel for managing calendar discovery and selection
// Handles server discovery, calendar listing, and sync configuration

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/caldav_account.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/services/caldav_service.dart';
import '../../data/services/capability_discovery_service.dart';
import '../../core/logger.dart';

// CalDAV Settings ViewModel State
class CaldavSettingsState {
  final bool isLoading;
  final bool isDiscovering;
  final String? error;
  final CaldavAccount? currentAccount;
  final List<TaskCalendar> availableCalendars;
  final List<TaskCalendar> selectedCalendars;
  final Map<String, String> serverCapabilities;

  const CaldavSettingsState({
    this.isLoading = false,
    this.isDiscovering = false,
    this.error,
    this.currentAccount,
    this.availableCalendars = const [],
    this.selectedCalendars = const [],
    this.serverCapabilities = const {},
  });

  CaldavSettingsState copyWith({
    bool? isLoading,
    bool? isDiscovering,
    String? error,
    CaldavAccount? currentAccount,
    List<TaskCalendar>? availableCalendars,
    List<TaskCalendar>? selectedCalendars,
    Map<String, String>? serverCapabilities,
  }) {
    return CaldavSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: error,
      currentAccount: currentAccount ?? this.currentAccount,
      availableCalendars: availableCalendars ?? this.availableCalendars,
      selectedCalendars: selectedCalendars ?? this.selectedCalendars,
      serverCapabilities: serverCapabilities ?? this.serverCapabilities,
    );
  }
}

// CalDAV Settings ViewModel
class CaldavSettingsViewModel extends StateNotifier<CaldavSettingsState> {
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;

  CaldavSettingsViewModel(
    this._accountRepository,
    this._calendarRepository,
  ) : super(const CaldavSettingsState());

  /// Initialize the view model with current account data
  Future<void> initialize() async {
    // AppLogger.info('CaldavSettingsViewModel: Initializing');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load current account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account != null) {
            state = state.copyWith(currentAccount: account);
            
            // Load selected calendars
            final calendarsResult = await _calendarRepository.getProjectCalendars();
            await calendarsResult.when(
              success: (calendars) async {
                state = state.copyWith(
                  selectedCalendars: calendars,
                  isLoading: false,
                );
              },
              failure: (failure) async {
                AppLogger.error('CaldavSettingsViewModel: Failed to load calendars', failure.exception, failure.stackTrace);
                state = state.copyWith(
                  isLoading: false,
                  error: 'Failed to load calendars: ${failure.message}',
                );
              },
            );
          } else {
            state = state.copyWith(isLoading: false);
          }
        },
        failure: (failure) async {
          AppLogger.error('CaldavSettingsViewModel: Failed to load account', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load account: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CaldavSettingsViewModel: Exception during initialization', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize: $e',
      );
    }
  }

  /// Discover available calendars on the server
  Future<void> discoverCalendars() async {
    final account = state.currentAccount;
    if (account == null) {
      state = state.copyWith(error: 'No active account configured');
      return;
    }

    // AppLogger.info('CaldavSettingsViewModel: Discovering calendars');
    
    state = state.copyWith(isDiscovering: true, error: null);

    try {
      // Use capability discovery service
      final discoveryService = CapabilityDiscoveryService(account: account);
      final discoveryResult = await discoveryService.discoverCapabilities();
      
      await discoveryResult.when(
        success: (discovery) async {
          // AppLogger.info('CaldavSettingsViewModel: Found ${discovery.availableCalendars.length} calendars');
          
          state = state.copyWith(
            availableCalendars: discovery.availableCalendars,
            serverCapabilities: {
              'CalDAV Support': discovery.capabilities.supportsCalDAV ? 'Yes' : 'No',
              'Task Support': discovery.availableCalendars.any((cal) => cal.supportsTodos) ? 'Yes' : 'No',
              'Principal': discovery.capabilities.principal ?? 'Unknown',
              'Calendar Home': discovery.capabilities.calendarHome ?? 'Unknown',
              'Server': discovery.capabilities.serverInfo,
            },
            isDiscovering: false,
          );
        },
        failure: (failure) async {
          AppLogger.error('CaldavSettingsViewModel: Calendar discovery failed', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isDiscovering: false,
            error: 'Failed to discover calendars: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CaldavSettingsViewModel: Exception during discovery', e, stackTrace);
      state = state.copyWith(
        isDiscovering: false,
        error: 'Failed to discover calendars: $e',
      );
    }
  }

  /// Toggle calendar selection for synchronization
  Future<void> toggleCalendarSelection(TaskCalendar calendar) async {
    // AppLogger.info('CaldavSettingsViewModel: Toggling calendar selection: ${calendar.displayName}');
    
    try {
      final isCurrentlySelected = state.selectedCalendars.any((cal) => cal.path == calendar.path);
      
      if (isCurrentlySelected) {
        // Remove from selection
        final result = await _calendarRepository.delete(calendar.path);
        await result.when(
          success: (_) async {
            final updatedSelected = state.selectedCalendars.where((cal) => cal.path != calendar.path).toList();
            state = state.copyWith(selectedCalendars: updatedSelected);
            // AppLogger.info('CaldavSettingsViewModel: Calendar removed from sync: ${calendar.displayName}');
          },
          failure: (failure) async {
            AppLogger.error('CaldavSettingsViewModel: Failed to remove calendar', failure.exception, failure.stackTrace);
            state = state.copyWith(error: 'Failed to remove calendar: ${failure.message}');
          },
        );
      } else {
        // Add to selection
        final result = await _calendarRepository.save(calendar);
        await result.when(
          success: (_) async {
            final updatedSelected = [...state.selectedCalendars, calendar];
            state = state.copyWith(selectedCalendars: updatedSelected);
            // AppLogger.info('CaldavSettingsViewModel: Calendar added to sync: ${calendar.displayName}');
          },
          failure: (failure) async {
            AppLogger.error('CaldavSettingsViewModel: Failed to add calendar', failure.exception, failure.stackTrace);
            state = state.copyWith(error: 'Failed to add calendar: ${failure.message}');
          },
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('CaldavSettingsViewModel: Exception toggling calendar', e, stackTrace);
      state = state.copyWith(error: 'Failed to toggle calendar: $e');
    }
  }

  /// Create a new calendar on the server
  Future<void> createCalendar({
    required String name,
    required String description,
    String? color,
  }) async {
    final account = state.currentAccount;
    if (account == null) {
      state = state.copyWith(error: 'No active account configured');
      return;
    }

    // AppLogger.info('CaldavSettingsViewModel: Creating calendar: $name');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Create calendar using CalDAV service
      final newCalendar = TaskCalendarFactory.createNew(
        path: '/calendars/${account.username}/${name.toLowerCase().replaceAll(' ', '_')}/',
        displayName: name,
        description: description,
      );

      // TODO: Implement calendar creation in CalDAVService
      // For now, just add it locally
      final result = await _calendarRepository.save(newCalendar);
      await result.when(
        success: (_) async {
          final updatedAvailable = [...state.availableCalendars, newCalendar];
          final updatedSelected = [...state.selectedCalendars, newCalendar];
          
          state = state.copyWith(
            availableCalendars: updatedAvailable,
            selectedCalendars: updatedSelected,
            isLoading: false,
          );
          
          // AppLogger.info('CaldavSettingsViewModel: Calendar created successfully: $name');
        },
        failure: (failure) async {
          AppLogger.error('CaldavSettingsViewModel: Failed to create calendar', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to create calendar: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CaldavSettingsViewModel: Exception creating calendar', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create calendar: $e',
      );
    }
  }

  /// Test connection to the server
  Future<void> testConnection() async {
    final account = state.currentAccount;
    if (account == null) {
      state = state.copyWith(error: 'No active account configured');
      return;
    }

    // AppLogger.info('CaldavSettingsViewModel: Testing connection');
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      final caldavService = CalDAVService(account: account);
      final testResult = await caldavService.testConnection();
      
      await testResult.when(
        success: (capabilities) async {
          state = state.copyWith(
            isLoading: false,
            serverCapabilities: {
              'Connection': 'Success',
              'CalDAV Support': capabilities.supportsCalDAV ? 'Yes' : 'No',
              'Task Support': capabilities.supportsTasks ? 'Yes' : 'No',
              'Principal': capabilities.principal,
              'Calendar Home': capabilities.calendarHome,
              'Server': capabilities.serverInfo,
            },
          );
          // AppLogger.info('CaldavSettingsViewModel: Connection test successful');
        },
        failure: (failure) async {
          AppLogger.error('CaldavSettingsViewModel: Connection test failed', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isLoading: false,
            error: 'Connection test failed: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CaldavSettingsViewModel: Exception testing connection', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Connection test failed: $e',
      );
    }
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Check if a calendar is currently selected for sync
  bool isCalendarSelected(TaskCalendar calendar) {
    return state.selectedCalendars.any((cal) => cal.path == calendar.path);
  }

  /// Get the number of selected calendars
  int get selectedCalendarCount => state.selectedCalendars.length;

  /// Get the number of available calendars that support tasks
  int get taskSupportedCalendarCount => 
      state.availableCalendars.where((cal) => cal.supportsTodos).length;
} 
