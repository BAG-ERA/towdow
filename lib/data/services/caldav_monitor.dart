// CalDAV Monitor for detecting changes in calendars
// Monitors sync tokens and ETags to detect changes that need synchronization
// Delegates actual sync operations to SyncService

import 'dart:async';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/task_calendar.dart';
import '../repositories/account_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/category_repository.dart';
import 'connection_monitor_service.dart';
import 'sync_service.dart';
import 'caldav_service.dart';

class CalDAVMonitor {
  // Dependencies - focused on calendar monitoring
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final CategoryRepository _categoryRepository;
  final ConnectionMonitorService _connectionMonitorService;
  final SyncService _syncService;

  // Dynamic interval configuration
  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _maxInterval = Duration(seconds: 4);
  static const Duration _initialInterval = Duration(seconds: 10);
  static const double _changeMultiplier = 0.5; // Divide by 2 when change detected
  static const double _noChangeMultiplier = 1.5; // Multiply by 1.5 when no change

  // State management
  Timer? _monitorTimer;
  bool _isMonitoring = false;
  Duration _currentInterval = _initialInterval;

  CalDAVMonitor({
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required CategoryRepository categoryRepository,
    required ConnectionMonitorService connectionMonitorService,
    required SyncService syncService,
  })  : _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _categoryRepository = categoryRepository,
        _connectionMonitorService = connectionMonitorService,
        _syncService = syncService;

