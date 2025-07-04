// Main Riverpod providers for FlowIt state management
// Provides repositories, services, and global app state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/background_sync_service.dart';
import '../services/domain_service.dart';
import '../services/status_service.dart';
import '../repositories/task_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/external_account_repository.dart';
import '../repositories/external_calendar_repository.dart';
import '../repositories/external_event_repository.dart';
import '../models/task.dart';
import '../models/task_calendar.dart';
import '../models/caldav_account.dart';
import '../models/external_caldav_account.dart';
import '../models/external_calendar.dart';
import '../models/calendar_event.dart';
import '../services/caldav_service.dart';
import '../services/external_caldav_service.dart';
import '../services/external_sync_service.dart';
import '../../core/app_lifecycle_manager.dart';

import '../../presentation/viewmodels/task_viewmodel.dart';
import '../../presentation/viewmodels/caldav_settings_viewmodel.dart';
import '../../presentation/viewmodels/navbar_sync_viewmodel.dart';
import '../../presentation/viewmodels/project_list_viewmodel.dart';
import '../../presentation/viewmodels/validator_viewmodel.dart';

// Local storage service provider
// This must be overridden in main.dart with an initialized instance
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'LocalStorageService must be provided via ProviderScope override in main.dart'
  );
});

// Repository providers
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalTaskRepository(storageService);
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalCalendarRepository(storageService);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalAccountRepository(storageService);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalUserRepository(storageService);
});

// External calendar repository providers
final externalAccountRepositoryProvider = Provider<ExternalAccountRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalExternalAccountRepository(storageService);
});

final externalCalendarRepositoryProvider = Provider<ExternalCalendarRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalExternalCalendarRepository(storageService);
});

final externalEventRepositoryProvider = Provider<ExternalEventRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalExternalEventRepository(storageService);
});

// CalDAV service provider  
final caldavServiceProvider = Provider.family<CalDAVService, CaldavAccount>((ref, account) {
  return CalDAVService(account: account);
});

// External CalDAV service provider
final externalCalDAVServiceProvider = Provider.family<ExternalCalDAVService, ExternalCaldavAccount>((ref, account) {
  return ExternalCalDAVService(account: account);
});

// External calendar sync service provider
final externalCalendarSyncServiceProvider = Provider<ExternalCalendarSyncService>((ref) {
  final accountRepository = ref.watch(externalAccountRepositoryProvider);
  final calendarRepository = ref.watch(externalCalendarRepositoryProvider);
  final eventRepository = ref.watch(externalEventRepositoryProvider);
  
  return ExternalCalendarSyncService(
    accountRepository,
    calendarRepository,
    eventRepository,
  );
});

// Background sync service provider
final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  
  return BackgroundSyncService(
    taskRepository: taskRepository,
    accountRepository: accountRepository,
    calendarRepository: calendarRepository,
  );
});

// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  
  return SyncService(
    taskRepository: taskRepository,
    accountRepository: accountRepository,
    calendarRepository: calendarRepository,
    localStorage: localStorage,
  );
});

// Domain service provider
final domainServiceProvider = Provider<DomainService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return DomainService(calendarRepository, localStorageService, accountRepository);
});

// Status service provider
final statusServiceProvider = Provider<StatusService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return StatusService(calendarRepository, localStorageService, accountRepository);
});

// App Lifecycle Manager provider
final appLifecycleManagerProvider = Provider<AppLifecycleManager>((ref) {
  return AppLifecycleManager.instance;
});

// App Lifecycle Manager initialization provider
final appLifecycleInitializationProvider = FutureProvider<void>((ref) async {
  final lifecycleManager = ref.watch(appLifecycleManagerProvider);
  final syncService = ref.watch(syncServiceProvider);
  final backgroundSyncService = ref.watch(backgroundSyncServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);

  final result = await lifecycleManager.initialize(
    syncService: syncService,
    backgroundSyncService: backgroundSyncService,
    accountRepository: accountRepository,
  );

  await result.when(
    success: (_) async {
      // AppLifecycleManager initialized successfully
    },
    failure: (failure) async {
      throw Exception(failure.message);
    },
  );
});

// App Lifecycle State provider
final appLifecycleStateProvider = StreamProvider<FlowItAppState>((ref) {
  final lifecycleManager = ref.watch(appLifecycleManagerProvider);
  return lifecycleManager.stateStream;
});

