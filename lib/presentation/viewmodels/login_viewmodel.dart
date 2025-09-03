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
import '../../core/logger.dart';
import '../../core/result.dart';

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

  const LoginState({
    this.isLoading = false,
    this.error,
    this.account,
    this.isReturningUser,
  });

  LoginState copyWith({
    bool? isLoading,
    String? error,
    CaldavAccount? account,
    bool? isReturningUser,
  }) => LoginState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    account: account ?? this.account,
    isReturningUser: isReturningUser ?? this.isReturningUser,
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

      // Set account and complete authentication
      state = state.copyWith(
        account: account,
        isLoading: false,
      );
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

      // Always set hasExistingUserData to true to skip calendar selection
      state = state.copyWith(
        account: account,
        isLoading: false,
      );
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
}

// Provider
final loginViewModelProvider =
    StateNotifierProvider.autoDispose<LoginViewModel, LoginState>(
      (ref) => LoginViewModel(
        accountRepository: ref.read(accountRepositoryProvider),
        externalSyncService: ref.read(externalCalendarSyncServiceProvider),
      ),
    );
