// App Lifecycle Manager for FlowIt
// Manages service initialization and lifecycle independently of UI state
// Ensures background sync continues even when UI is minimized

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/services/sync_service.dart';
import '../data/services/background_sync_service.dart';
import '../data/services/external_sync_service.dart';
import '../data/services/file_upload_queue_service.dart';
import '../data/services/connection_monitor_service.dart';
import '../data/services/user_sync_service.dart';
import '../data/repositories/account_repository.dart';
import 'logger.dart';
import 'result.dart';

enum FlowItAppState {
  initial,
  initializing,
  ready,
  backgrounded,
  resumed,
  error,
}

class AppLifecycleManager {
  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance => _instance ??= AppLifecycleManager._();
  
  AppLifecycleManager._();

  // Services
  SyncService? _syncService;
  BackgroundSyncService? _backgroundSyncService;
  ExternalCalendarSyncService? _externalSyncService;
  FileUploadQueueService? _fileUploadQueueService;
  ConnectionMonitorService? _connectionMonitorService;
  UserSyncService? _userSyncService;
  AccountRepository? _accountRepository;

  // State management
  FlowItAppState _state = FlowItAppState.initial;
  final StreamController<FlowItAppState> _stateController = StreamController<FlowItAppState>.broadcast();
  
  // Timers and subscriptions
  Timer? _backgroundSyncTimer;
  StreamSubscription<FlowItAppState>? _lifecycleSubscription;

  // Getters
  FlowItAppState get state => _state;
  Stream<FlowItAppState> get stateStream => _stateController.stream;
  bool get isReady => _state == FlowItAppState.ready;
  bool get hasServices => _syncService != null && _backgroundSyncService != null && _externalSyncService != null && _fileUploadQueueService != null && _connectionMonitorService != null && _userSyncService != null;

