// TowDow Cloud connection dialog
// Implementation of BaseAuthDialog for TowDow Cloud

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../viewmodels/login_viewmodel.dart';
import 'cloud_auth_dialog.dart';

class TowdowCloudDialog extends BaseCloudAuthDialog {
  const TowdowCloudDialog({super.key}) : super(type: AuthDialogType.cloud);

  @override
  ConsumerState<TowdowCloudDialog> createState() => _TowdowCloudDialogState();
}

class _TowdowCloudDialogState extends BaseCloudAuthDialogState<TowdowCloudDialog> {
  @override
  String getDialogTitle() => 'TowDow Cloud';

  @override
  List<Widget> buildNativeLoginFlow(LoginState loginState) {
    return [
      const Text(
        'Connecting to TowDow Cloud...',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      const SizedBox(height: 24),
      if (loginState.isLoading) const CircularProgressIndicator(),
    ];
  }

  @override
  List<Widget> buildWebLoginForm(LoginState loginState) {
    return [
      const Text(
        'Sign in to TowDow Cloud',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter your credentials to access your TowDow Cloud account',
        style: TextStyle(fontSize: 14, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            children: [
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
