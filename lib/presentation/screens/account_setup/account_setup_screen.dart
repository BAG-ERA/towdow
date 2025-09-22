import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/login_viewmodel.dart';
import '../../../core/logger.dart';
import '../../../web/web_utils.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  void _maybeLeaveSetup(LoginState current) {
    if (!mounted) return;
    final account = current.account;
    if (account != null && current.isConfiguringAccount == false) {
      AppLogger.debug("AccountSetupScreen: ");
      final isOffline = account.serverUrl.startsWith('https://localhost') ||
          account.serverUrl.startsWith('http://localhost');
      String destination = (isOffline || current.isReturningUser == false)
          ? '/projects'
          : '/today';

      // On web, if a target project path is present in local storage, prioritize redirecting to that project
      try {
        final target = WebLocalStorage.getItem('targetProjectPath');
        if (target != null && target.isNotEmpty) {
          destination = '/project/${Uri.encodeComponent(target)}';
        }
      } catch (_) {}

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppLogger.debug("[ROUTING] redirect '$destination' (account_setup)");
          GoRouter.of(context).go(destination);
        }
      });
    }
    else{
      if (account == null){
        AppLogger.warning("AccountSetupScreen: account is null when waiting for account setup");
      }
      else{
        AppLogger.warning("AccountSetupScreen: isConfiguringAccount is false when waiting for account setup");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.05)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _didListen = false;

  @override
  Widget build(BuildContext context) {
    // Navigate away when configuration completes or if already completed before listener attached
    if (!_didListen) {
      _didListen = true;
      // 1) Attach listener for future changes
      ref.listen<LoginState>(loginViewModelProvider, (prev, current) {
        _maybeLeaveSetup(current);
      });
      // 2) Also check immediately in case configuration already finished
      final current = ref.read(loginViewModelProvider);
      _maybeLeaveSetup(current);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Setting things up'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulse,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                        ),
                      ),
                      Icon(
                        Icons.cloud_sync_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Getting your account ready…',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'TowDow is starting services and preparing your workspace. This usually takes a few seconds.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
