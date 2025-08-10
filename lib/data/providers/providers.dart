// Main Riverpod providers for FlowIt state management
// Provides repositories, services, and global app state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/domain_service.dart';
import '../services/status_service.dart';
import '../repositories/task_repository.dart';
import '../../core/logger.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/external_account_repository.dart';
import '../repositories/external_calendar_repository.dart';
import '../repositories/external_event_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/kanban_repository.dart';
import '../repositories/step_repository.dart';
import '../models/task.dart';
import '../models/task_calendar.dart';
import '../models/caldav_account.dart';
import '../models/external_caldav_account.dart';
import '../models/external_calendar.dart';
import '../models/calendar_event.dart';
import '../models/category.dart';
import '../services/caldav_service.dart';
import '../services/external_caldav_service.dart';
import '../services/external_sync_service.dart';
import '../services/export_import_service.dart';
import '../services/offline_file_service.dart';
import '../services/file_upload_queue_service.dart';
import '../services/connection_monitor_service.dart';
import '../services/user_sync_service.dart';
import '../services/user_preferences_queue_service.dart';
import '../services/caldav_monitor.dart';
import '../../core/app_lifecycle_manager.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/viewmodels/task_viewmodel.dart';
import '../../presentation/viewmodels/caldav_settings_viewmodel.dart';

import '../../presentation/viewmodels/project_list_viewmodel.dart';
import '../../presentation/viewmodels/validator_viewmodel.dart';
import '../../presentation/viewmodels/task_file_attachment_viewmodel.dart';
import '../../presentation/viewmodels/task_media_attachment_viewmodel.dart';
import '../../presentation/viewmodels/category_viewmodel.dart';
import '../../presentation/viewmodels/project_kanban_viewmodel.dart';
import '../../presentation/viewmodels/project_sharing_viewmodel.dart';
import '../../presentation/viewmodels/step_viewmodel.dart';
import '../services/kanban_service.dart';
import '../../app.dart';
import '../services/share_service.dart';
import '../services/users_api_service.dart';
import '../models/user_preferences.dart';
import '../services/workflow_service.dart';
import '../models/step.dart';

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
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return LocalCalendarRepository(storageService, accountRepository, userRepository);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalAccountRepository(storageService);
});

// User repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return LocalUserRepository(storageService);
});

// User sync service provider
final userSyncServiceProvider = Provider<UserSyncService>((ref) {
  final userSyncService = UserSyncService(
    userRepository: ref.watch(userRepositoryProvider),
    externalAccountRepository: ref.watch(externalAccountRepositoryProvider),
    externalCalendarRepository: ref.watch(externalCalendarRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
  );

  // Set up callback to invalidate user preferences provider when preferences are updated
  userSyncService.setPreferencesUpdateCallback(() {
    AppLogger.debug('Providers: Invalidating user preferences and project list providers');
    AppLogger.debug('Providers: Invalidating userPreferencesProvider');
    ref.invalidate(userPreferencesProvider);
    AppLogger.debug('Providers: Invalidating projectListProvider');
    ref.invalidate(projectListProvider);
    AppLogger.debug('Providers: Invalidating activeCalendarListProvider');
    ref.invalidate(activeCalendarListProvider);
    AppLogger.debug('Providers: Invalidating calendarListProvider');
    ref.invalidate(calendarListProvider);
    // Also invalidate providers that depend on user preferences
    AppLogger.debug('Providers: Invalidating projectSharedNotificationProvider');
    ref.invalidate(projectSharedNotificationProvider);
    AppLogger.debug('Providers: Invalidating projectSharedByProvider');
    ref.invalidate(projectSharedByProvider);
    AppLogger.debug('Providers: All provider invalidations completed');
  });
  
  AppLogger.debug('Providers: UserSyncService provider created with callback set');
  return userSyncService;
});

// User preferences queue service provider
final userPreferencesQueueServiceProvider = Provider<UserPreferencesQueueService>((ref) {
  return UserPreferencesQueueService(
    userRepository: ref.watch(userRepositoryProvider),
    userSyncService: ref.watch(userSyncServiceProvider),
    localStorage: ref.watch(localStorageServiceProvider),
  );
});

// User preferences queue setup provider - sets up queue callback after both providers are created
final userPreferencesQueueSetupProvider = Provider<void>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  final userPreferencesQueueService = ref.watch(userPreferencesQueueServiceProvider);
  
  // Set up queue callback after both providers are available
  if (userRepository is LocalUserRepository) {
    userRepository.setQueueCallback((preferences) async {
      await userPreferencesQueueService.queueUserPreferencesUpdate(preferences);
    });
  }
  
  return;
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

// Category repository provider
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return CategoryRepository(calendarRepository, accountRepository);
});

