// Background sync service for incremental CalDAV synchronization using sync tokens
// Implements RFC 6578 for WebDAV Sync and RFC 4791 for CalDAV sync-collection reports
// Provides optimistic, offline-first sync every 10 seconds with intelligent etag comparison

import 'dart:async';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/caldav_account.dart';
import '../models/task_calendar.dart';
import '../repositories/task_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/calendar_repository.dart';
import 'caldav_service.dart';
import 'webdav_client.dart';
import 'parsers/vtodo_parser.dart';
import 'parsers/xml_response_parser.dart';

class BackgroundSyncService {
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;

  Timer? _syncTimer;
  bool _isRunning = false;
  bool _isSyncing = false;

  // Configuration
  static const Duration syncInterval = Duration(seconds: 10);
  static const String syncTokenPrefix = 'data:,';

  BackgroundSyncService({
    required TaskRepository taskRepository,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
  })  : _taskRepository = taskRepository,
        _accountRepository = accountRepository,
        _calendarRepository = calendarRepository;

  /// Start background sync service
  Future<Result<void>> start() async {
    if (_isRunning) {
      // AppLogger.debug('BackgroundSyncService: Already running');
      return const Result.success(null);
    }

    try {
      // AppLogger.info('BackgroundSyncService: Starting background sync service (every ${syncInterval.inSeconds}s)');
      _isRunning = true;
      
      // Start periodic sync
      _syncTimer = Timer.periodic(syncInterval, (_) {
        _performBackgroundSync();
      });
      
      // Perform initial sync
      await _performBackgroundSync();
      
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Failed to start', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to start background sync service: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Stop background sync service
  void stop() {
    if (!_isRunning) return;
    
    _syncTimer?.cancel();
    _syncTimer = null;
    _isRunning = false;
    
    // AppLogger.info('BackgroundSyncService: Stopped background sync service');
  }

  /// Perform background sync for all calendars
  Future<void> _performBackgroundSync() async {
    if (_isSyncing) {
      // AppLogger.debug('BackgroundSyncService: Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    
    try {
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            // AppLogger.debug('BackgroundSyncService: No active account, skipping sync');
            return;
          }

          // Get all calendars to sync
          final calendarsResult = await _calendarRepository.getProjectCalendars();
          await calendarsResult.when(
            success: (calendars) async {
              for (final calendar in calendars) {
                await _syncCalendar(account, calendar);
              }
            },
            failure: (failure) async {
              AppLogger.error('BackgroundSyncService: Failed to get calendars', failure.exception, failure.stackTrace);
            },
          );
        },
        failure: (failure) async {
          // AppLogger.debug('BackgroundSyncService: No active account available');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Background sync failed', e, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single calendar using sync tokens if available
  Future<void> _syncCalendar(CaldavAccount account, TaskCalendar calendar) async {
    try {
      // AppLogger.debug('BackgroundSyncService: Syncing calendar ${calendar.path}');
      
      final webdavClient = WebDAVClient(
        serverUrl: account.serverUrl,
        username: account.username,
        password: account.password ?? '',
      );

      if (calendar.syncToken == null) {
        // First sync or calendar without sync token - perform full sync
        await _performFullSync(webdavClient, account, calendar);
      } else {
        // Incremental sync using sync token
        await _performIncrementalSync(webdavClient, account, calendar);
      }
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Failed to sync calendar ${calendar.path}', e, stackTrace);
    }
  }

  /// Perform full sync and get initial sync token
  Future<void> _performFullSync(WebDAVClient webdavClient, CaldavAccount account, TaskCalendar calendar) async {
    try {
      // AppLogger.info('BackgroundSyncService: Performing full sync for ${calendar.path}');
      
      // Create CalDAV service for this account
      final caldavService = CalDAVService(account: account);
      
      // Fetch all tasks using existing fetchTasks method
      final tasksResult = await caldavService.fetchTasks(calendarPath: calendar.path);
      await tasksResult.when(
        success: (remoteTasks) async {
          // Save all remote tasks to local storage
          for (final task in remoteTasks) {
            final taskWithCalendar = task.copyWith(sourceCalendarUid: calendar.uid);
            await _taskRepository.save(taskWithCalendar);
          }
          
          // Get the current sync token
          final syncTokenResult = await _getCurrentSyncToken(webdavClient, calendar.path);
          await syncTokenResult.when(
            success: (syncToken) async {
              // Update calendar with sync token
              final updatedCalendar = calendar.copyWith(
                syncToken: syncToken,
                lastSyncAt: DateTime.now(),
              );
              await _calendarRepository.save(updatedCalendar);
              
              // AppLogger.info('BackgroundSyncService: Full sync completed for ${calendar.path} - ${remoteTasks.length} tasks, sync token: $syncToken');
            },
            failure: (failure) async {
              AppLogger.warning('BackgroundSyncService: Could not get sync token for ${calendar.path}: ${failure.message}');
              // Update without sync token
              final updatedCalendar = calendar.copyWith(lastSyncAt: DateTime.now());
              await _calendarRepository.save(updatedCalendar);
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('BackgroundSyncService: Failed to fetch tasks during full sync', failure.exception, failure.stackTrace);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Full sync failed for ${calendar.path}', e, stackTrace);
    }
  }

  /// Perform incremental sync using sync token
  Future<void> _performIncrementalSync(WebDAVClient webdavClient, CaldavAccount account, TaskCalendar calendar) async {
    try {
      // AppLogger.debug('BackgroundSyncService: Performing incremental sync for ${calendar.path} with token ${calendar.syncToken}');
      
      // Get changes since last sync using REPORT sync-collection
      final changesResult = await _getSyncChanges(webdavClient, calendar.path, calendar.syncToken!);
      await changesResult.when(
        success: (result) async {
          final changes = result['changes'] as List<SyncChange>;
          final newSyncToken = result['syncToken'] as String?;
          
          if (changes.isEmpty) {
            // AppLogger.debug('BackgroundSyncService: No changes detected for ${calendar.path}');
          } else {
            // AppLogger.info('BackgroundSyncService: Processing ${changes.length} changes for ${calendar.path}');
            
            // Process each change
            for (final change in changes) {
              await _processChange(webdavClient, account, calendar, change);
            }
          }
          
          // Update calendar with new sync token if available
          if (newSyncToken != null && newSyncToken != calendar.syncToken) {
            final updatedCalendar = calendar.copyWith(
              syncToken: newSyncToken,
              lastSyncAt: DateTime.now(),
            );
            await _calendarRepository.save(updatedCalendar);
            // AppLogger.debug('BackgroundSyncService: Updated sync token for ${calendar.path}: $newSyncToken');
          }
        },
        failure: (failure) async {
          AppLogger.warning('BackgroundSyncService: Incremental sync failed for ${calendar.path}, falling back to full sync: ${failure.message}');
          // Fallback to full sync if incremental sync fails
          await _performFullSync(webdavClient, account, calendar);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Incremental sync failed for ${calendar.path}', e, stackTrace);
    }
  }

  /// Get current sync token for a calendar using PROPFIND
  Future<Result<String>> _getCurrentSyncToken(WebDAVClient webdavClient, String calendarPath) async {
    try {
      final propfindBody = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:sync-token />
  </D:prop>
</D:propfind>''';

      final result = await webdavClient.propfind(calendarPath, body: propfindBody, depth: 0);
      return await result.when(
        success: (response) async {
          if (response.statusCode == 207) {
            final syncToken = _extractSyncTokenFromPropfind(response.body);
            if (syncToken != null) {
              return Result.success(syncToken);
            } else {
              return Result.failure(Failure(
                message: 'No sync token found in response',
                exception: Exception('Missing sync token'),
              ));
            }
          } else {
            return Result.failure(Failure(
              message: 'PROPFIND failed with status ${response.statusCode}',
              exception: Exception('HTTP ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      return Result.failure(Failure(
        message: 'Failed to get sync token: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Get changes using REPORT sync-collection (RFC 6578)
  Future<Result<Map<String, dynamic>>> _getSyncChanges(WebDAVClient webdavClient, String calendarPath, String syncToken) async {
    try {
      final reportBody = '''<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:sync-token>$syncToken</D:sync-token>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getetag />
    <C:calendar-data />
  </D:prop>
</D:sync-collection>''';

      final result = await webdavClient.report(calendarPath, reportBody);
      return await result.when(
        success: (response) async {
          if (response.statusCode == 207) {
            final parsedResult = _parseSyncCollectionResponse(response.body);
            return Result.success(parsedResult);
          } else {
            return Result.failure(Failure(
              message: 'REPORT sync-collection failed with status ${response.statusCode}',
              exception: Exception('HTTP ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      return Result.failure(Failure(
        message: 'Failed to get sync changes: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Process a single sync change
  Future<void> _processChange(WebDAVClient webdavClient, CaldavAccount account, TaskCalendar calendar, SyncChange change) async {
    try {
      switch (change.type) {
        case SyncChangeType.deleted:
          // Find task by href and delete from local storage
          await _deleteTaskByHref(change.href, calendar.uid);
          // AppLogger.debug('BackgroundSyncService: Deleted task ${change.href}');
          break;
          
        case SyncChangeType.created:
        case SyncChangeType.updated:
          if (change.vtodoContent != null) {
            // Parse task from VTODO content
            final task = VTODOParser.parseVTODOFromCalendarData(change.vtodoContent!);
            if (task != null) {
              // Check if we already have this task locally
              final localTaskResult = await _taskRepository.getById(task.uid);
              await localTaskResult.when(
                success: (localTask) async {
                  if (localTask == null) {
                    // New task - save with calendar UID
                    final taskWithCalendar = task.copyWith(sourceCalendarUid: calendar.uid);
                    await _taskRepository.save(taskWithCalendar);
                    // AppLogger.debug('BackgroundSyncService: Created task ${task.uid}');
                  } else {
                    // Check if remote task is newer than local
                    if (task.lastModified.isAfter(localTask.lastModified)) {
                      // Update local task
                      final taskWithCalendar = task.copyWith(sourceCalendarUid: calendar.uid);
                      await _taskRepository.save(taskWithCalendar);
                      // AppLogger.debug('BackgroundSyncService: Updated task ${task.uid}');
                    } else {
                      // AppLogger.debug('BackgroundSyncService: Local task ${task.uid} is newer, skipping');
                    }
                  }
                },
                failure: (failure) async {
                  AppLogger.error('BackgroundSyncService: Failed to get local task', failure.exception, failure.stackTrace);
                },
              );
            }
          }
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Failed to process change ${change.href}', e, stackTrace);
    }
  }

  /// Delete task by href from local storage
  Future<void> _deleteTaskByHref(String href, String calendarUid) async {
    try {
      // Extract UID from href (assuming href ends with UID.ics)
      final filename = href.split('/').last;
      final uid = filename.endsWith('.ics') ? filename.substring(0, filename.length - 4) : filename;
      
      final taskResult = await _taskRepository.getById(uid);
      await taskResult.when(
        success: (task) async {
          if (task != null && task.sourceCalendarUid == calendarUid) {
            await _taskRepository.delete(uid);
            // AppLogger.debug('BackgroundSyncService: Deleted local task $uid');
          }
        },
        failure: (failure) async {
          // AppLogger.debug('BackgroundSyncService: Task $uid not found locally for deletion');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('BackgroundSyncService: Failed to delete task by href $href', e, stackTrace);
    }
  }

  /// Extract sync token from PROPFIND response
  String? _extractSyncTokenFromPropfind(String xmlResponse) {
    return XMLResponseParser.extractSyncToken(xmlResponse);
  }

  /// Parse REPORT sync-collection response
  Map<String, dynamic> _parseSyncCollectionResponse(String xmlResponse) {
    return XMLResponseParser.parseSyncCollectionResponse(xmlResponse);
  }



  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Dispose resources
  void dispose() {
    stop();
    // AppLogger.info('BackgroundSyncService: Disposed');
  }
} 
