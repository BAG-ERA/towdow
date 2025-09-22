// Login ViewModel
// Handles authentication flow, user sync, and login state management for both TowDow Cloud and self-hosted connections
//
// This ViewModel encapsulates:
// - OAuth2/OIDC authentication with Keycloak
// - User sync data download/upload
// - External calendar sync triggering
// - Connection testing and capability discovery
// - Navigation state management for login flows
//
// Follows MVVM architecture with proper dependency injection

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openid_client/openid_client_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:towdow_app/web/web_utils.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../../core/app_lifecycle_manager.dart';

import '../../data/models/caldav_account.dart';
import '../../data/services/integration/external_caldav_calendar/external_sync_service.dart';
import '../../data/services/storage/s3_storage_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/providers/providers.dart';

// Login state for authentication flows
class LoginState {
  final bool isLoading;
  final String? error;
  final CaldavAccount? account;
  final bool? isReturningUser; // null until checked
  final bool isConfiguringAccount; // true while lifecycle/services are starting

  const LoginState({
    this.isLoading = false,
    this.error,
    this.account,
    this.isReturningUser,
    this.isConfiguringAccount = false,
  });

  LoginState copyWith({
    bool? isLoading,
    String? error,
    CaldavAccount? account,
    bool? isReturningUser,
    bool? isConfiguringAccount,
  }) => LoginState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    account: account ?? this.account,
    isReturningUser: isReturningUser ?? this.isReturningUser,
    isConfiguringAccount: isConfiguringAccount ?? this.isConfiguringAccount,
  );
}

// Login ViewModel
class LoginViewModel extends StateNotifier<LoginState> {
  final AccountRepository _accountRepository;
  final ExternalCalendarSyncService _externalSyncService;

  LoginViewModel({
    required AccountRepository accountRepository,
    required ExternalCalendarSyncService externalSyncService,
  }) : _accountRepository = accountRepository,
       _externalSyncService = externalSyncService,
       super(const LoginState());

  // Detect returning user via S3 private bucket marker (preferences.json presence or any object)
  Future<bool> _detectReturningUser(CaldavAccount account) async {
    try {
      // Only for TowDow providers that have S3 credentials
      if (account.providerType != 'towdow_cloud' && account.providerType != 'towdow_self_hosted') {
        return false;
      }

      // Lightweight check: attempt to HEAD preferences.json in private bucket
      final s3 = S3StorageService(account: account);
      final prefix = s3.getUserPrefix();
      final key = '${prefix}preferences.json';
      final etagResult = await s3.getCurrentEtag(key: key, isPrivate: true);
      return await etagResult.when(
        success: (etag) => etag != null,
        failure: (_) async => false,
      );
    } catch (_) {
      return false;
    }
  }

  /// Authenticate with TowDow Cloud using fixed configuration
  Future<void> authenticateWithTowDowCloud() async {
    await _authenticateWithKeycloak(
      issuerUrl: "https://auth.towdow.app/realms/towdow",
      clientId: "radicale-api",
      serverUrl: "https://api.towdow.app",
      providerType: "towdow_cloud",
    );
  }

  /// Authenticate with self-hosted TowDow server
  Future<void> authenticateWithSelfHosted({
    required String issuerUrl,
    required String clientId,
    required String serverUrl,
  }) async {
    await _authenticateWithKeycloak(
      issuerUrl: issuerUrl,
      clientId: clientId,
      serverUrl: serverUrl,
      providerType: 'towdow_self_hosted',
    );
  }