// Step repository provider
final stepRepositoryProvider = Provider<StepRepository>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  return StepRepository(calendarRepository, taskRepository);
});

// Kanban service provider
final kanbanServiceProvider = Provider<KanbanService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return KanbanService(
    calendarRepository: calendarRepository,
    accountRepository: accountRepository,
  );
});

// Kanban repository provider
final kanbanRepositoryProvider = Provider<KanbanRepository>((ref) {
  final kanbanService = ref.watch(kanbanServiceProvider);
  return LocalKanbanRepository(kanbanService);
});

// CalDAV service provider  
final caldavServiceProvider = Provider.family<CalDAVService, CaldavAccount>((ref, account) {
  return CalDAVService(account: account);
});

// Workflow service provider
final workflowServiceProvider = Provider<WorkflowService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final service = WorkflowService(calendarRepository);
  // Inject step repository for default step creation in conversions
  service.setStepRepository(ref.watch(stepRepositoryProvider));
  return service;
});

// External CalDAV service provider
final externalCalDAVServiceProvider = Provider.family<ExternalCalDAVService, ExternalCaldavAccount>((ref, account) {
  return ExternalCalDAVService(account: account);
});

// Offline file service provider
final offlineFileServiceProvider = Provider<OfflineFileService>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  return OfflineFileService(storageService);
});

/// File upload queue service provider
final fileUploadQueueServiceProvider = Provider<FileUploadQueueService>((ref) {
  return FileUploadQueueService(
    localStorage: ref.watch(localStorageServiceProvider),
    offlineFileService: ref.watch(offlineFileServiceProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    connectionMonitorService: ref.watch(connectionMonitorServiceProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

// Connection monitor service provider
final connectionMonitorServiceProvider = Provider<ConnectionMonitorService>((ref) {
  return ConnectionMonitorService();
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

// Sharing service provider
final shareServiceProvider = Provider.family<ShareService, CaldavAccount>((ref, account) {
  return ShareService(account: account);
});

// Users API service provider
final usersApiServiceProvider = Provider.family<UsersApiService, CaldavAccount>((ref, account) {
  return UsersApiService(account: account);
});

// Global navigator key for session expiry navigation
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();
BuildContext? get globalContext => globalNavigatorKey.currentContext;

// Session epoch provider to force GoRouter refresh on session expiry
final sessionEpochProvider = StateProvider<int>((ref) => 0);

/// Global session expiry handler: navigates to /connect and invalidates account providers.
void handleSessionExpired([ProviderRef? ref]) {
  final context = globalContext;
  if (context != null && context.mounted) {
    GoRouter.of(context).go('/connect');
  }
  // Invalidate main account providers so UI updates
  if (ref != null) {
    ref.invalidate(activeAccountProvider);
    ref.invalidate(hasActiveAccountProvider);
    ref.invalidate(accountStatusNotifierProvider);
    // Force GoRouter to refresh
    ref.read(sessionEpochProvider.notifier).state++;
  }
}

// Sync service provider - initializes singleton
final syncServiceProvider = Provider<SyncService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  
  // Initialize singleton instance
  final syncService = SyncService(
    taskRepository: taskRepository,
    accountRepository: accountRepository,
    calendarRepository: calendarRepository,
    categoryRepository: categoryRepository,
    userRepository: userRepository,
    localStorage: localStorage,
  );
  
  // Inject sync service into repository for sync coordination
  if (taskRepository is LocalTaskRepository) {
    taskRepository.setSyncService(syncService);
  }
  
  return syncService;
});

// CalDAV Monitor provider
final caldavMonitorProvider = Provider<CalDAVMonitor>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  final externalAccountRepository = ref.watch(externalAccountRepositoryProvider);

  final connectionMonitorService = ref.watch(connectionMonitorServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  final userSyncService = ref.watch(userSyncServiceProvider);
  final userPreferencesQueueService = ref.watch(userPreferencesQueueServiceProvider);
  
  AppLogger.debug('Providers: Creating CalDAVMonitor with injected UserSyncService');
  
  return CalDAVMonitor(
    accountRepository: accountRepository,
    calendarRepository: calendarRepository,
    categoryRepository: categoryRepository,
    userRepository: userRepository,
    externalAccountRepository: externalAccountRepository,
    connectionMonitorService: connectionMonitorService,
    syncService: syncService,
    userSyncService: userSyncService,
    userPreferencesQueueService: userPreferencesQueueService,
  );
});

// Domain service provider
final domainServiceProvider = Provider<DomainService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  return DomainService(calendarRepository, localStorageService, ref.watch(accountRepositoryProvider));
});

// Status service provider
final statusServiceProvider = Provider<StatusService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  return StatusService(calendarRepository, localStorageService);
});

