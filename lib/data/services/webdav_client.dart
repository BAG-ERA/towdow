// WebDAV client for CalDAV operations
// Implements RFC 4791 (CalDAV) and RFC 3744 (WebDAV ACL) HTTP methods
//
// Throws [RefreshTokenExpiredException] if the refresh token is expired or invalid.
//
// WebDAVClientKeycloak now supports automatic access token refresh using the refresh token.
// When the access token is expired, it will use the refresh token to obtain a new access token
// and update its internal state. You can provide an onTokenRefresh callback to persist the new tokens.
//
// Usage:
//   WebDAVClientKeycloak(
//     serverUrl: ...,
//     accessToken: ...,
//     refreshToken: ...,
//     tokenExpiry: ...,
//     clientId: ...,
//     issuerUrl: ...,
//     onTokenRefresh: (newAccessToken, newRefreshToken, newExpiry) { ... },
//   )

import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../core/result.dart';
import '../../core/logger.dart';
import '../../data/models/caldav_account.dart';
import 'package:openid_client/openid_client.dart';

const String CLIENT_SECRET = "J8cxks5GVinlCFB0x3E39WMOpjnXZjJK";

class WebDAVResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  WebDAVResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Exception thrown when the refresh token is expired or invalid.
class RefreshTokenExpiredException implements Exception {
  final String message;
  RefreshTokenExpiredException([this.message = "Refresh token expired, please log in again."]);
  @override
  String toString() => message;
}

abstract class WebDAVClient {
  final String serverUrl;
  final Duration timeout;

  WebDAVClient({
    required this.serverUrl,
    this.timeout = const Duration(seconds: 30),
  });

  /// Factory to create the correct WebDAVClient for the account.
  /// Optionally provide onTokenRefresh to persist new tokens when refreshed (Keycloak only).
  static WebDAVClient fromAccount(
    CaldavAccount account, {
    Duration timeout = const Duration(seconds: 30),
    void Function(String accessToken, String? refreshToken, DateTime? tokenExpiry)? onTokenRefresh,
  }) {
    switch (account.providerType) {
      case 'custom':
        return WebDAVClientBasicAuth(
          serverUrl: account.serverUrl,
          username: account.username,
          password: account.password ?? '',
          timeout: timeout,
        );
      case 'towdow_cloud':
        return WebDAVClientKeycloak(
          serverUrl: account.serverUrl,
          accessToken: account.accessToken ?? '',
          refreshToken: account.refreshToken,
          tokenExpiry: account.tokenExpiry,
          clientId: account.clientId,
          issuerUrl: account.issuerUrl,
          onTokenRefresh: onTokenRefresh,
          timeout: timeout,
        );
      default:
        throw UnsupportedError('Unsupported providerType: \'${account.providerType}\'');
    }
  }

  Future<Map<String, String>> getAuthHeaders();

  /// Build URI correctly handling absolute vs relative paths
  Uri _buildUri(String path) {
    final serverUri = Uri.parse(serverUrl);
    
    if (path.startsWith('/')) {
      // Absolute path - use server's host but replace the path completely
      return Uri(
        scheme: serverUri.scheme,
        host: serverUri.host,
        port: serverUri.port,
        path: path,
      );
    } else {
      // Relative path - append to current server URL
      return Uri.parse('$serverUrl$path');
    }
  }

  /// Protected getter for common headers (including auth)
  Future<Map<String, String>> get _commonHeaders async => await getAuthHeaders();

