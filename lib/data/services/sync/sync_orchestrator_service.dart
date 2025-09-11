// SyncOrchestratorService: orchestrates connection monitoring, CalDAV change
// detection (sync tokens/ETags), sharing state refresh, and delegates actual
// sync operations to SyncService. This unit centralizes orchestration across
// CalDAV, TowDow APIs, and external storage providers.

import 'dart:async';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../models/caldav_account.dart';

import '../../models/shared_with_me_project.dart';

import '../../repositories/account_repository.dart';
import '../../repositories/calendar_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/external_account_repository.dart';

import 'connection_monitor_service.dart';
import 'sync_service.dart';
import '../caldav/caldav_discovery_service.dart';
import '../storage/s3_storage_service.dart';
import '../../providers/providers.dart';
import '../../models/task_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../user/user_sync_service.dart';
import '../user/user_preferences_queue_service.dart';
import '../user/external_account_queue_service.dart';
import '../share/share_service.dart';

class CalDAVMonitor {
  // Global cross-instance guard to prevent concurrent monitoring across multiple instances
  static int? _globalRunnerId; // identityHashCode of the instance currently running
  // Dependencies - focused on calendar monitoring
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final UserRepository _userRepository;
  final ExternalAccountRepository _externalAccountRepository;
  final TaskRepository? _taskRepository;

  final ConnectionMonitorService _connectionMonitorService;
  final SyncService _syncService;
  final UserSyncService _userSyncService;
  final UserPreferencesQueueService _userPreferencesQueueService;
  final ExternalAccountQueueService _externalAccountQueueService;
  // Optional Ref for DI families
  final Ref? _ref;

  // Dynamic interval configuration
  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _maxInterval = Duration(seconds: 40);
  static const Duration _initialInterval = Duration(seconds: 10);
  static const double _changeMultiplier = 0.5; // Divide by 2 when change detected
  static const double _noChangeMultiplier = 1.5; // Multiply by 1.5 when no change

  // State management
  Timer? _monitorTimer;
  bool _isMonitoring = false;
  bool _isPerformingMonitoring = false; // Guard against concurrent executions
  Duration _currentInterval = _initialInterval;

  CalDAVMonitor({
    Ref? ref,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required CategoryRepository categoryRepository,
    required UserRepository userRepository,
    required ExternalAccountRepository externalAccountRepository,
    required ConnectionMonitorService connectionMonitorService,
    required SyncService syncService,
    required UserSyncService userSyncService,
    required UserPreferencesQueueService userPreferencesQueueService,
    required ExternalAccountQueueService externalAccountQueueService,
    TaskRepository? taskRepository,
  })  : _ref = ref,
        _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _userRepository = userRepository,
        _externalAccountRepository = externalAccountRepository,
        _taskRepository = taskRepository,
        _connectionMonitorService = connectionMonitorService,
        _syncService = syncService,
        _userSyncService = userSyncService,
        _userPreferencesQueueService = userPreferencesQueueService,
        _externalAccountQueueService = externalAccountQueueService;

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
    // Timings for monitoring cycle
    final Stopwatch swTotal = Stopwatch()..start();
    final Map<String, int> timings = {};
    if (!_isMonitoring) {
      AppLogger.debug('CalDAVMonitor: Not monitoring, skipping change check');
      swTotal.stop();
      timings['overall_wall_ms'] = swTotal.elapsedMilliseconds;
      AppLogger.info('CalDAVMonitor: Monitor timings (ms): '+timings.toString());
      return;
    }

    // Prevent concurrent executions (per-instance)
    if (_isPerformingMonitoring) {
      final int selfId = identityHashCode(this);
      AppLogger.debug('CalDAVMonitor['+selfId.toString()+']: Monitoring already in progress, skipping concurrent execution');
      swTotal.stop();
      timings['overall_wall_ms'] = swTotal.elapsedMilliseconds;
      AppLogger.info('CalDAVMonitor: Monitor timings (ms): '+timings.toString());
      return;
    }

