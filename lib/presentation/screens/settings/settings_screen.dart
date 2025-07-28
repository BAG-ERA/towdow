// Settings screen for app configuration
// CalDAV connections, theme, and app preferences

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/logger.dart';
import '../../../data/services/local_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import 'caldav_management_screen.dart';
import 'connection_info_screen.dart';
import 'external_calendar_management_screen.dart';
import 's3_debug_screen.dart';
import 'shared_projects_test_screen.dart';
import '../../widgets/utils/popup/export_dialog.dart';
import '../../widgets/utils/popup/import_dialog.dart';
import '../../../data/services/web_storage.dart';
import '../../../data/services/sync_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;

    return Scaffold(
      appBar: isDesktop
          ? AppBar(
              title: const Text('Settings'),
              automaticallyImplyLeading: false,
              scrolledUnderElevation: 0,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsItem(
                title: 'Connection Information',
                subtitle: 'View account details and status',
                icon: Icons.info_rounded,
                onTap: () => _showConnectionInfo(context, ref),
              ),
              _SettingsItem(
                title: 'Sync Setting',
                subtitle: 'Manage CalDAV synchronization',
                icon: Icons.sync_rounded,
                onTap: () => _showSyncSettings(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Integration',
            children: [
              _SettingsItem(
                title: 'External Calendars',
                subtitle: 'Connect external CalDAV calendars',
                icon: Icons.calendar_view_month_rounded,
                onTap: () => _showExternalCalendars(context, ref),
              ),
              _SettingsItem(
                title: 'Export Data',
                subtitle: 'Export all local data to a file',
                icon: Icons.download_rounded,
                onTap: () => _showExportData(context, ref),
              ),
              _SettingsItem(
                title: 'Import Data',
                subtitle: 'Import data from a file',
                icon: Icons.upload_rounded,
                onTap: () => _showImportData(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SettingsSection(
            title: 'Appearance',
            children: [
              _SettingsItem(
                title: 'Theme',
                subtitle: 'Light, dark, or system',
                icon: Icons.palette_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SettingsSection(
            title: 'About',
            children: [
              _SettingsItem(
                title: 'Version',
                subtitle: '1.0.0+1',
                icon: Icons.info_rounded,
              ),
              _SettingsItem(
                title: 'License',
                subtitle: 'View open source licenses',
                icon: Icons.description_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Debug',
            children: [
              _SettingsItem(
                title: 'Shared Projects Test',
                subtitle: 'Test shared project API endpoints',
                icon: Icons.share_rounded,
                onTap: () => _showSharedProjectsTest(context, ref),
              ),
              _SettingsItem(
                title: 'S3 Storage Debug',
                subtitle: 'Test S3 file storage operations',
                icon: Icons.cloud_queue_rounded,
                onTap: () => _showS3Debug(context, ref),
              ),
              _SettingsItem(
                title: 'Clear All Data',
                subtitle: 'Delete all local data without disconnecting',
                icon: Icons.delete_forever_rounded,
                isDestructive: true,
                onTap: () => _clearAllData(context, ref),
              ),
              _SettingsItem(
                title: 'Inspect Storage',
                subtitle: 'Debug local storage contents',
                icon: Icons.bug_report_rounded,
                onTap: () => _debugStorage(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Danger Zone',
            children: [
              _SettingsItem(
                title: 'Disconnect & Clear Data',
                subtitle: 'Clear all data and restart the app',
                icon: Icons.logout_rounded,
                isDestructive: true,
                onTap: () => _showDisconnectConfirmation(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConnectionManagement(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Navigate directly to the CalDAV management screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CalDAVManagementScreen()),
    );
  }

  Future<void> _showConnectionInfo(BuildContext context, WidgetRef ref) async {
    // Navigate to connection information screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ConnectionInfoScreen()),
    );
  }

  Future<void> _showDisconnectConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Disconnect & Clear Data'),
            content: const Text(
              'This will permanently delete:\n'
              '• All tasks\n'
              '• All projects\n'
              '• All accounts\n'
              '• All sync data\n\n'
              'This action cannot be undone!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('DISCONNECT'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final storageService = ref.read(localStorageServiceProvider);

      // Special handling for web platform
      if (kIsWeb) {
        // For web browsers, we need to clear the browser's localStorage as well
        await _clearWebStorageAndCache();
      }

      final result = await storageService.clearAllData();

      result.when(
        success: (_) async {
          // Reset SyncService singleton to clean up timers and streams
          await SyncService.reset();
          


          // Invalidate all relevant providers to clear cached data
          ref.invalidate(taskListProvider);
          ref.invalidate(calendarListProvider);
          ref.invalidate(externalCalendarListProvider);
          ref.invalidate(externalEventListProvider);
          ref.invalidate(enabledExternalCalendarListProvider);
          ref.invalidate(enabledExternalEventListProvider);
          ref.invalidate(hasActiveAccountProvider);
          ref.invalidate(activeAccountProvider);
          ref.invalidate(syncStatusStreamProvider);
          ref.invalidate(currentSyncStatusProvider);
          ref.invalidate(userRepositoryProvider);
          ref.invalidate(accountRepositoryProvider);
          ref.invalidate(calendarRepositoryProvider);
          ref.invalidate(taskRepositoryProvider);
          ref.invalidate(externalAccountRepositoryProvider);
          ref.invalidate(externalCalendarRepositoryProvider);
          ref.invalidate(externalEventRepositoryProvider);
          ref.invalidate(syncServiceProvider);

          // Restart the app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          });
        },
        failure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to clear data: ${failure.message}'),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error clearing data: $e')));
    }
  }

  Future<void> _debugStorage(BuildContext context, WidgetRef ref) async {
    try {
      final storageService = ref.read(localStorageServiceProvider);
      await storageService.debugAllBoxes();


    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Debug error: $e')));
      }
    }
  }

  Future<void> _showSyncSettings(BuildContext context, WidgetRef ref) async {
    // Navigate to sync/CalDAV management screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CalDAVManagementScreen()),
    );
  }

  Future<void> _showExternalCalendars(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Navigate to external calendar management screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExternalCalendarManagementScreen(),
      ),
    );
  }

  Future<void> _showSharedProjectsTest(BuildContext context, WidgetRef ref) async {
    // Navigate to shared projects test screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SharedProjectsTestScreen(),
      ),
    );
  }

  Future<void> _showS3Debug(BuildContext context, WidgetRef ref) async {
    // Navigate to S3 debug screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const S3DebugScreen()));
  }

  Future<void> _showExportData(BuildContext context, WidgetRef ref) async {
    showDialog(context: context, builder: (context) => const ExportDialog());
  }

  Future<void> _showImportData(BuildContext context, WidgetRef ref) async {
    showDialog(context: context, builder: (context) => const ImportDialog());
  }

  // Helper method to clear web-specific storage and cache
  Future<void> _clearWebStorageAndCache() async {
    if (kIsWeb) {
      try {
        // Use dart:html's window.localStorage to clear browser storage
        // This needs to be done using JS interop in a web-safe way
        await _clearLocalStorageUsingJsInterop();

        // Clear Hive's IndexedDB storage more aggressively using known box names
        final boxNames = [
          LocalStorageService.tasksBoxName,
          LocalStorageService.projectsBoxName,
          LocalStorageService.calendarsBoxName,
          LocalStorageService.automatedTasksBoxName,
          LocalStorageService.accountsBoxName,
          LocalStorageService.syncQueueBoxName,
          LocalStorageService.domainsBoxName,
          LocalStorageService.statusesBoxName,
          LocalStorageService.userPreferencesBoxName,
          LocalStorageService.externalAccountsBoxName,
          LocalStorageService.externalCalendarsBoxName,
          LocalStorageService.externalEventsBoxName,
          LocalStorageService.offlineFilesBoxName,
          LocalStorageService.fileUploadQueueBoxName,
        ];

        for (final boxName in boxNames) {
          if (Hive.isBoxOpen(boxName)) {
            try {
              await Hive.box(boxName).clear();
              await Hive.box(boxName).close();
              await Hive.deleteBoxFromDisk(boxName);
            } catch (e) {
              AppLogger.warning('Failed to clear box $boxName: $e');
            }
          }
        }

        // Force page refresh to ensure clean state (only in production)
        if (!const bool.fromEnvironment('dart.vm.product')) {
          await _reloadPageUsingJsInterop();
        }
      } catch (e) {
        AppLogger.error('Failed to clear web storage', e);
      }
    }
  }

  // Clear localStorage using JS interop
  Future<void> _clearLocalStorageUsingJsInterop() async {
    if (kIsWeb) {
      try {
        await clearLocalStorage();
        AppLogger.info('localStorage cleared successfully via JS interop');
      } catch (e, stacktrace) {
        AppLogger.error('Failed to clear localStorage', e, stacktrace);
      }
    }
  }

  // Reload the page using JS interop
  Future<void> _reloadPageUsingJsInterop() async {
    if (kIsWeb) {
      try {
        // In a real implementation with conditional imports:
        // js.context.callMethod('eval', ['window.location.reload();']);
        AppLogger.info('Web platform: page would be reloaded here');
      } catch (e) {
        AppLogger.error('Failed to reload page', e);
      }
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Clear ALL Data'),
            content: const Text(
              'This will permanently delete:\n'
              '• All tasks\n'
              '• All projects\n'
              '• All accounts\n'
              '• All sync data\n\n'
              'This action cannot be undone!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('DELETE ALL'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final storageService = ref.read(localStorageServiceProvider);

      // Special handling for web platform
      if (kIsWeb) {
        // For web browsers, we need to clear the browser's localStorage as well
        await _clearWebStorageAndCache();
      }

      final result = await storageService.clearAllData();

      if (context.mounted) {
        result.when(
          success: (_) async {
            // Reset SyncService singleton to clean up timers and streams
            await SyncService.reset();
            
            // Invalidate all relevant providers to clear cached data
            ref.invalidate(taskListProvider);
            ref.invalidate(calendarListProvider);
            ref.invalidate(externalCalendarListProvider);
            ref.invalidate(externalEventListProvider);
            ref.invalidate(enabledExternalCalendarListProvider);
            ref.invalidate(enabledExternalEventListProvider);
            ref.invalidate(hasActiveAccountProvider);
            ref.invalidate(activeAccountProvider);
            ref.invalidate(syncStatusStreamProvider);
            ref.invalidate(currentSyncStatusProvider);
            ref.invalidate(userRepositoryProvider);
            ref.invalidate(accountRepositoryProvider);
            ref.invalidate(calendarRepositoryProvider);
            ref.invalidate(taskRepositoryProvider);
            ref.invalidate(externalAccountRepositoryProvider);
            ref.invalidate(externalCalendarRepositoryProvider);
            ref.invalidate(externalEventRepositoryProvider);
            ref.invalidate(syncServiceProvider);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ All data cleared successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          failure: (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Failed to clear data: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(
        title,
        style: isDestructive
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios_rounded),
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$title coming soon!')));
          },
    );
  }
}
