// Centralized environment/config flags
// Use String.fromEnvironment/bool.fromEnvironment to allow build-time overrides.

class AppConfig {
  static const String caldavEndpointOverride = String.fromEnvironment('CALDAV_ENDPOINT', defaultValue: '');
  static const bool debugLogging = bool.fromEnvironment('DEBUG_LOGGING', defaultValue: false);
}



