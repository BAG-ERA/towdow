// Connection monitoring service for detecting internet connectivity
// Triggers upload queue processing when connection is restored

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../../../core/logger.dart';

/// Connection status
enum ConnectionStatus {
  connected,
  disconnected,
  unknown,
}

/// Connection monitoring service
class ConnectionMonitorService {
  final Connectivity _connectivity = Connectivity();
  
  // State (start connected better getting a network error than being stuck while waiting for first connectivity check)
  ConnectionStatus _currentStatus = ConnectionStatus.connected;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _connectivityCheckTimer;
  
  // Streams
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _connectionRestoredController = StreamController<void>.broadcast();
  
  // Configuration
  static const Duration _checkInterval = Duration(seconds: 10);
  static const Duration _httpTimeout = Duration(seconds: 3);
  static const String _probeUrl = 'https://api.towdow.app/docs';
  
  /// Stream of connection status changes
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  /// Stream that emits when connection is restored
  Stream<void> get connectionRestoredStream => _connectionRestoredController.stream;
  
  /// Current connection status
  ConnectionStatus get currentStatus => _currentStatus;
  
  /// Check if currently connected
  bool get isConnected => _currentStatus == ConnectionStatus.connected;

  /// Start monitoring connection
  Future<void> startMonitoring() async {
    AppLogger.info('ConnectionMonitorService: Starting connection monitoring');
    
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Set up periodic connectivity checks
    _connectivityCheckTimer = Timer.periodic(_checkInterval, (_) {
      _checkConnectivity();
    });
  }

  /// Stop monitoring connection
  void stopMonitoring() {
    AppLogger.info('ConnectionMonitorService: Stopping connection monitoring');
    
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = null;
  }

  /// Handle connectivity changes from the connectivity plugin
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    AppLogger.debug('ConnectionMonitorService: Connectivity changed to: $results');
    
    // The connectivity plugin only tells us about network interface status,
    // not actual internet connectivity, so we need to test actual connectivity
    _checkConnectivity();
  }

  /// Check actual internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      // AppLogger.debug('ConnectionMonitorService: Checking connectivity...');
      
      // First check if we have network interface connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      // AppLogger.debug('ConnectionMonitorService: Network interface results: $connectivityResults');
      
      if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
        AppLogger.debug('ConnectionMonitorService: No network interface available');
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }
      
      // We have a network interface, verify actual internet reachability via HTTP probe
      final hasInternet = await _hasInternetAccess();
      if (hasInternet) {
        _updateStatus(ConnectionStatus.connected);
      } else {
        _updateStatus(ConnectionStatus.disconnected);
      }
    } catch (e, st) {
      AppLogger.warning('ConnectionMonitorService: Failed to check connectivity: $e');
      AppLogger.debug('ConnectionMonitorService: Stacktrace for connectivity check failure: $st');
      _updateStatus(ConnectionStatus.unknown);
    }
  }
  
  /// Performs a lightweight HTTP request to validate internet connectivity
  Future<bool> _hasInternetAccess() async {
    try {
      final uri = Uri.parse(_probeUrl);
      final response = await http.get(uri).timeout(_httpTimeout);
      // AppLogger.debug('ConnectionMonitorService: Probe response: ${response.statusCode}');
      // Common captive portal check endpoints return 204 on success; accept 204 or any 2xx as online
      return response.statusCode >= 200 && response.statusCode < 300;
    } on TimeoutException {
      AppLogger.debug('ConnectionMonitorService: HTTP probe timed out');
      return false;
    } catch (e) {
      AppLogger.debug('ConnectionMonitorService: HTTP probe failed: $e');
      return false;
    }
  }

  /// Update connection status and notify listeners
  void _updateStatus(ConnectionStatus newStatus) {
    if (_currentStatus == newStatus) {
      return; // No change
    }
    
    final previousStatus = _currentStatus;
    _currentStatus = newStatus;
    
    AppLogger.info('ConnectionMonitorService: Connection status changed from $previousStatus to $newStatus');
    
    // Notify status change
    _statusController.add(newStatus);
    
    // Notify connection restored if we went from disconnected to connected
    if (previousStatus == ConnectionStatus.disconnected && newStatus == ConnectionStatus.connected) {
      AppLogger.info('ConnectionMonitorService: Connection restored, triggering upload queue processing');
      _connectionRestoredController.add(null);
    }
  }

  /// Force a connectivity check
  Future<void> forceCheck() async {
    AppLogger.debug('ConnectionMonitorService: Force checking connectivity');
    await _checkConnectivity();
  }

  /// Get connection status as a string for debugging
  String getStatusString() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.unknown:
        return 'Unknown';
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _statusController.close();
    _connectionRestoredController.close();
  }
} 