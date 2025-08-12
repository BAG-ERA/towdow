// App lifecycle providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_lifecycle_manager.dart';
import 'providers_services_core.dart';
// caldav services are used indirectly via providers_services_core
import 'providers_repositories.dart';

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

  ref.watch(userPreferencesQueueSetupProvider);

  final caldavMonitor = ref.watch(caldavMonitorProvider);

  await stepRepository.initialize();
  await requirementRepository.initialize();

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
    success: (_) async {},
    failure: (failure) async {
      throw Exception(failure.message);
    },
  );
});

final appLifecycleStateProvider = StreamProvider<FlowItAppState>((ref) {
  final lifecycleManager = ref.watch(appLifecycleManagerProvider);
  return lifecycleManager.stateStream;
});


