// Base Authentication Dialog
// Shared functionality between TowDow Cloud and Self-Hosted dialogs

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:towdow_app/core/logger.dart';
import '../../../../data/providers/providers.dart';
import '../../../viewmodels/login_viewmodel.dart';

enum AuthDialogType {
  cloud,
  selfHosted
}

abstract class BaseCloudAuthDialog extends ConsumerStatefulWidget {
  final AuthDialogType type;

  const BaseCloudAuthDialog({required this.type, super.key});
}

abstract class BaseCloudAuthDialogState<T extends BaseCloudAuthDialog> extends ConsumerState<T> {
  // Make controllers protected so subclasses can access them
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _issuerUrlController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _clientIdController = TextEditingController();

  // Expose getters for controllers if needed in subclasses
  TextEditingController get emailController => _emailController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get issuerUrlController => _issuerUrlController;
  TextEditingController get serverUrlController => _serverUrlController;
  TextEditingController get clientIdController => _clientIdController;

  // Expose form key for subclasses
  GlobalKey<FormState> get formKey => _formKey;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _issuerUrlController.dispose();
    _serverUrlController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // For cloud type on non-web platforms, start OAuth flow immediately
    if (widget.type == AuthDialogType.cloud && !kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(loginViewModelProvider.notifier).authenticateWithTowDowCloud();
      });
    }

  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) return;

    if (widget.type == AuthDialogType.cloud) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await ref
          .read(loginViewModelProvider.notifier)
          .authenticateWebTowDowCloud(email: email, password: password);
    } else {
      // Self-hosted web authentication
      await ref.read(loginViewModelProvider.notifier).authenticateWebSelfHosted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            serverUrl: _serverUrlController.text.trim(),
            issuerUrl: _issuerUrlController.text.trim(),
            clientId: _clientIdController.text.trim(),
          );
    }
  }

  Future<void> _authenticateAndConnect() async {
    AppLogger.info("_authenticateAndConnect called");
    // Ensure form validation works correctly
    if (formKey.currentState == null) {
      AppLogger.error("Form key state is null");
      return;
    }

    if (!formKey.currentState!.validate()) {
      AppLogger.error("Form validation failed");
      return;
    }

    AppLogger.info("Form validated, proceeding with authentication");
    await ref.read(loginViewModelProvider.notifier).authenticateWithSelfHosted(
      issuerUrl: _issuerUrlController.text.trim(),
      clientId: _clientIdController.text.trim(),
      serverUrl: _serverUrlController.text.trim(),
    );
  }

  void _handleLoginStateChange(LoginState state) {
    // Always redirect to today screen after successful authentication
    if (state.account != null) {
      if (mounted) {
        // Invalidate the account status provider to ensure router recognizes the account
        ref.invalidate(hasActiveAccountProvider);
        // Also invalidate active account details so the navbar badge updates immediately
        ref.invalidate(activeAccountProvider);

        Navigator.of(context).pop(); // Close dialog
        // Navigate based on returning/new detection; default to projects when custom/offline/new
        final account = state.account;
        final isOffline = account != null && (account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost'));
        final destination = (isOffline || state.isReturningUser == false) ? '/projects' : '/today';
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            GoRouter.of(context).go(destination);
          }
        });
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
              Text(getDialogTitle()),
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
                  ...buildWebLoginForm(loginState)
                else
                  ...buildNativeLoginFlow(loginState),
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
                      } else if (widget.type == AuthDialogType.cloud) {
                        ref
                            .read(loginViewModelProvider.notifier)
                            .authenticateWithTowDowCloud();
                      } else {
                        _authenticateAndConnect();
                      }
                    },
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!loginState.isLoading)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
          ],
        );
      },
    );
  }

  // Abstract methods to be implemented by subclasses
  String getDialogTitle();
  List<Widget> buildNativeLoginFlow(LoginState loginState);
  List<Widget> buildWebLoginForm(LoginState loginState);

  // Shared helper methods
  Widget buildServerConfigFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.serverInformation,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serverUrlController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.serverUrlLabel,
            hintText: 'https://api.your-server.com',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.dns_rounded),
          ),
          autofillHints: const [AutofillHints.url],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)!.noneFound(AppLocalizations.of(context)!.serverUrlLabel.toLowerCase());
            }
            return null;
          },
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _issuerUrlController,
          decoration: InputDecoration(
            labelText: 'Issuer URL',
            hintText: 'https://your-keycloak/realms/yourrealm',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.security_rounded),
          ),
          autofillHints: const [AutofillHints.url],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)!.noneFound('issuer url');
            }
            return null;
          },
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _clientIdController,
          decoration: InputDecoration(
            labelText: 'Client ID',
            hintText: 'radicale-api',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.vpn_key_rounded),
          ),
          autofillHints: const [AutofillHints.username],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)!.noneFound('client id');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget buildCredentialsFields() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.emailAddress,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.noneFound(AppLocalizations.of(context)!.emailAddress.toLowerCase());
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
              return AppLocalizations.of(context)!.pleaseEnterValidEmail;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.noneFound('password');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget buildLoginButton(LoginState loginState) {
    return SizedBox(
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
    );
  }

  Widget buildConnectButton(LoginState loginState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loginState.isLoading ? null : _authenticateAndConnect,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: loginState.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(AppLocalizations.of(context)!.connect),
      ),
    );
  }
}
