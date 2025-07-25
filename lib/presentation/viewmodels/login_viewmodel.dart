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

import '../../data/models/caldav_account.dart';
import '../../data/services/caldav_service.dart';
import '../../data/services/user_sync_service.dart';
import '../../data/services/external_sync_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/providers/providers.dart';

// Login state for authentication flows
class LoginState {
  final bool isLoading;
  final String? error;
  final CaldavAccount? account;
  final bool hasExistingUserData;
  final CalDAVCapabilities? capabilities;

  const LoginState({
    this.isLoading = false,
    this.error,
    this.account,
    this.hasExistingUserData = false,
    this.capabilities,
  });

  LoginState copyWith({
    bool? isLoading,
    String? error,
    CaldavAccount? account,
    bool? hasExistingUserData,
    CalDAVCapabilities? capabilities,
  }) => LoginState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    account: account ?? this.account,
    hasExistingUserData: hasExistingUserData ?? this.hasExistingUserData,
    capabilities: capabilities ?? this.capabilities,
  );
}

// Login ViewModel
class LoginViewModel extends StateNotifier<LoginState> {
  final AccountRepository _accountRepository;
  final UserSyncService _userSyncService;
  final ExternalCalendarSyncService _externalSyncService;

  LoginViewModel({
    required AccountRepository accountRepository,
    required UserSyncService userSyncService,
    required ExternalCalendarSyncService externalSyncService,
  }) : _accountRepository = accountRepository,
       _userSyncService = userSyncService,
       _externalSyncService = externalSyncService,
       super(const LoginState());

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

      // Save account temporarily for user sync check
      await _accountRepository.save(account);

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

        state = state.copyWith(
          account: account,
          hasExistingUserData: true,
          isLoading: false,
        );
        return;
    } catch (e, stackTrace) {
      AppLogger.error('Login: Authentication failed', e, stackTrace);
      state = state.copyWith(
        error: 'Authentication failed: $e',
        isLoading: false,
      );
    }
  }

  Future<void> _testConnectionAndDiscoverCapabilities(
    CaldavAccount account,
  ) async {
    try {
      final caldavService = CalDAVService(account: account);
      final testResult = await caldavService.testConnection();

      await testResult.when(
        success: (capabilities) async {
          // Update account with discovered principal and calendarHome
          final updatedAccount = account.copyWith(
            principal: capabilities.principal,
            calendarHome: capabilities.calendarHome,
          );
          
          // Save the updated account with principal and calendarHome
          await _accountRepository.save(updatedAccount);
          
          state = state.copyWith(
            account: updatedAccount,
            capabilities: capabilities,
            hasExistingUserData: false,
            isLoading: false,
          );
        },
        failure: (failure) async {
          state = state.copyWith(
            error: 'Connection test failed: ${failure.message}',
            isLoading: false,
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Login: Connection test failed', e, stackTrace);
      state = state.copyWith(
        error: 'Connection test failed: $e',
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
        // Would need to decode JWT token to get these
        lastName: null,
        email: email,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Save account temporarily for user sync check
      await _accountRepository.save(account);

      // Check for existing user data
      final syncDownloadResult = await _userSyncService.downloadUserData();
      final hasExistingData = syncDownloadResult.when(
        success: (hasData) => hasData,
        failure: (failure) {
          AppLogger.warning(
            'Login: Failed to check for existing user data: ${failure.message}',
          );
          return false;
        },
      );

      if (hasExistingData) {
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

        state = state.copyWith(
          account: account,
          hasExistingUserData: true,
          isLoading: false,
        );
        return;
      }

      // No existing data, test connection for capability discovery
      await _testConnectionAndDiscoverCapabilities(account);
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
        userSyncService: ref.read(userSyncServiceProvider),
        externalSyncService: ref.read(externalCalendarSyncServiceProvider),
      ),
    );
