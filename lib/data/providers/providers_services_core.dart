// Core services providers (sync, status, workflow, storage-related services)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/result.dart';
import '../services/export_import_service.dart';
import '../services/kanban_service.dart';
import '../services/deeplink/deep_link_service.dart';
import '../services/workflow_service.dart';
import '../services/status_service.dart';
import '../services/storage/file_upload_queue_service.dart';
import '../services/storage/offline_file_service.dart';
import '../services/storage/media_cleanup_service.dart';
import '../services/storage/s3_storage_service.dart';
import '../services/vobject_service.dart';
import '../services/sync/connection_monitor_service.dart';
import '../services/sync/sync_orchestrator_service.dart';
import '../services/sync/sync_service.dart';
import '../services/user/user_preferences_queue_service.dart';
import '../services/user/external_account_queue_service.dart';
import '../services/user/user_sync_service.dart';
import '../services/user/users_api_service.dart';
import '../services/share/share_service.dart';
import '../services/share/sharing_sync_service.dart';
// import '../services/workflow_service.dart';
import '../models/caldav_account.dart';
import '../models/user_preferences.dart';
// step model not used directly here
// repositories are referenced via provider getters; direct types not needed here
import '../models/external_calendar.dart';
import '../models/calendar_event.dart';
import 'providers_repositories.dart';
import 'providers_project.dart';
import '../services/integration/external_caldav_calendar/external_sync_service.dart';
import 'providers_storage.dart';
// caldav service family is defined in providers_services_caldav
import '../services/domain_service.dart' as caldav_domain;
// import '../../core/app_lifecycle_manager.dart';
import '../../core/logger.dart';
import '../services/sync/sync_commander_provider.dart';
import '../services/storage/encryption_service.dart';

/// Feature flag: whether file features (S3, file/media validators, attachments)
/// are enabled for the current active account. Disabled for `providerType == 'custom'`.
final fileFeaturesEnabledProvider = Provider<bool>((ref) {
  final activeAccount = ref.watch(activeAccountProvider);
  return activeAccount.maybeWhen(
    data: (acc) => acc != null && acc.providerType != 'custom',
    orElse: () => false,
  );
});

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final offlineFileServiceProvider = Provider<OfflineFileService>((ref) {
  final storageService = ref.watch(localStorageServiceProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);
  return OfflineFileService(storageService, encryptionService);
});

final mediaCleanupServiceProvider = Provider<MediaCleanupService>((ref) {
  final offlineFileService = ref.watch(offlineFileServiceProvider);
  return MediaCleanupService(offlineFileService);
});

final fileUploadQueueServiceProvider = Provider<FileUploadQueueService>((ref) {
  final service = FileUploadQueueService(
    localStorage: ref.watch(localStorageServiceProvider),
    offlineFileService: ref.watch(offlineFileServiceProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    connectionMonitorService: ref.watch(connectionMonitorServiceProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
  );
  // Inject generic VObjectService so upload pipeline is type-agnostic
  try {
    service.setVObjectService(ref.watch(vobjectServiceProvider));
  } catch (_) {}
  return service;
});

final vobjectServiceProvider = Provider<VObjectService>((ref) {
  return VObjectService(
    taskRepository: ref.watch(taskRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
  );
});

final connectionMonitorServiceProvider = Provider<ConnectionMonitorService>((ref) {
  return ConnectionMonitorService();
});

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

// Keep a simple const provider; caldav module references default through DI
final sharingSyncServiceProvider = Provider<SharingSyncService>((ref) => const SharingSyncService());

final usersApiServiceProvider = Provider.family<UsersApiService, CaldavAccount>((ref, account) => UsersApiService(account: account));

final shareServiceProvider = Provider.family<ShareService, CaldavAccount>((ref, account) => ShareService(account: account));

final s3StorageServiceProvider = Provider.family<S3StorageService, CaldavAccount>((ref, account) {
  return S3StorageService(account: account);
});

final kanbanServiceProvider = Provider<KanbanService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  return KanbanService(
    calendarRepository: calendarRepository,
    accountRepository: accountRepository,
  );
});

final workflowServiceProvider = Provider<WorkflowService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final commander = ref.watch(syncCommanderProvider);
  final service = WorkflowService(calendarRepository, sync: commander);
  // Optionally wire repositories if needed by the service
  try {
    // ignore: avoid_dynamic_calls
    service.setStepRepository(ref.watch(stepRepositoryProvider));
    // ignore: avoid_dynamic_calls
    service.setTaskRepository(ref.watch(taskRepositoryProvider));
  } catch (_) {}
  return service;
});

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

