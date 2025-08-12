// Settings screen for app configuration
// CalDAV connections, theme, and app preferences

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/logger.dart';
import '../../../data/services/storage/local_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import 'caldav_management_screen.dart';
import 'connection_info_screen.dart';
import 'external_calendar_management_screen.dart';
import '../../widgets/utils/popup/export_dialog.dart';
import '../../widgets/utils/popup/import_dialog.dart';
import '../../../data/services/web/web_storage.dart';
import '../../../data/services/sync/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/appearance_settings_viewmodel.dart';

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
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _ThemeModeSelector(),
                    const SizedBox(height: 16),
                    Text('Font size', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _FontScaleSelector(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsItem(
                title: 'About us',
                subtitle: 'Learn more about TowDow',
                icon: Icons.public_rounded,
                onTap: () => _openExternalUrl('https://gettowdow.com'),
              ),
              _SettingsItem(
                title: 'License',
                subtitle: 'Mozilla Public License 2.0',
                icon: Icons.description_rounded,
                onTap: () => _openExternalUrl('https://gitlab.com/towdow/towdow-flutter/-/blob/develop/LICENSE'),
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

      // Perform full on-disk wipe to ensure nothing lingers
      await SyncService.reset();
      final result = await storageService.emergencyReset();
      // Re-initialize empty boxes for a clean app state
      await storageService.initialize();

      result.when(
        success: (_) async {
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
          AppLogger.error('Failed to clear data: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('Error clearing data: $e');
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

  Future<void> _showExportData(BuildContext context, WidgetRef ref) async {
    showDialog(context: context, builder: (context) => const ExportDialog());
  }

  Future<void> _showImportData(BuildContext context, WidgetRef ref) async {
    showDialog(context: context, builder: (context) => const ImportDialog());
  }

  // Helper method to clear web-specific storage and cache
  Future<void> _clearWebStorageAndCache() async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.clearAllBoxesWebSafe();
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
  Future<void> _reloadPageUsingJsInterop() async {}

  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        AppLogger.error('Cannot launch URL: $url');
        return;
      }
      final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!didLaunch) {
        AppLogger.error('Failed to launch URL: $url');
      }
    } catch (e, stacktrace) {
      AppLogger.error('Error launching URL: $url', e, stacktrace);
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
            // Feature coming soon - no action needed
          },
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final vm = ref.read(appearanceSettingsViewModelProvider.notifier);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('System')),
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
      ],
      selected: {current},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) {
          vm.setThemeMode(set.first);
        }
      },
    );
  }
}

class _FontScaleSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScale = ref.watch(fontScaleProvider);
    final vm = ref.read(appearanceSettingsViewModelProvider.notifier);

    String currentKey;
    if (currentScale <= 0.95) {
      currentKey = 'small';
    } else if (currentScale >= 1.1) {
      currentKey = 'large';
    } else {
      currentKey = 'medium';
    }

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'small', label: Text('Small')),
        ButtonSegment(value: 'medium', label: Text('Medium')),
        ButtonSegment(value: 'large', label: Text('Large')),
      ],
      selected: {currentKey},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) {
          vm.setFontScale(set.first);
        }
      },
    );
  }
}
