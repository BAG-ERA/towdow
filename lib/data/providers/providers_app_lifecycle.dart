// App lifecycle providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_lifecycle_manager.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import 'providers_services_core.dart';
// caldav services are used indirectly via providers_services_core
import 'providers_repositories.dart';
import '../../presentation/viewmodels/commands/deep_link_commands.dart';

final appLifecycleManagerProvider = Provider<AppLifecycleManager>((ref) {
  return AppLifecycleManager.instance;
});

final appLifecycleInitializationProvider = FutureProvider<void>((ref) async {
  final lifecycleManager = ref.watch(appLifecycleManagerProvider);
  final syncService = ref.watch(syncServiceProvider);
  final externalSyncService = ref.watch(externalCalendarSyncServiceProvider);
  final fileUploadQueueService = ref.watch(fileUploadQueueServiceProvider);
  final connectionMonitorService = ref.watch(connectionMonitorServiceProvider);
  final userSyncService = ref.watch(userSyncServiceProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final stepRepository = ref.watch(stepRepositoryProvider);
  final requirementRepository = ref.watch(requirementRepositoryProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  final taskRepository = ref.watch(taskRepositoryProvider);

  ref.watch(userPreferencesQueueSetupProvider);

  final caldavMonitor = ref.watch(caldavMonitorProvider);

  await stepRepository.initialize();
  await requirementRepository.initialize();

  // Cleanup orphan tasks on startup (local-only): tasks whose projectPath doesn't match existing calendars
  try {
    final calendarsResult = await calendarRepository.getAll();
    await calendarsResult.when(
      success: (calendars) async {
        final validPaths = calendars.map((c) => c.path).toSet();
        final cleanupResult = await taskRepository.deleteOrphanedTasksLocalOnly(validPaths);
        cleanupResult.when(
          success: (_) {},
          failure: (f) => AppLogger.warning('AppLifecycle: Orphan task cleanup failed: ${f.message}'),
        );
      },
      failure: (f) async {
        AppLogger.warning('AppLifecycle: Could not load calendars for orphan cleanup: ${f.message}');
      },
    );
  } catch (_) {}

  final mediaCleanupService = ref.watch(mediaCleanupServiceProvider);

  final result = await lifecycleManager.initialize(
    syncService: syncService,
    caldavMonitor: caldavMonitor,
    externalSyncService: externalSyncService,
    fileUploadQueueService: fileUploadQueueService,
    mediaCleanupService: mediaCleanupService,
    connectionMonitorService: connectionMonitorService,
    userSyncService: userSyncService,
    accountRepository: accountRepository,
  );

  await result.when(
    success: (_) async {},
    failure: (failure) async {
      throw Exception(failure.message);
    },
  );

  // Deep link initialization (after services are ready enough for navigation)
  final deepLinkService = ref.watch(deepLinkServiceProvider);
  final command = HandleDeepLinkCommand(ref);

  // Handle initial link
  try {
    final initial = await deepLinkService.getInitialLink();
    if (initial != null) {
      AppLogger.info('AppLifecycle: Handling initial deep link ${initial.kind.name}');
      await command.handle(initial);
    }
  } catch (e) {
    AppLogger.warning('AppLifecycle: initial deep link failed: $e');
  }

  // Subscribe to runtime links
  deepLinkService.linkStream.listen((target) async {
    AppLogger.info('AppLifecycle: Handling runtime deep link ${target.kind.name}');
    await command.handle(target);
  });
});

final appLifecycleStateProvider = StreamProvider<FlowItAppState>((ref) {
  final lifecycleManager = ref.watch(appLifecycleManagerProvider);
  return lifecycleManager.stateStream;
});


