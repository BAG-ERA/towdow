// TowDow Cloud connection dialog
// Allows users to connect to TowDow Cloud using OAuth2 authentication

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/providers/providers.dart';
import '../../../viewmodels/login_viewmodel.dart';
import 'calendar_selection_screen.dart';


class FlowitCloudDialog extends ConsumerStatefulWidget {
  const FlowitCloudDialog({super.key});

  @override
  ConsumerState<FlowitCloudDialog> createState() => _FlowitCloudDialogState();
}

class _FlowitCloudDialogState extends ConsumerState<FlowitCloudDialog> {
  @override
  void initState() {
    super.initState();
    // Start login immediately for FlowIt Cloud
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loginViewModelProvider.notifier).authenticateWithTowDowCloud();
    });
  }

  void _handleLoginStateChange(LoginState state) {
    if (state.hasExistingUserData) {
      // User data found, go directly to home screen
      if (mounted) {
        // Invalidate the account status provider to ensure router recognizes the account
        ref.invalidate(hasActiveAccountProvider);
        
        Navigator.of(context).pop(); // Close dialog
        // Navigate to home screen using GoRouter
        GoRouter.of(context).go('/today');
      }
    } else if (state.account != null && state.capabilities != null) {
      // No existing data, proceed with calendar selection
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CalendarSelectionScreen(
              account: state.account!,
              capabilities: state.capabilities!,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final loginState = ref.watch(loginViewModelProvider);
        
        // Handle state changes (navigation)
        ref.listen<LoginState>(loginViewModelProvider, (previous, current) {
          _handleLoginStateChange(current);
        });
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cloud_rounded),
              const SizedBox(width: 8),
              const Text('FlowIt Cloud'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 500
                ? 450
                : MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connecting to FlowIt Cloud...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                if (loginState.isLoading) const CircularProgressIndicator(),
                if (loginState.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    loginState.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(loginViewModelProvider.notifier).clearError();
                      ref.read(loginViewModelProvider.notifier).authenticateWithTowDowCloud();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!loginState.isLoading)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
          ],
        );
      },
    );
  }
}