  /// PROPFIND method - RFC 4918 Section 9.1
  /// Used for capability discovery and resource listing
  Future<Result<WebDAVResponse>> propfind(
    String path, {
    String? body,
    int depth = 1,
  }) async {
    try {
      // AppLogger.debug('WebDAVClient: PROPFIND $path (depth: $depth)');
      
      final uri = _buildUri(path);
      final headers = {
        ...await _commonHeaders,
        'Depth': depth.toString(),
      };

      final request = http.Request('PROPFIND', uri)
        ..headers.addAll(headers)
        ..body = body ?? _defaultPropfindBody;

      final streamedResponse = await request.send().timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      
      final result = WebDAVResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
      );

      // AppLogger.debug('WebDAVClient: PROPFIND response ${streamedResponse.statusCode}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: PROPFIND failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'PROPFIND request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// OPTIONS method - RFC 2616 Section 9.2
  /// Used to discover server capabilities
  Future<Result<WebDAVResponse>> options(String path) async {
    try {
      // AppLogger.debug('WebDAVClient: OPTIONS $path');
      
      final uri = _buildUri(path);
      final request = http.Request('OPTIONS', uri)
        ..headers.addAll(await _commonHeaders);

      final streamedResponse = await request.send().timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      
      final result = WebDAVResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
      );

      // AppLogger.debug('WebDAVClient: OPTIONS response ${streamedResponse.statusCode}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: OPTIONS failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'OPTIONS request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// GET method - RFC 2616 Section 9.3
  /// Used to retrieve calendar objects (VTODO)
  Future<Result<WebDAVResponse>> get(String path) async {
    try {
      // AppLogger.debug('WebDAVClient: GET $path');
      
      final uri = _buildUri(path);
      final response = await http.get(uri, headers: await _commonHeaders)
          .timeout(timeout);

      final result = WebDAVResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
      );

      // AppLogger.debug('WebDAVClient: GET response ${response.statusCode}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: GET failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'GET request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// PUT method - RFC 2616 Section 9.6
  /// Used to create/update calendar objects
  Future<Result<WebDAVResponse>> put(String path, String body, {String? etag}) async {
    try {
      AppLogger.info('WebDAVClient: PUT $path');
      AppLogger.debug('WebDAVClient: PUT body: $body');
      
      final uri = _buildUri(path);
      AppLogger.info('WebDAVClient: PUT URI: $uri');
      
      final headers = {
        ...await _commonHeaders,
        'Content-Type': 'text/calendar; charset=utf-8',
      };

      // Add If-Match header for updates (optimistic locking)
      if (etag != null) {
        headers['If-Match'] = etag;
      }

      AppLogger.debug('WebDAVClient: PUT headers: $headers');

      final response = await http.put(uri, headers: headers, body: body)
          .timeout(timeout);

      final result = WebDAVResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
      );

      AppLogger.info('WebDAVClient: PUT response ${response.statusCode}');
      AppLogger.debug('WebDAVClient: PUT response body: ${response.body}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: PUT failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'PUT request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// DELETE method - RFC 2616 Section 9.7
  /// Used to delete calendar objects
  Future<Result<WebDAVResponse>> delete(String path, {String? etag}) async {
    try {
      // AppLogger.debug('WebDAVClient: DELETE $path');
      
      final uri = _buildUri(path);
      final headers = Map<String, String>.from(await _commonHeaders);

      // Add If-Match header for conditional deletion
      if (etag != null) {
        headers['If-Match'] = etag;
      }

      final response = await http.delete(uri, headers: headers)
          .timeout(timeout);

      final result = WebDAVResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
      );

      // AppLogger.debug('WebDAVClient: DELETE response ${response.statusCode}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: DELETE failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'DELETE request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// REPORT method - RFC 3253 Section 3.6, enhanced by RFC 4791 Section 7
  /// Used for CalDAV calendar queries
  Future<Result<WebDAVResponse>> report(String path, String body) async {
    try {
      // AppLogger.debug('WebDAVClient: REPORT $path');
      
      final uri = _buildUri(path);
      final request = http.Request('REPORT', uri)
        ..headers.addAll(await _commonHeaders)
        ..headers['Depth'] = '1'  // CalDAV requires Depth: 1 for calendar-query
        ..body = body;

      final streamedResponse = await request.send().timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      
      final result = WebDAVResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
      );

      // AppLogger.debug('WebDAVClient: REPORT response ${streamedResponse.statusCode}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: REPORT failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'REPORT request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// MKCALENDAR method - RFC 4791 Section 5.3.1  
  /// Used to create new calendar collections
  Future<Result<WebDAVResponse>> mkcalendar(String path, String body) async {
    try {
      // AppLogger.debug('WebDAVClient: MKCALENDAR $path');
      
      final uri = _buildUri(path);
      final headers = {
        ...await _commonHeaders,
        'Content-Type': 'application/xml; charset=utf-8',
      };
      
      final request = http.Request('MKCALENDAR', uri)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send().timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      
      final result = WebDAVResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
      );

      // AppLogger.debug('WebDAVClient: MKCALENDAR response ${streamedResponse.statusCode}');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: MKCALENDAR failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'MKCALENDAR request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// PROPPATCH method - RFC 4918 Section 9.2
  /// Used to update/set WebDAV properties on collections
  Future<Result<WebDAVResponse>> proppatch(String path, String body) async {
    try {
      AppLogger.info('WebDAVClient: PROPPATCH $path');
      AppLogger.debug('WebDAVClient: PROPPATCH body: $body');
      
      final uri = _buildUri(path);
      AppLogger.info('WebDAVClient: PROPPATCH URI: $uri');
      
      final headers = {
        ...await _commonHeaders,
        'Content-Type': 'application/xml; charset=utf-8',
      };
      
      AppLogger.debug('WebDAVClient: PROPPATCH headers: $headers');
      
      final request = http.Request('PROPPATCH', uri)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send().timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      
      final result = WebDAVResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
      );

      AppLogger.info('WebDAVClient: PROPPATCH response ${streamedResponse.statusCode}');
      AppLogger.debug('WebDAVClient: PROPPATCH response body: $responseBody');
      return Result.success(result);
    } catch (e, stackTrace) {
      AppLogger.error('WebDAVClient: PROPPATCH failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'PROPPATCH request failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Default PROPFIND body for basic resource discovery
  static const String _defaultPropfindBody = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:FLOWIT="https://flowit.app/ns/">
  <D:prop>
    <D:resourcetype />
    <D:displayname />
    <C:supported-calendar-component-set />
    <C:calendar-description />
    <C:calendar-timezone />
    <D:current-user-privilege-set />
    <FLOWIT:domain/>
    <FLOWIT:type/>
    <FLOWIT:asflow/>
    <FLOWIT:owner/>
    <FLOWIT:template/>
  </D:prop>
</D:propfind>''';
}

class WebDAVClientBasicAuth extends WebDAVClient {
  final String username;
  final String password;
  late final String _basicAuthHeader;

  WebDAVClientBasicAuth({
    required super.serverUrl,
    required this.username,
    required this.password,
    super.timeout,
  }) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    _basicAuthHeader = 'Basic $credentials';
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    return {'Authorization': _basicAuthHeader};
  }
}

class WebDAVClientKeycloak extends WebDAVClient {
  String accessToken;
  String? refreshToken;
  DateTime? tokenExpiry;
  final String? clientId;
  final String? issuerUrl;
  final void Function(String accessToken, String? refreshToken, DateTime? tokenExpiry)? onTokenRefresh;

  WebDAVClientKeycloak({
    required super.serverUrl,
    required this.accessToken,
    this.refreshToken,
    this.tokenExpiry,
    this.clientId,
    this.issuerUrl,
    super.timeout,
    this.onTokenRefresh,
  });

  bool get _isTokenExpired {
    if (tokenExpiry == null) return false;
    // Add a 1 minute buffer
    return DateTime.now().isAfter(tokenExpiry!.subtract(const Duration(minutes: 1)));
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    if (_isTokenExpired && refreshToken != null && clientId != null && issuerUrl != null) {
      try {
        final issuer = await Issuer.discover(Uri.parse(issuerUrl!));
        final client = Client(
          issuer,
          clientId!,
          clientSecret: CLIENT_SECRET,
        );
        final credential = client.createCredential(
          refreshToken: refreshToken,
        );
        final tokenResponse = await credential.getTokenResponse();
        accessToken = tokenResponse.accessToken!;
        refreshToken = tokenResponse.refreshToken ?? refreshToken;
        tokenExpiry = tokenResponse.expiresIn != null
            ? DateTime.now().add(tokenResponse.expiresIn!)
            : null;
        if (onTokenRefresh != null) {
          onTokenRefresh!(accessToken, refreshToken, tokenExpiry);
        }
      } catch (e, st) {
        AppLogger.error('WebDAVClientKeycloak: Failed to refresh access token', e, st);
        // If the error is due to invalid_grant or similar, throw our custom exception
        throw RefreshTokenExpiredException();
      }
    }
    return {'Authorization': 'Bearer $accessToken'};
  }
}