// Available domains provider - watches calendar changes to update domain list
final availableDomainsProvider = FutureProvider<List<String>>((ref) async {
  final domainService = ref.watch(domainServiceProvider);
  
  // Watch calendar list to refresh domains when calendars change
  ref.watch(calendarListProvider);
  
  final result = await domainService.getAvailableDomains();
  return result.when(
    success: (domains) => domains,
    failure: (failure) => <String>[],
  );
});

// Export/Import service provider
final exportImportServiceProvider = Provider<ExportImportService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return ExportImportService(
    calendarRepository: calendarRepository,
    taskRepository: taskRepository,
    localStorage: localStorage,
    accountRepository: accountRepository,
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
  final externalSyncService = ref.watch(externalCalendarSyncServiceProvider);
  final fileUploadQueueService = ref.watch(fileUploadQueueServiceProvider);
  final connectionMonitorService = ref.watch(connectionMonitorServiceProvider);
  final userSyncService = ref.watch(userSyncServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  
  // Initialize user preferences queue setup
  ref.watch(userPreferencesQueueSetupProvider);

  final caldavMonitor = ref.watch(caldavMonitorProvider);

  final result = await lifecycleManager.initialize(
    syncService: syncService,
    caldavMonitor: caldavMonitor,
    externalSyncService: externalSyncService,
    fileUploadQueueService: fileUploadQueueService,
    connectionMonitorService: connectionMonitorService,
    userSyncService: userSyncService,
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
  return TaskViewModel(taskRepository, accountRepository);
});

final caldavSettingsViewModelProvider = StateNotifierProvider<CaldavSettingsViewModel, CaldavSettingsState>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return CaldavSettingsViewModel(accountRepository, calendarRepository);
});



// Project list view model provider is declared later to co-locate with workflow variant

final validatorViewModelProvider = StateNotifierProvider.family<ValidatorViewModel, ValidatorViewModelState, String>((ref, taskUid) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return ValidatorViewModel(taskRepository, accountRepository);
});

// Task file attachment ViewModel provider for managing file attachments per task
final taskFileAttachmentViewModelProvider = StateNotifierProvider.family<TaskFileAttachmentViewModel, TaskFileAttachmentState, String>((ref, taskUid) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final offlineFileService = ref.watch(offlineFileServiceProvider);
  final fileUploadQueueService = ref.watch(fileUploadQueueServiceProvider);
  return TaskFileAttachmentViewModel(
    taskRepository: taskRepository,
    accountRepository: accountRepository,
    offlineFileService: offlineFileService,
    fileUploadQueueService: fileUploadQueueService,
  );
});

// Task media attachment ViewModel provider for managing media attachments per task
final taskMediaAttachmentViewModelProvider = StateNotifierProvider.family<TaskMediaAttachmentViewModel, TaskMediaAttachmentState, String>((ref, taskUid) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final offlineFileService = ref.watch(offlineFileServiceProvider);
  final fileUploadQueueService = ref.watch(fileUploadQueueServiceProvider);
  return TaskMediaAttachmentViewModel(
    taskUid,
    taskRepository,
    accountRepository,
    offlineFileService,
    fileUploadQueueService,
  );
});

// Category ViewModel provider
final categoryViewModelProvider = StateNotifierProvider<CategoryViewModel, CategoryViewModelState>((ref) {
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  return CategoryViewModel(categoryRepository);
});

// Category ViewModel provider for specific project
final projectCategoryViewModelProvider = StateNotifierProvider.family<CategoryViewModel, CategoryViewModelState, String>((ref, projectPath) {
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final viewModel = CategoryViewModel(categoryRepository);
  // Initialize with project path
  viewModel.initialize(projectPath);
  return viewModel;
});

