// App Lifecycle Manager for FlowIt
// Manages service initialization and lifecycle independently of UI state
// Ensures background sync continues even when UI is minimized

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/services/sync/sync_service.dart';
import '../data/services/sync/sync_orchestrator_service.dart';
import '../data/services/integration/external_caldav_calendar/external_sync_service.dart';
import '../data/services/storage/file_upload_queue_service.dart';
import '../data/services/storage/media_cleanup_service.dart';
import '../data/services/sync/connection_monitor_service.dart';
import '../data/services/user/user_sync_service.dart';
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
  CalDAVMonitor? _caldavMonitor;
  ExternalCalendarSyncService? _externalSyncService;
  FileUploadQueueService? _fileUploadQueueService;
  MediaCleanupService? _mediaCleanupService;
  ConnectionMonitorService? _connectionMonitorService;
  UserSyncService? _userSyncService;
  AccountRepository? _accountRepository;

  // State management
  FlowItAppState _state = FlowItAppState.initial;
  final StreamController<FlowItAppState> _stateController = StreamController<FlowItAppState>.broadcast();
  
  // Timers and subscriptions
  Timer? _backgroundSyncTimer;
  StreamSubscription<FlowItAppState>? _lifecycleSubscription;
  
  // Cooldown control to prevent overly frequent health-check syncs
  DateTime? _lastHealthCheckSyncAt;
  static const Duration _healthCheckCooldown = Duration(minutes: 3);

  // Getters
  FlowItAppState get state => _state;
  Stream<FlowItAppState> get stateStream => _stateController.stream;
  bool get isReady => _state == FlowItAppState.ready;
  bool get hasServices => _syncService != null && _caldavMonitor != null && _externalSyncService != null && _fileUploadQueueService != null && _connectionMonitorService != null && _userSyncService != null;

  /// Initialize the app lifecycle manager with required services
  Future<Result<void>> initialize({
    required SyncService syncService,
    required CalDAVMonitor caldavMonitor,
    required ExternalCalendarSyncService externalSyncService,
    required FileUploadQueueService fileUploadQueueService,
    required MediaCleanupService mediaCleanupService,
    required ConnectionMonitorService connectionMonitorService,
    required UserSyncService userSyncService,
    required AccountRepository accountRepository,
  }) async {
    try {
      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting initialization');
      _updateState(FlowItAppState.initializing);

      // Store service references
      _syncService = syncService;
      _caldavMonitor = caldavMonitor;
      _externalSyncService = externalSyncService;
      _fileUploadQueueService = fileUploadQueueService;
      _mediaCleanupService = mediaCleanupService;
      _connectionMonitorService = connectionMonitorService;
      _userSyncService = userSyncService;
      _accountRepository = accountRepository;

      // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Services assigned, checking for active account');

      // Always start external calendar sync service (independent of main account)
      if (_externalSyncService != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting ExternalCalendarSyncService (always)');
        _externalSyncService!.startExternalAccountBackgroundSync();
        AppLogger.info('AppLifecycleManager: ExternalCalendarSyncService started successfully (independent)');
      }

      // Check if we have an active account before starting main FlowIt services
      final accountResult = await _accountRepository!.getActiveAccount();
      accountResult.when(
        success: (account) async {
          if (account != null) {
            // Skip starting sync services for offline scheme (offline-only)
            if (account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost')) {
              AppLogger.info('AppLifecycleManager: Offline-only mode detected - skipping CalDAV sync services');

              // Even in offline-only mode, start file upload queue and connection monitoring
              // so S3-backed features (validators, attachments) can upload when connectivity exists
              try {
                if (_fileUploadQueueService != null) {
                  final accRes2 = await _accountRepository!.getActiveAccount();
                  await accRes2.when(
                    success: (acc2) async {
                      final fileFeaturesEnabled = acc2 != null && acc2.providerType != 'custom';
                      if (fileFeaturesEnabled) {
                        AppLogger.debug('AppLifecycleManager: Starting FileUploadQueueService (offline-only mode)');
                        _fileUploadQueueService!.startQueueProcessing();
                        AppLogger.info('AppLifecycleManager: FileUploadQueueService started (offline-only mode)');
                      } else {
                        AppLogger.info('AppLifecycleManager: File features disabled (custom provider) - not starting FileUploadQueueService');
                      }
                    },
                    failure: (_) async {
                      AppLogger.info('AppLifecycleManager: No active account - file upload queue not started');
                    },
                  );
                }

                // Start media cleanup service (always enabled for local file management)
                if (_mediaCleanupService != null) {
                  AppLogger.debug('AppLifecycleManager: Starting MediaCleanupService (offline-only mode)');
                  _mediaCleanupService!.startCleanupService();
                  AppLogger.info('AppLifecycleManager: MediaCleanupService started (offline-only mode)');
                }

                if (_connectionMonitorService != null) {
                  AppLogger.debug('AppLifecycleManager: Starting ConnectionMonitorService (offline-only mode)');
                  await _connectionMonitorService!.startMonitoring();
                  // Trigger file queue when connection is restored
                  _connectionMonitorService!.connectionRestoredStream.listen((_) {
                    AppLogger.info('AppLifecycleManager: Connection restored, triggering queued file uploads');
                    _fileUploadQueueService?.startQueueProcessing();
                  });
                  AppLogger.info('AppLifecycleManager: ConnectionMonitorService started (offline-only mode)');
                }
              } catch (e) {
                AppLogger.warning('AppLifecycleManager: Failed to start offline-only services: $e');
              }

              _updateState(FlowItAppState.ready);
            } else {
              // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Active account found: ${account.username}');
              await _startMainServices();
            }
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

      // Start CalDAV monitor service FIRST to perform discovery before initial sync
      if (_caldavMonitor != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Starting CalDAVMonitor');
        
        final monitorResult = await _caldavMonitor!.start();
        monitorResult.when(
          success: (_) {
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] CalDAVMonitor started successfully');
          },
          failure: (failure) {
            AppLogger.warning('AppLifecycleManager: CalDAVMonitor start failed: ${failure.message}');
            // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] CalDAVMonitor start failed: ${failure.message}');
          },
        );
      }

      // Initialize main sync service AFTER discovery to ensure calendars exist locally
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

      // Start file upload queue service only if file features are enabled for current account
      if (_fileUploadQueueService != null && _accountRepository != null) {
        final accRes = await _accountRepository!.getActiveAccount();
        await accRes.when(
          success: (acc) async {
            final fileFeaturesEnabled = acc != null && acc.providerType != 'custom';
            if (fileFeaturesEnabled) {
              AppLogger.debug('AppLifecycleManager: Starting FileUploadQueueService');
              _fileUploadQueueService!.startQueueProcessing();
              AppLogger.info('AppLifecycleManager: FileUploadQueueService started successfully');
            } else {
              AppLogger.info('AppLifecycleManager: File features disabled (custom provider) - not starting FileUploadQueueService');
            }
          },
          failure: (_) async {
            // Default to not starting when account unknown
            AppLogger.info('AppLifecycleManager: No active account - file upload queue not started');
          },
        );
      }

      // Start media cleanup service (always enabled for local file management)
      if (_mediaCleanupService != null) {
        AppLogger.debug('AppLifecycleManager: Starting MediaCleanupService');
        _mediaCleanupService!.startCleanupService();
        AppLogger.info('AppLifecycleManager: MediaCleanupService started successfully');
      }

      // Start user sync service (cloud only)
      if (_userSyncService != null && _accountRepository != null) {
        final accRes = await _accountRepository!.getActiveAccount();
        await accRes.when(
          success: (acc) async {
            final enableUserSync = acc != null && acc.providerType == 'towdow_cloud';
            if (enableUserSync) {
              // Periodic user sync removed (handled by SyncOrchestrator/ConnectionMonitor)

              // Fetch shared projects on startup
              AppLogger.debug('AppLifecycleManager: Fetching shared projects on startup');
              try {
                final sharedProjectsResult = await _userSyncService!.updateSharedProjects(duringDownload: true);
                sharedProjectsResult.when(
                  success: (_) {
                    AppLogger.info('AppLifecycleManager: Shared projects fetched successfully on startup');
                  },
                  failure: (failure) {
                    AppLogger.warning('AppLifecycleManager: Failed to fetch shared projects on startup: ${failure.message}');
                  },
                );
              } catch (e) {
                AppLogger.warning('AppLifecycleManager: Error fetching shared projects on startup: $e');
              }

              AppLogger.info('AppLifecycleManager: UserSyncService started successfully');
            } else {
              AppLogger.info('AppLifecycleManager: UserSyncService disabled for providerType ${acc?.providerType ?? 'unknown'}');
            }
          },
          failure: (_) async {
            AppLogger.info('AppLifecycleManager: No active account - UserSyncService not started');
          },
        );
      }

      // Start connection monitoring service
      if (_connectionMonitorService != null) {
        AppLogger.debug('AppLifecycleManager: Starting ConnectionMonitorService');
        await _connectionMonitorService!.startMonitoring();
        
        // Set up connection restored listener to trigger upload queue processing
        _connectionMonitorService!.connectionRestoredStream.listen((_) {
          AppLogger.info('AppLifecycleManager: Connection restored, triggering queued operations processing');
          if (_fileUploadQueueService != null) {
            _fileUploadQueueService!.startQueueProcessing();
          }
          if (_syncService != null) {
            // Process sync queue immediately without full pull to avoid stale UI
            _syncService!.processQueueOnly();
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

  // _startServices kept for backward compatibility in tests; suppress warning
  // ignore: unused_element
  Future<Result<void>> _startServices() async => _startMainServices();

  /// Called when account configuration changes
  Future<void> onAccountConfigured() async {
    AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Account configured, starting main services');
    
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

      // Stop CalDAV monitor
      if (_caldavMonitor != null) {
        _caldavMonitor!.stop();
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] CalDAVMonitor stopped');
      }

      // Note: SyncService no longer has periodic sync - CalDAVMonitor handles this
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
      
      // Optional immediate sync is gated by cooldown; avoid double-trigger with _ensureServicesRunning
      if (_syncService != null) {
        final lastSync = _syncService!.lastSyncTime ?? _lastHealthCheckSyncAt;
        final shouldSync = lastSync == null || DateTime.now().difference(lastSync) > _healthCheckCooldown;
        if (shouldSync) {
          _lastHealthCheckSyncAt = DateTime.now();
          _syncService!.syncAllActiveCaldav();
        } else {
          AppLogger.debug('AppLifecycleManager: Skipping immediate resume sync due to cooldown');
        }
      }
      
      // Update shared projects when app resumes
      if (_userSyncService != null) {
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Updating shared projects on app resume');
        _userSyncService!.updateSharedProjects(duringDownload: true).then((result) {
          result.when(
            success: (_) {
              // AppLogger.debug('AppLifecycleManager: Shared projects updated successfully on app resume');
            },
            failure: (failure) {
              AppLogger.warning('AppLifecycleManager: Failed to update shared projects on app resume: ${failure.message}');
            },
          );
        }).catchError((e) {
          AppLogger.warning('AppLifecycleManager: Error updating shared projects on app resume: $e');
        });
      }
      
      // Removed update check on resume
    }
  }

  /// Called when app goes to background
  void _onAppBackgrounded() {
    // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] App backgrounded - services continue running');
    
    if (_state == FlowItAppState.ready || _state == FlowItAppState.resumed) {
      _updateState(FlowItAppState.backgrounded);
      
      // Services should continue running in background
      // Just log current status
              // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] CalDAV monitor status: ${_caldavMonitor?.isMonitoring ?? false}');
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
      
      // Check CalDAV monitor
      if (_caldavMonitor != null && !_caldavMonitor!.isMonitoring) {
        AppLogger.warning('AppLifecycleManager: CalDAV monitor not running, restarting');
        // AppLogger.debug('🚀 AppLifecycleManager: [DIAGNOSIS] Restarting CalDAV monitor service');
        _caldavMonitor!.start();
      }

      // Check external calendar sync (restart if timer is not active)
      if (_externalSyncService != null) {
        // For external sync, we need to check if the background timer is running
        // Since we don't have direct access to _syncTimer, we'll periodically restart it
        // This is safer than checking the sync flag which is only true during active sync
        try {
          _externalSyncService!.startExternalAccountBackgroundSync(); // This will cancel existing timer and restart
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
              // Services should be running, trigger a health check sync (cooldown guarded)
              final lastSync = _syncService!.lastSyncTime ?? _lastHealthCheckSyncAt;
              final shouldSync = lastSync == null || DateTime.now().difference(lastSync) > _healthCheckCooldown;
              if (shouldSync) {
                _lastHealthCheckSyncAt = DateTime.now();
                _syncService!.syncAllActiveCaldav();
              } else {
                AppLogger.debug('AppLifecycleManager: Skipping health-check sync due to cooldown');
              }
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
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Get current sync status for UI
  Map<String, dynamic> getSyncStatus() {
    return {
      'appLifecycleState': _state.name,
      'hasServices': hasServices,
      'syncServiceStatus': _syncService?.status.name ?? 'not_initialized',
              'caldavMonitorRunning': _caldavMonitor?.isMonitoring ?? false,
        'caldavMonitorActive': _caldavMonitor?.isMonitoring ?? false,
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
          _caldavMonitor = null;
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
