// Settings screen for app configuration
// CalDAV connections, theme, and app preferences

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import 'caldav_management_screen.dart';
import 'connection_info_screen.dart';
import 'external_calendar_management_screen.dart';
import '../../widgets/utils/popup/export_dialog.dart';
import '../../widgets/utils/popup/import_dialog.dart';
import '../../../data/services/sync/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/appearance_settings_viewmodel.dart';
import '../../widgets/header_screen_widget.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: HeaderScreenWidget(
        title: AppLocalizations.of(context)!.settings,
        showVoiceFeedback: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SettingsSection(
            title: AppLocalizations.of(context)!.appearance,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(AppLocalizations.of(context)!.themeLabel, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _ThemeModeSelector(),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.language, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    const _LanguageSelector(),
                    const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.fontSizeLabel, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _FontScaleSelector(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: AppLocalizations.of(context)!.account,
            children: [
              _SettingsItem(
                title: AppLocalizations.of(context)!.connectionInfo,
                subtitle: AppLocalizations.of(context)!.connectionInfoSubtitle,
                icon: Icons.info_rounded,
                onTap: () => _showConnectionInfo(context, ref),
              ),
              _SettingsItem(
                title: AppLocalizations.of(context)!.syncSettings,
                subtitle: AppLocalizations.of(context)!.syncSettingsSubtitle,
                icon: Icons.sync_rounded,
                onTap: () => _showSyncSettings(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: AppLocalizations.of(context)!.integration,
            children: [
              _SettingsItem(
                title: AppLocalizations.of(context)!.externalCalendars,
                subtitle: AppLocalizations.of(context)!.externalCalendarsSubtitle,
                icon: Icons.calendar_view_month_rounded,
                onTap: () => _showExternalCalendars(context, ref),
              ),
              _SettingsItem(
                title: AppLocalizations.of(context)!.exportData,
                subtitle: AppLocalizations.of(context)!.exportDataSubtitle,
                icon: Icons.download_rounded,
                onTap: () => _showExportData(context, ref),
              ),
              _SettingsItem(
                title: AppLocalizations.of(context)!.importData,
                subtitle: AppLocalizations.of(context)!.importDataSubtitle,
                icon: Icons.upload_rounded,
                onTap: () => _showImportData(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: AppLocalizations.of(context)!.about,
            children: [
              _SettingsItem(
                title: AppLocalizations.of(context)!.aboutUs,
                subtitle: AppLocalizations.of(context)!.aboutUsSubtitle,
                icon: Icons.public_rounded,
                onTap: () => _openExternalUrl('https://gettowdow.com'),
              ),
              _SettingsItem(
                title: AppLocalizations.of(context)!.license,
                subtitle: AppLocalizations.of(context)!.licenseSubtitle,
                icon: Icons.description_rounded,
                onTap: () => _openExternalUrl('https://gitlab.com/towdow/towdow-flutter/-/blob/develop/LICENSE'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: AppLocalizations.of(context)!.dangerZone,
            children: [
              _SettingsItem(
                title: AppLocalizations.of(context)!.disconnectAndClearData,
                subtitle: AppLocalizations.of(context)!.disconnectAndClearDataSubtitle,
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
            title: Text(AppLocalizations.of(context)!.disconnectDialogTitle),
            content: Text(AppLocalizations.of(context)!.disconnectDialogBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(AppLocalizations.of(context)!.disconnect),
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
        await _clearWebStorageAndCache(ref);
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
  Future<void> _clearWebStorageAndCache(WidgetRef ref) async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.clearAllBoxesWebSafe();
  }

  // JS interop helpers removed; handled by LocalStorageService

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
      segments: [
        ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.phone_android), label: Text(AppLocalizations.of(context)!.themeSystem)),
        ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(AppLocalizations.of(context)!.themeLight)),
        ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(AppLocalizations.of(context)!.themeDark)),
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
      segments: [
        ButtonSegment(value: 'small', label: Text(AppLocalizations.of(context)!.fontSmall)),
        ButtonSegment(value: 'medium', label: Text(AppLocalizations.of(context)!.fontMedium)),
        ButtonSegment(value: 'large', label: Text(AppLocalizations.of(context)!.fontLarge)),
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

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(appearanceSettingsViewModelProvider.notifier);
    final currentLocale = ref.watch(localeProvider);
    String selected = currentLocale == null
        ? 'system'
        : currentLocale.countryCode == null
            ? currentLocale.languageCode
            : '${currentLocale.languageCode}-${currentLocale.countryCode}';

    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'system', label: Text(AppLocalizations.of(context)!.languageSystem)),
        ButtonSegment(value: 'en', label: Text(AppLocalizations.of(context)!.languageEn)),
        ButtonSegment(value: 'fr', label: Text(AppLocalizations.of(context)!.languageFr)),
      ],
      selected: {selected}
          .where((e) => e == 'system' || e == 'en' || e == 'fr')
          .toSet(),
      onSelectionChanged: (set) {
        if (set.isNotEmpty) {
          vm.setLocale(set.first);
        }
      },
    );
  }
}
