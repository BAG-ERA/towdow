// TowDow Self-Hosted connection dialog
// Allows users to configure their CalDAV server connection with Keycloak OAuth2 (cross-platform)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/providers/providers.dart';
import '../../../viewmodels/login_viewmodel.dart';
import 'calendar_selection_screen.dart';

class TowdowSelfHostedDialog extends ConsumerStatefulWidget {
  const TowdowSelfHostedDialog({super.key});

  @override
  ConsumerState<TowdowSelfHostedDialog> createState() =>
      _TowdowSelfHostedDialogState();
}

class _TowdowSelfHostedDialogState
    extends ConsumerState<TowdowSelfHostedDialog> {
  final _formKey = GlobalKey<FormState>();

  final _issuerUrlController = TextEditingController();
  final _radicaleServerUrlController = TextEditingController();
  final _clientIdController = TextEditingController();

  @override
  void dispose() {
    _issuerUrlController.dispose();
    _clientIdController.dispose();
    _radicaleServerUrlController.dispose();
    super.dispose();
  }

  Future<void> _authenticateAndConnect() async {
    if (!_formKey.currentState!.validate()) return;
    
    await ref.read(loginViewModelProvider.notifier).authenticateWithSelfHosted(
      issuerUrl: _issuerUrlController.text.trim(),
      clientId: _clientIdController.text.trim(),
      serverUrl: _radicaleServerUrlController.text.trim(),
    );
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
          title: const Row(
            children: [
              Icon(Icons.cloud_rounded),
              SizedBox(width: 8),
              Text('Towdow Self-Hosted (Keycloak)'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 500
                ? 450
                : MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Connect to your self-hosted Towdow server with Keycloak (OIDC).',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'User Information',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _radicaleServerUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Radicale server URL',
                        hintText: 'https://api.your-server.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Server URL is required';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _issuerUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Issuer URL *',
                        hintText: 'https://your-keycloak/realms/yourrealm',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Issuer URL is required';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Client ID *',
                        hintText: 'radicale-api',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Client ID is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (loginState.isLoading) const CircularProgressIndicator(),
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
                        },
                        child: const Text('Clear Error'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: loginState.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: loginState.isLoading ? null : _authenticateAndConnect,
                          child: const Text('Connect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
