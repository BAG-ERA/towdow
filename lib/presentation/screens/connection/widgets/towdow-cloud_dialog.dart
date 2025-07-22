// TowDow Cloud connection dialog
// Allows users to connect to TowDow Cloud using OAuth2 authentication

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Start login immediately for FlowIt Cloud only on non-web platforms
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(loginViewModelProvider.notifier).authenticateWithTowDowCloud();
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await ref
          .read(loginViewModelProvider.notifier)
          .authenticateWithCredentials(email: email, password: password);
    }
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
                if (kIsWeb)
                  ..._buildWebLoginForm(loginState)
                else
                  ..._buildNativeLoginFlow(loginState),
                if (loginState.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    loginState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(loginViewModelProvider.notifier).clearError();
                      if (kIsWeb) {
                        _login();
                      } else {
                        ref
                            .read(loginViewModelProvider.notifier)
                            .authenticateWithTowDowCloud();
                      }
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

  List<Widget> _buildNativeLoginFlow(LoginState loginState) {
    return [
      const Text(
        'Connecting to FlowIt Cloud...',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      const SizedBox(height: 24),
      if (loginState.isLoading) const CircularProgressIndicator(),
    ];
  }

  List<Widget> _buildWebLoginForm(LoginState loginState) {
    return [
      const Text(
        'Sign in to FlowIt Cloud',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter your credentials to access your FlowIt Cloud account',
        style: TextStyle(fontSize: 14, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
              AutofillGroup(
        child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loginState.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: loginState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
      ),
    ];
  }
}
