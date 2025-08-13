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
import '../share/share_service.dart';

class CalDAVMonitor {
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
        _userPreferencesQueueService = userPreferencesQueueService;

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

    // Prevent concurrent executions
    if (_isPerformingMonitoring) {
      AppLogger.debug('CalDAVMonitor: Monitoring already in progress, skipping concurrent execution');
      return;
    }

    _isPerformingMonitoring = true;
    try {
      // Check connection status first (defensive against unconfigured mocks)
      try {
        final connectionStatus = _connectionMonitorService.currentStatus;
        if (connectionStatus != ConnectionStatus.connected) {
          AppLogger.warning('CalDAVMonitor: No internet connection, skipping change monitoring');
          _updateInterval(false); /// if no connexion update intervel
          return;
        }
      } catch (e, st) {
        AppLogger.warning('CalDAVMonitor: Could not read connection status, skipping cycle');
        AppLogger.debug('CalDAVMonitor: Connection status error: $e');
        _updateInterval(false);
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

          bool discoveryChanges = await _discoverAndEnsureAllCalendars(account);
          
          // Get all calendars to monitor (now includes all discovered calendars)
          final calendarsResult = await _calendarRepository.getProjectCalendars();
          await calendarsResult.when(
            success: (calendars) async {
              bool changesDetected = discoveryChanges; // Include discovery changes
              
               // If discovery added/updated calendars, trigger an immediate full sync
               if (discoveryChanges) {
                 try {
                   AppLogger.info('CalDAVMonitor: Discovery detected changes - triggering immediate full sync');
                   await _syncService.syncAllActiveCaldav();
                 } catch (e, st) {
                   AppLogger.warning('CalDAVMonitor: Failed to trigger full sync after discovery: $e');
                   AppLogger.debug('CalDAVMonitor: Stack: $st');
                 }
               }

              // Process queued operations
              changesDetected |= await _processQueuedOperations();
              
              // Process user preferences queue
              changesDetected |= await _processUserPreferencesQueue();
              
              // Check for changes in user preferences
              changesDetected |= await _checkUserPreferencesChanges(account);
              
              // Check for changes in external accounts
              changesDetected |= await _checkExternalAccountChanges(account);
              
              // Check for changes in shared projects (now simplified since calendars already exist)
              changesDetected |= await _checkAndUpdateSharedProjects(account);
                        
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
      _isPerformingMonitoring = false;
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
      // First, check and update shared projects from server
      await _checkAndUpdateSharedProjects(account);

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
          AppLogger.debug('CalDAVMonitor: User preferences etag comparison:');
          AppLogger.debug('  Local etag:  ${localEtag ?? "(null)"}');
          AppLogger.debug('  Remote etag: ${remoteEtag ?? "(null)"}');
          
          if (localEtag != remoteEtag) {
            AppLogger.info('CalDAVMonitor: User preferences etags differ, triggering download');
            
            // Get file info to compare last modified dates for conflict resolution
            final fileInfoResult = await s3Service.getFileInfo(key: key, isPrivate: true);
            await fileInfoResult.when(
              success: (fileInfo) async {
                AppLogger.debug('CalDAVMonitor: Remote file last modified: ${fileInfo.lastModified}');
                
                // Use injected UserSyncService instead of creating a new instance
                final downloadResult = await _userSyncService.downloadUserData();
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
              success: (prefs) => prefs.projectOrder.isNotEmpty || prefs.excludedProjects.isNotEmpty,
              failure: (_) => false,
            );
            
            if (hasLocalPrefs) {
              AppLogger.info('CalDAVMonitor: Found local preferences, triggering upload to server');
              
              // Trigger upload of local preferences
              final uploadResult = await _userSyncService.uploadUserData();
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
          AppLogger.debug('CalDAVMonitor: External credentials etag comparison:');
          AppLogger.debug('  Local etag:  ${localEtag ?? "(null)"}');
          AppLogger.debug('  Remote etag: ${remoteEtag ?? "(null)"}');
          
          if (localEtag != remoteEtag) {
            AppLogger.info('CalDAVMonitor: External credentials etags differ, triggering download');
            
            // Get file info for conflict resolution
            final fileInfoResult = await s3Service.getFileInfo(key: credentialsKey, isPrivate: true);
            await fileInfoResult.when(
              success: (fileInfo) async {
                AppLogger.debug('CalDAVMonitor: Remote credentials file last modified: ${fileInfo.lastModified}');
                
                // Use injected UserSyncService instead of creating a new instance
                final downloadResult = await _userSyncService.downloadUserData();
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

  /// Discover all available calendars and ensure they exist locally
  /// This ensures shared projects and all other accessible projects are available for sync
  Future<bool> _discoverAndEnsureAllCalendars(CaldavAccount account) async {
    try {
      AppLogger.info('CalDAVMonitor: Discovering all available calendars from server');
      
      // Use DI CalDAV service if available to test connection and list calendars
      if (_ref != null) {
        final caldav = _ref.read(caldavServiceProvider(account));
        final capabilitiesResult = await caldav.testConnection();
        return await capabilitiesResult.when(
          success: (capabilities) async {
            final availableCalendars = capabilities.taskCalendars;
            AppLogger.info('CalDAVMonitor: Server has ${availableCalendars.length} available calendars');
            return await _ensureCalendarsExist(availableCalendars);
          },
          failure: (f) async {
            AppLogger.error('CalDAVMonitor: Failed to discover calendars: ${f.message}');
            return false;
          },
        );
      }
      // Fallback to discovery service
      final discovery = CalDavDiscoveryService(account: account);
      final capabilitiesResult = await discovery.testConnection();
      
      return await capabilitiesResult.when(
        success: (capabilities) async {
          return _ensureCalendarsExist(capabilities.taskCalendars);
        },
        failure: (failure) async {
          AppLogger.error('CalDAVMonitor: Failed to discover calendars: ${failure.message}');
          return false;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Exception during calendar discovery', e, stackTrace);
      return false;
    }
  }

  Future<bool> _ensureCalendarsExist(List<TaskCalendar> availableCalendars) async {
    // Ensure all discovered calendars exist in local repository
    int addedCount = 0;
    int existingCount = 0;
    final newlyAddedPaths = <String>[];
    for (final serverCalendar in availableCalendars) {
      final pendingDeletion = await _syncService.hasPendingDeletionForCalendar(serverCalendar.path);
      if (pendingDeletion) {
        AppLogger.info('CalDAVMonitor: Skipping discovered calendar pending deletion: ${serverCalendar.path}');
        continue;
      }
      final existingCalendarResult = await _calendarRepository.getByPath(serverCalendar.path);
      await existingCalendarResult.when(
        success: (existingCalendar) async {
          if (existingCalendar == null) {
            final saveResult = await _calendarRepository.save(serverCalendar);
            saveResult.when(
              success: (_) {
                addedCount++;
                AppLogger.info('CalDAVMonitor: Added discovered calendar: ${serverCalendar.displayName}');
                newlyAddedPaths.add(serverCalendar.path);
              },
              failure: (failure) {
                AppLogger.warning('CalDAVMonitor: Failed to save discovered calendar ${serverCalendar.displayName}: ${failure.message}');
              },
            );
          } else {
            existingCount++;
            if (existingCalendar.etag != serverCalendar.etag) {
              final updatedCalendar = existingCalendar.copyWith(
                displayName: serverCalendar.displayName,
                description: serverCalendar.description,
                etag: serverCalendar.etag,
                lastModified: DateTime.now(),
              );
              await _calendarRepository.save(updatedCalendar);
              AppLogger.debug('CalDAVMonitor: Updated existing calendar: ${serverCalendar.displayName}');
            }
          }
        },
        failure: (_) async {
          final saveResult = await _calendarRepository.save(serverCalendar);
          saveResult.when(
            success: (_) {
              addedCount++;
              AppLogger.info('CalDAVMonitor: Added discovered calendar (after lookup error): ${serverCalendar.displayName}');
              newlyAddedPaths.add(serverCalendar.path);
            },
            failure: (failure) {
              AppLogger.warning('CalDAVMonitor: Failed to save discovered calendar ${serverCalendar.displayName}: ${failure.message}');
            },
          );
        },
      );
    }
    AppLogger.info('CalDAVMonitor: Calendar discovery complete - $addedCount added, $existingCount already existed');

    // Ensure newly added calendars are included for sync and visible in project order by default
    if (newlyAddedPaths.isNotEmpty) {
      try {
        final prefsResult = await _userRepository.getUserPreferences();
        await prefsResult.when(
          success: (prefs) async {
            var updated = prefs;
            // Remove from excluded list if present
            for (final path in newlyAddedPaths) {
              if (!updated.shouldSyncProject(path)) {
                updated = updated.includeProject(path);
                AppLogger.info('CalDAVMonitor: Included newly discovered project in sync: $path');
              }
            }
            // Append to project order for visibility
            final currentOrder = [...updated.projectOrder];
            for (final path in newlyAddedPaths) {
              if (!currentOrder.contains(path)) {
                currentOrder.add(path);
              }
            }
            updated = updated.copyWith(projectOrder: currentOrder);
            await _userRepository.saveUserPreferences(updated);
            AppLogger.info('CalDAVMonitor: Updated user preferences for ${newlyAddedPaths.length} newly discovered projects');
          },
          failure: (failure) async {
            AppLogger.warning('CalDAVMonitor: Could not load user preferences to include new calendars: ${failure.message}');
          },
        );
      } catch (e, st) {
        AppLogger.warning('CalDAVMonitor: Failed to update preferences for new calendars: $e');
        AppLogger.debug('CalDAVMonitor: Stack: $st');
      }
    }
    // Remove calendars that disappeared from discovery (owned projects only)
    try {
      await _removeCalendarsMissingFromDiscovery(availableCalendars);
    } catch (e, st) {
      AppLogger.warning('CalDAVMonitor: Failed to remove calendars missing from discovery: $e');
      AppLogger.debug('CalDAVMonitor: Stack: $st');
    }
    return addedCount > 0;
  }

  /// Remove locally stored calendars that are no longer returned by discovery.
  /// Only applies to owned projects. Shared-with-me removals are handled by
  /// _checkAndUpdateSharedProjects using ShareService API semantics.
  Future<void> _removeCalendarsMissingFromDiscovery(List<TaskCalendar> availableCalendars) async {
    try {
      final discoveredPaths = availableCalendars.map((c) => c.path).toSet();
      final localResult = await _calendarRepository.getProjectCalendars();
      await localResult.when(
        success: (localCalendars) async {
          final toRemove = localCalendars
              .where((c) => !discoveredPaths.contains(c.path))
              .toList();

          if (toRemove.isEmpty) {
            return;
          }

          AppLogger.info('CalDAVMonitor: ${toRemove.length} local calendars not present in discovery');

          // For owned calendars, just unsync locally. Shared-with-me calendars are removed via share flow.
          for (final calendar in toRemove) {
            if (calendar.isSharedWithMe) {
              // Skip here; handled by _checkAndUpdateSharedProjects
              AppLogger.debug('CalDAVMonitor: Skipping shared-with-me calendar missing from discovery: ${calendar.path}');
              continue;
            }
            AppLogger.info('CalDAVMonitor: Unsyncing disappeared owned calendar: ${calendar.path}');
            final res = await _calendarRepository.unsyncCalendar(calendar.path);
            res.when(
              success: (_) => AppLogger.debug('CalDAVMonitor: Unsynced ${calendar.path}'),
              failure: (f) => AppLogger.warning('CalDAVMonitor: Failed to unsync ${calendar.path}: ${f.message}'),
            );
          }

          // Cleanup orphaned tasks referencing calendars that are not in discovery
          try {
            if (_taskRepository != null) {
              final cleanup = await _taskRepository!.deleteOrphanedTasksLocalOnly(discoveredPaths);
            cleanup.when(
              success: (_) => AppLogger.info('CalDAVMonitor: Cleaned up orphaned tasks for missing calendars'),
              failure: (f) => AppLogger.warning('CalDAVMonitor: Failed to cleanup orphaned tasks: ${f.message}'),
            );
            }
          } catch (_) {}

          // Update user preferences to remove missing calendars from project order/excluded lists
          try {
            final prefsResult = await _userRepository.getUserPreferences();
            await prefsResult.when(
              success: (prefs) async {
                final updatedOrder = prefs.projectOrder.where((p) => discoveredPaths.contains(p)).toList();
                final updatedExcluded = prefs.excludedProjects.where((p) => discoveredPaths.contains(p)).toList();
                if (updatedOrder.length != prefs.projectOrder.length || updatedExcluded.length != prefs.excludedProjects.length) {
                  final updatedPrefs = prefs.copyWith(
                    projectOrder: updatedOrder,
                    excludedProjects: updatedExcluded,
                  );
                  await _userRepository.saveUserPreferences(updatedPrefs);
                  AppLogger.info('CalDAVMonitor: Updated user preferences after removing missing calendars');
                }
              },
              failure: (f) async {
                AppLogger.warning('CalDAVMonitor: Could not load user preferences to update removed calendars: ${f.message}');
              },
            );
          } catch (_) {}
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Failed to load local calendars for removal check: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Exception while removing calendars missing from discovery', e, stackTrace);
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
                
                await _userRepository.saveUserPreferences(updatedPrefs);
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