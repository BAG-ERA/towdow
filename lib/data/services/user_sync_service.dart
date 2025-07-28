// User sync service for S3 synchronization of user data
// Syncs user preferences and external calendar credentials to private S3 bucket
// Only works for cloud/self-hosted users (not custom CalDAV)

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/user_preferences.dart';
import '../models/shared_with_me_project.dart';
import '../models/external_caldav_account.dart';
import '../repositories/user_repository.dart';
import '../repositories/external_account_repository.dart';
import '../repositories/external_calendar_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/calendar_repository.dart';
import '../models/task_calendar.dart';
import '../models/external_calendar.dart';
import 'caldav_service.dart';
import 's3_storage_service.dart';
import 'share_service.dart';

/// Service for synchronizing user preferences and external credentials to S3
class UserSyncService {
  final UserRepository _userRepository;
  final ExternalAccountRepository _externalAccountRepository;
  final ExternalCalendarRepository _externalCalendarRepository;
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  
  Timer? _periodicWatcher;
  DateTime? _lastSyncTime;
  
  // Callback to notify when preferences are updated from server
  void Function()? _onPreferencesUpdated;
  
  UserSyncService({
    required UserRepository userRepository,
    required ExternalAccountRepository externalAccountRepository,
    required ExternalCalendarRepository externalCalendarRepository,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
  }) : _userRepository = userRepository,
       _externalAccountRepository = externalAccountRepository,
       _externalCalendarRepository = externalCalendarRepository,
       _accountRepository = accountRepository,
       _calendarRepository = calendarRepository;

  /// Check if user sync is available (only for cloud/self-hosted users)
  Future<bool> isSyncAvailable() async {
    final accountResult = await _accountRepository.getActiveAccount();
    return accountResult.when(
      success: (account) {
        if (account == null) return false;
        // Only sync for towdow_cloud provider (not custom CalDAV)
        return account.providerType == 'towdow_cloud';
      },
      failure: (_) => false,
    );
  }

