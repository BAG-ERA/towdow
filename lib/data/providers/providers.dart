// Main Riverpod providers for FlowIt state management
// Provides repositories, services, and global app state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/background_sync_service.dart';
import '../repositories/task_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import '../models/task.dart';
import '../models/task_calendar.dart';
import '../models/caldav_account.dart';
import '../services/caldav_service.dart';
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

// CalDAV service provider  
final caldavServiceProvider = Provider.family<CalDAVService, CaldavAccount>((ref, account) {
  return CalDAVService(account: account);
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
  return ProjectListViewModel(calendarRepository, taskRepository, syncService);
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

// Today's tasks provider (not done with due date < 24h, including overdue)
final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final in24Hours = now.add(const Duration(hours: 24));
    
    final todayTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      // Include overdue tasks (due date in the past) and tasks due within 24h
      return task.due!.isBefore(in24Hours);
    }).toList();
    return todayTasks;
  });
});

// Soon tasks provider (not done with due date > 24h and < 7 days)
final soonTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final in24Hours = now.add(const Duration(hours: 24));
    final in7Days = now.add(const Duration(days: 7));
    
    final soonTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      return task.due!.isAfter(in24Hours) && task.due!.isBefore(in7Days);
    }).toList();
    return soonTasks;
  });
});

// Later tasks provider (not done with due date > 7 days)
final laterTasksProvider = StreamProvider<List<Task>>((ref) {
  final tasksStream = ref.watch(taskListProvider.stream);
  return tasksStream.map((tasks) {
    final now = DateTime.now();
    final in7Days = now.add(const Duration(days: 7));
    
    final laterTasks = tasks.where((task) {
      if (task.status == 'COMPLETED') return false;
      if (task.due == null) return false;
      return task.due!.isAfter(in7Days);
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

// Backward compatibility alias
final projectListProvider = calendarListProvider;

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