// Step ViewModel provider for specific project
final projectStepViewModelProvider = StateNotifierProvider.family<StepViewModel, StepViewModelState, String>((ref, projectPath) {
  final stepRepository = ref.watch(stepRepositoryProvider);
  final viewModel = StepViewModel(stepRepository);
  viewModel.initialize(projectPath);
  return viewModel;
});

// Project Kanban ViewModel provider for specific project
final projectKanbanViewModelProvider = StateNotifierProvider.family<ProjectKanbanViewModel, ProjectKanbanState, String>((ref, projectPath) {
  final kanbanRepository = ref.watch(kanbanRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final viewModel = ProjectKanbanViewModel(
    kanbanRepository,
    categoryRepository,
  );
  // Initialize with project path
  viewModel.initialize(projectPath);
  return viewModel;
});

// Project Sharing ViewModel provider
final projectSharingViewModelProvider = StateNotifierProvider<ProjectSharingViewModel, ProjectSharingState>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return ProjectSharingViewModel(accountRepository, calendarRepository);
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
  return repository.watchCalendars().asyncMap((watchedCalendars) async {
    AppLogger.info('ActiveCalendarListProvider: DEBUG - Received ${watchedCalendars.length} calendars from watchCalendars');
    final result = await repository.getProjectCalendars();
    return result.when(
      success: (calendars) {
        AppLogger.info('ActiveCalendarListProvider: DEBUG - getProjectCalendars returned ${calendars.length} calendars');
        // Filter out archived calendars
        final activeCalendars = calendars.where((calendar) => !calendar.isArchived).toList();
        AppLogger.info('ActiveCalendarListProvider: DEBUG - After filtering archived: ${activeCalendars.length} calendars');
        
        // Deduplicate calendars by UID to prevent shared projects from appearing twice
        final seen = <String>{};
        final deduplicatedCalendars = <TaskCalendar>[];
        
        for (final calendar in activeCalendars) {
          final uid = calendar.uid;
          if (!seen.contains(uid)) {
            seen.add(uid);
            deduplicatedCalendars.add(calendar);
          } else {
            AppLogger.debug('CalendarListProvider: Filtered duplicate calendar with UID: $uid (path: ${calendar.path})');
          }
        }
        
        AppLogger.info('ActiveCalendarListProvider: DEBUG - Final deduped list: ${deduplicatedCalendars.length} calendars');
        for (final cal in deduplicatedCalendars) {
          AppLogger.info('  - ${cal.displayName} | Path: ${cal.path} | UID: ${cal.uid}');
        }
        return deduplicatedCalendars;
      },
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

// Unified project-specific tasks provider
final projectTasksProvider = StreamProvider.family<List<Task>, String>((ref, projectPath) {
  final taskRepository = ref.read(taskRepositoryProvider);
  final categoryRepository = ref.read(categoryRepositoryProvider);
  final stepRepository = ref.read(stepRepositoryProvider);
  
  return taskRepository.watchTasks().asyncMap((allTasks) async {
    // Encode special characters in the project path to match encoded storage format
    final encodedProjectPath = projectPath.replaceAll('@', '%40');
    
    // Filter tasks by their project path (Calendar = Project model)
    final projectTasks = allTasks
        .where((task) => task.projectPath == encodedProjectPath)
        .toList();
    
    // Get project categories to filter task categoryIds
    final projectCategoriesResult = await categoryRepository.getProjectCategories(encodedProjectPath);
    final projectCategories = await projectCategoriesResult.when(
      success: (categories) async => categories,
      failure: (_) async => <Category>[],
    );
    
    // Create a set of valid category IDs for this project
    final validCategoryIds = projectCategories.map((cat) => cat.id).toSet();
    
    // Filter out invalid category IDs from tasks
    final filteredTasks = projectTasks.map((task) {
      final validTaskCategoryIds = task.categoryIds
          .where((categoryId) => validCategoryIds.contains(categoryId))
          .toList();
      
      // Only update the task if category IDs were filtered out
      if (validTaskCategoryIds.length != task.categoryIds.length) {
        AppLogger.debug('TaskProvider: Filtered categories for task ${task.summary}: '
                       'from ${task.categoryIds} to $validTaskCategoryIds');
        return task.copyWith(categoryIds: validTaskCategoryIds);
      }
      return task;
    }).toList();
    
    Future.microtask(() => stepRepository.recomputeProjectSteps(encodedProjectPath));
    return filteredTasks;
  });
});

// Deprecated: Keep for backward compatibility
final unregisteredTasksProvider = anytimeTasksProvider;

// Backward compatibility alias - use active calendars for navbar
final projectListProvider = activeCalendarListProvider;

// ViewModel providers for listing projects vs workflows (MVVM)
final projectListViewModelProvider = StateNotifierProvider<ProjectListViewModel, ProjectListState>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return ProjectListViewModel(calendarRepository, taskRepository, accountRepository, userRepository, workflowsMode: false);
});

final workflowListViewModelProvider = StateNotifierProvider<ProjectListViewModel, ProjectListState>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return ProjectListViewModel(calendarRepository, taskRepository, accountRepository, userRepository, workflowsMode: true);
});

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
        final result = await syncService.syncAllActiveCaldav();
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
    final events = eventsAsync.value ?? const <CalendarEvent>[];
    final enabledCalendars = enabledCalendarsAsync.value ?? const <ExternalCalendar>[];
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