final domainServiceProvider = Provider<caldav_domain.DomainService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  return caldav_domain.DomainService(calendarRepository, localStorageService, ref.watch(accountRepositoryProvider));
});

final statusServiceProvider = Provider<StatusService>((ref) {
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  final commander = ref.watch(syncCommanderProvider);
  return StatusService(calendarRepository, localStorageService, sync: commander);
});

// User preferences stream (from UserRepository)
final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.watchUserPreferences();
});

// Account status providers
final hasActiveAccountProvider = FutureProvider<bool>((ref) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final result = await accountRepository.hasActiveAccount();
  return result.when(
    success: (has) => has,
    failure: (_) => false,
  );
});

final activeAccountProvider = FutureProvider<CaldavAccount?>((ref) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final result = await accountRepository.getActiveAccount();
  return result.when(
    success: (acc) => acc,
    failure: (_) => null,
  );
});

final userSyncServiceProvider = Provider<UserSyncService>((ref) {
  final userSyncService = UserSyncService(
    userRepository: ref.watch(userRepositoryProvider),
    externalAccountRepository: ref.watch(externalAccountRepositoryProvider),
    externalCalendarRepository: ref.watch(externalCalendarRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
  );

  userSyncService.setPreferencesUpdateCallback(() {
    AppLogger.debug('Providers: Invalidating userPreferencesProvider and project lists');
    ref.invalidate(userPreferencesProvider);
    // Other derived providers listen to streams and will update automatically
  });
  return userSyncService;
});

final userPreferencesQueueServiceProvider = Provider<UserPreferencesQueueService>((ref) {
  return UserPreferencesQueueService(
    userRepository: ref.watch(userRepositoryProvider),
    userSyncService: ref.watch(userSyncServiceProvider),
    localStorage: ref.watch(localStorageServiceProvider),
  );
});

final externalAccountQueueServiceProvider = Provider<ExternalAccountQueueService>((ref) {
  return ExternalAccountQueueService(
    externalAccountRepository: ref.watch(externalAccountRepositoryProvider),
    userSyncService: ref.watch(userSyncServiceProvider),
    localStorage: ref.watch(localStorageServiceProvider),
  );
});

final userPreferencesQueueSetupProvider = Provider<void>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  final userPreferencesQueueService = ref.watch(userPreferencesQueueServiceProvider);
  // Use runtime type name to avoid direct import dependency
  if (userRepository.runtimeType.toString() == 'LocalUserRepository') {
    userRepository.setQueueCallback((preferences) async {
      await userPreferencesQueueService.queueUserPreferencesUpdate(preferences);
    });
  }
  return;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final taskRepository = ref.watch(taskRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  final journalRepository = ref.watch(journalRepositoryProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  final syncService = SyncService(
    taskRepository: taskRepository,
    accountRepository: accountRepository,
    calendarRepository: calendarRepository,
    categoryRepository: categoryRepository,
    userRepository: userRepository,
    journalRepository: journalRepository,
    localStorage: localStorage,
  );
  // Best-effort injection without importing LocalTaskRepository type
  try {
    // ignore: invalid_use_of_protected_member
    // dynamic call; will no-op if method not present
    // ignore: avoid_dynamic_calls
    (taskRepository as dynamic).setSyncService(syncService);
    // ignore: avoid_dynamic_calls
    (journalRepository as dynamic).setSyncService(syncService);
  } catch (_) {}
  return syncService;
});

final globalNavigatorKey = GlobalKey<NavigatorState>();
BuildContext? get globalContext => globalNavigatorKey.currentContext;

final sessionEpochProvider = StateProvider<int>((ref) => 0);

void handleSessionExpired([ProviderRef? ref]) {
  final context = globalContext;
  if (context != null && context.mounted) {
    GoRouter.of(context).go('/connect');
  }
  if (ref != null) {
    // Router refresh is handled by sessionEpochProvider only to avoid cross-module deps
    ref.read(sessionEpochProvider.notifier).state++;
  }
}

// Deep link service provider
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = PlatformDeepLinkService();
  ref.onDispose(service.dispose);
  return service;
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
  if (eventsAsync.isLoading || enabledCalendarsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (eventsAsync.hasError) {
    return AsyncValue.error(eventsAsync.error!, eventsAsync.stackTrace!);
  }
  if (enabledCalendarsAsync.hasError) {
    return AsyncValue.error(enabledCalendarsAsync.error!, enabledCalendarsAsync.stackTrace!);
  }
  if (eventsAsync.hasValue && enabledCalendarsAsync.hasValue) {
    final events = eventsAsync.value ?? const <CalendarEvent>[];
    final enabledCalendars = enabledCalendarsAsync.value ?? const <ExternalCalendar>[];
    final enabledCalendarUids = enabledCalendars.map((cal) => cal.uid).toSet();
    final filteredEvents = events.where((event) => enabledCalendarUids.contains(event.sourceCalendarUid)).toList();
    return AsyncValue.data(filteredEvents);
  }
  return const AsyncValue.loading();
});