    // Cross-instance guard to ensure only one monitor runs app-wide
    final int instanceId = identityHashCode(this);
    if (_globalRunnerId != null && _globalRunnerId != instanceId) {
      AppLogger.debug('CalDAVMonitor['+instanceId.toString()+']: Another instance is monitoring (owner: '+_globalRunnerId.toString()+'), skipping');
      swTotal.stop();
      timings['overall_wall_ms'] = swTotal.elapsedMilliseconds;
      AppLogger.info('CalDAVMonitor: Monitor timings (ms): '+timings.toString());
      return;
    }
    if (_globalRunnerId == null) {
      _globalRunnerId = instanceId;
    }

    _isPerformingMonitoring = true;
    final DateTime monitoringStart = DateTime.now();
    AppLogger.debug('CalDAVMonitor['+instanceId.toString()+']: start performMonitoring at ${monitoringStart.toIso8601String()}');
    try {
      // Check connection status first (defensive against unconfigured mocks)
      try {
        final swConn = Stopwatch()..start();
        final connectionStatus = _connectionMonitorService.currentStatus;
        swConn.stop();
        timings['connectionStatus_ms'] = swConn.elapsedMilliseconds;
        if (connectionStatus != ConnectionStatus.connected) {
          AppLogger.warning('CalDAVMonitor: No internet connection, skipping change monitoring (current status: $connectionStatus)');
          _updateInterval(false); /// if no connexion update intervel
          swTotal.stop();
          timings['overall_wall_ms'] = swTotal.elapsedMilliseconds;
          AppLogger.info('CalDAVMonitor: Monitor timings (ms): '+timings.toString());
          return;
        }
      } catch (e, st) {
        AppLogger.warning('CalDAVMonitor: Could not read connection status, skipping cycle');
        AppLogger.debug('CalDAVMonitor: Connection status error: $e');
        _updateInterval(false);
        swTotal.stop();
        timings['overall_wall_ms'] = swTotal.elapsedMilliseconds;
        AppLogger.info('CalDAVMonitor: Monitor timings (ms): '+timings.toString());
        return;
      }

      // Get active account
      final swGetAccount = Stopwatch()..start();
      final accountResult = await _accountRepository.getActiveAccount();
      swGetAccount.stop();
      timings['getActiveAccount_ms'] = swGetAccount.elapsedMilliseconds;
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.debug('CalDAVMonitor: No active account, skipping monitoring');
            return;
          }