  /// Initialize the app lifecycle manager with required services
  Future<Result<void>> initialize({
    required SyncService syncService,
    required BackgroundSyncService backgroundSyncService,
    required ExternalCalendarSyncService externalSyncService,
    required FileUploadQueueService fileUploadQueueService,
    required ConnectionMonitorService connectionMonitorService,
    required UserSyncService userSyncService,
    required AccountRepository accountRepository,
  }) async {
    try {
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting initialization');
      _updateState(FlowItAppState.initializing);

      // Store service references
      _syncService = syncService;
      _backgroundSyncService = backgroundSyncService;
      _externalSyncService = externalSyncService;
      _fileUploadQueueService = fileUploadQueueService;
      _connectionMonitorService = connectionMonitorService;
      _userSyncService = userSyncService;
      _accountRepository = accountRepository;

      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Services assigned, checking for active account');

      // Always start external calendar sync service (independent of main account)
      if (_externalSyncService != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting ExternalCalendarSyncService (always)');
        _externalSyncService!.startBackgroundSync();
        AppLogger.info('AppLifecycleManager: ExternalCalendarSyncService started successfully (independent)');
      }

      // Check if we have an active account before starting main FlowIt services
      final accountResult = await _accountRepository!.getActiveAccount();
      accountResult.when(
        success: (account) async {
          if (account != null) {
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Active account found: ${account.username}');
            await _startMainServices();
          } else {
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] No active account - main services will start when account is configured');
            _updateState(FlowItAppState.ready);
          }
        },
        failure: (failure) async {
          AppLogger.warning('AppLifecycleManager: Failed to check account status: ${failure.message}');
          // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Account check failed, starting without main services');
          _updateState(FlowItAppState.ready);
        },
      );

      // Set up app lifecycle monitoring
      _setupAppLifecycleMonitoring();

      // AppLogger.info('AppLifecycleManager: Initialized successfully');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('AppLifecycleManager: Failed to initialize', e, stackTrace);
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Initialization failed: $e');
      _updateState(FlowItAppState.error);
      return Result.failure(Failure(
        message: 'Failed to initialize app lifecycle manager: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Start main FlowIt sync services (requires main account)
  Future<Result<void>> _startMainServices() async {
    try {
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting main sync services');

      // Initialize main sync service
      if (_syncService != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Initializing SyncService');
        final syncResult = await _syncService!.initialize();
        syncResult.when(
          success: (_) {
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] SyncService initialized successfully');
          },
          failure: (failure) {
            AppLogger.warning('AppLifecycleManager: SyncService initialization failed: ${failure.message}');
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] SyncService init failed: ${failure.message}');
          },
        );
      }

      // Start background sync service
      if (_backgroundSyncService != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting BackgroundSyncService');
        
        // Set the main sync service reference for queue processing
        if (_syncService != null) {
          _backgroundSyncService!.setSyncService(_syncService!);
        }
        
        final bgResult = await _backgroundSyncService!.start();
        bgResult.when(
          success: (_) {
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] BackgroundSyncService started successfully');
          },
          failure: (failure) {
            AppLogger.warning('AppLifecycleManager: BackgroundSyncService start failed: ${failure.message}');
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] BackgroundSyncService start failed: ${failure.message}');
          },
        );
      }

      // Start file upload queue service
      if (_fileUploadQueueService != null) {
        AppLogger.debug('AppLifecycleManager: Starting FileUploadQueueService');
        _fileUploadQueueService!.startQueueProcessing();
        AppLogger.info('AppLifecycleManager: FileUploadQueueService started successfully');
      }

      // Start user sync service (for cloud/self-hosted users)
      if (_userSyncService != null) {
        AppLogger.debug('AppLifecycleManager: Starting UserSyncService periodic sync');
        _userSyncService!.startPeriodicSync(interval: const Duration(hours: 2)); // Check every 2 hours for user data updates
        AppLogger.info('AppLifecycleManager: UserSyncService started successfully');
      }

      // Start connection monitoring service
      if (_connectionMonitorService != null) {
        AppLogger.debug('AppLifecycleManager: Starting ConnectionMonitorService');
        await _connectionMonitorService!.startMonitoring();
        
        // Set up connection restored listener to trigger upload queue processing
        _connectionMonitorService!.connectionRestoredStream.listen((_) {
          AppLogger.info('AppLifecycleManager: Connection restored, triggering upload queue processing');
          if (_fileUploadQueueService != null) {
            _fileUploadQueueService!.startQueueProcessing(); // Trigger immediate processing
          }
        });
        
        AppLogger.info('AppLifecycleManager: ConnectionMonitorService started successfully');
      }

      _updateState(FlowItAppState.ready);
      // AppLogger.info('AppLifecycleManager: All main services started successfully');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('AppLifecycleManager: Failed to start main services', e, stackTrace);
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Main service startup failed: $e');
      _updateState(FlowItAppState.error);
      return Result.failure(Failure(
        message: 'Failed to start main services: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Start sync services when account is available (legacy method)
  Future<Result<void>> _startServices() async {
    return await _startMainServices();
  }

  /// Called when account configuration changes
  Future<void> onAccountConfigured() async {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Account configured, starting main services');
    
    if (!hasServices) {
      AppLogger.warning('AppLifecycleManager: Cannot start services - services not initialized');
      return;
    }

    await _startMainServices();
  }

  /// Called when account is removed
  Future<void> onAccountRemoved() async {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Account removed, stopping services');
    await _stopServices();
  }

  /// Stop all sync services
  Future<void> _stopServices() async {
    try {
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Stopping sync services');

      // Stop background sync
      if (_backgroundSyncService != null) {
        _backgroundSyncService!.stop();
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] BackgroundSyncService stopped');
      }

      // Note: SyncService no longer has periodic sync - BackgroundSyncService handles this
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] SyncService periodic sync not needed');

      // Stop external calendar sync
      if (_externalSyncService != null) {
        _externalSyncService!.stopBackgroundSync();
        AppLogger.info('AppLifecycleManager: ExternalCalendarSyncService stopped');
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] ExternalCalendarSyncService stopped');
      }

      // Stop file upload queue service
      if (_fileUploadQueueService != null) {
        _fileUploadQueueService!.stopQueueProcessing();
        AppLogger.info('AppLifecycleManager: FileUploadQueueService stopped');
      }

      // Stop connection monitoring service
      if (_connectionMonitorService != null) {
        _connectionMonitorService!.stopMonitoring();
        AppLogger.info('AppLifecycleManager: ConnectionMonitorService stopped');
      }

      // AppLogger.info('AppLifecycleManager: All services stopped');
    } catch (e, stackTrace) {
      AppLogger.error('AppLifecycleManager: Failed to stop services', e, stackTrace);
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Service stop failed: $e');
    }
  }

