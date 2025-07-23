// CalDAV Monitor for detecting changes in calendars
// Monitors sync tokens and ETags to detect changes that need synchronization
// Delegates actual sync operations to SyncService

import 'dart:async';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/task_calendar.dart';
import '../models/shared_with_me_project.dart';
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

  // Dynamic interval configuration
  static const Duration _minInterval = Duration(seconds: 1);
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
  })  : _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _userRepository = userRepository,
        _externalAccountRepository = externalAccountRepository,
        _externalCalendarRepository = externalCalendarRepository,
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

              // Check user preferences for changes
              final userPrefsChanges = await _checkUserPreferencesChanges(account);
              if (userPrefsChanges) {
                changesDetected = true;
                AppLogger.debug('CalDAVMonitor: Changes detected for user preferences');
              }

              // Check external accounts for changes
              final externalAccountChanges = await _checkExternalAccountChanges(account);
              if (externalAccountChanges) {
                changesDetected = true;
                AppLogger.debug('CalDAVMonitor: Changes detected for external accounts');
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
                
                // Create UserSyncService and trigger download
                final userSyncService = UserSyncService(
                  userRepository: _userRepository,
                  externalAccountRepository: _externalAccountRepository,
                  externalCalendarRepository: _externalCalendarRepository,
                  accountRepository: _accountRepository,
                  calendarRepository: _calendarRepository,
                );
                
                final downloadResult = await userSyncService.downloadUserData();
                await downloadResult.when(
                  success: (hasData) async {
                    if (hasData) {
                      AppLogger.info('CalDAVMonitor: Successfully downloaded updated user preferences');
                      // Update local etag to match remote
                      if (remoteEtag != null) {
                        await _userRepository.setEtag(remoteEtag);
                      }
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
                // Still update the etag to avoid repeated checks
                if (remoteEtag != null) {
                  await _userRepository.setEtag(remoteEtag);
                }
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
      
      // Get all external accounts
      final accountsResult = await _externalAccountRepository.getActiveAccounts();
      await accountsResult.when(
        success: (accounts) async {
          final s3Service = S3StorageService(account: account);
          final userPrefix = s3Service.getUserPrefix();
          
          // Check external credentials file
          final credentialsKey = '${userPrefix}external_credentials.json';
          final remoteEtagResult = await s3Service.getCurrentEtag(key: credentialsKey, isPrivate: true);
          
          await remoteEtagResult.when(
            success: (remoteEtag) async {
              // For external accounts, we check if any local account etag differs from remote
              // Since they're stored together, we use a simple approach
              bool shouldSync = false;
              
              if (accounts.isEmpty && remoteEtag != null) {
                // No local accounts but remote file exists - should download
                shouldSync = true;
                AppLogger.info('CalDAVMonitor: No local external accounts but remote file exists, should download');
              } else {
                // Check if any local account has different or missing etag
                for (final externalAccount in accounts) {
                  final localEtagResult = await _externalAccountRepository.getEtag(externalAccount.id);
                  final localEtag = localEtagResult.when(
                    success: (etag) => etag,
                    failure: (_) => null,
                  );
                  
                  if (localEtag != remoteEtag) {
                    shouldSync = true;
                    AppLogger.debug('CalDAVMonitor: External account ${externalAccount.id} etag differs (local: $localEtag, remote: $remoteEtag)');
                    break;
                  }
                }
              }
              
              if (shouldSync) {
                AppLogger.info('CalDAVMonitor: External credentials etags differ, triggering download');
                
                // Get file info for conflict resolution
                final fileInfoResult = await s3Service.getFileInfo(key: credentialsKey, isPrivate: true);
                await fileInfoResult.when(
                  success: (fileInfo) async {
                    AppLogger.debug('CalDAVMonitor: Remote credentials file last modified: ${fileInfo.lastModified}');
                    
                    // Create UserSyncService and trigger download
                    final userSyncService = UserSyncService(
                      userRepository: _userRepository,
                      externalAccountRepository: _externalAccountRepository,
                      externalCalendarRepository: _externalCalendarRepository,
                      accountRepository: _accountRepository,
                      calendarRepository: _calendarRepository,
                    );
                    
                    final downloadResult = await userSyncService.downloadUserData();
                    await downloadResult.when(
                      success: (hasData) async {
                        if (hasData) {
                          AppLogger.info('CalDAVMonitor: Successfully downloaded updated external credentials');
                          // Update all local accounts with the new etag
                          final updatedAccountsResult = await _externalAccountRepository.getAll();
                          await updatedAccountsResult.when(
                            success: (updatedAccounts) async {
                              for (final updatedAccount in updatedAccounts) {
                                if (remoteEtag != null) {
                                  await _externalAccountRepository.setEtag(updatedAccount.id, remoteEtag);
                                }
                              }
                            },
                            failure: (_) async {
                              AppLogger.warning('CalDAVMonitor: Could not update etags for external accounts after sync');
                            },
                          );
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
                    // Still update etags to avoid repeated checks
                    for (final externalAccount in accounts) {
                      if (remoteEtag != null) {
                        await _externalAccountRepository.setEtag(externalAccount.id, remoteEtag);
                      }
                    }
                  },
                );
                
                anyChanges = true;
              }
            },
            failure: (failure) async {
              AppLogger.warning('CalDAVMonitor: Could not get remote etag for external credentials: ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.warning('CalDAVMonitor: Could not get external accounts: ${failure.message}');
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
          // Convert server members to SharedWithMeProject, preserving acknowledgments
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
              ack: currentAcknowledgments[member.projectPath] ?? false,
            )
          ).toList();

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
                final updatedPrefs = prefs.copyWith(sharedWithMeProjects: newSharedProjects);
                await _userRepository.saveUserPreferences(updatedPrefs);
                AppLogger.info('CalDAVMonitor: Updated user preferences with ${newSharedProjects.length} shared projects');
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
                        .where((cal) => cal.uid == addedProjectPath)
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

  /// Dispose resources
  void dispose() {
    stop();
  }
} 