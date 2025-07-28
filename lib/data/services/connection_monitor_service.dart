// Connection monitoring service for detecting internet connectivity
// Triggers upload queue processing when connection is restored

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/logger.dart';

/// Connection status
enum ConnectionStatus {
  connected,
  disconnected,
  unknown,
}

/// Connection monitoring service
class ConnectionMonitorService {
  final Connectivity _connectivity = Connectivity();
  
  // State
  ConnectionStatus _currentStatus = ConnectionStatus.unknown;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _connectivityCheckTimer;
  
  // Streams
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _connectionRestoredController = StreamController<void>.broadcast();
  
  // Configuration
  static const Duration _checkInterval = Duration(seconds: 10);
  static const String _testHost = 'api.towdow.app';
  static const int _testPort = 80;
  static const Duration _testTimeout = Duration(seconds: 5);
  
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
      AppLogger.debug('ConnectionMonitorService: Checking connectivity...');
      
      // First check if we have network interface connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      AppLogger.debug('ConnectionMonitorService: Network interface results: $connectivityResults');
      
      if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
        AppLogger.debug('ConnectionMonitorService: No network interface available');
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }
      
      // Test actual internet connectivity
      AppLogger.debug('ConnectionMonitorService: Testing actual internet connection...');
      final isConnected = await _testInternetConnection();
      AppLogger.debug('ConnectionMonitorService: Internet connection test result: $isConnected');
      
      final newStatus = isConnected ? ConnectionStatus.connected : ConnectionStatus.disconnected;
      
      _updateStatus(newStatus);
    } catch (e) {
      AppLogger.warning('ConnectionMonitorService: Failed to check connectivity: $e');
      _updateStatus(ConnectionStatus.unknown);
    }
  }

  /// Test actual internet connection by connecting to a reliable host
  Future<bool> _testInternetConnection() async {
    try {
      AppLogger.debug('ConnectionMonitorService: Attempting socket connection to $_testHost:$_testPort');
      final socket = await Socket.connect(_testHost, _testPort, timeout: _testTimeout);
      socket.destroy();
      AppLogger.debug('ConnectionMonitorService: Socket connection successful');
      return true;
    } catch (e) {
      AppLogger.debug('ConnectionMonitorService: Internet connection test failed: $e');
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