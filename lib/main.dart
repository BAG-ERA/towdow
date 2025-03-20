import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/settings_service.dart';
import 'data/services/caldav_service.dart';
import 'data/services/sync_service.dart';
import 'data/repositories/task_repository.dart';
import 'presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final localStorageService = LocalStorageService();
  await localStorageService.init();

  final settingsService = SettingsService();
  await settingsService.init();

  runApp(MyApp(
    localStorageService: localStorageService,
    settingsService: settingsService,
  ));
}

class MyApp extends StatelessWidget {
  final LocalStorageService localStorageService;
  final SettingsService settingsService;

  const MyApp({
    super.key,
    required this.localStorageService,
    required this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ProxyProvider<SettingsService, CalDAVService?>(
          update: (context, settings, previous) {
            if (!settings.initialized || !settings.syncEnabled) return null;
            return CalDAVService(
              serverUrl: settings.serverUrl!,
              username: settings.username!,
              password: settings.password!,
            );
          },
        ),
        ProxyProvider2<SettingsService, CalDAVService?, SyncService?>(
          update: (context, settings, caldav, previous) {
            if (!settings.initialized || !settings.syncEnabled || caldav == null) {
              return null;
            }
            return SyncService(
              caldav: caldav,
              storage: localStorageService,
            )..startPeriodicSync();
          },
          dispose: (context, service) => service?.dispose(),
        ),
        ProxyProvider<SyncService?, TaskRepository>(
          update: (context, sync, previous) => TaskRepository(
            localStorageService,
            sync ?? _DummySyncService(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'FlowIt',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

/// A dummy sync service that does nothing, used when sync is disabled
class _DummySyncService implements SyncService {
  @override
  bool get isSyncing => false;

  @override
  DateTime? get lastSyncTime => null;

  @override
  void dispose() {}

  @override
  void startPeriodicSync() {}

  @override
  void stopPeriodicSync() {}

  @override
  Future<void> sync() async {}

  @override
  Future<void> queueTaskForSync(task) async {
    // Just save locally
    // This is handled by the TaskRepository
  }

  @override
  Future<void> queueTaskDeletionForSync(String uid) async {
    // Just delete locally
    // This is handled by the TaskRepository
  }
}
