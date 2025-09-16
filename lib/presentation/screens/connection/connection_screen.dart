// Connection screen for CalDAV account setup
// Onboarding screen for configuring server connections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/custom_caldav_dialog.dart';
import 'widgets/towdow_cloud_dialog.dart';
import 'widgets/towdow_self_hosted_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/caldav_account.dart';
import '../../../data/providers/providers.dart';
import '../../viewmodels/login_viewmodel.dart';
import '../../../../web/web_utils.dart';
import '../../../core/logger.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  bool _showHostingChoice = false;

  @override
  void initState() {
    super.initState();

    // Auto-login via auth code saved in local storage (Web)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final authCode = WebLocalStorage.getItem('authCode');
        if (authCode != null && authCode.isNotEmpty) {
          // Clear immediately to prevent relogging loops
          WebLocalStorage.removeItem('authCode');
          AppLogger.info('ConnectionScreen: Found authCode in localStorage, starting login');

          // Start authentication with default TowDow Cloud settings
          await ref.read(loginViewModelProvider.notifier).authenticateWebWithAuthCode(
                code: authCode,
              );

          // After authentication completes, force providers refresh and navigate
          try {
            ref.invalidate(hasActiveAccountProvider);
            ref.invalidate(activeAccountProvider);

            // Determine destination similar to listener logic
            final account = await ref.read(activeAccountProvider.future);
            if (account != null && mounted) {
              final isOffline = account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost');
              final destination = isOffline ? '/projects' : '/today';
              GoRouter.of(context).go(destination);
            }
          } catch (e) {
            AppLogger.warning('ConnectionScreen: Post-auth redirect failed (will rely on listener/router): $e');
          }
        }
      } catch (e) {
        AppLogger.error('ConnectionScreen: Error during auto-login with auth code: $e');
      }
    });

    // Listen for login state changes to navigate on success
    // NOTE: ref.listen cannot be used in initState on web (Riverpod assertion). Use post-frame + listen in build instead.
    // Moved to build() using ref.listen and guarding with a flag to avoid duplicate setup.
  }

  void _openOtherMethodsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Custom CalDAV'),
                subtitle: const Text('Connect any CalDAV server'),
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (context) => const CustomCaldavDialog(),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.offline_bolt_rounded),
                title: const Text('No account (offline only)'),
                subtitle: const Text('On-device only. No sync, shares, or file attachments'),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmOfflineOnly();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmOfflineOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool understood = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Offline only'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your data will be stored only on this device. Removing the app or clearing data will erase everything. '
                  'You can enable sync later in Settings.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: understood,
                      onChanged: (v) => setState(() => understood = v ?? false),
                    ),
                    const Expanded(
                      child: Text('I understand data is not backed up'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: understood
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('Start offline'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      // Create a local offline-only pseudo account treated as custom CalDAV with offline scheme
      final account = CaldavAccount(
        id: const Uuid().v4(),
        providerType: 'custom',
        serverUrl: 'https://localhost/',
        username: 'local',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      final repo = ref.read(accountRepositoryProvider);
      await repo.save(account);

      if (!mounted) return;
      ref.invalidate(hasActiveAccountProvider);
      // Ensure navbar user badge updates immediately
      ref.invalidate(activeAccountProvider);
      GoRouter.of(context).go('/projects');
    }
  }

  bool _didSetupListen = false;

  @override
  Widget build(BuildContext context) {
    // Setup Riverpod listen within build to satisfy web assertion
    if (!_didSetupListen) {
      _didSetupListen = true;
      ref.listen<LoginState>(loginViewModelProvider, (previous, current) {
        if (!mounted) return;
        if (current.account != null) {
          // Invalidate providers so router recognizes account
          ref.invalidate(hasActiveAccountProvider);
          ref.invalidate(activeAccountProvider);

          final account = current.account!;
          final isOffline = account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost');
          final destination = (isOffline || current.isReturningUser == false) ? '/projects' : '/today';
          // Defer navigation to next frame to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) GoRouter.of(context).go(destination);
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(_showHostingChoice ? 'Choose hosting' : 'Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _showHostingChoice
                  ? Column(
                      key: const ValueKey('hosting'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'How do you want to connect?',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _ConnectionOptionCard(
                          title: 'TowDow Cloud',
                          subtitle: 'Zero setup, secure cloud sync',
                          icon: Icons.cloud_rounded,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => const TowdowCloudDialog(),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _ConnectionOptionCard(
                          title: 'TowDow self hosted',
                          subtitle: 'Use your own TowDow server',
                          icon: Icons.account_circle_rounded,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => const TowdowSelfHostedDialog(),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _openOtherMethodsSheet,
                          icon: const Icon(Icons.more_horiz_rounded),
                          label: const Text('Other methods'),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('welcome'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Simple to‑do for you.\nPowerful workflows for your team.',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A clear task app that stays simple for individuals and scales to teams with flexible workflows.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 240,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _showHostingChoice = true),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Get started'),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ConnectionOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded),
        onTap: onTap,
      ),
    );
  }
}
