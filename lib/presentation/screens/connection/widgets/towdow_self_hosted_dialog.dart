// TowDow Self-Hosted connection dialog
// Implementation of BaseAuthDialog for Self-Hosted TowDow servers

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../viewmodels/login_viewmodel.dart';
import 'base_auth_dialog.dart';

class TowdowSelfHostedDialog extends BaseAuthDialog {
  const TowdowSelfHostedDialog({super.key}) : super(type: AuthDialogType.selfHosted);

  @override
  ConsumerState<TowdowSelfHostedDialog> createState() => _TowdowSelfHostedDialogState();
}

class _TowdowSelfHostedDialogState extends BaseAuthDialogState<TowdowSelfHostedDialog> {
  @override
  String getDialogTitle() => 'TowDow Self-Hosted (Keycloak)';

  @override
  List<Widget> buildNativeLoginFlow(LoginState loginState) {
    return [
      const Text(
        'Connect to your self-hosted TowDow server with Keycloak (OIDC).',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      const SizedBox(height: 24),
      Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildServerConfigFields(),
            const SizedBox(height: 24),
            buildConnectButton(loginState),
          ],
        ),
      ),
    ];
  }

  @override
  List<Widget> buildWebLoginForm(LoginState loginState) {
    return [
      const Text(
        'Sign in to Self-Hosted TowDow',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter your credentials and server information',
        style: TextStyle(fontSize: 14, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildServerConfigFields(),
              const SizedBox(height: 24),
              Text(
                'Credentials',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              buildCredentialsFields(),
              const SizedBox(height: 24),
              buildLoginButton(loginState),
            ],
          ),
        ),
      ),
    ];
  }
}
