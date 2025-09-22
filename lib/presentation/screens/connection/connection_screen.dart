// Connection screen for CalDAV account setup
// Onboarding screen for configuring server connections

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/custom_caldav_dialog.dart';
import 'widgets/towdow_cloud_dialog.dart';
import 'widgets/towdow_self_hosted_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/caldav_account.dart';
import '../../../data/providers/providers.dart';
import '../../viewmodels/login_viewmodel.dart';
import '../../../web/web_utils.dart';
import '../../../core/logger.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  // Guard to ensure we only navigate once after authentication completes
  bool _handledPostAuthNavigation = false;
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
          final storedRedirect = WebLocalStorage.getItem('redirectUri');
          String? sanitizedRedirect = storedRedirect;
          if (sanitizedRedirect == null || sanitizedRedirect.isEmpty) {
            // Fallback to computed sanitized redirect
            sanitizedRedirect = getRedirectUri();
          }
          // Always remove stored value to avoid reuse
          WebLocalStorage.removeItem('redirectUri');
          AppLogger.info('ConnectionScreen: Found authCode in localStorage, starting login');

          // Start authentication with default TowDow Cloud settings
          await ref.read(loginViewModelProvider.notifier).authenticateWebWithAuthCode(
                code: authCode,
                redirectUri: sanitizedRedirect,
              );

          // After authentication completes, force providers refresh and navigate
          try {
            ref.invalidate(hasActiveAccountProvider);
            ref.invalidate(activeAccountProvider);

            // Wait until account status reflects the newly saved account to avoid router redirect races
            try { await ref.read(hasActiveAccountProvider.future); } catch (_) {}
            // Determine destination similar to listener logic, but prioritize target project from magic link
            final account = await ref.read(activeAccountProvider.future);
            if (account != null && mounted && !_handledPostAuthNavigation) {
                          _handledPostAuthNavigation = true;
              // Try to read target project path saved by main.dart from the initial magic link
              String? targetProjectPath = WebLocalStorage.getItem('targetProjectPath');
              AppLogger.debug('ConnectionScreen: targetProjectPath: $targetProjectPath');
              if (targetProjectPath != null && targetProjectPath.isNotEmpty) {
                // Clear it after use to avoid unintended future redirects
                // WebLocalStorage.removeItem('targetProjectPath');
                final destination = '/project/${account.id}/${Uri.encodeComponent(targetProjectPath)}';
                AppLogger.debug('ConnectionScreen: routing to : $destination');
                GoRouter.of(context).go(destination);
              } else {
                final isOffline = account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost');
                final destination = isOffline ? '/projects' : '/today';
                AppLogger.debug('ConnectionScreen: routing to : $destination');
                GoRouter.of(context).go(destination);
              }
            }
            else{
              AppLogger.warning("ConnectionScreen: no account after login from magik link");
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
                title: Text(AppLocalizations.of(context)!.customCaldav),
                subtitle: Text(AppLocalizations.of(context)!.connectAnyCaldavServer),
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
                title: Text(AppLocalizations.of(context)!.offlineNoAccountTitle),
                subtitle: Text(AppLocalizations.of(context)!.offlineNoAccountSubtitle),
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
            title: Text(AppLocalizations.of(context)!.offlineOnly),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.offlineOnlyExplainer,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: understood,
                      onChanged: (v) => setState(() => understood = v ?? false),
                    ),
                    Expanded(
                      child: Text(AppLocalizations.of(context)!.offlineOnlyAcknowledge),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: understood
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(AppLocalizations.of(context)!.startOffline),
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
      AppLogger.debug("[ROUTING] redirect '/projects' (_confirmOfflineOnly)");
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
        if (current.account != null && !_handledPostAuthNavigation) {
          // If account is in configuration, go to setup screen first
          if (current.isConfiguringAccount == true) {
            _handledPostAuthNavigation = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                AppLogger.debug("[ROUTING] redirect '/account-setup' (connect_screen - configuring)");
                GoRouter.of(context).go('/account-setup');
              }
            });
            return;
          }

          // If a target project is pending (from magic link), let the initState flow handle navigation
          final pendingTarget = WebLocalStorage.getItem('targetProjectPath');
          if (pendingTarget != null && pendingTarget.isNotEmpty) {
            AppLogger.debug("ConnectionScreen: pending targetProjectPath detected, skipping listener navigation");
            return; // Avoid racing with initState handler which will navigate to /project/:path
          }

          _handledPostAuthNavigation = true;
          // Invalidate providers so router recognizes account
          ref.invalidate(hasActiveAccountProvider);
          ref.invalidate(activeAccountProvider);

          // Ensure router sees the updated account state before we navigate,
          // otherwise it might immediately redirect back to /connect.
          Future.microtask(() async {
            try { await ref.read(hasActiveAccountProvider.future); } catch (_) {}
            final account = current.account!;
            // Prefer target project if present (should be absent here due to early return)
            String? targetProjectPath = WebLocalStorage.getItem('targetProjectPath');
            if (targetProjectPath != null && targetProjectPath.isNotEmpty) {
              // WebLocalStorage.removeItem('targetProjectPath');
              final encoded = Uri.encodeComponent(targetProjectPath);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  AppLogger.debug("[ROUTING] redirect '/project/$encoded' (connect_screen / microtask)");
                  GoRouter.of(context).go('/project/$encoded');
                }
              });
            } else {
              final isOffline = account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost');
              final destination = (isOffline || current.isReturningUser == false) ? '/projects' : '/today';
              // Defer navigation to next frame to avoid setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AppLogger.debug("[ROUTING] redirect '$destination' (connect_screen / microtask)");
                if (mounted) GoRouter.of(context).go(destination);
              });
            }
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(_showHostingChoice ? AppLocalizations.of(context)!.chooseHostingTitle : AppLocalizations.of(context)!.welcomeTitle)), 
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
                          AppLocalizations.of(context)!.howDoYouWantToConnect,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _ConnectionOptionCard(
                          title: AppLocalizations.of(context)!.towDowCloud,
                          subtitle: AppLocalizations.of(context)!.cloudOptionSubtitle,
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
                          title: AppLocalizations.of(context)!.towDowSelfHosted,
                          subtitle: AppLocalizations.of(context)!.selfHostedOptionSubtitle,
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
                          label: Text(AppLocalizations.of(context)!.otherMethods),
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
                          AppLocalizations.of(context)!.welcomeHeadline,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)!.welcomeBody,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 240,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _showHostingChoice = true),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(AppLocalizations.of(context)!.getStarted),
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
