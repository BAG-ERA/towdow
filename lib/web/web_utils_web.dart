// Web-specific implementation of utilities
// This file is only imported on web platforms

import 'dart:js_interop';
import 'package:web/web.dart' as web;

// Lightweight web HTTP response shape used by view models
class WebHttpResponse {
  final int statusCode;
  final String body;
  WebHttpResponse({required this.statusCode, required this.body});
}

// Get the appropriate redirect URI based on the current environment
// It must contain only the app URL and the optional 'project' query parameter.
String getRedirectUri() {
  final currentLocation = web.window.location.href;
  final uri = Uri.parse(currentLocation);

  // Build sanitized query: only keep 'project' if present
  final project = uri.queryParameters['project'];
  final cleanQuery = project == null || project.isEmpty ? null : {'project': project};

  // Compute base path: keep '/' or current path if app is hosted under subpath (non-empty path)
  final path = uri.path.isEmpty ? '/' : uri.path;

  // For localhost and production, return sanitized URL
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
    queryParameters: cleanQuery,
  ).toString();
}

// Clear sensitive query parameters from URL without reloading
void clearUrl() {
  // Clear sensitive query parameters from URL without reloading
  final uri = Uri.parse(web.window.location.href);
  final cleanUri = uri.replace(queryParameters: {});
  web.window.history.replaceState(null, 'Towdow App', cleanUri.toString());
}

// Parse the current URI
Uri parseCurrentUri() {
  return Uri.parse(web.window.location.href);
}

// Perform a CORS-friendly application/x-www-form-urlencoded POST using the browser Fetch API.
// Avoids adding non-simple headers to prevent preflight where possible.
Future<WebHttpResponse> postFormUrlEncoded(String url, Map<String, String> data) async {
  final params = web.URLSearchParams();
  for (final entry in data.entries) {
    params.append(entry.key, entry.value);
  }

  final init = web.RequestInit(
    method: 'POST',
    mode: 'cors', // explicit CORS mode
    // Do not set credentials to avoid older API mismatch; leaving it unset avoids sending cookies cross-origin by default
    body: params, // lets the browser set appropriate Content-Type
  );

  // Use JSString for RequestInfo and convert JSString -> String for body
  final res = await web.window.fetch(url.toJS, init).toDart;
  final jsText = await res.text().toDart; // JSString
  final text = jsText.toDart; // Dart String
  final statusCode = (res.status as num).toInt();
  return WebHttpResponse(statusCode: statusCode, body: text);
}

// Local storage operations
class WebLocalStorage {
  static String? getItem(String key) {
    return web.window.localStorage.getItem(key);
  }

  static void setItem(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }

  static void removeItem(String key) {
    web.window.localStorage.removeItem(key);
  }

  // Clear all browser storage related to this origin (localStorage + sessionStorage)
  static void clearAll() {
    try {
      web.window.localStorage.clear();
    } catch (_) {}
    try {
      // sessionStorage may not exist in some contexts, wrap in try/catch
      web.window.sessionStorage.clear();
    } catch (_) {}
  }
}