// ViewModel providers
final taskViewModelProvider = StateNotifierProvider<TaskViewModel, TaskViewModelState>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return TaskViewModel(taskRepository, accountRepository, syncService);
});

final caldavSettingsViewModelProvider = StateNotifierProvider<CaldavSettingsViewModel, CaldavSettingsState>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return CaldavSettingsViewModel(accountRepository, calendarRepository);
});

final navbarSyncViewModelProvider = StateNotifierProvider<NavbarSyncViewModel, NavbarSyncState>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return NavbarSyncViewModel(accountRepository, syncService);
});

final projectListViewModelProvider = StateNotifierProvider<ProjectListViewModel, ProjectListState>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  final domainService = ref.watch(domainServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return ProjectListViewModel(calendarRepository, taskRepository, syncService, domainService, accountRepository, userRepository);
});

final validatorViewModelProvider = StateNotifierProvider<ValidatorViewModel, ValidatorViewModelState>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return ValidatorViewModel(taskRepository, accountRepository, syncService);
});

// Account status providers
final hasActiveAccountProvider = FutureProvider<bool>((ref) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final result = await accountRepository.hasActiveAccount();
  return result.when(
    success: (hasAccount) => hasAccount,
    failure: (failure) => false, // Assume no account on error
  );
});

final activeAccountProvider = FutureProvider<CaldavAccount?>((ref) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final result = await accountRepository.getActiveAccount();
  return result.when(
    success: (account) => account,
    failure: (failure) => null,
  );
});

// State providers for data
final taskListProvider = StreamProvider<List<Task>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchTasks();
});

final calendarListProvider = StreamProvider<List<TaskCalendar>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  return repository.watchCalendars().asyncMap((_) async {
    final result = await repository.getProjectCalendars();
    return result.when(
      success: (calendars) => calendars,
      failure: (failure) => throw Exception(failure.message),
    );
  });
});

// Active calendars provider (excludes archived calendars)
final activeCalendarListProvider = StreamProvider<List<TaskCalendar>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  return repository.watchCalendars().asyncMap((_) async {
    final result = await repository.getProjectCalendars();
    return result.when(
      success: (calendars) => calendars.where((calendar) => !calendar.isArchived).toList(),
      failure: (failure) => throw Exception(failure.message),
    );
  });
});

// Helper function to find next Monday at 12AM
DateTime _getNextMondayMidnight(DateTime from) {
  final currentWeekday = from.weekday; // 1 = Monday, 7 = Sunday
  int daysUntilNextMonday;
  
  if (currentWeekday == DateTime.monday) {
    // If today is Monday, next Monday is 7 days away
    daysUntilNextMonday = 7;
  } else {
    // Calculate days until next Monday
    daysUntilNextMonday = (DateTime.monday + 7 - currentWeekday) % 7;
  }
  
  final nextMonday = from.add(Duration(days: daysUntilNextMonday));
  // Set to midnight (12AM)
  return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
}

// Helper function to get midnight of current day
DateTime _getTodayMidnight(DateTime from) {
  return DateTime(from.year, from.month, from.day);
}

// Today's tasks provider (not done with due date before 12AM of current day - overdue and due today)
final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final todayMidnight = _getTodayMidnight(now);
    final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));
    
    final todayTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      // Include overdue tasks (before today midnight) and tasks due today (before tomorrow midnight)
      return task.due!.isBefore(tomorrowMidnight);
    }).toList();
    return todayTasks;
  });
});

// Soon tasks provider (not done with due date between 12AM today and next Monday 12AM)
final soonTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final tomorrowMidnight = _getTodayMidnight(now).add(const Duration(days: 1));
    final nextMondayMidnight = _getNextMondayMidnight(now);
    
    final soonTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      return !task.due!.isBefore(tomorrowMidnight) && task.due!.isBefore(nextMondayMidnight);
    }).toList();
    return soonTasks;
  });
});

// Next week tasks provider (not done with due date between next Monday 12AM and Monday after 12AM)
final nextWeekTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final nextMondayMidnight = _getNextMondayMidnight(now);
    final mondayAfterNextMidnight = nextMondayMidnight.add(const Duration(days: 7));
    
    final nextWeekTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      return !task.due!.isBefore(nextMondayMidnight) && task.due!.isBefore(mondayAfterNextMidnight);
    }).toList();
    return nextWeekTasks;
  });
});

