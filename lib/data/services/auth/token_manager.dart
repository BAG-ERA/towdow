import 'dart:async';

import 'package:openid_client/openid_client.dart';

import '../../../core/logger.dart';

/// A singleton responsible for holding and refreshing OAuth tokens.
/// Keeps tokens centralized across services so they don't each manage copies.
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _clientId;
  String? _issuerUrl;

  // Ensure only one refresh happens at a time
  Future<String?>? _refreshInFlight;

  // Listeners to be notified when tokens change (for persistence or observers)
  final Set<void Function(String accessToken, String? refreshToken, DateTime? tokenExpiry)> _listeners = {};

  void configure({
    required String? accessToken,
    required String? refreshToken,
    required DateTime? tokenExpiry,
    required String? clientId,
    required String? issuerUrl,
  }) {
    // Always set static OIDC client configuration (idempotent)
    _clientId = clientId ?? _clientId;
    _issuerUrl = issuerUrl ?? _issuerUrl;

    // Guard against overwriting fresher tokens with stale ones.
    // Prefer incoming tokens only if:
    // - we currently have no tokens, or
    // - incoming expiry is later than current expiry.
    // Never overwrite with nulls.
    final hasCurrent = _accessToken != null || _refreshToken != null || _tokenExpiry != null;
    bool shouldApplyNewTokens = false;
    if (!hasCurrent) {
      shouldApplyNewTokens = (accessToken != null || refreshToken != null || tokenExpiry != null);
    } else {
      if (tokenExpiry != null) {
        if (_tokenExpiry == null || tokenExpiry.isAfter(_tokenExpiry!)) {
          shouldApplyNewTokens = true;
        }
      } else {
        // No expiry info: only apply if we currently lack an access token
        // (avoid overwriting a valid token with potentially stale data)
        if (_accessToken == null && accessToken != null) {
          shouldApplyNewTokens = true;
        }
      }
    }

    if (shouldApplyNewTokens) {
      if (accessToken != null) _accessToken = accessToken;
      if (refreshToken != null) _refreshToken = refreshToken;
      if (tokenExpiry != null) _tokenExpiry = tokenExpiry;
      _notifyListeners();
    }
  }

  void updateTokens({
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  }) {
    // Apply same freshness guard as in configure
    bool shouldApplyNewTokens = false;
    if (_accessToken == null && _refreshToken == null && _tokenExpiry == null) {
      shouldApplyNewTokens = (accessToken != null || refreshToken != null || tokenExpiry != null);
    } else {
      if (tokenExpiry != null) {
        if (_tokenExpiry == null || tokenExpiry.isAfter(_tokenExpiry!)) {
          shouldApplyNewTokens = true;
        }
      } else {
        if (_accessToken == null && accessToken != null) {
          shouldApplyNewTokens = true;
        }
      }
    }

    if (shouldApplyNewTokens) {
      if (accessToken != null) _accessToken = accessToken;
      if (refreshToken != null) _refreshToken = refreshToken;
      if (tokenExpiry != null) _tokenExpiry = tokenExpiry;
      _notifyListeners();
    }
  }

  // Add/remove listeners. If accessToken is null, we skip immediate notification.
  void addListener(void Function(String accessToken, String? refreshToken, DateTime? tokenExpiry) listener) {
    _listeners.add(listener);
    // Optionally, immediately inform the listener of current tokens if available
    if (_accessToken != null) {
      listener(_accessToken!, _refreshToken, _tokenExpiry);
    }
  }

  void removeListener(void Function(String accessToken, String? refreshToken, DateTime? tokenExpiry) listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    if (_accessToken == null) return; // we notify only when we have a usable access token
    for (final l in _listeners) {
      try {
        l(_accessToken!, _refreshToken, _tokenExpiry);
      } catch (e, st) {
        AppLogger.error('TokenManager: listener threw', e, st);
      }
    }
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  DateTime? get tokenExpiry => _tokenExpiry;

  bool get _isTokenExpired {
    if (_tokenExpiry == null) return false;
    // 1 minute buffer
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 1)));
  }

  /// Returns a valid access token, refreshing if necessary.
  Future<String?> getValidAccessToken() async {
    // If we already have a non-expired access token, return it.
    if (_accessToken != null && !_isTokenExpired) {
      return _accessToken;
    }

    // If we don't have an access token (e.g., after app restart) but we do have a refresh token,
    // try to refresh to obtain a new access token.
    if (_accessToken == null && _refreshToken != null) {
      return await _refreshAccessToken();
    }

    // If token is expired (or near expiry), refresh it.
    if (_isTokenExpired) {
      return await _refreshAccessToken();
    }

    // Otherwise we have no access token and can't refresh, return null.
    return _accessToken;
  }

  Future<String?> _refreshAccessToken() async {
    AppLogger.debug("refresh token request");
    // If a refresh is already in progress, return the same Future for all callers
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      AppLogger.debug("refresh token in progress");
      return inFlight;
    }

    AppLogger.debug("no refresh in progress, starting refresh token");
    final completer = Completer<String?>();
    _refreshInFlight = completer.future;

    () async {
      try {
        if (_refreshToken == null || _clientId == null || _issuerUrl == null) {
          AppLogger.warning('TokenManager: Missing data for refresh');
          // We cannot refresh; resolve with whatever access token we currently have (may be null)
          completer.complete(_accessToken);
          return;
        }
        AppLogger.debug("refreshing token");
        final issuer = await Issuer.discover(Uri.parse(_issuerUrl!));
        final client = Client(issuer, _clientId!, clientSecret: "");
        final credential = client.createCredential(refreshToken: _refreshToken);
        final tokenResponse = await credential.getTokenResponse();

        _accessToken = tokenResponse.accessToken ?? _accessToken;
        _refreshToken = tokenResponse.refreshToken ?? _refreshToken;
        _tokenExpiry = tokenResponse.expiresIn != null
            ? DateTime.now().add(tokenResponse.expiresIn!)
            : _tokenExpiry;

        _notifyListeners();
        completer.complete(_accessToken);
        AppLogger.debug("refreshed token");
      } catch (e, st) {
        AppLogger.error('TokenManager: Failed to refresh access token', e, st);
        // Propagate the error to all awaiting callers
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      } finally {
        // Clear in-flight flag after the completer is resolved/rejected
        _refreshInFlight = null;
      }
    }();

    // Always return the completer.future so callers await the refresh result,
    // even though _refreshInFlight will be nulled after completion.
    return completer.future;
  }
}