// Sync status providers
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.statusStream;
});

final currentSyncStatusProvider = Provider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.status;
});

// Available domains provider - reacts to calendar list
final availableDomainsProvider = FutureProvider<List<String>>((ref) async {
  final domainService = ref.watch(domainServiceProvider);
  // Recompute when calendars change
  ref.watch(calendarListProvider);
  final result = await domainService.getAvailableDomains();
  return result.when(success: (d) => d, failure: (_) => <String>[]);
});

// Project sharing notification providers
final projectSharedNotificationProvider = Provider.family<AsyncValue<bool>, String>((ref, projectId) {
  final userPreferencesAsync = ref.watch(userPreferencesProvider);
  return userPreferencesAsync.when(
    data: (prefs) {
      final sharedProject = prefs.getSharedProject(projectId);
      final hasNotification = sharedProject != null && !sharedProject.ack;
      return AsyncValue.data(hasNotification);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, st) => AsyncValue.error(err, st),
  );
});

final projectSharedByProvider = Provider.family<AsyncValue<String>, String>((ref, projectId) {
  final userPreferencesAsync = ref.watch(userPreferencesProvider);
  return userPreferencesAsync.when(
    data: (prefs) {
      final sharedProject = prefs.getSharedProject(projectId);
      final sourceEmail = sharedProject?.sourceUserEmail ?? '';
      return AsyncValue.data(sourceEmail);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, st) => AsyncValue.error(err, st),
  );
});

// CalDAV Monitor provider with DI
final caldavMonitorProvider = Provider<CalDAVMonitor>((ref) {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  final externalAccountRepository = ref.watch(externalAccountRepositoryProvider);

  final connectionMonitorService = ref.watch(connectionMonitorServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  final userSyncService = ref.watch(userSyncServiceProvider);
  final userPreferencesQueueService = ref.watch(userPreferencesQueueServiceProvider);
  final externalAccountQueueService = ref.watch(externalAccountQueueServiceProvider);

  AppLogger.debug('Providers: Creating CalDAVMonitor with injected UserSyncService');

  return CalDAVMonitor(
    ref: ref,
    accountRepository: accountRepository,
    calendarRepository: calendarRepository,
    categoryRepository: categoryRepository,
    userRepository: userRepository,
    externalAccountRepository: externalAccountRepository,
    connectionMonitorService: connectionMonitorService,
    syncService: syncService,
    userSyncService: userSyncService,
    userPreferencesQueueService: userPreferencesQueueService,
    externalAccountQueueService: externalAccountQueueService,
    taskRepository: taskRepository,
  );
});