  /// Set up monitoring of app lifecycle changes
  void _setupAppLifecycleMonitoring() {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Setting up app lifecycle monitoring');
    
    // Monitor Flutter app lifecycle state changes
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
    
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] App lifecycle monitoring configured');
  }

  /// Handle app lifecycle state changes
  void _onFlutterLifecycleStateChanged(AppLifecycleState lifecycleState) {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Flutter lifecycle state changed: $lifecycleState');
    
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _onAppBackgrounded();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
    }
  }

  /// Called when app comes to foreground
  void _onAppResumed() {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] App resumed - ensuring services are running');
    
    if (_state == FlowItAppState.backgrounded) {
      _updateState(FlowItAppState.resumed);
      
      // Ensure services are still running
      _ensureServicesRunning();
      
      // Trigger immediate sync to get latest data
      if (_syncService != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Triggering sync on app resume');
        _syncService!.syncNow();
      }
    }
  }

  /// Called when app goes to background
  void _onAppBackgrounded() {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] App backgrounded - services continue running');
    
    if (_state == FlowItAppState.ready || _state == FlowItAppState.resumed) {
      _updateState(FlowItAppState.backgrounded);
      
      // Services should continue running in background
      // Just log current status
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Background sync status: ${_backgroundSyncService?.isRunning ?? false}');
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Periodic sync active: ${_syncService != null}');
    }
  }

  /// Called when app is detached/closed
  void _onAppDetached() {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] App detached - cleaning up');
    dispose();
  }

  /// Ensure services are still running (recovery mechanism)
  void _ensureServicesRunning() {
    if (!hasServices) return;

    try {
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Checking service health');
      
      // Check background sync
      if (_backgroundSyncService != null && !_backgroundSyncService!.isRunning) {
        AppLogger.warning('AppLifecycleManager: Background sync not running, restarting');
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Restarting background sync service');
        _backgroundSyncService!.start();
      }

      // Check external calendar sync (restart if timer is not active)
      if (_externalSyncService != null) {
        // For external sync, we need to check if the background timer is running
        // Since we don't have direct access to _syncTimer, we'll periodically restart it
        // This is safer than checking the sync flag which is only true during active sync
        try {
          _externalSyncService!.startBackgroundSync(); // This will cancel existing timer and restart
          // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Ensured external calendar sync service is running');
        } catch (e) {
          AppLogger.warning('AppLifecycleManager: Failed to ensure external calendar sync is running: $e');
        }
      }

      // Check if we have an account and services should be running
      _accountRepository?.getActiveAccount().then((result) {
        result.when(
          success: (account) {
            if (account != null && _syncService != null) {
              // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Account available, ensuring sync service is initialized');
              // Services should be running, trigger a health check sync
              _syncService!.syncNow();
            }
          },
          failure: (failure) {
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] No account available during health check');
          },
        );
      });
    } catch (e, stackTrace) {
      AppLogger.error('AppLifecycleManager: Failed to ensure services are running', e, stackTrace);
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Service health check failed: $e');
    }
  }

  /// Update lifecycle state and notify listeners
  void _updateState(FlowItAppState newState) {
    if (_state != newState) {
      final oldState = _state;
      _state = newState;
      _stateController.add(_state);
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] State changed: ${oldState.name} -> ${newState.name}');
    }
  }

  /// Get current sync status for UI
  Map<String, dynamic> getSyncStatus() {
    return {
      'appLifecycleState': _state.name,
      'hasServices': hasServices,
      'syncServiceStatus': _syncService?.status.name ?? 'not_initialized',
      'backgroundSyncRunning': _backgroundSyncService?.isRunning ?? false,
      'backgroundSyncing': _backgroundSyncService?.isSyncing ?? false,
      'externalSyncRunning': _externalSyncService?.isSyncRunning ?? false,
      'lastSyncTime': _syncService?.lastSyncTime?.toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Disposing resources');
    
    _backgroundSyncTimer?.cancel();
    _lifecycleSubscription?.cancel();
    _stateController.close();
    
    // Dispose services
    _externalSyncService?.dispose();
    _fileUploadQueueService?.dispose();
    _connectionMonitorService?.dispose();
    _userSyncService?.dispose();
    
    // Services will be disposed by their providers
    _syncService = null;
    _backgroundSyncService = null;
    _externalSyncService = null;
    _fileUploadQueueService = null;
    _connectionMonitorService = null;
    _userSyncService = null;
    _accountRepository = null;
    
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Resources disposed');
  }
}

/// Flutter app lifecycle observer
class _AppLifecycleObserver with WidgetsBindingObserver {
  final AppLifecycleManager _manager;
  
  _AppLifecycleObserver(this._manager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _manager._onFlutterLifecycleStateChanged(state);
  }
} 
