// Keycloak CalDAV connection dialog
// Allows users to configure their CalDAV server connection with Keycloak OAuth2 (cross-platform)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/caldav_account.dart';
import '../../../../data/services/caldav_service.dart';
import 'calendar_selection_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:openid_client/openid_client_io.dart';
import '../../../../data/services/webdav_client.dart';
import '../../../../core/logger.dart';
import 'package:hive/hive.dart';
import '../../../../data/models/storage_config.dart';

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

  bool _isLoading = false;
  String? _errorMessage;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  final TextEditingController _s3EndpointController = TextEditingController();

  @override
  void dispose() {
    _radicaleServerUrlController.dispose();
    _issuerUrlController.dispose();
    _clientIdController.dispose();
    _s3EndpointController.dispose();
    super.dispose();
  }

  Future<void> _authenticateAndConnect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final issuer = await Issuer.discover(
        Uri.parse(_issuerUrlController.text.trim()),
      );
      final client = Client(
        issuer,
        _clientIdController.text.trim(),
        clientSecret: "",
      );
      final redirectPort = 4000;
      final redirectUri = Uri.parse('http://localhost:$redirectPort/callback');
      final authenticator = Authenticator(
        client,
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        port: redirectPort,
        urlLancher: (url) async {
          if (!await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          )) {
            throw Exception('Could not launch $url');
          }
        },
        redirectUri: redirectUri,
      );
      final c = await authenticator.authorize();
      final token = await c.getTokenResponse();
      // Extract user info from ID token claims (preferred) or userinfo endpoint
      String? firstName;
      String? lastName;
      String? email;
      try {
        final userInfo = await c.getUserInfo();
        firstName ??= userInfo.givenName;
        lastName ??= userInfo.familyName;
        email ??= userInfo.email;
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to extract user info from ID token',
          e,
          stackTrace,
        );
      }
      setState(() {
        _accessToken = token.accessToken;
        _refreshToken = token.refreshToken;
        _tokenExpiry = token.expiresIn != null
            ? DateTime.now().add(token.expiresIn!)
            : null;
      });
      final account = CaldavAccount(
        id: const Uuid().v4(),
        providerType: 'towdow_cloud',
        serverUrl: _radicaleServerUrlController.text.trim(),
        username: email ?? '',
        accessToken: _accessToken,
        refreshToken: _refreshToken,
        tokenExpiry: _tokenExpiry,
        clientId: _clientIdController.text.trim(),
        issuerUrl: _issuerUrlController.text.trim(),
        firstName: firstName,
        lastName: lastName,
        email: email,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Persist S3 endpoint configuration linked to this account
      final storageConfig = StorageConfig(
        accountId: account.id,
        s3Endpoint: _s3EndpointController.text.trim(),
      );
      final box = await Hive.openBox<StorageConfig>('storage_configs');
      await box.put(account.id, storageConfig);

      final caldavService = CalDAVService(account: account);
      final testResult = await caldavService.testConnection();
      await testResult.when(
        success: (capabilities) async {
          if (mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CalendarSelectionScreen(
                  account: account,
                  capabilities: capabilities,
                ),
              ),
            );
          }
        },
        failure: (failure) async {
          setState(() {
            _errorMessage = 'Connection test failed: ${failure.message}';
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _s3EndpointController,
                  decoration: const InputDecoration(
                    labelText: 'S3 Endpoint *',
                    hintText: 'https://minio.your-server.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cloud_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'S3 endpoint is required';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                if (_isLoading) const CircularProgressIndicator(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _authenticateAndConnect,
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
  }
}
