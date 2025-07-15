// Keycloak CalDAV connection dialog
// Allows users to configure their CalDAV server connection with Keycloak OAuth2 (cross-platform)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/caldav_account.dart';
import '../../../../data/services/caldav_service.dart';
import '../../../../data/services/user_sync_service.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/external_account_repository.dart';
import '../../../../data/repositories/external_calendar_repository.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/calendar_repository.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';
import 'calendar_selection_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openid_client/openid_client_io.dart';

const String TOWDOW_ISSUER_URL = "https://auth.towdow.app/realms/towdow";
const String CLIENT_ID = "radicale-api";
const String TOWDOW_SERVER_URL = "https://api.towdow.app";


class FlowitCloudDialog extends ConsumerStatefulWidget {

  const FlowitCloudDialog({super.key});

  @override
  ConsumerState<FlowitCloudDialog> createState() => _FlowitCloudDialogState();
}

class _FlowitCloudDialogState extends ConsumerState<FlowitCloudDialog> {

  bool _isLoading = false;
  String? _errorMessage;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  @override
  void initState() {
    super.initState();
      // Start login immediately for FlowIt Cloud
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithKeycloak();
      });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _authenticateWithKeycloak() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Discover the OpenID configuration
      final issuer = await Issuer.discover(
        Uri.parse(TOWDOW_ISSUER_URL),
      );
      final client = Client(
        issuer,
        CLIENT_ID,
        clientSecret: ""
      );

      // Use a fixed port for the local redirect server to be allowed on KeyCloak
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
        final idToken = c.idToken;
        final claims = idToken.claims;
        firstName = claims['given_name'] as String?;
        lastName = claims['family_name'] as String?;
        email = claims['email'] as String?;
              // Fallback: fetch userinfo if not present in idToken
        if (firstName == null || lastName == null || email == null) {
          final userInfo = await c.getUserInfo();
          firstName ??= userInfo.givenName;
          lastName ??= userInfo.familyName;
          email ??= userInfo.email;
        }
      } catch (_) {}

      setState(() {
        _accessToken = token.accessToken;
        _refreshToken = token.refreshToken;
        _tokenExpiry = token.expiresIn != null
            ? DateTime.now().add(token.expiresIn!)
            : null;
      });

      // Create a temporary account for testing
      final testAccount = CaldavAccount(
        id: const Uuid().v4(),
        providerType: 'towdow_cloud',
        serverUrl: TOWDOW_SERVER_URL,
        username: email ?? '',
        accessToken: _accessToken,
        refreshToken: _refreshToken,
        tokenExpiry: _tokenExpiry,
        clientId: CLIENT_ID,
        issuerUrl: TOWDOW_ISSUER_URL,
        firstName: firstName,
        lastName: lastName,
        email: email,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Check for existing user sync data first (before capability discovery)
      // Create minimal service instances for this check (we need to set the account first)
      final localStorage = LocalStorageService();
      await localStorage.initialize();
      
      final userRepository = LocalUserRepository(localStorage);
      final externalAccountRepository = LocalExternalAccountRepository(localStorage);
      final externalCalendarRepository = LocalExternalCalendarRepository(localStorage);
      final accountRepository = LocalAccountRepository(localStorage);
      final calendarRepository = LocalCalendarRepository(localStorage);
      
      final userSyncService = UserSyncService(
        userRepository: userRepository,
        externalAccountRepository: externalAccountRepository,
        externalCalendarRepository: externalCalendarRepository,
        accountRepository: accountRepository,
        calendarRepository: calendarRepository,
      );
      
      // Temporarily save the test account so userSyncService can access it
      await accountRepository.save(testAccount);
      
      final syncDownloadResult = await userSyncService.downloadUserData();
      final hasExistingData = syncDownloadResult.when(
        success: (hasData) => hasData,
        failure: (failure) {
          AppLogger.warning('TowDow Cloud login: Failed to check for existing user data: ${failure.message}');
          return false;
        },
      );
      
      // If we downloaded user data, trigger external calendar sync
      if (hasExistingData) {
        try {
          final externalSyncService = ref.read(externalCalendarSyncServiceProvider);
          final syncResult = await externalSyncService.syncAllAccounts();
          syncResult.when(
            success: (_) => AppLogger.info('TowDow Cloud login: External calendar sync completed successfully'),
            failure: (failure) => AppLogger.warning('TowDow Cloud login: External calendar sync failed: ${failure.message}'),
          );
        } catch (e, stackTrace) {
          AppLogger.error('TowDow Cloud login: Failed to trigger external calendar sync', e, stackTrace);
          // Don't fail the login process if external sync fails
        }
      }
      
      if (hasExistingData) {
        // User data found, go directly to home screen (account already saved)
        if (mounted) {
          // Invalidate the account status provider to ensure router recognizes the account
          ref.invalidate(hasActiveAccountProvider);
          
          Navigator.of(context).pop(); // Close dialog
          // Navigate to home screen using GoRouter
          GoRouter.of(context).go('/today');
        }
        return;
      }
      
      // No existing user data, proceed with normal flow (test connection and calendar selection)
      final caldavService = CalDAVService(account: testAccount);
      final testResult = await caldavService.testConnection();

      await testResult.when(
        success: (capabilities) async {
          if (mounted) {
            Navigator.of(context).pop(); // Close the dialog
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CalendarSelectionScreen(
                  account: testAccount,
                  capabilities: capabilities,
                ),
              ),
            );
          }
        },
        failure: (failure) async {
          setState(() {
            _errorMessage =
                'Connection test failed: \u001b[31m${failure.message}\u001b[0m';
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
    // Show only loading or error for FlowIt Cloud
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
            if (_isLoading) const CircularProgressIndicator(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // TextButton(
        //   onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        //   child: const Text('Cancel'),
        // ),
      ],
    );
  }
}
