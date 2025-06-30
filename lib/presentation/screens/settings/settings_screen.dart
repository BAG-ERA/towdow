// Settings screen for app configuration
// CalDAV connections, theme, and app preferences

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/sync_service.dart';
import 'caldav_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsItem(
                title: 'CalDAV Connection',
                subtitle: 'Manage server connections',
                icon: Icons.cloud_rounded,
                onTap: () => _showConnectionManagement(context, ref),
              ),
              const _SettingsItem(
                title: 'Sync Settings',
                subtitle: 'Configure sync behavior',
                icon: Icons.sync_rounded,
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
                title: 'Sync Now',
                subtitle: 'Force immediate sync with server',
                icon: Icons.sync_rounded,
                onTap: () => _performSync(context, ref),
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

  Future<void> _showConnectionManagement(BuildContext context, WidgetRef ref) async {
    // Navigate directly to the CalDAV management screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CalDAVManagementScreen(),
      ),
    );
  }

  Future<void> _showDisconnectConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Disconnect & Clear Data'),
        content: const Text(
          'This will permanently delete:\n'
          '• All tasks\n'
          '• All projects\n'
          '• All accounts\n'
          '• All sync data\n\n'
          'This action cannot be undone!'
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
    ) ?? false;

    if (!confirmed) return;

    try {
      final storageService = ref.read(localStorageServiceProvider);
      final result = await storageService.clearAllData();
      
      result.when(
        success: (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ All data cleared successfully!')),
            );
          }
          
          // Restart the app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          });
        },
        failure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Failed to clear data: ${failure.message}')),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error clearing data: $e')),
      );
    }
  }

  Future<void> _debugStorage(BuildContext context, WidgetRef ref) async {
    try {
      final storageService = ref.read(localStorageServiceProvider);
      await storageService.debugAllBoxes();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Storage debug info logged to console!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Debug error: $e')),
        );
      }
    }
  }

  Future<void> _performSync(BuildContext context, WidgetRef ref) async {
    try {
      final syncService = ref.read(syncServiceProvider);
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔄 Syncing...')),
      );
      
      final result = await syncService.syncNow();
      
      if (context.mounted) {
        result.when(
          success: (syncResult) {
            if (syncResult.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Sync completed: ${syncResult.syncedItems} items synced'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Sync completed with errors: ${syncResult.errors.join(', ')}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          failure: (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Sync failed: ${failure.message}'),
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
            content: Text('❌ Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear ALL Data'),
        content: const Text(
          'This will permanently delete:\n'
          '• All tasks\n'
          '• All projects\n'
          '• All accounts\n'
          '• All sync data\n\n'
          'This action cannot be undone!'
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
    ) ?? false;

    if (!confirmed) return;

    try {
      final storageService = ref.read(localStorageServiceProvider);
      final result = await storageService.clearAllData();
      
      if (context.mounted) {
        result.when(
          success: (_) {
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

  const _SettingsSection({
    required this.title,
    required this.children,
  });

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
        Card(
          child: Column(children: children),
        ),
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
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title coming soon!')),
        );
      },
    );
  }
} 
