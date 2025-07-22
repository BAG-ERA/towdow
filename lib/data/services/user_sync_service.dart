// User sync service for S3 synchronization of user data
// Syncs user preferences and external calendar credentials to private S3 bucket
// Only works for cloud/self-hosted users (not custom CalDAV)

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/user_preferences.dart';
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

/// Service for synchronizing user preferences and external credentials to S3
class UserSyncService {
  final UserRepository _userRepository;
  final ExternalAccountRepository _externalAccountRepository;
  final ExternalCalendarRepository _externalCalendarRepository;
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  
  Timer? _periodicWatcher;
  DateTime? _lastSyncTime;
  
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
          message: 'No active account available',
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
      AppLogger.info('UserSyncService: User data upload completed successfully');
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
      );
      return await downloadResult.when(
        success: (data) async {
          try {
            final jsonString = utf8.decode(data);
            final preferences = _deserializeUserPreferences(jsonString);
            await _userRepository.saveUserPreferences(preferences);
            
            // Activate calendars from project order
            await _activateCalendarsFromProjectOrder(preferences);
            
            AppLogger.info('UserSyncService: Downloaded and saved user preferences with ${preferences.projectOrder.length} active projects');
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
            
            // Save each account
            for (final account in accounts) {
              await _externalAccountRepository.save(account);
            }
            
            // Save each calendar
            for (final calendar in calendars) {
              await _externalCalendarRepository.save(calendar);
            }
            
            AppLogger.info('UserSyncService: Downloaded and saved ${accounts.length} external accounts and ${calendars.length} calendars');
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
    };
    return jsonEncode(json);
  }

  /// Deserialize user preferences from JSON
  UserPreferences _deserializeUserPreferences(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return UserPreferences(
      projectOrder: (json['projectOrder'] as List<dynamic>?)?.cast<String>() ?? [],
      preferredTheme: json['preferredTheme'] as String?,
      enableNotifications: json['enableNotifications'] as bool?,
      defaultProjectView: json['defaultProjectView'] as String?,
      customSettings: json['customSettings'] as Map<String, dynamic>?,
      syncedProjects: (json['syncedProjects'] as List<dynamic>?)?.cast<String>() ?? [],
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

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
  }
} 