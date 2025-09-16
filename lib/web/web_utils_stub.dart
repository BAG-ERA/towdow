// Stub implementation for non-web platforms
// This file is used on mobile and desktop platforms

class WebHttpResponse {
  final int statusCode;
  final String body;
  WebHttpResponse({required this.statusCode, required this.body});
}

// Get the appropriate redirect URI (stub implementation)
String getRedirectUri() {
  // Not used on non-web platforms
  return '';
}

// Clear URL (stub implementation)
void clearUrl() {
  // Not used on non-web platforms
}

// Parse the current URI (stub implementation)
Uri parseCurrentUri() {
  // Return empty URI on non-web platforms
  return Uri();
}

// Non-web platforms should not call this; provided to keep API consistent.
Future<WebHttpResponse> postFormUrlEncoded(String url, Map<String, String> data) async {
  throw UnsupportedError('postFormUrlEncoded is only available on web');
}

// Local storage operations stub
class WebLocalStorage {
  static String? getItem(String key) {
    return null;
  }

  static void setItem(String key, String value) {
    // Do nothing on non-web platforms
  }

  static void removeItem(String key) {
    // Do nothing on non-web platforms
  }
}