          // 1. Update the calendar list from server (add, remove calendars if needed)
          bool changesDetected = await _syncService.updateCalendarList(account);
          bool changesDetected = false;
          // if (shouldRefreshCalendarList) {
          final swUpdateList = Stopwatch()..start();
          changesDetected = await _syncService.updateCalendarList(account);
          swUpdateList.stop();
          timings['updateCalendarList_ms'] = swUpdateList.elapsedMilliseconds;
          // 2. synchronize all calendars from server,
          // this MUST be done before queue processing to handle orphan in queues (e.g. project deleted or unshared)
          // Get all calendars to monitor (now includes all discovered calendars)
          final swGetCalendars = Stopwatch()..start();
          final calendarsResult = await _calendarRepository.getProjectCalendars();
          swGetCalendars.stop();
          timings['getProjectCalendars_ms'] = swGetCalendars.elapsedMilliseconds;
          await calendarsResult.when(
            success: (calendars) async {
              try {
                final swSync = Stopwatch()..start();
                await _syncService.syncAllActiveCaldavNoDiscovery();
                swSync.stop();
                timings['syncAllActiveCaldavNoDiscovery_ms'] = swSync.elapsedMilliseconds;
              } catch (e, st) {
                AppLogger.warning('CalDAVMonitor: Failed to trigger full sync after calendar list update: $e');
                AppLogger.debug('CalDAVMonitor: Stack: $st');
              }
              final DateTime monitoringDownloadTask = DateTime.now();
              final Duration elapsed = monitoringDownloadTask.difference(monitoringStart);
              AppLogger.debug('CalDAVMonitor: performMonitoring got task after ${elapsed.inMilliseconds}ms (started at ${monitoringStart.toIso8601String()}, ended at ${monitoringDownloadTask.toIso8601String()})');
              // Run other synchro (upload / download) in parallel to speed up the cycle
              try {
                final futures = <Future<bool>>[
                  // push action done locally
                  _processQueuedOperations(),
                  _checkAndUpdateUserPreferences(account),
                  _checkAndUpdateExternalAccounts(account),
                  // get remotes for project shared with me (local changes have been handled in processQueue as for owned calendars)
                  _checkAndUpdateSharedProjects(account),
                ];
                final results = await Future.wait(
                  futures.map((f) async {
                    try {
                      return await f;
                    } catch (e, st) {
                      AppLogger.warning('CalDAVMonitor: Parallel task failed: $e');
                      AppLogger.debug('CalDAVMonitor: Parallel task stack: $st');
                      return false;
                    }
                  }).toList(),
                  eagerError: false,
                );
                // Aggregate results
                for (final r in results) {
                  changesDetected |= r;
                }
              } catch (e, st) {
                // Should not happen due to per-task try/catch, but keep defensive logging
                AppLogger.warning('CalDAVMonitor: Parallel checks encountered an error: $e');
                AppLogger.debug('CalDAVMonitor: Stack: $st');
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
    } finally {
      // Release per-instance flag and global guard if owned
      _isPerformingMonitoring = false;
      final int instanceId = identityHashCode(this);
      if (_globalRunnerId == instanceId) {
        _globalRunnerId = null;
      }
      final DateTime monitoringEnd = DateTime.now();
      final Duration elapsed = monitoringEnd.difference(monitoringStart);
      AppLogger.debug('CalDAVMonitor['+instanceId.toString()+']: end performMonitoring after ${elapsed.inMilliseconds}ms (started at ${monitoringStart.toIso8601String()}, ended at ${monitoringEnd.toIso8601String()})');
      // Log timings
      try {
        swTotal.stop();
        timings['overall_wall_ms'] = swTotal.elapsedMilliseconds;
        AppLogger.info('CalDAVMonitor: Monitor timings (ms): '+timings.toString());
      } catch (_) {}
    }
  }

  Future<bool> _checkAndUpdateUserPreferences(CaldavAccount account) async {
    // push local changes in user preferences
    await _processUserPreferencesQueue();
    // get remote changes for user preferences
    return await _checkUserPreferencesChanges(account);
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

  Future<bool> _checkAndUpdateExternalAccounts(CaldavAccount account) async {
    await _processExternalAccountQueue();
    // get remote changes for external accounts
    return await _checkExternalAccountChanges(account);
  }

  /// Process user preferences queue
  Future<bool> _processUserPreferencesQueue() async {
    try {
      final result = await _userPreferencesQueueService.processQueue();
      return result.when(
        success: (_) => true,
        failure: (_) => false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: User preferences queue processing failed', e, stackTrace);
      return false;
    }
  }

  /// Process external account queue
  Future<bool> _processExternalAccountQueue() async {
    try {
      final result = await _externalAccountQueueService.processQueue();
      return result.when(
        success: (_) => true,
        failure: (_) => false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: External account queue processing failed', e, stackTrace);
      return false;
    }
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
  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Get current monitoring interval
  Duration get currentInterval => _currentInterval;

  /// Check for changes in user preferences by comparing S3 etags
  Future<bool> _checkUserPreferencesChanges(CaldavAccount account) async {
    try {
      // Skip S3 checks for custom provider accounts (no S3 features)
      if (account.providerType == 'custom') {
        AppLogger.debug('CalDAVMonitor: Skipping user preferences S3 checks for custom provider');
        return false;
      }

      // Get current local etag
      final localEtagResult = await _userRepository.getEtag();
      final localEtag = localEtagResult.when(
        success: (etag) => etag,
        failure: (_) => null,
      );

      AppLogger.debug('CalDAVMonitor: Retrieved local ETag: $localEtag');

      // Create S3 service and get remote etag
      final s3Service = _ref != null
          ? _ref.read(s3StorageServiceProvider(account))
          : S3StorageService(account: account);
      final userPrefix = s3Service.getUserPrefix();
      final key = '${userPrefix}preferences.json';
      
      final remoteEtagResult = await s3Service.getCurrentEtag(key: key, isPrivate: true);
      return await remoteEtagResult.when(
        success: (remoteEtag) async {
          AppLogger.debug('CalDAVMonitor: User preferences etag comparison: Local etag:  ${localEtag ?? "(null)"}, Remote etag: ${remoteEtag ?? "(null)"}');
          
          if (localEtag != remoteEtag) {
            AppLogger.info('CalDAVMonitor: User preferences etags differ, triggering download');
            
            // Get file info to compare last modified dates for conflict resolution
            final fileInfoResult = await s3Service.getFileInfo(key: key, isPrivate: true);
            await fileInfoResult.when(
              success: (fileInfo) async {
                AppLogger.debug('CalDAVMonitor: Remote file last modified: ${fileInfo.lastModified}');
                
                // Use injected UserSyncService instead of creating a new instance
                final downloadResult = await _userSyncService.downloadUserPreferences();
                await downloadResult.when(
                  success: (hasData) async {
                    if (hasData) {
                      AppLogger.info('CalDAVMonitor: Successfully downloaded updated user preferences');
                      // Etag is now updated automatically by UserSyncService
                    } else {
                      AppLogger.info('CalDAVMonitor: No user preferences data found on server');
                    }
                  },
                  failure: (failure) async {
                    AppLogger.error('CalDAVMonitor: Failed to download user preferences: ${failure.message}');
                  },
                );
              },
              failure: (failure) async {
                AppLogger.warning('CalDAVMonitor: Could not get file info for user preferences: ${failure.message}');
                // No need to update etag manually - let sync handle it
              },
            );
            
            return true;
          }
          else{
            AppLogger.debug('CalDAVMonitor: User preferences etags match, no sync needed');
          }
          
          return false;
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Could not get remote etag for user preferences: ${failure.message}');
          
          // Check if this is a 404 (file not found) and we have local preferences
          if (failure.message.contains('404') || failure.message.contains('not found')) {
            AppLogger.info('CalDAVMonitor: No remote user preferences file found, checking for local preferences to upload');
            
            // Check if we have local preferences that should be uploaded
            final localPrefsResult = await _userRepository.getUserPreferences();
            final hasLocalPrefs = localPrefsResult.when(
              success: (prefs) => prefs.projectOrder.isNotEmpty,
              failure: (_) => false,
            );
            
            if (hasLocalPrefs) {
              AppLogger.info('CalDAVMonitor: Found local preferences, triggering upload to server');
              
              // Trigger upload of local preferences
              final uploadResult = await _userSyncService.uploadUserPreferences();
              await uploadResult.when(
                success: (_) async {
                  AppLogger.info('CalDAVMonitor: Successfully uploaded local user preferences to server');
                },
                failure: (uploadFailure) async {
                  AppLogger.error('CalDAVMonitor: Failed to upload local user preferences: ${uploadFailure.message}');
                },
              );
              
              return true; // Return true to indicate changes were processed
            }
          }
          
          return false;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to check user preferences changes', e, stackTrace);
      return false;
    }
  }

  /// Check for changes in external accounts by comparing S3 etags
  Future<bool> _checkExternalAccountChanges(CaldavAccount account) async {
    try {
      // Skip S3 checks for custom provider accounts (no S3 features)
      if (account.providerType == 'custom') {
        AppLogger.debug('CalDAVMonitor: Skipping external account S3 checks for custom provider');
        return false;
      }
      bool anyChanges = false;
      
      // Get the global credentials file etag (similar to user preferences)
      final localEtagResult = await _externalAccountRepository.getCredentialsFileEtag();
      final localEtag = localEtagResult.when(
        success: (etag) => etag,
        failure: (_) => null,
      );
      
      final s3Service = _ref != null
          ? _ref.read(s3StorageServiceProvider(account))
          : S3StorageService(account: account);
      final userPrefix = s3Service.getUserPrefix();
      
      // Check external credentials file
      final credentialsKey = '${userPrefix}external_credentials.json';
      final remoteEtagResult = await s3Service.getCurrentEtag(key: credentialsKey, isPrivate: true);
      
      await remoteEtagResult.when(
        success: (remoteEtag) async {
          AppLogger.debug('CalDAVMonitor: External credentials etag comparison: Local etag:  ${localEtag ?? "(null)"}, Remote etag: ${remoteEtag ?? "(null)"}');
          if (localEtag != remoteEtag) {
            AppLogger.info('CalDAVMonitor: External credentials etags differ, triggering download');
            
            // Get file info for conflict resolution
            final fileInfoResult = await s3Service.getFileInfo(key: credentialsKey, isPrivate: true);
            await fileInfoResult.when(
              success: (fileInfo) async {
                AppLogger.debug('CalDAVMonitor: Remote credentials file last modified: ${fileInfo.lastModified}');
                
                // Use injected UserSyncService instead of creating a new instance
                final downloadResult = await _userSyncService.downloadExternalCredentials();
                await downloadResult.when(
                  success: (hasData) async {
                    if (hasData) {
                      AppLogger.info('CalDAVMonitor: Successfully downloaded updated external credentials');
                      // Etag is now updated automatically by UserSyncService
                    } else {
                      AppLogger.info('CalDAVMonitor: No external credentials data found on server');
                    }
                  },
                  failure: (failure) async {
                    AppLogger.error('CalDAVMonitor: Failed to download external credentials: ${failure.message}');
                  },
                );
              },
              failure: (failure) async {
                AppLogger.warning('CalDAVMonitor: Could not get file info for external credentials: ${failure.message}');
                // No need to update etag manually - let sync handle it
              },
            );
            anyChanges = true;
          } else {
            AppLogger.debug('CalDAVMonitor: External credentials etags match, no sync needed');
          }
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Could not get remote etag for external credentials: ${failure.message}');
        },
      );

      return anyChanges;
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to check external account changes', e, stackTrace);
      return false;
    }
  }


  /// Check and update shared projects from server
  Future<bool> _checkAndUpdateSharedProjects(CaldavAccount account) async {
    try {
      // Check if account supports sharing
      final shareService = ShareService(account: account);
      if (!shareService.supportsSharing) {
        AppLogger.debug('CalDAVMonitor: Account does not support sharing, skipping shared project check');
        return false;
      }

      AppLogger.debug('CalDAVMonitor: Checking shared projects from server');

      // Get current shared projects from user preferences
      final currentPrefsResult = await _userRepository.getUserPreferences();
      final currentSharedProjects = currentPrefsResult.when(
        success: (prefs) => prefs.sharedWithMeProjects,
        failure: (_) => <SharedWithMeProject>[],
      );

      // Get shared projects from server
      final serverSharedResult = await shareService.getProjectsSharedWithMe();
      await serverSharedResult.when(
        success: (serverMembers) async {
          AppLogger.info('CalDAVMonitor: Server returned ${serverMembers.length} shared projects:');
          for (final member in serverMembers) {
            AppLogger.info('CalDAVMonitor:   - ${member.projectPath} (from ${member.sourceUserEmail})');
          }
          
          AppLogger.info('CalDAVMonitor: Current preferences has ${currentSharedProjects.length} shared projects:');
          for (final project in currentSharedProjects) {
            AppLogger.info('CalDAVMonitor:   - ${project.projectId} (ack: ${project.ack}, from ${project.sourceUserEmail})');
          }
          
          // Convert server members to SharedWithMeProject
          // NEW SHARED PROJECTS: Set ack: false regardless of user preferences
          // EXISTING SHARED PROJECTS: Preserve current acknowledgment status
          final currentAcknowledgments = <String, bool>{};
          for (final currentProject in currentSharedProjects) {
            currentAcknowledgments[currentProject.projectId] = currentProject.ack;
          }

          final newSharedProjects = serverMembers.map((member) => 
            SharedWithMeProject.fromSharedProjectMember(
              projectPath: member.projectPath,
              allTasks: member.allTasks,
              projectRight: member.projectRight,
              sourceUserEmail: member.sourceUserEmail,
              // NEW PROJECTS: Always set ack: false
              // EXISTING PROJECTS: Preserve current ack status
              ack: currentAcknowledgments[member.projectPath] ?? false,
            )
          ).toList();
          
          AppLogger.info('CalDAVMonitor: After merging, new shared projects list:');
          for (final project in newSharedProjects) {
            AppLogger.info('CalDAVMonitor:   - ${project.projectId} (ack: ${project.ack}, from ${project.sourceUserEmail})');
          }

          // Compare and detect changes
          final currentProjectPaths = currentSharedProjects.map((p) => p.projectId).toSet();
          final newProjectPaths = newSharedProjects.map((p) => p.projectId).toSet();
          
          final addedProjects = newProjectPaths.difference(currentProjectPaths);
          final removedProjects = currentProjectPaths.difference(newProjectPaths);
          
          if (addedProjects.isNotEmpty || removedProjects.isNotEmpty) {
            AppLogger.info('CalDAVMonitor: Shared projects changed - added: ${addedProjects.length}, removed: ${removedProjects.length}');
            
            // Remove disappeared shared projects from calendar list (adding is handled by discovery)
            await _removeDisappearedSharedProjectCalendars(removedProjects);
            
            // Update user preferences with new shared projects list
            final prefsResult = await _userRepository.getUserPreferences();
            await prefsResult.when(
              success: (prefs) async {
                // In new architecture: all projects sync by default, no special handling needed
                // Just update the shared projects list and add new ones to project order for display
                final updatedProjectOrder = [...prefs.projectOrder];
                
                // Get all non-acknowledged shared projects (will auto-sync due to discovery)
                final nonAckedSharedProjects = newSharedProjects
                    .where((project) => !project.ack)
                    .map((project) => project.projectId)
                    .toSet();
                
                AppLogger.info('CalDAVMonitor: Found ${nonAckedSharedProjects.length} non-acknowledged shared projects (will auto-sync):');
                for (final projectId in nonAckedSharedProjects) {
                  AppLogger.info('CalDAVMonitor:   - $projectId');
                  
                  // Add to project order for display if not already there
                  if (!updatedProjectOrder.contains(projectId)) {
                    updatedProjectOrder.add(projectId);
                    AppLogger.info('CalDAVMonitor: Added shared project $projectId to project order');
                  }
                }
                
                // Remove disappeared shared projects from project order
                for (final removedProject in removedProjects) {
                  updatedProjectOrder.remove(removedProject);
                  AppLogger.info('CalDAVMonitor: Removed disappeared shared project $removedProject from project order');
                }
                
                final updatedPrefs = prefs.copyWith(
                  sharedWithMeProjects: newSharedProjects,
                  projectOrder: updatedProjectOrder,
                );
                
                await _userRepository.saveUserPreferencesWithoutSync(updatedPrefs);
                AppLogger.info('CalDAVMonitor: Updated user preferences with ${newSharedProjects.length} shared projects and updated active lists');
                
                // Note: Calendar activation removed - projectOrder is UI state only
                AppLogger.info('CalDAVMonitor: Updated project order - UI will reflect changes automatically');
              },
              failure: (failure) async {
                AppLogger.error('CalDAVMonitor: Failed to update user preferences with shared projects: ${failure.message}');
              },
            );
            return true;
          } else {
            AppLogger.debug('CalDAVMonitor: No changes in shared projects');
          }
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Failed to get shared projects from server: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to check and update shared projects', e, stackTrace);
    }
    return false;
  }

  /// Remove disappeared shared project calendars
  /// Note: Adding calendars is now handled by the discovery process
  Future<void> _removeDisappearedSharedProjectCalendars(Set<String> removedProjects) async {
    try {
      // Remove disappeared shared projects from calendar list
      for (final removedProjectPath in removedProjects) {
        AppLogger.info('CalDAVMonitor: Removing disappeared shared project from calendar list: $removedProjectPath');
        final removeResult = await _calendarRepository.delete(removedProjectPath);
        removeResult.when(
          success: (_) => AppLogger.debug('CalDAVMonitor: Successfully removed calendar $removedProjectPath'),
          failure: (failure) => AppLogger.warning('CalDAVMonitor: Failed to remove calendar $removedProjectPath: ${failure.message}'),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to remove disappeared shared project calendars', e, stackTrace);
    }
  }



  /// Dispose resources
  void dispose() {
    stop();
  }
}