// CalDAV Monitor for detecting changes in calendars
// Monitors sync tokens and ETags to detect changes that need synchronization
// Delegates actual sync operations to SyncService

import 'dart:async';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/task_calendar.dart';
import '../models/shared_with_me_project.dart';
import '../models/user_preferences.dart';
import '../repositories/account_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/external_account_repository.dart';
import '../repositories/external_calendar_repository.dart';
import 'connection_monitor_service.dart';
import 'sync_service.dart';
import 'caldav_service.dart';
import 's3_storage_service.dart';
import 'user_sync_service.dart';
import 'user_preferences_queue_service.dart';
import 'share_service.dart';

class CalDAVMonitor {
  // Dependencies - focused on calendar monitoring
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final UserRepository _userRepository;
  final ExternalAccountRepository _externalAccountRepository;
  final ExternalCalendarRepository _externalCalendarRepository;
  final ConnectionMonitorService _connectionMonitorService;
  final SyncService _syncService;
  final UserSyncService _userSyncService;
  final UserPreferencesQueueService _userPreferencesQueueService;

  // Dynamic interval configuration
  static const Duration _minInterval = Duration(seconds: 2);
  static const Duration _maxInterval = Duration(seconds: 40);
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
    required UserRepository userRepository,
    required ExternalAccountRepository externalAccountRepository,
    required ExternalCalendarRepository externalCalendarRepository,
    required ConnectionMonitorService connectionMonitorService,
    required SyncService syncService,
    required UserSyncService userSyncService,
    required UserPreferencesQueueService userPreferencesQueueService,
  })  : _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _userRepository = userRepository,
        _externalAccountRepository = externalAccountRepository,
        _externalCalendarRepository = externalCalendarRepository,
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
              
              // Process queued operations
              final queueChanges = await _processQueuedOperations();
              
              // Process user preferences queue
              final userPreferencesQueueChanges = await _processUserPreferencesQueue();
              
              // Check for changes in user preferences
              final userPrefsChanges = await _checkUserPreferencesChanges(account);
              
              // Check for changes in external accounts
              final externalAccountChanges = await _checkExternalAccountChanges(account);
              
              // Check for changes in shared projects
              await _checkAndUpdateSharedProjects(account);
              
              // Determine if any changes were detected
              final anyChanges = queueChanges || userPrefsChanges || externalAccountChanges || userPreferencesQueueChanges;
              
              // Update interval based on changes detected
              _updateInterval(anyChanges);
              
              
              if (anyChanges) {
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

  /// Check for changes in a specific calendar
  Future<bool> _checkCalendarChanges(CaldavAccount account, TaskCalendar calendar) async {
    try {
      final caldavService = CalDAVService(account: account);
      
                      // Get fresh calendar data from repository to ensure we have current state
      AppLogger.debug('CalDAVMonitor: About to retrieve fresh calendar from repository for ${calendar.path}');
      final freshCalendarResult = await _calendarRepository.getById(calendar.path);
      return await freshCalendarResult.when(
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
      final s3Service = S3StorageService(account: account);
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
      bool anyChanges = false;
      
      // Get the global credentials file etag (similar to user preferences)
      final localEtagResult = await _externalAccountRepository.getCredentialsFileEtag();
      final localEtag = localEtagResult.when(
        success: (etag) => etag,
        failure: (_) => null,
      );
      
      final s3Service = S3StorageService(account: account);
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

  /// Check and update shared projects from server
  Future<void> _checkAndUpdateSharedProjects(CaldavAccount account) async {
    try {
      // Check if account supports sharing
      final shareService = ShareService(account: account);
      if (!shareService.supportsSharing) {
        AppLogger.debug('CalDAVMonitor: Account does not support sharing, skipping shared project check');
        return;
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
            
            // Update calendar list by adding new shared projects and removing disappeared ones
            await _updateCalendarListForSharedProjects(addedProjects, removedProjects);
            
            // Update user preferences with new shared projects list
            final prefsResult = await _userRepository.getUserPreferences();
            await prefsResult.when(
              success: (prefs) async {
                // Add ALL non-acknowledged shared projects to active synced list
                final updatedProjectOrder = [...prefs.projectOrder];
                final updatedSyncedProjects = [...prefs.syncedProjects];
                
                // Get all non-acknowledged shared projects
                final nonAckedSharedProjects = newSharedProjects
                    .where((project) => !project.ack)
                    .map((project) => project.projectId)
                    .toSet();
                
                AppLogger.info('CalDAVMonitor: Found ${nonAckedSharedProjects.length} non-acknowledged shared projects:');
                for (final projectId in nonAckedSharedProjects) {
                  AppLogger.info('CalDAVMonitor:   - $projectId');
                }
                
                AppLogger.info('CalDAVMonitor: Current project order: ${prefs.projectOrder}');
                AppLogger.info('CalDAVMonitor: Current synced projects: ${prefs.syncedProjects}');
                
                // Add all non-acknowledged shared projects to active synced list
                for (final projectId in nonAckedSharedProjects) {
                  // Add to project order if not already there
                  if (!updatedProjectOrder.contains(projectId)) {
                    updatedProjectOrder.add(projectId);
                    AppLogger.info('CalDAVMonitor: Added non-acknowledged shared project $projectId to active synced list');
                  } else {
                    AppLogger.info('CalDAVMonitor: Non-acknowledged shared project $projectId already in active synced list');
                  }
                  
                  // Add to synced projects if not already there
                  if (!updatedSyncedProjects.contains(projectId)) {
                    updatedSyncedProjects.add(projectId);
                    AppLogger.info('CalDAVMonitor: Added non-acknowledged shared project $projectId to synced projects list');
                  } else {
                    AppLogger.info('CalDAVMonitor: Non-acknowledged shared project $projectId already in synced projects list');
                  }
                }
                
                AppLogger.info('CalDAVMonitor: Final project order: $updatedProjectOrder');
                AppLogger.info('CalDAVMonitor: Final synced projects: $updatedSyncedProjects');
                
                // Remove disappeared shared projects from active lists
                for (final removedProject in removedProjects) {
                  updatedProjectOrder.remove(removedProject);
                  updatedSyncedProjects.remove(removedProject);
                  AppLogger.info('CalDAVMonitor: Removed shared project $removedProject from active synced list');
                }
                
                final updatedPrefs = prefs.copyWith(
                  sharedWithMeProjects: newSharedProjects,
                  projectOrder: updatedProjectOrder,
                  syncedProjects: updatedSyncedProjects,
                );
                
                await _userRepository.saveUserPreferences(updatedPrefs);
                AppLogger.info('CalDAVMonitor: Updated user preferences with ${newSharedProjects.length} shared projects and updated active lists');
                
                // Activate calendars for the updated project order to update UI
                AppLogger.info('CalDAVMonitor: Starting calendar activation for updated project order');
                await _activateCalendarsFromProjectOrder(updatedPrefs);
                AppLogger.info('CalDAVMonitor: Calendar activation completed');
              },
              failure: (failure) async {
                AppLogger.error('CalDAVMonitor: Failed to update user preferences with shared projects: ${failure.message}');
              },
            );
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
  }

  /// Update calendar list for shared project changes
  Future<void> _updateCalendarListForSharedProjects(Set<String> addedProjects, Set<String> removedProjects) async {
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

      // Add new shared projects to calendar list
      if (addedProjects.isNotEmpty) {
        // Get active account to discover new calendars
        final accountResult = await _accountRepository.getActiveAccount();
        await accountResult.when(
          success: (account) async {
            if (account != null) {
              // Discover available calendars using CalDAV service
              final caldavService = CalDAVService(account: account);
              final capabilitiesResult = await caldavService.discoverCapabilities();

              await capabilitiesResult.when(
                success: (capabilities) async {
                  final availableCalendars = capabilities.taskCalendars;
                  
                  // Find and add calendars for new shared projects
                  for (final addedProjectPath in addedProjects) {
                    final matchingCalendar = availableCalendars
                        .where((cal) => cal.path == addedProjectPath)
                        .firstOrNull;
                    
                    if (matchingCalendar != null) {
                      AppLogger.info('CalDAVMonitor: Adding new shared project to calendar list: $addedProjectPath');
                      final saveResult = await _calendarRepository.save(matchingCalendar);
                      saveResult.when(
                        success: (_) => AppLogger.debug('CalDAVMonitor: Successfully added calendar $addedProjectPath'),
                        failure: (failure) => AppLogger.warning('CalDAVMonitor: Failed to add calendar $addedProjectPath: ${failure.message}'),
                      );
                    } else {
                      AppLogger.warning('CalDAVMonitor: Could not find calendar for new shared project: $addedProjectPath');
                    }
                  }
                },
                failure: (failure) async {
                  AppLogger.error('CalDAVMonitor: Failed to discover calendars for new shared projects: ${failure.message}');
                },
              );
            } else {
              AppLogger.warning('CalDAVMonitor: No active account available to discover new shared project calendars');
            }
          },
          failure: (failure) async {
            AppLogger.error('CalDAVMonitor: Failed to get active account for shared project calendar updates: ${failure.message}');
          },
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to update calendar list for shared projects', e, stackTrace);
    }
  }

  /// Activate calendars for the given project order
  Future<void> _activateCalendarsFromProjectOrder(UserPreferences prefs) async {
    try {
      AppLogger.info('CalDAVMonitor: Activating calendars for project order: ${prefs.projectOrder}');
      
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.warning('CalDAVMonitor: No active account to activate calendars');
            return;
          }

          AppLogger.info('CalDAVMonitor: Got active account, discovering capabilities');
          final caldavService = CalDAVService(account: account);
          final capabilitiesResult = await caldavService.discoverCapabilities();

          await capabilitiesResult.when(
            success: (capabilities) async {
              final availableCalendars = capabilities.taskCalendars;
              AppLogger.info('CalDAVMonitor: Discovered ${availableCalendars.length} available calendars');
              
              // Log all available calendars for debugging
              for (final calendar in availableCalendars) {
                AppLogger.debug('CalDAVMonitor: Available calendar: ${calendar.path} (${calendar.displayName})');
              }
              
              final projectOrder = prefs.projectOrder;
              AppLogger.info('CalDAVMonitor: Processing ${projectOrder.length} projects in project order');

              for (final projectId in projectOrder) {
                AppLogger.info('CalDAVMonitor: Looking for calendar for project: $projectId');
                
                // Try to find calendar by exact path match first
                var matchingCalendar = availableCalendars
                    .where((cal) => cal.path == projectId)
                    .firstOrNull;
                
                // If not found, try to find by UID (for shared projects)
                if (matchingCalendar == null) {
                  AppLogger.debug('CalDAVMonitor: No exact path match, trying UID match for: $projectId');
                  matchingCalendar = availableCalendars
                      .where((cal) => cal.uid == projectId)
                      .firstOrNull;
                }
                
                // If still not found, try to construct path from UID
                if (matchingCalendar == null) {
                  AppLogger.debug('CalDAVMonitor: No UID match, trying path construction for: $projectId');
                  final calendarHome = capabilities.calendarHome;
                  final constructedPath = '$calendarHome$projectId/';
                  AppLogger.debug('CalDAVMonitor: Constructed path: $constructedPath');
                  
                  matchingCalendar = availableCalendars
                      .where((cal) => cal.path == constructedPath)
                      .firstOrNull;
                }
                
                // If still not found, try to find by path containing the project ID
                if (matchingCalendar == null) {
                  AppLogger.debug('CalDAVMonitor: No constructed path match, trying path contains for: $projectId');
                  matchingCalendar = availableCalendars
                      .where((cal) => cal.path.contains(projectId))
                      .firstOrNull;
                }
                
                if (matchingCalendar != null) {
                  AppLogger.info('CalDAVMonitor: Found matching calendar for $projectId: ${matchingCalendar.displayName} (${matchingCalendar.path})');
                  final saveResult = await _calendarRepository.save(matchingCalendar);
                  saveResult.when(
                    success: (_) => AppLogger.info('CalDAVMonitor: Successfully activated calendar $projectId'),
                    failure: (failure) => AppLogger.warning('CalDAVMonitor: Failed to activate calendar $projectId: ${failure.message}'),
                  );
                } else {
                  AppLogger.warning('CalDAVMonitor: Could not find calendar to activate: $projectId');
                  AppLogger.debug('CalDAVMonitor: Available calendars: ${availableCalendars.map((c) => '${c.path} (${c.uid})').join(', ')}');
                }
              }
            },
            failure: (failure) async {
              AppLogger.error('CalDAVMonitor: Failed to discover capabilities for calendar activation: ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('CalDAVMonitor: Failed to get active account for calendar activation: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('CalDAVMonitor: Failed to activate calendars from project order', e, stackTrace);
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}