// Later tasks provider (not done with due date after Monday after next Monday 12AM)
final laterTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final nextMondayMidnight = _getNextMondayMidnight(now);
    final mondayAfterNextMidnight = nextMondayMidnight.add(const Duration(days: 7));
    
    final laterTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      return !task.due!.isBefore(mondayAfterNextMidnight);
    }).toList();
    return laterTasks;
  });
});

// Anytime tasks provider (not done without due date)
final anytimeTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final anytimeTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      return task.due == null;
    }).toList();
    return anytimeTasks;
  });
});

// Deprecated: Keep for backward compatibility
final unregisteredTasksProvider = anytimeTasksProvider;

// Backward compatibility alias - use active calendars for navbar
final projectListProvider = activeCalendarListProvider;

// Selected project provider  
final selectedProjectProvider = StateProvider<String?>((ref) => null);

// Selected task provider
final selectedTaskProvider = StateProvider<String?>((ref) => null);

// Real sync status stream provider using SyncService
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.statusStream;
});

// Current sync status provider
final currentSyncStatusProvider = Provider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.status;
});

// Manual sync trigger provider
final manualSyncProvider = FutureProvider.autoDispose<SyncResult>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  final result = await syncService.syncNow();
  return result.when(
    success: (syncResult) => syncResult,
    failure: (failure) => throw Exception(failure.message),
  );
});

// Server capabilities provider for account setup
final serverCapabilitiesProvider = FutureProvider.family.autoDispose<CalDAVCapabilities, CaldavAccount>((ref, account) async {
  final caldavService = CalDAVService(account: account);
  final result = await caldavService.testConnection();
  return result.when(
    success: (capabilities) => capabilities,
    failure: (failure) => throw Exception(failure.message),
  );
});

// External calendar data providers
final externalCalendarListProvider = StreamProvider<List<ExternalCalendar>>((ref) {
  final repository = ref.watch(externalCalendarRepositoryProvider);
  return repository.watchCalendars();
});

final externalEventListProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final repository = ref.watch(externalEventRepositoryProvider);
  return repository.watchEvents();
});

final enabledExternalCalendarListProvider = Provider<AsyncValue<List<ExternalCalendar>>>((ref) {
  final calendarsAsync = ref.watch(externalCalendarListProvider);
  return calendarsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (calendars) => AsyncValue.data(calendars.where((calendar) => calendar.isEnabled).toList()),
  );
});

final enabledExternalEventListProvider = Provider<AsyncValue<List<CalendarEvent>>>((ref) {
  final eventsAsync = ref.watch(externalEventListProvider);
  final enabledCalendarsAsync = ref.watch(enabledExternalCalendarListProvider);
  
  // Handle loading states
  if (eventsAsync.isLoading || enabledCalendarsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  
  // Handle error states
  if (eventsAsync.hasError) {
    return AsyncValue.error(eventsAsync.error!, eventsAsync.stackTrace!);
  }
  if (enabledCalendarsAsync.hasError) {
    return AsyncValue.error(enabledCalendarsAsync.error!, enabledCalendarsAsync.stackTrace!);
  }
  
  // Handle data
  if (eventsAsync.hasValue && enabledCalendarsAsync.hasValue) {
    final events = eventsAsync.value!;
    final enabledCalendars = enabledCalendarsAsync.value!;
    final enabledCalendarUids = enabledCalendars.map((cal) => cal.uid).toSet();
    final filteredEvents = events.where((event) => enabledCalendarUids.contains(event.sourceCalendarUid)).toList();
    return AsyncValue.data(filteredEvents);
  }
  
  return const AsyncValue.loading();
});

// DEBUG: Provider pour compter les tâches avec attendees
final tasksWithAttendeesProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  final allTasksResult = await repository.getAll();
  
  return allTasksResult.when(
    success: (tasks) {
      final stats = <String, int>{
        'total': tasks.length,
        'withAttendees': tasks.where((task) => task.attendees.isNotEmpty).length,
        'withoutAttendees': tasks.where((task) => task.attendees.isEmpty).length,
        'maxAttendees': tasks.isNotEmpty 
          ? tasks.map((task) => task.attendees.length).reduce((a, b) => a > b ? a : b)
          : 0,
      };
      return stats;
    },
    failure: (failure) => throw Exception(failure.message),
  );
}); 