  /// Start monitoring with dynamic interval
  Future<Result<void>> start() async {
    if (_isMonitoring) {
      AppLogger.debug('CalDAVMonitor: Already monitoring, skipping start');
      return const Result.success(null);
    }

    try {
      AppLogger.info('CalDAVMonitor: Starting calendar monitoring with interval: ${_currentInterval.inSeconds}s');
      _isMonitoring = true;
      
      // Start periodic monitoring
      _monitorTimer = Timer.periodic(_currentInterval, (_) {
        _performChangeMonitoring();
      });
      
      // Perform initial monitoring
      await _performChangeMonitoring();
      
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to start monitoring', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to start monitoring: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Stop monitoring
  void stop() {
    if (!_isMonitoring) return;
    
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    
    AppLogger.info('CalDAVMonitor: Stopped calendar monitoring');
  }

  /// Perform change monitoring for all calendars
  Future<void> _performChangeMonitoring() async {
    if (!_isMonitoring) {
      AppLogger.debug('CalDAVMonitor: Not monitoring, skipping change check');
      return;
    }

    try {
      // Check connection status first
      final connectionStatus = _connectionMonitorService.currentStatus;
      if (connectionStatus != ConnectionStatus.connected) {
        AppLogger.warning('CalDAVMonitor: No internet connection, skipping change monitoring');
        _updateInterval(false); /// if no connexion update intervel
        return;
      }

      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.debug('CalDAVMonitor: No active account, skipping monitoring');
            return;
          }

          // Get all calendars to monitor
          final calendarsResult = await _calendarRepository.getProjectCalendars();
          await calendarsResult.when(
            success: (calendars) async {
              bool changesDetected = false;
              
              // Process queued operations first
              final queueChanges = await _processQueuedOperations();
              if (queueChanges) {
                changesDetected = true;
                AppLogger.debug('CalDAVMonitor: Queued operations processed');
              }

              // Check each calendar for changes
              for (final calendar in calendars) {
                final calendarChanges = await _checkCalendarChanges(account, calendar);
                if (calendarChanges) {
                  changesDetected = true;
                  AppLogger.debug('CalDAVMonitor: Changes detected for calendar ${calendar.displayName}');
                }
              }

              // Update interval based on changes detected
              _updateInterval(changesDetected);
              
              
              if (changesDetected) {
                AppLogger.debug('CalDAVMonitor: Changes detected, interval adjusted to ${_currentInterval.inSeconds}s');
              } else {
                AppLogger.debug('CalDAVMonitor: No changes detected, interval adjusted to ${_currentInterval.inSeconds}s');
              }
            },
            failure: (failure) async {
              AppLogger.error('CalDAVMonitor: Failed to get calendars', failure.exception, failure.stackTrace);
            },
          );
        },
        failure: (failure) async {
          AppLogger.debug('CalDAVMonitor: No active account available');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Change monitoring failed', e, stackTrace);
    }
  }

  /// Process queued operations if connection is available
  Future<bool> _processQueuedOperations() async {
    try {
      // Delegate to SyncService for queue processing
      final result = await _syncService.processQueueOnly();
      return await result.when(
        success: (syncResult) async {
          return syncResult.syncedItems > 0;
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Queue processing failed: ${failure.message}');
          return false;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Queue processing failed', e, stackTrace);
      return false;
    }
  }

  /// Check for changes in a specific calendar
  Future<bool> _checkCalendarChanges(CaldavAccount account, TaskCalendar calendar) async {
    try {
      final caldavService = CalDAVService(account: account);
      
                      // Get fresh calendar data from repository to ensure we have current state
      AppLogger.debug('CalDAVMonitor: About to retrieve fresh calendar from repository for ${calendar.path}');
      final freshCalendarResult = await _calendarRepository.getById(calendar.path);
      await freshCalendarResult.when(
        success: (freshCalendar) async {
          if (freshCalendar == null) {
            AppLogger.warning('CalDAVMonitor: Calendar not found in repository: ${calendar.path}');
            return false;
          }
          
          // Use fresh calendar data from repository
          final currentCalendar = freshCalendar;
          AppLogger.debug('CalDAVMonitor: Retrieved fresh calendar from repository: ${currentCalendar.path}');
          AppLogger.debug('CalDAVMonitor: Repository sync token: ${currentCalendar.syncToken ?? "(null)"}');
          AppLogger.debug('CalDAVMonitor: Repository ETag: ${currentCalendar.etag ?? "(null)"}');
          AppLogger.debug('CalDAVMonitor: Repository lastSyncAt: ${currentCalendar.lastSyncAt}');
          
                    // Get both sync token and ETag using CalDAVService
          final serverPropertiesResult = await caldavService.getCalendarProperties(currentCalendar);
          return await serverPropertiesResult.when(
            success: (updatedCalendar) async {
              final localSyncToken = currentCalendar.syncToken;
              final localEtag = currentCalendar.etag;
              final serverSyncToken = updatedCalendar.syncToken;
              final serverEtag = updatedCalendar.etag;
          
              // Log sync token comparison for debugging
              AppLogger.info('CalDAVMonitor: Sync token comparison for ${currentCalendar.displayName}:');
              AppLogger.info('CalDAVMonitor:   Local sync token:  ${localSyncToken ?? "(null)"}');
              AppLogger.info('CalDAVMonitor:   Server sync token: ${serverSyncToken ?? "(null)"}');
              AppLogger.info('CalDAVMonitor:   Local ETag:       ${localEtag ?? "(null)"}');
              AppLogger.info('CalDAVMonitor:   Server ETag:      ${serverEtag ?? "(null)"}');
              
              // Check sync tokens first
              if (localSyncToken != serverSyncToken) {
                // Sync tokens differ - delegate to SyncService
                AppLogger.info('CalDAVMonitor: Sync tokens differ for ${currentCalendar.displayName}, delegating to SyncService');
                await _syncService.syncCalendar(account, currentCalendar, []);
                
                // After sync, just return true - let the sync service handle all saving
                AppLogger.info('CalDAVMonitor: Sync completed for ${currentCalendar.displayName}');
                return true;
              } else if (localEtag != serverEtag) {
                // Sync tokens are equal but ETags differ - delegate to sync service
                AppLogger.info('CalDAVMonitor: ETag differs for ${currentCalendar.displayName}, delegating to SyncService');
                await _syncService.syncCalendar(account, currentCalendar, []);
                return true;
              }
              
              return false; // No changes detected
            },
            failure: (failure) async {
              AppLogger.warning('CalDAVMonitor: Could not get server properties for ${currentCalendar.displayName}: ${failure.message}');
              return false;
            },
          );
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Could not get fresh calendar from repository: ${failure.message}');
          return false;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to check changes for ${calendar.displayName}', e, stackTrace);
      return false;
    }
    return false; // Fallback return
  }

  /// Update interval based on whether changes were detected
  void _updateInterval(bool changesDetected) {
    if (changesDetected) {
      // Decrease interval (more frequent monitoring)
      _currentInterval = Duration(
        milliseconds: (_currentInterval.inMilliseconds * _changeMultiplier).round(),
      );
      
      // Ensure minimum interval
      if (_currentInterval < _minInterval) {
        _currentInterval = _minInterval;
      }
    } else {
      // Increase interval (less frequent monitoring)
      _currentInterval = Duration(
        milliseconds: (_currentInterval.inMilliseconds * _noChangeMultiplier).round(),
      );
      
      // Ensure maximum interval
      if (_currentInterval > _maxInterval) {
        _currentInterval = _maxInterval;
      }
    }

    // Restart timer with new interval
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_currentInterval, (_) {
      _performChangeMonitoring();
    });
  }

  /// Update last sync time for all calendars
  Future<void> _updateLastSyncTime(List<TaskCalendar> calendars) async {
    try {
      for (final calendar in calendars) {
        final updatedCalendar = calendar.copyWith(lastSyncAt: DateTime.now());
        await _calendarRepository.save(updatedCalendar);
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to update last sync time', e, stackTrace);
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Get current monitoring interval
  Duration get currentInterval => _currentInterval;

  /// Dispose resources
  void dispose() {
    stop();
  }
} 