// TowDow Cloud connection dialog
// Implementation of BaseAuthDialog for TowDow Cloud

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../viewmodels/login_viewmodel.dart';
import '../../../../web/web_utils.dart';
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
        'You will be redirected to the secure TowDow login page. After signing in, you\'ll return here automatically.',
        style: TextStyle(fontSize: 14, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loginState.isLoading
              ? null
              : () async {
                  final redirect = getRedirectUri();
                  final authUrl = Uri.parse(
                    'https://auth.towdow.app/realms/towdow/protocol/openid-connect/auth'
                    '?response_type=code'
                    '&client_id=radicale-api'
                    '&redirect_uri=' + Uri.encodeComponent(redirect) +
                    '&scope=' + Uri.encodeComponent('openid profile email offline_access'),
                  );
                  await launchUrl(authUrl, webOnlyWindowName: '_self');
                },
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: loginState.isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue with TowDow Cloud'),
        ),
      ),
    ];
  }
}