// Simple search state for project task filtering
final projectSearchQueryProvider = StateProvider.family<String, String>((ref, projectPath) => '');

// Provider for filtered tasks within a specific project based on search query
final filteredProjectTasksProvider = Provider.family<List<Task>, String>((ref, projectPath) {
  final projectTasksAsync = ref.watch(projectTasksProvider(projectPath));
  final searchQuery = ref.watch(projectSearchQueryProvider(projectPath));
  
  final allTasks = projectTasksAsync.maybeWhen(
    data: (tasks) => tasks,
    orElse: () => <Task>[],
  );
  
  if (searchQuery.trim().isEmpty) {
    return allTasks;
  }

  final searchLower = searchQuery.toLowerCase();
  
  final filteredTasks = allTasks.where((task) {
    final summaryMatch = task.summary.toLowerCase().contains(searchLower);
    final descriptionMatch = task.description.toLowerCase().contains(searchLower);
    final categoriesMatch = task.categoryIds.any(
      (categoryId) => categoryId.toLowerCase().contains(searchLower),
    );
    
    return summaryMatch || descriptionMatch || categoriesMatch;
  }).toList();
  
  return filteredTasks;
});

final projectStepsProvider = FutureProvider.family<List<ProjectStep>, String>((ref, projectPath) async {
  // Watch calendar list to refresh when calendars change (sync/import)
  ref.watch(calendarListProvider);

  final stepRepository = ref.watch(stepRepositoryProvider);
  // Ensure encoded path consistency
  final encodedProjectPath = projectPath.replaceAll('@', '%40');
  final result = await stepRepository.getProjectSteps(encodedProjectPath);
  return await result.when(
    success: (steps) async {
      if (steps.isNotEmpty) return steps;
      // Auto-heal: create a default step when none exist (mirrors category pattern resilience)
      await stepRepository.ensureDefaultStep(encodedProjectPath);
      final secondTry = await stepRepository.getProjectSteps(encodedProjectPath);
      return secondTry.when(
        success: (s) => s,
        failure: (_) => <ProjectStep>[],
      );
    },
    failure: (_) async => <ProjectStep>[],
  );
});

// Project sharing notification provider - reactive to user preferences changes
final projectSharedNotificationProvider = Provider.family<AsyncValue<bool>, String>((ref, projectId) {
  final userPreferencesAsync = ref.watch(userPreferencesProvider);
  
  return userPreferencesAsync.when(
    data: (preferences) {
      final sharedProject = preferences.getSharedProject(projectId);
      final hasNotification = sharedProject != null && !sharedProject.ack;
      return AsyncValue.data(hasNotification);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// Shared project source provider - reactive to user preferences changes  
final projectSharedByProvider = Provider.family<AsyncValue<String>, String>((ref, projectId) {
  final userPreferencesAsync = ref.watch(userPreferencesProvider);
  
  return userPreferencesAsync.when(
    data: (preferences) {
      final sharedProject = preferences.getSharedProject(projectId);
      final sourceEmail = sharedProject?.sourceUserEmail ?? '';
      return AsyncValue.data(sourceEmail);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

// User preferences provider - watches user repository for changes
final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.watchUserPreferences();
});
