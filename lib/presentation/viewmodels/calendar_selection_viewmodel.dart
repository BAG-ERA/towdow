import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import '../../data/models/task_calendar.dart';
import '../../data/models/caldav_account.dart';
import '../../data/services/caldav_service.dart';
import '../../data/services/capability_discovery_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/external_account_repository.dart';
import '../../data/repositories/external_calendar_repository.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/user_sync_service.dart';
import '../../data/providers/providers.dart';

// State object
class CalendarSelectionState {
  final bool isLoading;
  final String? error;
  final List<TaskCalendar> availableCalendars;
  final List<TaskCalendar> selectedCalendars;
  final CaldavAccount? account;

  const CalendarSelectionState({
    this.isLoading = false,
    this.error,
    this.availableCalendars = const [],
    this.selectedCalendars = const [],
    this.account,
  });

  CalendarSelectionState copyWith({
    bool? isLoading,
    String? error,
    List<TaskCalendar>? availableCalendars,
    List<TaskCalendar>? selectedCalendars,
    CaldavAccount? account,
  }) => CalendarSelectionState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        availableCalendars: availableCalendars ?? this.availableCalendars,
        selectedCalendars: selectedCalendars ?? this.selectedCalendars,
        account: account ?? this.account,
      );
}

/// ViewModel responsible for creating a new calendar (portfolio) during first-run connection
class CalendarSelectionViewModel extends StateNotifier<CalendarSelectionState> {
  final CaldavAccount _account;
  final CalDAVService _caldavService;
  final CapabilityDiscoveryService _discoveryService;
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final LocalStorageService _localStorageService;
  final void Function()? onInvalidateProjectList;

  CalendarSelectionViewModel({
    required CaldavAccount account,
    required CalDAVService caldavService,
    required CapabilityDiscoveryService discoveryService,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required LocalStorageService localStorageService,
    this.onInvalidateProjectList,
  })  : _account = account,
        _caldavService = caldavService,
        _discoveryService = discoveryService,
        _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _localStorageService = localStorageService,
        super(const CalendarSelectionState());