  Future<void> _authenticateWithKeycloak({
    required String issuerUrl,
    required String clientId,
    required String serverUrl,
    String providerType = 'towdow_cloud',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    String successPage = '<h1> Login succeeded you can close this window now and go back to the app. </h1>';
    try{
      // get login success page from website
      final resp = await http.get(Uri.parse('https://towdow.gitlab.io/login_success.html'));

      if (resp.statusCode == 200) {
        successPage = resp.body;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Login: Failed to get success login page',
        e,
        stackTrace,
      );
    }

    try {

      // Discover the OpenID configuration
      final issuer = await Issuer.discover(Uri.parse(issuerUrl));
      final client = Client(issuer, clientId, clientSecret: "");

      // Use a fixed port for the local redirect server
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
        htmlPage: successPage,
      );

      final c = await authenticator.authorize();
      final token = await c.getTokenResponse();

      // Extract user info
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

      // Create account
      final account = CaldavAccount(
        id: const Uuid().v4(),
        providerType: providerType,
        serverUrl: serverUrl,
        username: email ?? '',
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        tokenExpiry: token.expiresIn != null
            ? DateTime.now().add(token.expiresIn!)
            : null,
        clientId: clientId,
        issuerUrl: issuerUrl,
        firstName: firstName,
        lastName: lastName,
        email: email,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Save account
      await _accountRepository.save(account);

      // Set account and enter configuration phase (UI can show setup view)
      state = state.copyWith(
        account: account,
        isConfiguringAccount: true,
        isLoading: false,
      );

      // Notify lifecycle to start main services (starts CalDAV monitor)
      try {
        await AppLifecycleManager.instance.onAccountConfigured();
        AppLogger.debug("Login: First app synchro completed");
      } catch (e) {
        AppLogger.warning('Login: Failed to notify lifecycle after account save: $e');
      }

      // Mark configuration as complete immediately after services start
      state = state.copyWith(
        isConfiguringAccount: false,
      );

      // Detect returning user (non-blocking)
      try {
        final returning = await _detectReturningUser(account);
        state = state.copyWith(isReturningUser: returning);
      } catch (_) {}

      // Trigger external calendar sync
      try {
        final syncResult = await _externalSyncService.syncAllAccounts();
        syncResult.when(
          success: (_) => AppLogger.info(
            'Login: External calendar sync completed successfully',
          ),
          failure: (failure) => AppLogger.warning(
            'Login: External calendar sync failed: ${failure.message}',
          ),
        );
      } catch (e, stackTrace) {
        AppLogger.error(
          'Login: Failed to trigger external calendar sync',
          e,
          stackTrace,
        );
      }

    } catch (e, stackTrace) {
      AppLogger.error('Login: Authentication failed', e, stackTrace);
      state = state.copyWith(
        error: 'Authentication failed: $e',
        isLoading: false,
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Authenticate with credentials (for web platform)
  Future<void> authenticateWebTowDowCloud({
    required String email,
    required String password,
  }) async {
    return authenticateWebSelfHosted(
      email: email,
      password: password,
      serverUrl: "https://api.towdow.app",
      issuerUrl: "https://auth.towdow.app/realms/towdow",
      clientId: "radicale-api",
    );
  }

  /// Authenticate with self-hosted credentials (for web platform)
  Future<void> authenticateWebSelfHosted({
    required String email,
    required String password,
    required String serverUrl,
    required String issuerUrl,
    required String clientId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Extract the tokenEndpoint from the issuer URL
      final tokenEndpoint = "$issuerUrl/protocol/openid-connect/token";

      // Make direct token request
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'client_id': clientId,
          'username': email,
          'password': password,
          'scope': 'openid profile email offline_access',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Authentication failed: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final tokenData = jsonDecode(response.body);

      // Create account
      final account = CaldavAccount(
        id: const Uuid().v4(),
        providerType: serverUrl == "https://api.towdow.app"
            ? 'towdow_cloud'
            : 'towdow_self_hosted',
        serverUrl: serverUrl,
        username: email,
        accessToken: tokenData['access_token'],
        refreshToken: tokenData['refresh_token'],
        tokenExpiry: DateTime.now().add(
          Duration(seconds: tokenData['expires_in']),
        ),
        clientId: clientId,
        issuerUrl: issuerUrl,
        firstName: null,
        lastName: null,
        email: email,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Save account
      await _accountRepository.save(account);

      // Expose account and enter configuration phase
      state = state.copyWith(
        account: account,
        isConfiguringAccount: true,
        isLoading: false,
      );

      // Notify lifecycle to start main services (starts CalDAV monitor)
      try {
        await AppLifecycleManager.instance.onAccountConfigured();
      } catch (e) {
        AppLogger.warning('Login: Failed to notify lifecycle after account save: $e');
      }

      // Mark configuration as complete immediately after services start
      state = state.copyWith(
        isConfiguringAccount: false,
      );

      // Detect returning user (non-blocking)
      try {
        final returning = await _detectReturningUser(account);
        state = state.copyWith(isReturningUser: returning);
      } catch (_) {}

      // Trigger external calendar sync
      try {
        final syncResult = await _externalSyncService.syncAllAccounts();
        syncResult.when(
          success: (_) => AppLogger.info(
            'Login: External calendar sync completed successfully',
          ),
          failure: (failure) => AppLogger.warning(
            'Login: External calendar sync failed: ${failure.message}',
          ),
        );
      } catch (e, stackTrace) {
        AppLogger.error(
          'Login: Failed to trigger external calendar sync',
          e,
          stackTrace,
        );
      }

    } catch (e, stackTrace) {
      AppLogger.error(
        'Login: Authentication with credentials failed',
        e,
        stackTrace,
      );
      state = state.copyWith(
        error: 'Authentication failed: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  void reset() {
    state = const LoginState();
  }

  /// Authenticate on web using an authorization code (Keycloak)
  Future<void> authenticateWebWithAuthCode({
    required String code,
    String issuerUrl = "https://auth.towdow.app/realms/towdow",
    String clientId = "radicale-api",
    String serverUrl = "https://api.towdow.app",
    String? redirectUri,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tokenEndpoint = "$issuerUrl/protocol/openid-connect/token";

      // On web, use a fetch-based form-encoded POST to avoid CORS preflight issues.
      int statusCode;
      String bodyStr;
      if (kIsWeb) {
        final res = await postFormUrlEncoded(tokenEndpoint, {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUri ?? getRedirectUri(),
        });
        statusCode = res.statusCode;
        bodyStr = res.body;
      } else {
        final response = await http.post(
          Uri.parse(tokenEndpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'authorization_code',
            'client_id': clientId,
            'code': code,
            'redirect_uri': redirectUri ?? getRedirectUri(),
          },
        );
        statusCode = response.statusCode;
        bodyStr = response.body;
      }

      if (statusCode != 200) {
        throw Exception('Auth code exchange failed: $statusCode');
      }

      final tokenData = jsonDecode(bodyStr);

      // Try to extract profile fields from id_token claims
      String? emailFromIdToken;
      String? firstNameFromIdToken;
      String? lastNameFromIdToken;
      try {
        final idToken = tokenData['id_token'] as String?;
        if (idToken != null && idToken.isNotEmpty) {
          final parts = idToken.split('.');
          if (parts.length >= 2) {
            final payload = parts[1]
                .replaceAll('-', '+')
                .replaceAll('_', '/');
            // Fix base64 padding if needed
            final normalized = payload + '=' * ((4 - payload.length % 4) % 4);
            final decoded = utf8.decode(base64.decode(normalized));
            final claims = jsonDecode(decoded) as Map<String, dynamic>;
            emailFromIdToken = claims['email'] as String?;
            firstNameFromIdToken = claims['given_name'] as String?;
            lastNameFromIdToken = claims['family_name'] as String?;
          }
        }
        else{
          AppLogger.warning("Login: idToken empty or null");
        }
      } catch (e, stackTrace) {
        AppLogger.warning('Login: Failed to decode id_token claims on web', e, stackTrace);
      }

      final account = CaldavAccount(
        id: const Uuid().v4(),
        providerType: serverUrl == "https://api.towdow.app" ? 'towdow_cloud' : 'towdow_self_hosted',
        serverUrl: serverUrl,
        // Use email or preferred username when available to avoid empty username on web
        username: emailFromIdToken ?? '--',
        accessToken: tokenData['access_token'],
        refreshToken: tokenData['refresh_token'],
        tokenExpiry: DateTime.now().add(Duration(seconds: tokenData['expires_in'] ?? 3600)),
        clientId: clientId,
        issuerUrl: issuerUrl,
        firstName: firstNameFromIdToken ?? '--',
        lastName: lastNameFromIdToken ?? '--',
        email: emailFromIdToken,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      await _accountRepository.save(account);

      // Enter configuration phase and expose account to UI
      if (!mounted) return;
      state = state.copyWith(account: account, isConfiguringAccount: true, isLoading: false);

      // Notify lifecycle to start main services (starts CalDAV monitor)
      AppLogger.info('Login: waiting Account to be configured configured');
      try {
        await AppLifecycleManager.instance.onAccountConfigured();
        AppLogger.info('Login: Account configured');
      } catch (e) {
        AppLogger.warning('Login: Failed to notify lifecycle after account save: $e');
      }

      // Mark configuration as complete immediately after services start
      state = state.copyWith(isConfiguringAccount: false);

      try {
        final returning = await _detectReturningUser(account);
        if (!mounted) return; // notifier might have been disposed
        state = state.copyWith(isReturningUser: returning);
      } catch (_) {}

      try {
        final syncResult = await _externalSyncService.syncAllAccounts();
        syncResult.when(
          success: (_) => AppLogger.info('Login: External calendar sync completed successfully'),
          failure: (failure) => AppLogger.warning('Login: External calendar sync failed: ${failure.message}'),
        );
      } catch (e, stackTrace) {
        AppLogger.error('Login: Failed to trigger external calendar sync', e, stackTrace);
      }

      if (!mounted) return;
    } catch (e, stackTrace) {
      AppLogger.error('Login: Auth code authentication failed', e, stackTrace);
      if (!mounted) return;
      state = state.copyWith(error: 'Authentication failed: ${e.toString()}', isLoading: false);
    }
  }
}

// Provider
final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, LoginState>(
      (ref) => LoginViewModel(
        accountRepository: ref.read(accountRepositoryProvider),
        externalSyncService: ref.read(externalCalendarSyncServiceProvider),
      ),
    );
