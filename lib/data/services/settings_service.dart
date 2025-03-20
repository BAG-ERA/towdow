import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for managing app settings, including CalDAV configuration
class SettingsService extends ChangeNotifier {
  static const String _settingsBoxName = 'settings';
  static const String _caldavConfigKey = 'caldav_config';
  late Box _settingsBox;

  bool _initialized = false;
  String? _serverUrl;
  String? _username;
  String? _password;
  bool _syncEnabled = false;

  bool get initialized => _initialized;
  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get password => _password;
  bool get syncEnabled => _syncEnabled;

  /// Initialize the settings service
  Future<void> init() async {
    _settingsBox = await Hive.openBox(_settingsBoxName);
    await _loadSettings();
    _initialized = true;
    notifyListeners();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    final caldavConfig = _settingsBox.get(_caldavConfigKey);
    if (caldavConfig != null) {
      final Map<String, dynamic> config = jsonDecode(caldavConfig);
      _serverUrl = config['server_url'];
      _username = config['username'];
      _password = config['password'];
      _syncEnabled = config['sync_enabled'] ?? false;
    }
  }

  /// Save CalDAV configuration
  Future<void> saveCalDAVConfig({
    required String serverUrl,
    required String username,
    required String password,
    bool syncEnabled = true,
  }) async {
    _serverUrl = serverUrl;
    _username = username;
    _password = password;
    _syncEnabled = syncEnabled;

    await _settingsBox.put(_caldavConfigKey, jsonEncode({
      'server_url': serverUrl,
      'username': username,
      'password': password, // In a production app, this should be stored securely
      'sync_enabled': syncEnabled,
    }));

    notifyListeners();
  }

  /// Enable or disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('CalDAV configuration not set');
    }

    _syncEnabled = enabled;
    await _settingsBox.put(_caldavConfigKey, jsonEncode({
      'server_url': _serverUrl,
      'username': _username,
      'password': _password,
      'sync_enabled': enabled,
    }));

    notifyListeners();
  }

  /// Clear all settings
  Future<void> clear() async {
    await _settingsBox.clear();
    _serverUrl = null;
    _username = null;
    _password = null;
    _syncEnabled = false;
    notifyListeners();
  }
} 