  Future<void> loadAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _accountRepository.getActiveAccount();
      await result.when(
        success: (account) async {
          state = state.copyWith(account: account);
        },
        failure: (failure) async {
          state = state.copyWith(error: 'Failed to load account: ${failure.message}');
        },
      );
    } catch (e, st) {
      AppLogger.error('CalendarSelectionViewModel: Exception loading account', e, st);
      state = state.copyWith(error: 'Unexpected error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> discoverCalendars() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _discoveryService.discoverCapabilities();
      await result.when(
        success: (discovery) async {
          state = state.copyWith(availableCalendars: discovery.availableCalendars);
        },
        failure: (failure) async {
          state = state.copyWith(error: 'Failed to discover calendars: ${failure.message}');
        },
      );
    } catch (e, st) {
      AppLogger.error('CalendarSelectionViewModel: Exception discovering calendars', e, st);
      state = state.copyWith(error: 'Unexpected error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleCalendarSelection(TaskCalendar calendar) {
    final selected = List<TaskCalendar>.from(state.selectedCalendars);
    if (selected.contains(calendar)) {
      selected.remove(calendar);
    } else {
      selected.add(calendar);
    }
    state = state.copyWith(selectedCalendars: selected);
  }

  void selectAllCalendars() {
    state = state.copyWith(selectedCalendars: List.from(state.availableCalendars));
  }

  void deselectAllCalendars() {
    state = state.copyWith(selectedCalendars: []);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> saveSelection() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Save account
      final accountResult = await _accountRepository.save(_account);
      await accountResult.when(
        success: (_) async {
          // Save selected calendars
          for (final calendar in state.selectedCalendars) {
            final calendarResult = await _calendarRepository.save(calendar);
            calendarResult.when(
              success: (_) {},
              failure: (f) => AppLogger.error('Save calendar failed', f.exception, f.stackTrace),
            );
          }
          // Set setup completed flag using the generic put method
          await _localStorageService.put('user_preferences', 'setup_completed', true);
        },
        failure: (f) async {
          state = state.copyWith(error: 'Failed to save selection: ${f.message}');
        },
      );
    } catch (e, st) {
      AppLogger.error('CalendarSelectionViewModel: Exception saving selection', e, st);
      state = state.copyWith(error: 'Unexpected error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void addCalendar(TaskCalendar calendar) {
    if (!state.selectedCalendars.contains(calendar)) {
      final updated = [...state.selectedCalendars, calendar];
      state = state.copyWith(selectedCalendars: updated);
    }
  }

  void removeCalendar(TaskCalendar calendar) {
    final updated = state.selectedCalendars.where((cal) => cal != calendar).toList();
    state = state.copyWith(selectedCalendars: updated);
  }

  Future<void> createCalendar({required String name, String? description}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _caldavService.createCalendar(
        displayName: name,
        description: description ?? 'Project portfolio created by FlowIt',
      );
      await result.when(
        success: (calendar) async {
          final updated = [...state.selectedCalendars, calendar];
          state = state.copyWith(selectedCalendars: updated);
        },
        failure: (failure) async {
          state = state.copyWith(error: 'Failed to create portfolio: ${failure.message}');
        },
      );
    } catch (e, st) {
      AppLogger.error('CalendarSelectionViewModel: Exception creating calendar', e, st);
      state = state.copyWith(error: 'Unexpected error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> finishSetup(CaldavAccount account) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final saveResult = await _accountRepository.save(account);
      await saveResult.when(
        success: (_) async {
          await _saveCalendarsAsProjects();
          
          // Trigger user sync upload for cloud/self-hosted users
          await _triggerUserSyncUpload();
        },
        failure: (f) async {
          state = state.copyWith(error: 'Failed to save setup: ${f.message}');
        },
      );
    } catch (e, st) {
      AppLogger.error('CalendarSelectionViewModel: Exception in finishSetup', e, st);
      state = state.copyWith(error: 'Unexpected error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveCalendarsAsProjects() async {
    // Clear old
    final clearResult = await _localStorageService.clear(LocalStorageService.calendarsBoxName);
    clearResult.when(
      success: (_) {},
      failure: (f) => AppLogger.warning('CalendarSelection: failed clear: ${f.message}'),
    );

    for (final cal in state.selectedCalendars) {
      final res = await _calendarRepository.save(cal);
      res.when(
        success: (_) {},
        failure: (f) => AppLogger.error('Save calendar failed', f.exception, f.stackTrace),
      );
    }

    if (onInvalidateProjectList != null) {
      onInvalidateProjectList!();
    }
  }

  /// Trigger user sync upload for cloud/self-hosted users
  Future<void> _triggerUserSyncUpload() async {
    try {
      // Create a temporary UserSyncService to trigger upload
      final userRepository = LocalUserRepository(_localStorageService);
      final externalAccountRepository = LocalExternalAccountRepository(_localStorageService);
      final externalCalendarRepository = LocalExternalCalendarRepository(_localStorageService);
      final calendarRepository = LocalCalendarRepository(_localStorageService);
      
      final userSyncService = UserSyncService(
        userRepository: userRepository,
        externalAccountRepository: externalAccountRepository,
        externalCalendarRepository: externalCalendarRepository,
        accountRepository: _accountRepository,
        calendarRepository: calendarRepository,
      );
      
      final syncAvailable = await userSyncService.isSyncAvailable();
      if (syncAvailable) {
        final uploadResult = await userSyncService.uploadUserData();
        uploadResult.when(
          success: (_) {
            AppLogger.info('CalendarSelection: Successfully uploaded user data to S3');
          },
          failure: (failure) {
            AppLogger.warning('CalendarSelection: Failed to sync user data: ${failure.message}');
          },
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalendarSelection: Error triggering user sync upload', e, stackTrace);
    }
  }
}

// Provider factory
final calendarSelectionViewModelProvider = StateNotifierProvider.autoDispose.family<CalendarSelectionViewModel, CalendarSelectionState, CaldavAccount>(
  (ref, account) => CalendarSelectionViewModel(
    account: account,
    caldavService: CalDAVService(account: account),
    discoveryService: CapabilityDiscoveryService(account: account),
    accountRepository: ref.read(accountRepositoryProvider),
    calendarRepository: ref.read(calendarRepositoryProvider),
    localStorageService: ref.read(localStorageServiceProvider),
    onInvalidateProjectList: () => ref.invalidate(projectListProvider),
  ),
); 