  /// Fetch and update shared projects from server
  Future<Result<void>> updateSharedProjects({bool duringDownload = false}) async {
    try {
      AppLogger.info('UserSyncService: Updating shared projects from server');
      
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      final account = accountResult.when(
        success: (acc) => acc,
        failure: (_) => null,
      );

      if (account == null) {
        AppLogger.warning('UserSyncService: No active account available for shared projects update');
        return Result.failure(Failure(
          message: 'No active account available',
          exception: Exception('No account'),
        ));
      }

      // Check if account supports sharing
      final shareService = ShareService(account: account);
      if (!shareService.supportsSharing) {
        AppLogger.info('UserSyncService: Account does not support sharing, skipping shared projects update');
        return Result.success(null);
      }

      // Fetch shared projects from server
      final sharedProjectsResult = await shareService.getProjectsSharedWithMe();
      return await sharedProjectsResult.when(
        success: (sharedMembers) async {
          // Get current user preferences to preserve existing acknowledgments
          final currentPreferencesResult = await _userRepository.getUserPreferences();
          final currentAcknowledgments = <String, bool>{};
          
          await currentPreferencesResult.when(
            success: (currentPreferences) async {
              // Build map of existing acknowledgments
              for (final existingProject in currentPreferences.sharedWithMeProjects) {
                currentAcknowledgments[existingProject.projectId] = existingProject.ack;
              }
            },
            failure: (_) async {
              // If we can't get current preferences, continue with defaults
            },
          );

          // Convert to SharedWithMeProject objects, preserving acknowledgments
          final sharedProjects = sharedMembers.map((member) => 
            SharedWithMeProject.fromSharedProjectMember(
              projectPath: member.projectPath,
              allTasks: member.allTasks,
              projectRight: member.projectRight,
              sourceUserEmail: member.sourceUserEmail,
              ack: currentAcknowledgments[member.projectPath] ?? false, // Preserve existing ack or default to false
            )
          ).toList();

          // Update user repository with shared projects
          final updateResult = duringDownload 
              ? await _userRepository.updateSharedWithMeProjectsWithoutSync(sharedProjects)
              : await _userRepository.updateSharedWithMeProjects(sharedProjects);
          return await updateResult.when(
            success: (_) async {
              AppLogger.info('UserSyncService: Successfully updated ${sharedProjects.length} shared projects');
              
              // If this is during download, also add new shared projects to active synced list
              if (duringDownload) {
                await _addSharedProjectsToActiveList(sharedProjects);
              }
              
              return Result.success(null);
            },
            failure: (failure) async {
              AppLogger.error('UserSyncService: Failed to save shared projects: ${failure.message}');
              return Result.failure(failure);
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('UserSyncService: Failed to fetch shared projects: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Exception updating shared projects', e, stackTrace);
      return Result.failure(Failure(
        message: 'Exception updating shared projects: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Activate calendars from downloaded project order
  Future<void> _activateCalendarsFromProjectOrder(UserPreferences preferences) async {
    if (preferences.projectOrder.isEmpty) {
      AppLogger.info('UserSyncService: No projects in project order to activate');
      return;
    }

    try {
      // Get active account to discover calendars
      final accountResult = await _accountRepository.getActiveAccount();
      final account = accountResult.when(
        success: (acc) => acc,
        failure: (_) => null,
      );

      if (account == null) {
        AppLogger.warning('UserSyncService: No active account available for calendar activation');
        return;
      }

      // Discover available calendars using CalDAV service
      final caldavService = CalDAVService(account: account);
      final capabilitiesResult = await caldavService.discoverCapabilities();

      await capabilitiesResult.when(
        success: (capabilities) async {
          final availableCalendars = capabilities.taskCalendars;
          AppLogger.info('UserSyncService: Discovered ${availableCalendars.length} available calendars');

          // Filter calendars that match project order paths
          final calendarsToActivate = <TaskCalendar>[];
          for (final projectPath in preferences.projectOrder) {
            final matchingCalendar = availableCalendars
                .where((cal) => cal.path == projectPath)
                .firstOrNull;
            
            if (matchingCalendar != null) {
              calendarsToActivate.add(matchingCalendar);
            } else {
              AppLogger.warning('UserSyncService: Calendar not found for project path: $projectPath');
            }
          }

          // Clear existing calendars by getting all and deleting them
          final existingCalendarsResult = await _calendarRepository.getAll();
          await existingCalendarsResult.when(
            success: (existingCalendars) async {
              // Delete existing calendars
              for (final calendar in existingCalendars) {
                await _calendarRepository.delete(calendar.path);
              }
              AppLogger.info('UserSyncService: Cleared ${existingCalendars.length} existing calendars');
              
              // Save each activated calendar
              for (final calendar in calendarsToActivate) {
                final saveResult = await _calendarRepository.save(calendar);
                await saveResult.when(
                  success: (_) {
                    AppLogger.info('UserSyncService: Activated calendar: ${calendar.displayName} (${calendar.path})');
                  },
                  failure: (failure) {
                    AppLogger.error('UserSyncService: Failed to save calendar ${calendar.path}: ${failure.message}');
                  },
                );
              }
              
              AppLogger.info('UserSyncService: Successfully activated ${calendarsToActivate.length} calendars from project order');
            },
            failure: (failure) {
              AppLogger.error('UserSyncService: Failed to get existing calendars for clearing: ${failure.message}');
            },
          );
        },
        failure: (failure) {
          AppLogger.error('UserSyncService: Failed to discover calendars: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Error activating calendars from project order', e, stackTrace);
    }
  }

  /// Generate user-specific S3 path for preferences
  String _getUserPreferencesPath(S3StorageService s3Service) {
    return '${s3Service.getUserPrefix()}preferences.json';
  }

  /// Generate user-specific S3 path for external credentials
  String _getExternalCredentialsPath(S3StorageService s3Service) {
    return '${s3Service.getUserPrefix()}external_credentials.json';
  }

  /// Upload user preferences and external credentials to S3
  Future<Result<void>> uploadUserData() async {
    try {
      AppLogger.info('UserSyncService: Starting user data upload');
      
      // Check if sync is available
      if (!await isSyncAvailable()) {
        return Result.failure(Failure(
          message: 'User sync not available for this account type',
          exception: Exception('Sync not available'),
        ));
      }

      // Get active account for S3 access
      final accountResult = await _accountRepository.getActiveAccount();
      final account = accountResult.when(
        success: (acc) => acc,
        failure: (_) => null,
      );

      if (account == null) {
        return Result.failure(Failure(
          message: 'No active account for S3 sync',
          exception: Exception('No account'),
        ));
      }

      // Get S3 storage service
      final s3Service = S3StorageService(account: account);

      // Upload user preferences
      final preferencesResult = await _uploadUserPreferences(s3Service);
      if (preferencesResult is Error<void>) {
        return preferencesResult;
      }

      // Upload external credentials
      final credentialsResult = await _uploadExternalCredentials(s3Service);
      if (credentialsResult is Error<void>) {
        return credentialsResult;
      }

      _lastSyncTime = DateTime.now();
      return Result.success(null);

    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Failed to upload user data', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to upload user data: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Download user preferences and external credentials from S3
  Future<Result<bool>> downloadUserData() async {
    try {
      AppLogger.info('UserSyncService: Starting user data download');
      
      // Check if sync is available
      if (!await isSyncAvailable()) {
        AppLogger.info('UserSyncService: Sync not available for this account type');
        return Result.success(false);
      }

      // Note: Shared projects update removed from download to keep downloads read-only
      // Shared projects should be updated through separate sync operations, not during download

      // Get active account for S3 access
      final accountResult = await _accountRepository.getActiveAccount();
      final account = accountResult.when(
        success: (acc) => acc,
        failure: (_) => null,
      );

      if (account == null) {
        return Result.failure(Failure(
          message: 'No active account available',
          exception: Exception('No account'),
        ));
      }

      // Get S3 storage service
      final s3Service = S3StorageService(account: account);

      bool hasData = false;

      // Download user preferences
      final preferencesResult = await _downloadUserPreferences(s3Service);
      final preferencesDownloaded = preferencesResult.when(
        success: (downloaded) => downloaded,
        failure: (failure) {
          AppLogger.warning('UserSyncService: Failed to download preferences: ${failure.message}');
          return false;
        },
      );

      // Download external credentials
      final credentialsResult = await _downloadExternalCredentials(s3Service);
      final credentialsDownloaded = credentialsResult.when(
        success: (downloaded) => downloaded,
        failure: (failure) {
          AppLogger.warning('UserSyncService: Failed to download credentials: ${failure.message}');
          return false;
        },
      );

      hasData = preferencesDownloaded || credentialsDownloaded;
      
      if (hasData) {
        _lastSyncTime = DateTime.now();
        AppLogger.info('UserSyncService: User data download completed successfully');
      } else {
        AppLogger.info('UserSyncService: No user data found on server');
      }

      return Result.success(hasData);

    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Failed to download user data', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to download user data: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Start periodic watcher for file updates
  void startPeriodicSync({Duration interval = const Duration(hours: 1)}) {
    _periodicWatcher?.cancel();
    _periodicWatcher = Timer.periodic(interval, (_) async {
      final result = await downloadUserData();
      result.when(
        success: (hasUpdates) {
          if (hasUpdates) {
            AppLogger.info('UserSyncService: Periodic sync found updates');
          }
        },
        failure: (failure) {
          AppLogger.warning('UserSyncService: Periodic sync failed: ${failure.message}');
        },
      );
    });
    AppLogger.info('UserSyncService: Started periodic sync (every ${interval.inHours} hours)');
  }

  /// Stop periodic watcher
  void stopPeriodicSync() {
    _periodicWatcher?.cancel();
    _periodicWatcher = null;
    AppLogger.info('UserSyncService: Stopped periodic sync');
  }

  /// Upload user preferences to S3
  Future<Result<void>> _uploadUserPreferences(S3StorageService s3Service) async {
    try {
      final preferencesResult = await _userRepository.getUserPreferences();
      return await preferencesResult.when(
        success: (preferences) async {
          final data = _serializeUserPreferences(preferences);
          final dataBytes = Uint8List.fromList(utf8.encode(data));
          
          return await s3Service.uploadFile(
            key: _getUserPreferencesPath(s3Service),
            data: dataBytes,
            isPrivate: true, // User preferences are always private
            symmetricKey: 'dummy-key', // TODO: Use proper encryption key when encryption is implemented
            contentType: 'application/json',
            skipEncryption: true, // Skip encryption for user preferences
          );
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Failed to upload user preferences', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to upload user preferences: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Download user preferences from S3
  Future<Result<bool>> _downloadUserPreferences(S3StorageService s3Service) async {
    try {
      final downloadResult = await s3Service.downloadFile(
        key: _getUserPreferencesPath(s3Service),
        isPrivate: true,
        symmetricKey: 'dummy-key', // TODO: Use proper encryption key when encryption is implemented
        skipDecryption: true, // Skip decryption for user preferences
      );
      return await downloadResult.when(
        success: (data) async {
          try {
            final jsonString = utf8.decode(data);
            final preferences = _deserializeUserPreferences(jsonString);
            
            // Get the current etag from S3 after successful download
            final etagResult = await s3Service.getCurrentEtag(
              key: _getUserPreferencesPath(s3Service),
              isPrivate: true,
            );
            final currentEtag = etagResult.when(
              success: (etag) => etag,
              failure: (_) => null,
            );
            
            AppLogger.debug('UserSyncService: Downloaded preferences with ETag: $currentEtag');
            
            // Save preferences with the current etag to avoid sync loops
            final preferencesWithEtag = preferences.copyWith(etag: currentEtag);
            final saveResult = await _userRepository.saveUserPreferencesWithoutSync(preferencesWithEtag);
            
            AppLogger.debug('UserSyncService: Save result: ${saveResult.when(success: (_) => 'success', failure: (f) => 'failure: ${f.message}')}');
            
            // Verify the ETag was saved correctly
            final verifyEtagResult = await _userRepository.getEtag();
            final savedEtag = verifyEtagResult.when(
              success: (etag) => etag,
              failure: (_) => null,
            );
            AppLogger.debug('UserSyncService: Verified saved ETag: $savedEtag');
            
            // Activate calendars for the downloaded project order to update UI
            await _activateCalendarsFromProjectOrder(preferencesWithEtag);
            
            // Notify that preferences have been updated
            if (_onPreferencesUpdated != null) {
              AppLogger.debug('UserSyncService: Notifying preferences update - callback available');
              _onPreferencesUpdated!();
              AppLogger.debug('UserSyncService: Preferences update notification sent');
            } else {
              AppLogger.warning('UserSyncService: Preferences updated but no callback set');
            }
            
            // Note: Calendar activation is not done during download to keep downloads read-only
            // Calendar activation should happen through user actions or separate sync operations
            
            AppLogger.info('UserSyncService: Downloaded and saved user preferences with ${preferences.projectOrder.length} active projects and etag: $currentEtag');
            return Result.success(true);
          } catch (e, stackTrace) {
            AppLogger.error('UserSyncService: Failed to parse downloaded preferences', e, stackTrace);
            return Result.failure(Failure(
              message: 'Failed to parse user preferences: $e',
              exception: e is Exception ? e : Exception(e.toString()),
              stackTrace: stackTrace,
            ));
          }
        },
        failure: (failure) async {
          // File not found is not an error
          if (failure.message.contains('NoSuchKey') || failure.message.contains('not found')) {
            AppLogger.info('UserSyncService: No user preferences found on server');
            return Result.success(false);
          }
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Failed to download user preferences', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to download user preferences: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Upload external credentials to S3
  Future<Result<void>> _uploadExternalCredentials(S3StorageService s3Service) async {
    try {
      final accountsResult = await _externalAccountRepository.getAll();
      final calendarsResult = await _externalCalendarRepository.getAll();
      
      return await accountsResult.when(
        success: (accounts) async {
          return await calendarsResult.when(
            success: (calendars) async {
              final data = _serializeExternalCredentials(accounts, calendars);
              final dataBytes = Uint8List.fromList(utf8.encode(data));
              
              return await s3Service.uploadFile(
                key: _getExternalCredentialsPath(s3Service),
                data: dataBytes,
                isPrivate: true, // External credentials are always private
                symmetricKey: 'dummy-key', // TODO: Use proper encryption key when encryption is implemented
                contentType: 'application/json',
              );
            },
            failure: (failure) async => Result.failure(failure),
          );
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Failed to upload external credentials', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to upload external credentials: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Download external credentials from S3
  Future<Result<bool>> _downloadExternalCredentials(S3StorageService s3Service) async {
    try {
      final downloadResult = await s3Service.downloadFile(
        key: _getExternalCredentialsPath(s3Service),
        isPrivate: true,
        symmetricKey: 'dummy-key', // TODO: Use proper encryption key when encryption is implemented
      );
      return await downloadResult.when(
        success: (data) async {
          try {
            final jsonString = utf8.decode(data);
            final (accounts, calendars) = _deserializeExternalCredentials(jsonString);
            
            // Get the current etag from S3 after successful download
            final etagResult = await s3Service.getCurrentEtag(
              key: _getExternalCredentialsPath(s3Service),
              isPrivate: true,
            );
            final currentEtag = etagResult.when(
              success: (etag) => etag,
              failure: (_) => null,
            );
            
            // Save each account (no longer need to save individual etags)
            for (final account in accounts) {
              await _externalAccountRepository.save(account);
            }
            
            // Save each calendar
            for (final calendar in calendars) {
              await _externalCalendarRepository.save(calendar);
            }
            
            // Save the global credentials file etag
            if (currentEtag != null) {
              await _externalAccountRepository.setCredentialsFileEtag(currentEtag);
            }
            
            AppLogger.info('UserSyncService: Downloaded and saved ${accounts.length} external accounts and ${calendars.length} calendars with etag: $currentEtag');
            return Result.success(true);
          } catch (e, stackTrace) {
            AppLogger.error('UserSyncService: Failed to parse downloaded credentials', e, stackTrace);
            return Result.failure(Failure(
              message: 'Failed to parse external credentials: $e',
              exception: e is Exception ? e : Exception(e.toString()),
              stackTrace: stackTrace,
            ));
          }
        },
        failure: (failure) async {
          // File not found is not an error
          if (failure.message.contains('NoSuchKey') || failure.message.contains('not found')) {
            AppLogger.info('UserSyncService: No external credentials found on server');
            return Result.success(false);
          }
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('UserSyncService: Failed to download external credentials', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to download external credentials: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Serialize user preferences to JSON
  String _serializeUserPreferences(UserPreferences preferences) {
    final json = {
      'version': 1,
      'lastUpdated': DateTime.now().toIso8601String(),
      'projectOrder': preferences.projectOrder,
      'preferredTheme': preferences.preferredTheme,
      'enableNotifications': preferences.enableNotifications,
      'defaultProjectView': preferences.defaultProjectView,
      'customSettings': preferences.customSettings,
      'syncedProjects': preferences.syncedProjects,
      'sharedWithMeProjects': preferences.sharedWithMeProjects.map((project) => {
        'projectId': project.projectId,
        'allTasks': project.allTasks,
        'projectRight': project.projectRight,
        'sourceUserEmail': project.sourceUserEmail,
        'ack': project.ack,
      }).toList(),
    };
    return jsonEncode(json);
  }

  /// Deserialize user preferences from JSON
  UserPreferences _deserializeUserPreferences(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    
    // Handle shared projects deserialization
    final sharedProjectsJson = json['sharedWithMeProjects'] as List<dynamic>? ?? [];
    final sharedProjects = sharedProjectsJson.map((projectJson) {
      final projectMap = projectJson as Map<String, dynamic>;
      return SharedWithMeProject(
        projectId: projectMap['projectId'] as String,
        allTasks: projectMap['allTasks'] as bool,
        projectRight: projectMap['projectRight'] as String,
        sourceUserEmail: projectMap['sourceUserEmail'] as String,
        ack: projectMap['ack'] as bool? ?? false,
      );
    }).toList();
    
    return UserPreferences(
      projectOrder: (json['projectOrder'] as List<dynamic>?)?.cast<String>() ?? [],
      preferredTheme: json['preferredTheme'] as String?,
      enableNotifications: json['enableNotifications'] as bool?,
      defaultProjectView: json['defaultProjectView'] as String?,
      customSettings: json['customSettings'] as Map<String, dynamic>?,
      syncedProjects: (json['syncedProjects'] as List<dynamic>?)?.cast<String>() ?? [],
      sharedWithMeProjects: sharedProjects,
    );
  }

  /// Serialize external credentials to JSON
  String _serializeExternalCredentials(List<ExternalCaldavAccount> accounts, List<ExternalCalendar> calendars) {
    final json = {
      'version': 1,
      'lastUpdated': DateTime.now().toIso8601String(),
      'accounts': accounts.map((account) => account.toJson()).toList(),
      'calendars': calendars.map((calendar) => calendar.toJson()).toList(),
    };
    return jsonEncode(json);
  }

  /// Deserialize external credentials from JSON
  (List<ExternalCaldavAccount>, List<ExternalCalendar>) _deserializeExternalCredentials(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final accountsJson = json['accounts'] as List<dynamic>? ?? [];
    final calendarsJson = json['calendars'] as List<dynamic>? ?? [];
    
    final accounts = accountsJson
        .map((account) => ExternalCaldavAccount.fromJson(account as Map<String, dynamic>))
        .toList();
        
    final calendars = calendarsJson
        .map((calendar) => ExternalCalendar.fromJson(calendar as Map<String, dynamic>))
        .toList();
        
    return (accounts, calendars);
  }

  /// Add new shared projects to the active synced list
  Future<void> _addSharedProjectsToActiveList(List<SharedWithMeProject> newSharedProjects) async {
    final currentPreferencesResult = await _userRepository.getUserPreferences();
    final currentPreferences = currentPreferencesResult.when(
      success: (prefs) => prefs,
      failure: (_) => UserPreferences.defaultPreferences(),
    );

    // Add new shared projects to active synced list (project order and synced projects)
    final updatedProjectOrder = [...currentPreferences.projectOrder];
    final updatedSyncedProjects = [...currentPreferences.syncedProjects];
    
    for (final newProject in newSharedProjects) {
      // Add to project order if not already there
      if (!updatedProjectOrder.contains(newProject.projectId)) {
        updatedProjectOrder.add(newProject.projectId);
        AppLogger.info('UserSyncService: Added shared project ${newProject.projectId} to active synced list');
      }
      
      // Add to synced projects if not already there
      if (!updatedSyncedProjects.contains(newProject.projectId)) {
        updatedSyncedProjects.add(newProject.projectId);
        AppLogger.info('UserSyncService: Added shared project ${newProject.projectId} to synced projects list');
      }
    }
    
    final updatedPreferences = currentPreferences.copyWith(
      projectOrder: updatedProjectOrder,
      syncedProjects: updatedSyncedProjects,
    );
    
    await _userRepository.saveUserPreferencesWithoutSync(updatedPreferences);
    AppLogger.info('UserSyncService: Added ${newSharedProjects.length} new shared projects to active synced list');
    
    // Activate calendars for the updated project order to update UI
    await _activateCalendarsFromProjectOrder(updatedPreferences);
  }

  /// Set callback to be called when preferences are updated from server
  void setPreferencesUpdateCallback(void Function() callback) {
    AppLogger.debug('UserSyncService: Setting preferences update callback');
    _onPreferencesUpdated = callback;
    AppLogger.debug('UserSyncService: Preferences update callback set successfully');
  }

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
  }
} 