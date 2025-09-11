// Sync service for bidirectional synchronization between local storage and CalDAV
// Implements offline-first architecture with sync queue

import 'dart:async';
import 'package:xml/xml.dart';
import '../../../core/result.dart';
import '../../../core/logger.dart';
import '../../models/task.dart';
import '../../models/caldav_account.dart';
import '../../models/task_calendar.dart';
import '../../models/journal.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/account_repository.dart';
import '../../repositories/calendar_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/journal_repository.dart';
import '../caldav/caldav_task_service.dart';
import '../caldav/caldav_calendar_service.dart';
import '../caldav/caldav_properties_service.dart';
import '../caldav/caldav_service.dart';
import '../caldav/caldav_discovery_service.dart';
import '../caldav/caldav_journal_service.dart';
import '../storage/local_storage_service.dart';
import '../webdav_client.dart';
import '../parsers/vtodo_parser.dart';
import '../parsers/vjournal_parser.dart';
import '../share/share_service.dart';

enum SyncOperation {
  create,
  update,
  delete,
  updateCalendar,
  createCalendar,
  deleteCalendar,
  exitShare,
  createJournal,
  updateJournal,
  deleteJournal,
}

enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

class SyncQueueItem {
  final String id;
  final SyncOperation operation;
  final String itemId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? nextAttemptAt;

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.itemId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.nextAttemptAt,
  });

  SyncQueueItem copyWith({
    int? retryCount,
    DateTime? nextAttemptAt,
  }) {
    return SyncQueueItem(
      id: id,
      operation: operation,
      itemId: itemId,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }
}

class SyncResult {
  final bool success;
  final int syncedItems;
  final int failedItems;
  final List<String> errors;
  final DateTime syncTime;

  SyncResult({
    required this.success,
    required this.syncedItems,
    required this.failedItems,
    required this.errors,
    required this.syncTime,
  });
}

/// SyncService orchestrates offline-first synchronization with a CalDAV server.
///
/// Notes on CalDAV dependency injection:
/// - This class consumes `ICalDAVService` (see `caldav_service.dart`).
/// - In production, `caldavFactory` builds a concrete `CalDAVService`.
/// - In tests, override `SyncService.caldavFactory = (_) => mock;` to fully
///   control server interactions (create/update/delete/report) without network.
class SyncService implements SyncCommander {
  static SyncService? _instance;
  static CalDavTaskService Function(CaldavAccount) taskServiceFactory =
      (account) => CalDavTaskService(account: account);
  static CalDavCalendarService Function(CaldavAccount) calendarServiceFactory =
      (account) => CalDavCalendarService(account: account);
  static CalDavPropertiesService Function(CaldavAccount) propertiesServiceFactory =
      (account) => CalDavPropertiesService(client: WebDAVClient.fromAccount(account));
  
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final CategoryRepository _categoryRepository;
  final UserRepository _userRepository;
  final JournalRepository _journalRepository;
  final LocalStorageService _localStorage;
  // Note: _shareService is currently unused here; sharing updates handled elsewhere
  // ignore: unused_field
  final ShareService? _shareService;

  // Private constructor
  SyncService._({
    required TaskRepository taskRepository,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required CategoryRepository categoryRepository,
    required UserRepository userRepository,
    required JournalRepository journalRepository,
    required LocalStorageService localStorage,
    ShareService? shareService,
  })  : _taskRepository = taskRepository,
        _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _categoryRepository = categoryRepository,
        _userRepository = userRepository,
        _journalRepository = journalRepository,
        _localStorage = localStorage,
        _shareService = shareService;

  // Factory constructor for creating/getting singleton instance
  factory SyncService({
    required TaskRepository taskRepository,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required CategoryRepository categoryRepository,
    required UserRepository userRepository,
    required JournalRepository journalRepository,
    required LocalStorageService localStorage,
    ShareService? shareService,
  }) {
    _instance ??= SyncService._(
      taskRepository: taskRepository,
      accountRepository: accountRepository,
      calendarRepository: calendarRepository,
      categoryRepository: categoryRepository,
      userRepository: userRepository,
      journalRepository: journalRepository,
      localStorage: localStorage,
      shareService: shareService,
    );
    return _instance!;
  }

  // Static getter for accessing the singleton instance
  static SyncService? get instance => _instance;

  // Static method to ensure instance is available
  static SyncService get requireInstance {
    if (_instance == null) {
      throw Exception('SyncService instance not initialized. Call SyncService() first.');
    }
    return _instance!;
  }

  // Sync state
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  Timer? _periodicSyncTimer;
  Timer? _scheduledSyncTimer;
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  // Configuration
  static const Duration syncInterval = Duration(seconds: 10);
  static const int maxRetryCount = 3;
  static const String syncQueueBoxName = 'sync_queue';

  // Public streams
  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<double> get progressStream => _progressController.stream;

  // Public getters
  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isBackgroundSyncRunning => false;
  bool get isBackgroundSyncing => false;

  /// Initialize the sync service
  Future<Result<void>> initialize() async {
    try {
      // AppLogger.info('SyncService: Initializing sync service');
      
      // Check if we have an active account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account != null) {
                    // Perform initial sync
        await syncAllActiveCaldav();
          }
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: No active account found for sync');
        },
      );

      // AppLogger.info('SyncService: Initialized successfully');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to initialize', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to initialize sync service: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Discover all available calendars and ensure they exist locally
  /// This ensures shared projects and all other accessible projects are available for sync
  Future<bool> _discoverAndEnsureAllCalendars(CaldavAccount account) async {
    try {
      AppLogger.info('CalDAVMonitor: Discovering all available calendars from server');

      // Use discovery service to test connection and list calendars
      final discovery = CalDavDiscoveryService(account: account);
      final capabilitiesResult = await discovery.testConnection();

      return await capabilitiesResult.when(
        success: (capabilities) async {
          final availableCalendars = capabilities.taskCalendars;
          AppLogger.info('CalDAVMonitor: Server has ${availableCalendars.length} available calendars');
          return await _ensureCalendarsExist(availableCalendars);
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
      final pendingDeletion = await _hasPendingDeletionForCalendar(serverCalendar.path);
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
                etag: existingCalendar.etag,
                syncToken: existingCalendar.syncToken,
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

    // Ensure newly added calendars are visible in project order by default (sync is now for all projects)
    if (newlyAddedPaths.isNotEmpty) {
      try {
        final prefsResult = await _userRepository.getUserPreferences();
        await prefsResult.when(
          success: (prefs) async {
            var updated = prefs;
            // Append to project order for visibility only
            final currentOrder = [...updated.projectOrder];
            for (final path in newlyAddedPaths) {
              if (!currentOrder.contains(path)) {
                currentOrder.add(path);
              }
            }
            updated = updated.copyWith(projectOrder: currentOrder);
            if (prefs.etag == null) {
              await _userRepository.saveUserPreferencesWithoutSync(updated);
              AppLogger.info('CalDAVMonitor: Updated project order during initial bootstrap (no local ETag) without triggering upload');
            } else {
              await _userRepository.saveUserPreferences(updated);
              AppLogger.info('CalDAVMonitor: Updated user preferences project order for ${newlyAddedPaths.length} newly discovered projects');
            }
          },
          failure: (failure) async {
            AppLogger.warning('CalDAVMonitor: Could not load user preferences to update project order: ${failure.message}');
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
            final cleanup = await _taskRepository.deleteOrphanedTasksLocalOnly(discoveredPaths);
            cleanup.when(
              success: (_) => AppLogger.info('CalDAVMonitor: Cleaned up orphaned tasks for missing calendars'),
              failure: (f) => AppLogger.warning('CalDAVMonitor: Failed to cleanup orphaned tasks: ${f.message}'),
            );
          } catch (_) {}

          // Update user preferences to remove missing calendars from project order
          try {
            final prefsResult = await _userRepository.getUserPreferences();
            await prefsResult.when(
              success: (prefs) async {
                final updatedOrder = prefs.projectOrder.where((p) => discoveredPaths.contains(p)).toList();
                if (updatedOrder.length != prefs.projectOrder.length) {
                  final updatedPrefs = prefs.copyWith(
                    projectOrder: updatedOrder,
                  );
                  if (prefs.etag == null) {
                    await _userRepository.saveUserPreferencesWithoutSync(updatedPrefs);
                    AppLogger.info('CalDAVMonitor: Updated project order during initial bootstrap (no local ETag) without triggering upload');
                  } else {
                    await _userRepository.saveUserPreferences(updatedPrefs);
                    AppLogger.info('CalDAVMonitor: Updated user preferences after removing missing calendars');
                  }
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


  Future<bool> updateCalendarList(CaldavAccount account) async {
    return await _discoverAndEnsureAllCalendars(account);
  }

  /// Perform immediate sync with CalDAV server
  Future<Result<SyncResult>> syncAllActiveCaldav() async {
    return await _syncAllActiveCaldavInternal(requireDiscovery: true);
  }

  /// Perform immediate sync with an option to skip calendar discovery
  Future<Result<SyncResult>> syncAllActiveCaldavNoDiscovery() async {
    return await _syncAllActiveCaldavInternal(requireDiscovery: false);
  }

  Future<Result<SyncResult>> _syncAllActiveCaldavInternal({required bool requireDiscovery}) async {
    if (_status == SyncStatus.syncing) {
      // AppLogger.debug('SyncService: Sync already in progress, skipping');
      return Result.failure(Failure(
        message: 'Sync already in progress',
        exception: Exception('Sync in progress'),
      ));
    }

    try {
      _updateStatus(SyncStatus.syncing);
      _progressController.add(0.0);

      AppLogger.debug('SyncService: Starting sync operation with requireDiscovery: $requireDiscovery');

      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      return await accountResult.when(
        success: (account) async {
          if (account == null) {
            _updateStatus(SyncStatus.offline);
            return Result.failure(Failure(
              message: 'No active CalDAV account configured',
              exception: Exception('No account'),
            ));
          }

          try {
            return await _performSync(account, requireDiscovery: requireDiscovery);
          } on RefreshTokenExpiredException {
            rethrow;
          }
        },
        failure: (failure) async {
          _updateStatus(SyncStatus.error);
          return Result.failure(failure);
        },
      );
    } on RefreshTokenExpiredException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Sync failed', e, stackTrace);
      _updateStatus(SyncStatus.error);
      return Result.failure(Failure(
        message: 'Sync operation failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Perform the actual sync operation with a CalDAV account
  Future<Result<SyncResult>> _performSync(CaldavAccount account, {bool requireDiscovery = true}) async {
    final caldavTask = SyncService.taskServiceFactory(account);
    final caldavProps = SyncService.propertiesServiceFactory(account);
    final errors = <String>[];
    int syncedItems = 0;
    int failedItems = 0;

    try {
      // DEBUG: Inspect storage contents
      // AppLogger.info('SyncService: DEBUG - Inspecting storage before sync');
      await _localStorage.debugAllBoxes();
      
      // Optionally run discovery to ensure all calendars are available
      if (requireDiscovery) {
        await _discoverAndEnsureAllCalendars(account);
      }
      
      // Get ALL available calendars from repository (discovery ensures all are available)
      final allCalendarsResult = await _calendarRepository.getProjectCalendars();
      final allCalendars = allCalendarsResult.when(
        success: (calendars) => calendars,
        failure: (failure) {
          AppLogger.error('SyncService: Failed to get calendars: ${failure.message}');
          return <TaskCalendar>[];
        },
      );
      
      // Sync all calendars regardless of user preferences (removed per new requirement)
      final calendarsToSync = allCalendars;
      
      if (calendarsToSync.isEmpty) {
        AppLogger.warning('SyncService: No calendars available for sync.');
        errors.add('No calendars available for synchronization. Check your CalDAV connection and shared projects.');
        failedItems++;

        // Attempt to load the sync queue and handle errors
        final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
        await queueResult.when(
          success: (_) async {
            // No-op: nothing to process if no calendars
          },
          failure: (failure) async {
            errors.add('Failed to load sync queue: ${failure.message}');
            failedItems++;
          },
        );

        _progressController.add(1.0);
        _lastSyncTime = DateTime.now();
        final result = SyncResult(
          success: errors.isEmpty,
          syncedItems: syncedItems,
          failedItems: failedItems,
          errors: errors,
          syncTime: _lastSyncTime!,
        );
        _updateStatus(errors.isEmpty ? SyncStatus.idle : SyncStatus.error);
        return Result.success(result);
      } else {
        //AppLogger.debug('🔄 SyncService: Starting sync for ${calendarsToSync.length} calendars');
        
        for (final calendar in calendarsToSync) {
          // Check if calendar has pending deletion
          final hasPendingDeletion = await _hasPendingDeletionForCalendar(calendar.path);
          if (hasPendingDeletion) {
            AppLogger.info('🔄 SyncService: Skipping calendar ${calendar.path} - pending deletion');
            continue; // Skip this calendar
          }
          
          //AppLogger.debug('🔄 SyncService: Processing calendar ${calendar.path}');
          
          final calendarResult = await _syncCalendar(caldavTask, caldavProps, calendar, errors);
          if (calendarResult) {
            syncedItems++;
          } else {
            failedItems++;
          }
          
          _progressController.add(0.2 + (0.6 * (calendarsToSync.indexOf(calendar) + 1) / calendarsToSync.length));
        }
      }

      // Also process queue items for calendars not included in this sync pass (e.g., excluded by prefs)
      final includedPaths = calendarsToSync.map((c) => c.path).toSet();
      await _processRemainingQueueItems(caldavTask, includedPaths, errors);

      // Process queue items for calendars that no longer exist locally
      await _processOrphanedQueueItems(caldavTask, errors);

      _progressController.add(1.0);
      _lastSyncTime = DateTime.now();

      final result = SyncResult(
        success: errors.isEmpty,
        syncedItems: syncedItems,
        failedItems: failedItems,
        errors: errors,
        syncTime: _lastSyncTime!,
      );

      _updateStatus(errors.isEmpty ? SyncStatus.idle : SyncStatus.error);
      
      // AppLogger.info('SyncService: Sync completed - ${result.syncedItems} synced, ${result.failedItems} failed');
      return Result.success(result);

    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Sync operation failed', e, stackTrace);
      _updateStatus(SyncStatus.error);
      return Result.failure(Failure(
        message: 'Sync operation failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Sync a single calendar with the server
  /// Returns true if sync was successful, false if it failed
  Future<bool> _syncCalendar(CalDavTaskService caldavTask, CalDavPropertiesService caldavProps, TaskCalendar calendar, List<String> errors) async {
    // Push queued operations first for this calendar to avoid UI re-adding stale server state
    try {
      final hasQueuedOpsEarly = await _hasQueuedOperationsForCalendar(calendar.path);
      if (hasQueuedOpsEarly) {
        await _processSyncQueueForCalendar(caldavTask, calendar.path, errors);
      }
    } catch (_) {
      // ignore push-first failures; pull will still proceed
    }
    // Étape 1: Obtenir le sync-token actuel du serveur
    final serverSyncTokenResult = await _getServerSyncToken(caldavProps, calendar);
    
    return await serverSyncTokenResult.when(
      success: (serverSyncToken) async {
        final localSyncToken = calendar.syncToken;
        
        AppLogger.debug('🔄 SyncService: sync-token changed: ${localSyncToken != serverSyncToken}, Calendar ${calendar.path} - Local: ${localSyncToken}, Server: ${serverSyncToken} (displayName: ${calendar.displayName})');
        
        if (localSyncToken != serverSyncToken) {
          // Case 1: Sync token changed - get actual changes and apply them
          AppLogger.debug('🔄 SyncService: Sync-tokens differ - syncing changes from server (displayName: ${calendar.displayName})');
          await _syncFromServer(caldavTask, caldavProps, calendar, serverSyncToken, errors);
          return true;
        }
        
        // Case 2: Sync token unchanged - check if ETag needs updating
        final serverPropertiesResult = await caldavProps.getCalendarProperties(calendar);
        await serverPropertiesResult.when(
          success: (serverCalendar) async {
            AppLogger.debug('🔄 SyncService: ETag comparison, ETags equal? ${calendar.etag == serverCalendar.etag}, for ${calendar.path} (displayName: ${calendar.displayName}): Local ETag: ${calendar.etag ?? "(null)"}, Server ETag: ${serverCalendar.etag ?? "(null)"}');
            
            if (calendar.etag != serverCalendar.etag) {
              AppLogger.info('🔄 SyncService: ETag differs - updating calendar ${calendar.path} properties (displayName: ${calendar.displayName})');
              final updatedCalendar = calendar.copyWith(
                etag: serverCalendar.etag,
                lastSyncAt: DateTime.now(),
                // Copy server properties to sync changes from server
                displayName: serverCalendar.displayName,
                description: serverCalendar.description,
                color: serverCalendar.color,
                flowitDomain: serverCalendar.flowitDomain,
                flowitStatus: serverCalendar.flowitStatus,
                flowitKanban: serverCalendar.flowitKanban,
                projectCategories: serverCalendar.projectCategories,
                projectRequirements: serverCalendar.projectRequirements,
                projectSteps: serverCalendar.projectSteps,
                sharedWith: serverCalendar.sharedWith,
                lastModified: serverCalendar.lastModified,
                // Keep attendees from server if they exist, otherwise keep local ones
                attendees: serverCalendar.attendees.isNotEmpty ? serverCalendar.attendees : calendar.attendees,
              );
              
              final saveResult = await _calendarRepository.save(updatedCalendar);
              await saveResult.when(
                success: (_) async {
                  AppLogger.info('🔄 SyncService: Calendar ${calendar.path} (${calendar.displayName}) ETag updated successfully');
                },
                failure: (failure) async {
                  AppLogger.error('🔄 SyncService: Failed to save ETag update for ${calendar.path} (displayName: ${calendar.displayName}): ${failure.message}');
                },
              );
            }
            // else {
            //   AppLogger.debug('🔄 SyncService: ETags are equal - no update needed ${calendar.path} (displayName: ${calendar.displayName})');
            // }
          },
          failure: (failure) async {
            AppLogger.warning('🔄 SyncService: Could not get server properties for ${calendar.path} (displayName: ${calendar.displayName}): ${failure.message}');
          },
        );
        
        // TEST 2: queue non vide → pousser modifications vers serveur
        final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
        if (hasQueuedOperations) {
          //AppLogger.debug('🔄 SyncService: Queue has operations - pushing to server');
          await _processSyncQueueForCalendar(caldavTask, calendar.path, errors);
          
          // Récupérer le nouveau sync-token après push
          final newServerSyncTokenResult = await _getServerSyncToken(caldavProps, calendar);
          await newServerSyncTokenResult.when(
            success: (newServerSyncToken) async {
            AppLogger.debug('🔄 SyncService: Server sync token after queue processing: ${newServerSyncToken}');
              if (newServerSyncToken != serverSyncToken) {
                AppLogger.debug('🔄 SyncService: Server sync-token updated after push: ${newServerSyncToken}');
                
                // Get current calendar properties to update ETag as well
                final serverPropertiesResult = await caldavProps.getCalendarProperties(calendar);
                await serverPropertiesResult.when(
                  success: (serverCalendar) async {
                    // Update calendar with new sync token and ETag
                    final updatedCalendar = calendar.copyWith(
                      syncToken: newServerSyncToken,
                      etag: serverCalendar.etag,
                      lastSyncAt: DateTime.now(),
                    );
                    final saveResult = await _calendarRepository.save(updatedCalendar);
                    await saveResult.when(
                      success: (_) async {
                    AppLogger.info('🔄 SyncService: Calendar ${calendar.path} sync token and ETag updated after queue processing');
                      },
                      failure: (failure) async {
                        AppLogger.error('🔄 SyncService: Failed to save calendar ${calendar.path}: ${failure.message}');
                      },
                    );
                  },
                  failure: (failure) async {
                    AppLogger.warning('🔄 SyncService: Could not get server properties for ETag update: ${failure.message}');
                    // Fallback: update only sync token
                    final updatedCalendar = calendar.copyWith(
                      syncToken: newServerSyncToken,
                      lastSyncAt: DateTime.now(),
                    );
                    final saveResult = await _calendarRepository.save(updatedCalendar);
                    await saveResult.when(
                      success: (_) async {
                        AppLogger.info('🔄 SyncService: Calendar ${calendar.path} sync token updated after queue processing (ETag update failed)');
                      },
                      failure: (failure) async {
                        AppLogger.error('🔄 SyncService: Failed to save calendar ${calendar.path}: ${failure.message}');
                      },
                    );
                  },
                );
              } else {
                AppLogger.info('🔄 SyncService: Server sync token unchanged after queue processing ${calendar.path} ${calendar.displayName}');
              }
            },
            failure: (failure) async {
              AppLogger.warning('🔄 SyncService: Could not get updated sync token after push ${calendar.path} ${calendar.displayName}: ${failure.message}');
            },
          );
          return true;
        }

        // Si aucun des deux tests n'est vrai, rien à faire
        // if (localSyncToken == serverSyncToken) {
        //   AppLogger.debug('🔄 SyncService: No changes needed for ${calendar.path} ${calendar.displayName}');
        // }

        return true;
      },
      failure: (failure) async {
        AppLogger.warning('🔄 SyncService: Could not get server sync token for ${calendar.path}: ${failure.message}');
        // Fallback: traiter la queue si elle existe
        final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
        if (hasQueuedOperations) {
          //AppLogger.debug('🔄 SyncService: Fallback - processing queue without sync token verification');
          await _processSyncQueueForCalendar(caldavTask, calendar.path, errors);
        }
        errors.add('Could not verify sync state for ${calendar.path}: ${failure.message}');
        return false;
      },
    );
  }

  /// Public method to sync a single calendar (for use by monitor/services)
  Future<bool> syncCalendar(CaldavAccount account, TaskCalendar calendar, List<String> errors) async {
    final caldavTask = SyncService.taskServiceFactory(account);
    final caldavProps = SyncService.propertiesServiceFactory(account);
    return _syncCalendar(caldavTask, caldavProps, calendar, errors);
  }

  /// Process a single sync queue item
  Future<void> _processSyncQueueItem(SyncQueueItem item, CalDavTaskService caldavTask) async {
    switch (item.operation) {
      case SyncOperation.create:
        final taskUid = item.data['taskUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;

        if (taskUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing taskUid or calendarPath for create');
          throw Exception('Missing required data for task creation');
        }

        final taskResult = await _taskRepository.getById(taskUid);
        await taskResult.when(
          success: (task) async {
            if (task == null) {
              throw Exception('Task not found in repository: $taskUid');
            }

            // Use queued calendarPath directly to support orphaned items
            final result = await caldavTask.createTask(task, calendarPath);
            await result.when(
              success: (_) async {},
              failure: (failure) async {
                throw Exception('Failed to create task: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find task $taskUid for creation');
            throw Exception('Task not found for creation: ${failure.message}');
          },
        );
        break;

      case SyncOperation.update:
        final taskUid = item.data['taskUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;

        if (taskUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing taskUid or calendarPath for update');
          throw Exception('Missing required data for task update');
        }

        final taskResult = await _taskRepository.getById(taskUid);
        await taskResult.when(
          success: (task) async {
            if (task == null) {
              throw Exception('Task not found in repository: $taskUid');
            }

            // Construct task URL directly from queued calendar path
            final taskUrl = '${calendarPath}${taskUid}.ics';
            final result = await caldavTask.updateTask(task, taskUrl);
            await result.when(
              success: (_) async {},
              failure: (failure) async {
                throw Exception('Failed to update task: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find task $taskUid for update');
            throw Exception('Task not found for update: ${failure.message}');
          },
        );
        break;

      case SyncOperation.delete:
        final calendarPath = item.data['calendarPath'] as String?;
        final taskUid = item.data['taskUid'] as String?;

        if (calendarPath == null || taskUid == null) {
          AppLogger.warning('SyncService: Missing calendarPath or taskUid for deletion');
          throw Exception('Missing required data for task deletion');
        }

        final taskUrl = '${calendarPath}${taskUid}.ics';
        final result = await caldavTask.deleteTask(taskUrl);
        await result.when(
          success: (_) async {},
          failure: (failure) async {
            throw Exception('Failed to delete task: ${failure.message}');
          },
        );
        break;

      case SyncOperation.updateCalendar:
        // Get the calendar from repository using calendarPath
        final calendarPath = item.data['calendarPath'] as String?;
        
        AppLogger.debug('SyncService: Processing calendar update for: $calendarPath');
        
        if (calendarPath == null) {
          AppLogger.warning('SyncService: Missing calendarPath for calendar update');
          throw Exception('Missing required data for calendar update');
        }
        
        // Get the complete calendar from repository
        final calendarResult = await _calendarRepository.getById(calendarPath);
        await calendarResult.when(
          success: (calendar) async {
            if (calendar == null) {
              AppLogger.warning('SyncService: Calendar not found in repository: $calendarPath');
              throw Exception('Calendar not found in repository: $calendarPath');
            }
            
            AppLogger.debug('SyncService: Found calendar ${calendar.displayName}, performing PROPPATCH via CalDAVService');

            // Perform PROPPATCH update (also triggers sharing sync downstream)
            final caldav = CalDAVService(account: caldavTask.account);
            final result = await caldav.updateCalendarProperties(calendar);
            await result.when(
              success: (_) async {
                AppLogger.debug('SyncService: PROPPATCH completed for ${calendar.displayName}');
              },
              failure: (failure) async {
                throw Exception('Failed to update calendar properties: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find calendar $calendarPath for update');
            throw Exception('Calendar not found for update: ${failure.message}');
          },
        );
        break;

      case SyncOperation.createCalendar:
        // Get the calendar from repository using calendarPath
        final calendarPath = item.data['calendarPath'] as String?;
        
        AppLogger.debug('SyncService: Processing calendar creation for: $calendarPath');
        
        if (calendarPath == null) {
          AppLogger.warning('SyncService: Missing calendarPath for calendar creation');
          throw Exception('Missing required data for calendar creation');
        }
        
        // Get the complete calendar from repository
        final calendarResult = await _calendarRepository.getById(calendarPath);
        await calendarResult.when(
          success: (calendar) async {
            if (calendar == null) {
              AppLogger.warning('SyncService: Calendar not found in repository: $calendarPath');
              throw Exception('Calendar not found in repository: $calendarPath');
            }
            
            AppLogger.debug('SyncService: Found calendar ${calendar.displayName}, calling CalDAV create');
            
            // Create calendar on server
            final discovery = CalDavDiscoveryService(account: caldavTask.account);
            final caps = await discovery.testConnection();
            final calendarHome = await caps.when(
              success: (c) async => c.calendarHome,
              failure: (f) async => throw Exception('Discovery failed: ${f.message}'),
            );
            final caldavCalendar = SyncService.calendarServiceFactory(caldavTask.account);
            final asWorkflow = (calendar.flowitAsFlow == true) || ((calendar.flowitType.toUpperCase()) == 'WORKFLOW');
            final result = await caldavCalendar.createCalendar(
              calendarHome: calendarHome,
              displayName: calendar.displayName,
              description: calendar.description,
              domain: calendar.flowitDomain,
              kanban: calendar.flowitKanban,
              author: calendar.flowitAuthor,
              owner: calendar.flowitOwner,
              asWorkflow: asWorkflow,
            );
            await result.when(
              success: (createdCalendar) async {
                AppLogger.info('SyncService: Created calendar ${calendar.displayName} on server');
                // Update local calendar with server response (path, etag, etc.)
                final saveResult = await _calendarRepository.save(createdCalendar);
                await saveResult.when(
                  success: (_) {
                    AppLogger.debug('SyncService: Updated local calendar with server response');
                  },
                  failure: (failure) {
                    AppLogger.warning('SyncService: Failed to update local calendar after creation: ${failure.message}');
                  },
                );

                try {
                  // Migrate any locally cloned tasks pointing to the placeholder path to the new server path
                  final placeholderPath = calendarPath;
                  final serverPath = createdCalendar.path;

                  // 1) Rewrite queued operations that reference the placeholder calendarPath
                  final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
                  await queueResult.when(
                    success: (queueData) async {
                      for (final data in queueData) {
                        final item = _mapToSyncQueueItem(data);
                        if (item == null) continue;
                        final itemCalPath = item.data['calendarPath'] as String?;
                        if (itemCalPath == placeholderPath) {
                          final updatedItemMap = Map<String, dynamic>.from(_mapFromSyncQueueItem(item));
                          final updatedData = Map<String, dynamic>.from(updatedItemMap['data'] as Map<String, dynamic>);
                          updatedData['calendarPath'] = serverPath;
                          updatedItemMap['data'] = updatedData;
                          await _localStorage.put(syncQueueBoxName, item.id, updatedItemMap);
                        }
                      }
                    },
                    failure: (_) async {},
                  );

                  // 2) Migrate existing local tasks to point to the new server path
                  final tasksRes = await _taskRepository.getByProject(placeholderPath);
                  await tasksRes.when(
                    success: (tasks) async {
                      for (final t in tasks) {
                        final moved = t.copyWith(projectPath: serverPath);
                        await _taskRepository.save(moved);
                      }
                    },
                    failure: (_) async {},
                  );

                  // 3) Remove the placeholder calendar locally without queuing a server deletion
                  await _calendarRepository.unsyncCalendar(placeholderPath);
                } catch (e, st) {
                  AppLogger.warning('SyncService: Post-creation migration encountered an issue for ${calendar.displayName}: $e');
                  AppLogger.debug('SyncService: Stack: $st');
                }
              },
              failure: (failure) async {
                throw Exception('Failed to create calendar: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find calendar $calendarPath for creation');
            throw Exception('Calendar not found for creation: ${failure.message}');
          },
        );
        break;

      case SyncOperation.deleteCalendar:
        // Use queued path directly; calendar may already be removed locally
        final calendarPath = item.data['calendarPath'] as String?;
        AppLogger.debug('SyncService: Processing calendar deletion for: $calendarPath');
        if (calendarPath == null) {
          AppLogger.warning('SyncService: Missing calendarPath for calendar deletion');
          throw Exception('Missing required data for calendar deletion');
        }
        final caldavCalendar = SyncService.calendarServiceFactory(caldavTask.account);
        final result = await caldavCalendar.deleteCalendar(calendarPath);
        await result.when(
          success: (_) async {
            AppLogger.info('SyncService: Deleted calendar at $calendarPath from server');
          },
          failure: (failure) async {
            throw Exception('Failed to delete calendar: ${failure.message}');
          },
        );
        break;

      case SyncOperation.exitShare:
        // Get the calendar path for exit share
        final calendarPath = item.data['calendarPath'] as String?;
        
        
        if (calendarPath == null) {
          AppLogger.warning('SyncService: Missing calendarPath for exit share');
          throw Exception('Missing required data for exit share');
        }
        
        // Create ShareService instance and call exitShare
        final shareService = ShareService(account: caldavTask.account);       
        final result = await shareService.exitShare(calendarPath);
        await result.when(
          success: (_) async {
          },
          failure: (failure) async {
            throw Exception('Failed to exit share: ${failure.message}');
          },
        );
        break;

      case SyncOperation.createJournal:
        final journalUid = item.data['journalUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;

        if (journalUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing journalUid or calendarPath for journal creation');
          throw Exception('Missing required data for journal creation');
        }

        final journalResult = await _journalRepository.getById(journalUid);
        await journalResult.when(
          success: (journal) async {
            if (journal == null) {
              throw Exception('Journal not found in repository: $journalUid');
            }

            final caldavJournal = CalDavJournalService(account: caldavTask.account);
            final result = await caldavJournal.createJournal(journal, calendarPath);
            await result.when(
              success: (_) async {
                AppLogger.debug('SyncService: Successfully created journal on server: $journalUid');
              },
              failure: (failure) async {
                throw Exception('Failed to create journal: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find journal $journalUid for creation');
            throw Exception('Journal not found for creation: ${failure.message}');
          },
        );
        break;

      case SyncOperation.updateJournal:
        final journalUid = item.data['journalUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;

        if (journalUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing journalUid or calendarPath for journal update');
          throw Exception('Missing required data for journal update');
        }

        final journalResult = await _journalRepository.getById(journalUid);
        await journalResult.when(
          success: (journal) async {
            if (journal == null) {
              throw Exception('Journal not found in repository: $journalUid');
            }

            final journalUrl = '${calendarPath}${journalUid}.ics';
            final caldavJournal = CalDavJournalService(account: caldavTask.account);
            final result = await caldavJournal.updateJournal(journal, journalUrl);
            await result.when(
              success: (_) async {
                AppLogger.debug('SyncService: Successfully updated journal on server: $journalUid');
              },
              failure: (failure) async {
                throw Exception('Failed to update journal: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find journal $journalUid for update');
            throw Exception('Journal not found for update: ${failure.message}');
          },
        );
        break;

      case SyncOperation.deleteJournal:
        final journalUid = item.data['journalUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;

        if (journalUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing journalUid or calendarPath for journal deletion');
          throw Exception('Missing required data for journal deletion');
        }

        final journalUrl = '${calendarPath}${journalUid}.ics';
        final caldavJournal = CalDavJournalService(account: caldavTask.account);
        final result = await caldavJournal.deleteJournal(journalUrl);
        await result.when(
          success: (_) async {
            AppLogger.debug('SyncService: Successfully deleted journal from server: $journalUid');
          },
          failure: (failure) async {
            throw Exception('Failed to delete journal: ${failure.message}');
          },
        );
        break;
    }
  }

  /// Queue a calendar update operation for later processing
  Future<Result<void>> queueCalendarUpdate(String calendarPath) async {
    try {
      AppLogger.debug('SyncService: Queuing calendar update for: $calendarPath');
      
      final syncData = <String, dynamic>{
        'calendarPath': calendarPath,
      };

      final result = await queueSyncOperation(
        SyncOperation.updateCalendar,
        calendarPath,
        syncData,
      );
      
      AppLogger.debug('SyncService: Calendar update queue result: ${result is Success ? "SUCCESS" : "FAILURE"}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to queue calendar update', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue calendar update: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Queue a calendar creation operation for later processing
  Future<Result<void>> queueCalendarCreation(String calendarPath) async {
    try {
      AppLogger.debug('SyncService: Queuing calendar creation for: $calendarPath');
      
      final syncData = <String, dynamic>{
        'calendarPath': calendarPath,
      };

      final result = await queueSyncOperation(
        SyncOperation.createCalendar,
        calendarPath,
        syncData,
      );
      
      AppLogger.debug('SyncService: Calendar creation queue result: ${result is Success ? "SUCCESS" : "FAILURE"}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to queue calendar creation', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue calendar creation: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Queue a calendar deletion operation for later processing
  Future<Result<void>> queueCalendarDeletion(String calendarPath) async {
    try {
      AppLogger.debug('SyncService: Queuing calendar deletion for: $calendarPath');
      
      final syncData = <String, dynamic>{
        'calendarPath': calendarPath,
      };

      final result = await queueSyncOperation(
        SyncOperation.deleteCalendar,
        calendarPath,
        syncData,
      );
      
      AppLogger.debug('SyncService: Calendar deletion queue result: ${result is Success ? "SUCCESS" : "FAILURE"}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to queue calendar deletion', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue calendar deletion: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Queue an exit share operation for later processing
  Future<Result<void>> queueExitShare(String projectPath) async {
    try {
      AppLogger.debug('SyncService: Queuing exit share for project path: $projectPath');
      
      final syncData = <String, dynamic>{
        'calendarPath': projectPath,
      };

      final result = await queueSyncOperation(
        SyncOperation.exitShare,
        projectPath,
        syncData,
      );
      
      AppLogger.debug('SyncService: Exit share queue result: ${result is Success ? "SUCCESS" : "FAILURE"}');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to queue exit share', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue exit share: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Queue a sync operation for later processing
  Future<Result<void>> queueSyncOperation(
    SyncOperation operation,
    String itemId,
    Map<String, dynamic> data,
  ) async {
    try {
      final queueItem = SyncQueueItem(
        id: 'sync_${DateTime.now().microsecondsSinceEpoch}_${operation.name}_$itemId',
        operation: operation,
        itemId: itemId,
        data: data,
        createdAt: DateTime.now(),
      );

      final result = await _localStorage.put(
        syncQueueBoxName,
        queueItem.id,
        _mapFromSyncQueueItem(queueItem),
      );

      return await result.when(
        success: (_) async {
          // Schedule a near-immediate sync without microtask retry loops
          _scheduleSyncAfter(const Duration(milliseconds: 100));
          return const Result.success(null);
        },
        failure: (failure) async {
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to queue sync operation', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to queue sync operation: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  void _scheduleSyncAfter(Duration delay) {
    // Coalesce schedules; if one is already pending, keep it
    if (_scheduledSyncTimer != null && _scheduledSyncTimer!.isActive) {
      return;
    }
    _scheduledSyncTimer = Timer(delay, () async {
      try {
        await syncAllActiveCaldavNoDiscovery();
      } catch (e, stackTrace) {
        AppLogger.error('SyncService: Error during scheduled sync', e, stackTrace);
      } finally {
        _scheduledSyncTimer = null;
      }
    });
  }

  /// Check if there are queued operations for a specific calendar
  Future<bool> _hasQueuedOperationsForCalendar(String calendarPath) async {
    try {
      final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
      return await queueResult.when(
        success: (queueData) async {
          
          final queueItems = queueData
              .map((data) => _mapToSyncQueueItem(data))
              .where((item) => item != null)
              .cast<SyncQueueItem>()
              .toList();
          
          //AppLogger.debug('🔄 SyncService: Valid queue items: ${queueItems.length}');
          
          // Check if any queue item is for this calendar
          final calendarItems = queueItems.where((item) => 
            item.data['calendarPath'] == calendarPath
          ).toList();
          
          //AppLogger.debug('🔄 SyncService: Queue items for calendar $calendarPath: ${calendarItems.length}');
          
          if (calendarItems.isNotEmpty) {
            for (final item in calendarItems) {
              AppLogger.debug('🔄 SyncService: Queue item: ${item.operation.name} for ${item.itemId}');
            }
          }
          
          return calendarItems.isNotEmpty;
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: Could not check queue for calendar $calendarPath: ${failure.message}');
          return false;
        },
      );
    } catch (e) {
      AppLogger.error('SyncService: Error checking queue for calendar $calendarPath', e, StackTrace.current);
      return false;
    }
  }

  /// Check if a calendar has pending deletion operations
  Future<bool> _hasPendingDeletionForCalendar(String calendarPath) async {
    try {
      final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
      return await queueResult.when(
        success: (queueData) async {
          final queueItems = queueData
              .map((data) => _mapToSyncQueueItem(data))
              .where((item) => item != null)
              .cast<SyncQueueItem>()
              .toList();
          
          // Check if any queue item is a delete operation for this calendar
          final deleteItems = queueItems.where((item) => 
            (item.operation == SyncOperation.deleteCalendar || 
             item.operation == SyncOperation.exitShare) &&
            item.data['calendarPath'] == calendarPath
          ).toList();
          
          if (deleteItems.isNotEmpty) {
            AppLogger.debug('🔄 SyncService: Found ${deleteItems.length} pending deletion(s) for calendar $calendarPath');
          }
          
          return deleteItems.isNotEmpty;
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: Could not check pending deletions for calendar $calendarPath: ${failure.message}');
          return false;
        },
      );
    } catch (e) {
      AppLogger.error('SyncService: Error checking pending deletions for calendar $calendarPath', e, StackTrace.current);
      return false;
    }
  }

  /// Public check for pending calendar deletions (used by monitor/discovery)
  Future<bool> hasPendingDeletionForCalendar(String calendarPath) async {
    return _hasPendingDeletionForCalendar(calendarPath);
  }

  /// Get current sync token from server for a calendar
  Future<Result<String>> _getServerSyncToken(CalDavPropertiesService caldavProps, TaskCalendar calendar) async {
    try {
      // Use CalDAVService to get both sync token and ETag
      final propertiesResult = await caldavProps.getCalendarProperties(calendar);
      return await propertiesResult.when(
        success: (updatedCalendar) async {
          final syncToken = updatedCalendar.syncToken;
          if (syncToken != null) {
            return Result.success(syncToken);
          } else {
            return Result.failure(Failure(
              message: 'No sync token found in response',
              exception: Exception('Missing sync token'),
            ));
          }
        },
        failure: (failure) async => Result.failure(failure),
      );
    } catch (e, stackTrace) {
      return Result.failure(Failure(
        message: 'Failed to get server sync token: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Sync changes from server using sync-collection REPORT
  Future<void> _syncFromServer(CalDavTaskService caldavTask, CalDavPropertiesService caldavProps, TaskCalendar calendar, String newSyncToken, List<String> errors) async {
    try {
      AppLogger.debug('🔄 SyncService: Syncing from server for ${calendar.path}');
      
      // Use CalDAVMonitor logic for incremental sync
      final webdavClient = WebDAVClient.fromAccount(caldavTask.account);
      
      // Check if calendar exists on server before attempting sync
      final calendarExists = await _checkCalendarExistsOnServer(webdavClient, calendar.path);
      if (!calendarExists) {
        AppLogger.info('SyncService: Calendar ${calendar.path} not found on server, attempting to create it');
        final createdSuccessfully = await _createCalendarOnServer(caldavTask.account, calendar);
        if (!createdSuccessfully) {
          AppLogger.warning('SyncService: Failed to create calendar on server, skipping sync for ${calendar.path}');
          return;
        }
        AppLogger.info('SyncService: Successfully created calendar on server: ${calendar.path}');
      }
      
      if (calendar.syncToken == null) {
        // First sync - fetch all tasks and journals
        final tasksResult = await caldavTask.fetchTasks(calendar.path);
        await tasksResult.when(
          success: (remoteTasks) async {
            // Log each fetched task details from server before saving
            for (final t in remoteTasks) {
              try {
                AppLogger.debug("🔄 SyncService: fetched task from server: uid=${t.uid}, summary='${t.summary}', status=${t.status}, project=${calendar.path}");
              } catch (_) {}
            }
            for (final task in remoteTasks) {
              final taskWithCalendar = task.copyWith(projectPath: calendar.path);
              await _taskRepository.saveFromSync(taskWithCalendar);
            }
            AppLogger.debug('🔄 SyncService: Full sync completed - ${remoteTasks.length} tasks from ${calendar.path}');
          },
          failure: (failure) async {
            AppLogger.warning('🔄 SyncService: Failed to fetch tasks from ${calendar.path}: ${failure.message}');
            errors.add('Failed to fetch tasks from ${calendar.path}: ${failure.message}');
          },
        );

        // Fetch journals
        final caldavJournal = CalDavJournalService(account: caldavTask.account);
        final journalsResult = await caldavJournal.fetchJournals(calendar.path);
        await journalsResult.when(
          success: (remoteJournals) async {
            for (final journal in remoteJournals) {
              final journalWithCalendar = journal.copyWith(projectPath: calendar.path);
              await _journalRepository.saveFromSync(journalWithCalendar);
            }
            AppLogger.debug('🔄 SyncService: Full sync completed - ${remoteJournals.length} journals from ${calendar.path}');
          },
          failure: (failure) async {
            errors.add('Failed to fetch journals from ${calendar.path}: ${failure.message}');
          },
        );
      } else {
        // Incremental sync using sync-collection
        final changesResult = await _getSyncChanges(webdavClient, calendar.path, calendar.syncToken!);
        await changesResult.when(
          success: (result) async {
            final changes = result['changes'] as List<dynamic>;
            AppLogger.debug('🔄 SyncService: Processing ${changes.length} changes from server');
            
            // Process each change
            for (final change in changes) {
              final changeMap = change as Map<String, dynamic>;
              final changeType = changeMap['type'] as String;
              final href = changeMap['href'] as String;
              
              if (changeType == 'deleted') {
                // Delete task or journal from local storage
                await _deleteTaskByHref(href, calendar.path);
                await _deleteJournalByHref(href, calendar.path);
                AppLogger.debug('🔄 SyncService: Deleted remote item fetched from server (applied locally): href=$href, project=${calendar.path}');
              } else if (changeType == 'updated') {
                // Check if it's a task or journal based on the data
                if (changeMap.containsKey('task')) {
                  // Create or update task in local storage
                  final taskData = changeMap['task'] as Map<String, dynamic>;
                  final task = Task.fromJson(taskData);
                  final taskWithCalendar = task.copyWith(projectPath: calendar.path);
                  await _taskRepository.saveFromSync(taskWithCalendar);
                  AppLogger.debug("🔄 SyncService: updated task from server applied locally: uid=${task.uid}, summary='${task.summary}', status=${task.status}, project=${calendar.path}");
                } else if (changeMap.containsKey('journal')) {
                  // Create or update journal in local storage
                  final journalData = changeMap['journal'] as Map<String, dynamic>;
                  final journal = Journal.fromJson(journalData);
                  final journalWithCalendar = journal.copyWith(projectPath: calendar.path);
                  await _journalRepository.saveFromSync(journalWithCalendar);
                  //AppLogger.debug('🔄 SyncService: Updated journal ${journal.uid}');
                }
              }
            }
          },
          failure: (failure) async {
            errors.add('Failed to get sync changes for ${calendar.path}: ${failure.message}');
          },
        );
      }
      
      // Get current calendar properties from server to update ETag
      final serverPropertiesResult = await caldavProps.getCalendarProperties(calendar);
      await serverPropertiesResult.when(
        success: (serverCalendar) async {
          // Update calendar with new sync token and ETag
          AppLogger.info('🔄 SyncService: Updating calendar ${calendar.path}');
          
          final updatedCalendar = calendar.copyWith(
            syncToken: newSyncToken,
            etag: serverCalendar.etag,
            lastSyncAt: DateTime.now(),
            // Copy server properties to sync changes from server
            displayName: serverCalendar.displayName,
            description: serverCalendar.description,
            color: serverCalendar.color,
            flowitDomain: serverCalendar.flowitDomain,
            flowitStatus: serverCalendar.flowitStatus,
            flowitKanban: serverCalendar.flowitKanban,
            projectCategories: serverCalendar.projectCategories,
            projectRequirements: serverCalendar.projectRequirements,
            projectSteps: serverCalendar.projectSteps,
            sharedWith: serverCalendar.sharedWith,
            lastModified: serverCalendar.lastModified,
            attendees: serverCalendar.attendees,
          );
          

          
          final saveResult = await _calendarRepository.save(updatedCalendar);
          await saveResult.when(
            success: (_) async {
              AppLogger.info('🔄 SyncService: Calendar ${calendar.path} sync token and ETag updated successfully');
              

            },
            failure: (failure) async {
              AppLogger.error('🔄 SyncService: Failed to save calendar ${calendar.path}: ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.warning('🔄 SyncService: Could not get server properties for ETag update: ${failure.message}');
          // Fallback: update only sync token
          final updatedCalendar = calendar.copyWith(
            syncToken: newSyncToken,
            lastSyncAt: DateTime.now(),
          );
          final saveResult = await _calendarRepository.save(updatedCalendar);
          await saveResult.when(
            success: (_) async {
              AppLogger.info('🔄 SyncService: Calendar ${calendar.path} sync token updated (ETag update failed)');
            },
            failure: (failure) async {
              AppLogger.error('🔄 SyncService: Failed to save calendar ${calendar.path}: ${failure.message}');
            },
          );
        },
      );
      
      // Load categories from the updated calendar data
      await _categoryRepository.loadCategoriesFromCalendar(calendar);
      
      // Update sharing information if supported - use the updated calendar with correct ETag/syncToken
      AppLogger.info('SyncService: About to update sharing information for calendar ${calendar.path}');
      
      // Get the freshly updated calendar from repository to ensure we have the latest ETag/syncToken
      final freshCalendarResult = await _calendarRepository.getByPath(calendar.path);
      await freshCalendarResult.when(
        success: (freshCalendar) async {
          if (freshCalendar != null) {
            AppLogger.debug('SyncService: Using fresh calendar with ETag: ${freshCalendar.etag} for sharing update');
            await _updateSharingInformation(caldavTask.account, freshCalendar);
          } else {
            AppLogger.warning('SyncService: Could not get fresh calendar for sharing update, using original');
            await _updateSharingInformation(caldavTask.account, calendar);
          }
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: Could not get fresh calendar for sharing update: ${failure.message}, using original');
          await _updateSharingInformation(caldavTask.account, calendar);
        },
      );
      
      AppLogger.info('SyncService: Finished updating sharing information for calendar ${calendar.path}');
      
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to sync from server for ${calendar.path}', e, stackTrace);
      errors.add('Failed to sync from server for ${calendar.path}: $e');
    }
  }

  /// Process sync queue operations for a specific calendar
  Future<void> _processSyncQueueForCalendar(CalDavTaskService caldavTask, String calendarPath, List<String> errors) async {
    try {
      AppLogger.debug('🔄 SyncService: Processing queue for calendar $calendarPath');
      
      final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
      await queueResult.when(
        success: (queueData) async {
          final queueItems = queueData
              .map((data) => _mapToSyncQueueItem(data))
              .where((item) => item != null)
              .cast<SyncQueueItem>()
              .where((item) => item.data['calendarPath'] == calendarPath)
              .toList();

          // Process in chronological order (create → update → delete) to preserve user intent
          queueItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          //AppLogger.debug('🔄 SyncService: Found ${queueItems.length} queued operations for calendar $calendarPath');

          final now = DateTime.now();
          for (final item in queueItems) {
            try {
              if (item.nextAttemptAt != null && now.isBefore(item.nextAttemptAt!)) {
                continue;
              }
              await _processSyncQueueItem(item, caldavTask);
              // Remove from queue on success
              await _localStorage.delete(syncQueueBoxName, item.id);
              AppLogger.debug('🔄 SyncService: Successfully processed and removed queue item ${item.  id}');
            } catch (e) {
              AppLogger.error('SyncService: Failed to process queue item ${item.id}', e, StackTrace.current);
              AppLogger.error('SyncService: Failed to process queue item data : ${item.data}');
              
              if (item.retryCount >= maxRetryCount) {
                // Max retries reached, remove from queue
                errors.add('Max retries reached for item ${item.id}: $e');
                await _localStorage.delete(syncQueueBoxName, item.id);
              } else {
                final delay = _computeBackoffDelay(item.retryCount);
                final updatedItem = item.copyWith(
                  retryCount: item.retryCount + 1,
                  nextAttemptAt: DateTime.now().add(delay),
                );
                await _localStorage.put(syncQueueBoxName, item.id, _mapFromSyncQueueItem(updatedItem));
                _scheduleSyncAfter(delay);
              }
            }
          }
        },
        failure: (failure) async {
          errors.add('Failed to load sync queue for calendar $calendarPath: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('SyncService: Failed to process sync queue for calendar $calendarPath', e, StackTrace.current);
      errors.add('Failed to process sync queue for calendar $calendarPath: $e');
    }
  }

  /// Process queue items for calendars that no longer exist locally
  Future<void> _processOrphanedQueueItems(CalDavTaskService caldavTask, List<String> errors) async {
    try {
      AppLogger.debug('🔄 SyncService: Processing orphaned queue items');
      
      final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
      await queueResult.when(
        success: (queueData) async {
          final queueItems = queueData
              .map((data) => _mapToSyncQueueItem(data))
              .where((item) => item != null)
              .cast<SyncQueueItem>()
              .toList();

          // Find queue items for calendars that no longer exist locally
          final now = DateTime.now();
          for (final item in queueItems) {
            if (item.nextAttemptAt != null && now.isBefore(item.nextAttemptAt!)) {
              continue;
            }
            final calendarPath = item.data['calendarPath'] as String?;
            if (calendarPath != null) {
              final calendarResult = await _calendarRepository.getById(calendarPath);
              await calendarResult.when(
                success: (calendar) async {
                  if (calendar == null) {
                    // Calendar no longer exists locally, process the queue item
                    AppLogger.info('🔄 SyncService: Processing orphaned queue item for deleted calendar: $calendarPath');
                    try {
                      await _processSyncQueueItem(item, caldavTask);
                      // Remove from queue on success
                      await _localStorage.delete(syncQueueBoxName, item.id);
                      AppLogger.info('🔄 SyncService: Successfully processed orphaned queue item ${item.id}');
                    } catch (e) {
                      AppLogger.error('SyncService: Failed to process orphaned queue item ${item.id}', e, StackTrace.current);
                      if (item.retryCount >= maxRetryCount) {
                        errors.add('Max retries reached for orphaned item ${item.id}: $e');
                        await _localStorage.delete(syncQueueBoxName, item.id);
                      } else {
                        final delay = _computeBackoffDelay(item.retryCount);
                        final updatedItem = item.copyWith(
                          retryCount: item.retryCount + 1,
                          nextAttemptAt: DateTime.now().add(delay),
                        );
                        await _localStorage.put(syncQueueBoxName, item.id, _mapFromSyncQueueItem(updatedItem));
                        _scheduleSyncAfter(delay);
                      }
                    }
                  }
                },
                failure: (failure) async {
                  AppLogger.warning('SyncService: Could not check calendar existence for orphaned queue item: ${failure.message}');
                },
              );
            }
          }
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: Could not load queue for orphaned items: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('SyncService: Error processing orphaned queue items', e, StackTrace.current);
    }
  }

  /// Process queue items for calendars that were not in the current sync set (e.g. excluded by prefs)
  Future<void> _processRemainingQueueItems(CalDavTaskService caldavTask, Set<String> includedCalendarPaths, List<String> errors) async {
    try {
      final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
      await queueResult.when(
        success: (queueData) async {
          final queueItems = queueData
              .map((data) => _mapToSyncQueueItem(data))
              .where((item) => item != null)
              .cast<SyncQueueItem>()
              .toList();

          final now = DateTime.now();
          for (final item in queueItems) {
            final calendarPath = item.data['calendarPath'] as String?;
            if (calendarPath == null) continue;
            if (includedCalendarPaths.contains(calendarPath)) continue; // already processed in regular loop
            if (item.nextAttemptAt != null && now.isBefore(item.nextAttemptAt!)) {
              continue;
            }

            // Ensure the calendar exists locally; if it does, process its queue now
            final calendarResult = await _calendarRepository.getById(calendarPath);
            await calendarResult.when(
              success: (calendar) async {
                if (calendar != null) {
                  try {
                    await _processSyncQueueItem(item, caldavTask);
                    await _localStorage.delete(syncQueueBoxName, item.id);
                  } catch (e) {
                    if (item.retryCount >= maxRetryCount) {
                      errors.add('Max retries reached for item ${item.id}: $e');
                      await _localStorage.delete(syncQueueBoxName, item.id);
                    } else {
                      final delay = _computeBackoffDelay(item.retryCount);
                      final updatedItem = item.copyWith(
                        retryCount: item.retryCount + 1,
                        nextAttemptAt: DateTime.now().add(delay),
                      );
                      await _localStorage.put(syncQueueBoxName, item.id, _mapFromSyncQueueItem(updatedItem));
                      _scheduleSyncAfter(delay);
                    }
                  }
                }
              },
              failure: (_) async {},
            );
          }
        },
        failure: (_) async {},
      );
    } catch (_) {
      // swallow
    }
  }

  /// Get sync changes using REPORT sync-collection (RFC 6578)
  Future<Result<Map<String, dynamic>>> _getSyncChanges(WebDAVClient webdavClient, String calendarPath, String syncToken) async {
    try {
      AppLogger.debug('🔄 SyncService: Making sync-collection request for $calendarPath with token: $syncToken');
      
      final reportBody = '''<?xml version="1.0" encoding="utf-8" ?>
<D:sync-collection xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:sync-token>$syncToken</D:sync-token>
  <D:sync-level>1</D:sync-level>
  <D:prop>
    <D:getetag />
    <C:calendar-data />
  </D:prop>
</D:sync-collection>''';

      //AppLogger.debug('🔄 SyncService: Request body: $reportBody');

      final result = await webdavClient.report(calendarPath, reportBody);
      return await result.when(
        success: (response) async {
          AppLogger.debug('🔄 SyncService: REPORT sync-collection response status code: ${response.statusCode}');
          AppLogger.debug('🔄 SyncService: REPORT sync-collection response body: ${response.body}');
          
          if (response.statusCode == 207) {
            final parsedResult = _parseSyncCollectionResponse(response.body);
            //AppLogger.debug('🔄 SyncService: Parsed result: $parsedResult');
            return Result.success(parsedResult);
          } else {
            AppLogger.error('🔄 SyncService: REPORT sync-collection failed with status ${response.statusCode}: ${response.body}');
            return Result.failure(Failure(
              message: 'REPORT sync-collection failed with status ${response.statusCode}',
              exception: Exception('HTTP ${response.statusCode}'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('🔄 SyncService: Failed to send sync-collection request', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('🔄 SyncService: Exception in _getSyncChanges', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to get sync changes: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Parse REPORT sync-collection response
  Map<String, dynamic> _parseSyncCollectionResponse(String xmlResponse) {
    final changes = <Map<String, dynamic>>[];
    String? newSyncToken;

    try {
      //AppLogger.debug('🔄 SyncService: Parsing sync-collection response...');
      final document = XmlDocument.parse(xmlResponse);
      
      // Extract new sync token
      final syncTokenElement = document.findAllElements('sync-token').firstOrNull;
      newSyncToken = syncTokenElement?.innerText;
      //AppLogger.debug('🔄 SyncService: Found new sync token: $newSyncToken');
      
      // Extract responses
      final responseElements = document.findAllElements('response').toList();
      //AppLogger.debug('🔄 SyncService: Found ${responseElements.length} response elements');
      
      for (final responseElement in responseElements) {
        final href = responseElement.findElements('href').firstOrNull?.innerText;
        //AppLogger.debug('🔄 SyncService: Processing href: $href');
        if (href == null) {
          //AppLogger.warning('🔄 SyncService: Skipping response element without href');
          continue;
        }
        
        final propstatElement = responseElement.findElements('propstat').firstOrNull;
        if (propstatElement == null) {
          // Check for direct status in response element (for deletions)
          final directStatusElement = responseElement.findElements('status').firstOrNull;
          if (directStatusElement != null) {
            final directStatus = directStatusElement.innerText;
            AppLogger.debug('🔄 SyncService: Direct status for $href: $directStatus');
            
            if (directStatus.contains('404')) {
              // Resource was deleted
              changes.add({
                'href': href,
                'type': 'deleted',
              });
              //AppLogger.debug('🔄 SyncService: Added deleted change for $href');
            } else {
              AppLogger.warning('🔄 SyncService: Unhandled direct status for $href: $directStatus');
            }
          } else {
            AppLogger.warning('🔄 SyncService: Skipping response element without propstat or status for href: $href');
          }
          continue;
        }
        
        final statusElement = propstatElement.findElements('status').firstOrNull;
        final status = statusElement?.innerText ?? '';
        //AppLogger.debug('🔄 SyncService: Status for $href: $status');
        
        if (status.contains('404')) {
          // Resource was deleted
          changes.add({
            'href': href,
            'type': 'deleted',
          });
          //AppLogger.debug('🔄 SyncService: Added deleted change for $href');
        } else if (status.contains('200')) {
          // Resource was created or updated
          final propElement = propstatElement.findElements('prop').firstOrNull;
          if (propElement != null) {
            //AppLogger.debug('🔄 SyncService: Prop element children: ${propElement.children.whereType<XmlElement>().map((c) => c.name.local).toList()}');
            //AppLogger.debug('🔄 SyncService: All descendants: ${propElement.descendants.whereType<XmlElement>().map((d) => d.name.local).toList()}');
            
            final etag = propElement.findElements('getetag').firstOrNull?.innerText;
            final calendarDataElement = propElement.findAllElements('calendar-data').firstOrNull;
            
            //AppLogger.debug('🔄 SyncService: Found etag: $etag, calendar-data present: ${calendarDataElement != null}');
            
            if (calendarDataElement == null) {
              // Try alternative approaches to find calendar-data
              final allElements = propElement.descendants.whereType<XmlElement>().toList();
              //AppLogger.debug('🔄 SyncService: Looking for calendar-data in ${allElements.length} descendants');
              for (final element in allElements) {
                //AppLogger.debug('🔄 SyncService: Element: ${element.name.local} (qualified: ${element.name.qualified})');
                if (element.name.local == 'calendar-data') {
                  //AppLogger.debug('🔄 SyncService: Found calendar-data by local name!');
                  final vtodoContent = element.innerText;
                  //AppLogger.debug('🔄 SyncService: VTODO content length: ${vtodoContent.length}');
                  //AppLogger.debug('🔄 SyncService: VTODO content: $vtodoContent');
                  
                  final parsedResult = _parseCalendarData(vtodoContent);
                  
                  if (parsedResult != null) {
                    changes.add({
                      'href': href,
                      'etag': etag,
                      'type': 'updated',
                      ...parsedResult,
                    });
                    AppLogger.debug('🔄 SyncService: Added updated change for ${parsedResult.keys.first}');
                  } else {
                    AppLogger.warning('🔄 SyncService: Failed to parse calendar data for $href');
                  }
                  break;
                }
              }
            } else {
              final vtodoContent = calendarDataElement.innerText;
              //AppLogger.debug('🔄 SyncService: VTODO content length: ${vtodoContent.length}');
              //AppLogger.debug('🔄 SyncService: VTODO content: $vtodoContent');
              
              final parsedResult = _parseCalendarData(vtodoContent);
              
              if (parsedResult != null) {
                changes.add({
                  'href': href,
                  'etag': etag,
                  'type': 'updated',
                  ...parsedResult,
                });
                //AppLogger.debug('🔄 SyncService: Added updated change for ${parsedResult.keys.first}');
              } else {
                AppLogger.warning('🔄 SyncService: Failed to parse calendar data for $href');
              }
            }
          } else {
            AppLogger.warning('🔄 SyncService: No prop element found for $href');
          }
        } else {
          AppLogger.warning('🔄 SyncService: Unhandled status for $href: $status');
        }
      }
      
      //AppLogger.debug('🔄 SyncService: Parsing complete. Changes: ${changes.length}, New sync token: $newSyncToken');
    } catch (e) {
      AppLogger.error('🔄 SyncService: Failed to parse sync-collection response', e, StackTrace.current);
    }

    return {
      'changes': changes,
      'syncToken': newSyncToken,
    };
  }

  /// Parse VTODO from calendar data
  Task? _parseVTODOFromCalendarData(String calendarData) {
    try {
      // Use VTODOParser for proper parsing with escaping/unescaping
      return VTODOParser.parseVTODOFromCalendarData(calendarData);
    } catch (e) {
      AppLogger.error('SyncService: Failed to parse VTODO from calendar data', e, StackTrace.current);
    }
    return null;
  }

  /// Parse calendar data (VTODO or VJOURNAL) and return appropriate result
  Map<String, dynamic>? _parseCalendarData(String calendarData) {
    try {
      // Check if it's a VTODO
      if (calendarData.contains('BEGIN:VTODO')) {
        final task = VTODOParser.parseVTODOFromCalendarData(calendarData);
        if (task != null) {
          return {'task': task.toJson()};
        }
      }
      
      // Check if it's a VJOURNAL
      if (calendarData.contains('BEGIN:VJOURNAL')) {
        final journal = VJournalParser.parseVJOURNALFromCalendarData(calendarData);
        if (journal != null) {
          return {'journal': journal.toJson()};
        }
      }
      
      AppLogger.warning('SyncService: Unknown calendar data type');
      return null;
    } catch (e) {
      AppLogger.error('SyncService: Failed to parse calendar data', e, StackTrace.current);
      return null;
    }
  }

  /// Update sync status and notify listeners
  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
      // AppLogger.debug('SyncService: Status changed to ${_status.name}');
    }
  }

  /// Reset SyncService instance and clean up resources
  /// Called when clearing all data to ensure clean state
  static Future<void> reset() async {
    AppLogger.info('SyncService: Resetting singleton instance and cleaning up resources');
    
    if (_instance != null) {
      // Cancel any active timers
      _instance!._periodicSyncTimer?.cancel();
      _instance!._periodicSyncTimer = null;
      _instance!._scheduledSyncTimer?.cancel();
      _instance!._scheduledSyncTimer = null;
      
      // Close stream controllers
      await _instance!._statusController.close();
      await _instance!._progressController.close();
      
      // Reset state
      _instance!._status = SyncStatus.idle;
      _instance!._lastSyncTime = null;
    }
    
    // Clear singleton instance
    _instance = null;
    
    AppLogger.info('SyncService: Reset complete');
  }

  /// Helper to convert SyncQueueItem to Map for storage
  Map<String, dynamic> _mapFromSyncQueueItem(SyncQueueItem item) {
    return {
      'id': item.id,
      'operation': item.operation.name,
      'itemId': item.itemId,
      'data': item.data,
      'createdAt': item.createdAt.toIso8601String(),
      'retryCount': item.retryCount,
      'nextAttemptAt': item.nextAttemptAt?.toIso8601String(),
    };
  }

  /// Helper to convert Map to SyncQueueItem
  SyncQueueItem? _mapToSyncQueueItem(Map<String, dynamic> data) {
    try {
      // Safe conversion of nested data Map
      Map<String, dynamic> itemData;
      final rawData = data['data'];
      
      if (rawData is Map<String, dynamic>) {
        itemData = rawData;
      } else if (rawData is Map) {
        // Handle Map<dynamic, dynamic> to Map<String, dynamic> conversion
        itemData = <String, dynamic>{};
        rawData.forEach((key, value) {
          itemData[key.toString()] = value;
        });
      } else {
        AppLogger.warning('SyncService: Invalid data field in sync queue item: ${rawData.runtimeType}');
        return null;
      }
      
      return SyncQueueItem(
        id: data['id'] as String,
        operation: SyncOperation.values.firstWhere(
          (op) => op.name == data['operation'],
        ),
        itemId: data['itemId'] as String,
        data: itemData,
        createdAt: DateTime.parse(data['createdAt'] as String),
        retryCount: data['retryCount'] as int? ?? 0,
        nextAttemptAt: (data['nextAttemptAt'] as String?) != null
            ? DateTime.parse(data['nextAttemptAt'] as String)
            : null,
      );
    } catch (e) {
      AppLogger.error('SyncService: Failed to parse sync queue item', e, StackTrace.current);
      return null;
    }
  }

  /// Delete task by href from local storage TODO: check if this is needed
  Future<void> _deleteTaskByHref(String href, String calendarPath) async {
    try {
      // Extract UID from href (assuming href ends with UID.ics)
      final filename = href.split('/').last;
      final uid = filename.endsWith('.ics') ? filename.substring(0, filename.length - 4) : filename;
      
      final taskResult = await _taskRepository.getById(uid);
      await taskResult.when(
        success: (task) async {
          if (task != null && task.projectPath == calendarPath) {
            await _taskRepository.delete(uid);
            //AppLogger.debug('🔄 SyncService: Deleted local task $uid');
          }
        },
        failure: (failure) async {
          AppLogger.debug('🔄 SyncService: Task $uid not found locally for deletion');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to delete task by href $href', e, stackTrace);
    }
  }

  /// Delete journal by href from local storage
  Future<void> _deleteJournalByHref(String href, String calendarPath) async {
    try {
      // Extract UID from href (assuming href ends with UID.ics)
      final filename = href.split('/').last;
      final uid = filename.endsWith('.ics') ? filename.substring(0, filename.length - 4) : filename;
      
      final journalResult = await _journalRepository.getById(uid);
      await journalResult.when(
        success: (journal) async {
          if (journal != null && journal.projectPath == calendarPath) {
            await _journalRepository.delete(uid);
            //AppLogger.debug('🔄 SyncService: Deleted local journal $uid');
          }
        },
        failure: (failure) async {
          AppLogger.debug('🔄 SyncService: Journal $uid not found locally for deletion');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to delete journal by href $href', e, stackTrace);
    }
  }

  /// Process sync queue only (for background sync service) TODO: check if this is needed
  /// This method bypasses the sync status check and only processes queued operations
  Future<Result<SyncResult>> processQueueOnly() async {
    try {
      AppLogger.debug('SyncService: Processing queue only (bypassing sync status check)');
      
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      return await accountResult.when(
        success: (account) async {
          if (account == null) {
            return Result.failure(Failure(
              message: 'No active CalDAV account configured',
              exception: Exception('No account'),
            ));
          }

          return await _performQueueProcessing(account);
        },
        failure: (failure) async {
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Queue processing failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Queue processing failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Perform queue processing only (without sync status check) TODO: check if this is needed
  Future<Result<SyncResult>> _performQueueProcessing(CaldavAccount account) async {
    final caldavTask = SyncService.taskServiceFactory(account);
    final errors = <String>[];
    int syncedItems = 0;
    int failedItems = 0;

    try {
      // Get selected calendars from repository
      final selectedCalendarsResult = await _calendarRepository.getProjectCalendars();
      final selectedCalendars = selectedCalendarsResult.when(
        success: (calendars) => calendars,
        failure: (failure) {
          AppLogger.error('SyncService: Failed to get selected calendars: ${failure.message}');
          return <TaskCalendar>[];
        },
      );
      
      if (selectedCalendars.isEmpty) {
        AppLogger.warning('SyncService: No calendars selected for queue processing');
        errors.add('No calendars selected for queue processing');
        failedItems++;
      } else {
        AppLogger.debug('SyncService: Processing queue for ${selectedCalendars.length} calendars');
        
        for (final calendar in selectedCalendars) {
          // Check if there are queued operations for this calendar
          final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
          if (hasQueuedOperations) {
            AppLogger.debug('SyncService: Found queued operations for calendar ${calendar.path}');
            await _processSyncQueueForCalendar(caldavTask, calendar.path, errors);
            syncedItems++;
          } else {
            AppLogger.debug('SyncService: No queued operations for calendar ${calendar.path}');
          }
        }
      }

      final result = SyncResult(
        success: errors.isEmpty,
        syncedItems: syncedItems,
        failedItems: failedItems,
        errors: errors,
        syncTime: DateTime.now(),
      );

      AppLogger.info('SyncService: Queue processing completed - ${result.syncedItems} synced, ${result.failedItems} failed');
      return Result.success(result);

    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Queue processing operation failed', e, stackTrace);
      return Result.failure(Failure(
        message: 'Queue processing operation failed: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Force queue processing (for background sync service)
  /// This method processes the queue without doing full sync TODO: check if this is needed
  Future<void> forceQueueProcessing() async {
    try {
      AppLogger.debug('SyncService: Force processing queue');
      
      // Get active account
      final accountResult = await _accountRepository.getActiveAccount();
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.debug('SyncService: No active account for queue processing');
            return;
          }

          // Get selected calendars
          final selectedCalendarsResult = await _calendarRepository.getProjectCalendars();
          final selectedCalendars = selectedCalendarsResult.when(
            success: (calendars) => calendars,
            failure: (failure) {
              AppLogger.error('SyncService: Failed to get calendars for queue processing: ${failure.message}');
              return <TaskCalendar>[];
            },
          );
          
          if (selectedCalendars.isEmpty) {
            AppLogger.debug('SyncService: No calendars selected for queue processing');
            return;
          }

          // Process queue for each calendar
    final caldavTask = SyncService.taskServiceFactory(account);
          final errors = <String>[];
          
          for (final calendar in selectedCalendars) {
            final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
            if (hasQueuedOperations) {
              AppLogger.debug('SyncService: Processing queue for calendar ${calendar.path}');
              await _processSyncQueueForCalendar(caldavTask, calendar.path, errors);
            }
          }
          
          if (errors.isNotEmpty) {
            AppLogger.warning('SyncService: Queue processing completed with errors: ${errors.join(', ')}');
          } else {
            AppLogger.debug('SyncService: Queue processing completed successfully');
          }
        },
        failure: (failure) async {
          AppLogger.error('SyncService: Failed to get account for queue processing: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Exception during force queue processing', e, stackTrace);
    }
  }

  /// Check if calendar exists on server using PROPFIND TODO: check if this is needed
  Future<bool> _checkCalendarExistsOnServer(WebDAVClient webdavClient, String calendarPath) async {
    try {
      final propfindBody = '''<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:resourcetype />
  </D:prop>
</D:propfind>''';

      final result = await webdavClient.propfind(calendarPath, body: propfindBody, depth: 0);
      return await result.when(
        success: (response) async {
          // Calendar exists if we get 207 Multi-Status or 200 OK
          return response.statusCode == 207 || response.statusCode == 200;
        },
        failure: (failure) async {
          // Calendar doesn't exist or we can't access it
          return false;
        },
      );
    } catch (e) {
      // Any exception means calendar is not accessible
      return false;
    }
  }

  /// Create a local calendar on the server TODO: check if this is needed
  Future<bool> _createCalendarOnServer(CaldavAccount account, TaskCalendar calendar) async {
    try {
      AppLogger.info('SyncService: Creating calendar on server: ${calendar.displayName}');
      
      // Use CalDAV service to create the calendar
    final discovery = CalDavDiscoveryService(account: account);
    final caps = await discovery.testConnection();
    final calendarHome = await caps.when(
      success: (c) async => c.calendarHome,
      failure: (f) async => throw Exception('Discovery failed: ${f.message}'),
    );
    final caldavCalendar = SyncService.calendarServiceFactory(account);
    final createResult = await caldavCalendar.createCalendar(
      calendarHome: calendarHome,
      displayName: calendar.displayName,
      description: calendar.description,
      author: account.email?.isNotEmpty == true ? account.email : account.username,
      owner: account.email?.isNotEmpty == true ? account.email : account.username,
    );

      return await createResult.when(
        success: (serverCalendar) async {
          AppLogger.info('SyncService: Successfully created calendar on server at ${serverCalendar.path}');
          
          // Update local calendar with server etag for sync tracking
          final updatedCalendar = calendar.copyWith(
            etag: serverCalendar.etag,
          );
          await _calendarRepository.save(updatedCalendar);
          
          return true;
        },
        failure: (failure) async {
          AppLogger.error('SyncService: Failed to create calendar on server: ${failure.message}');
          return false;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Exception creating calendar on server', e, stackTrace);
      return false;
    }
  }

  /// Update sharing information for a calendar TODO: check if this is needed
  Future<void> _updateSharingInformation(CaldavAccount account, TaskCalendar calendar) async {
    try {
      // Only update sharing info for TowDow Cloud and self-hosted accounts
      final sharingService = ShareService(account: account);
      if (!sharingService.supportsSharing) {
        AppLogger.debug('SyncService: Skipping sharing update - account type ${account.providerType} does not support sharing');
        return;
      }
      
      AppLogger.info('SyncService: Updating sharing information for calendar ${calendar.path}');
      AppLogger.debug('SyncService: Account: ${account.username}@${account.serverUrl}, Provider: ${account.providerType}');
      
      // Extract project path from calendar path (UUID part)
      final projectPath = calendar.uid;
      if (projectPath.isEmpty) {
        AppLogger.warning('SyncService: Could not extract project path from ${calendar.path}');
        return;
      }
      
      AppLogger.debug('SyncService: Extracted project path: $projectPath');
      AppLogger.debug('SyncService: Calling ShareService.getProjectMembers...');
      
      // Determine if this project is shared-with-me (drives delete vs exitShare behavior)
      bool isSharedWithMeFlag = calendar.isSharedWithMe;
      try {
        isSharedWithMeFlag = await sharingService.isSharedWithMe(projectPath);
        AppLogger.debug('SyncService: isSharedWithMe=$isSharedWithMeFlag for ${calendar.path}');
      } catch (_) {
        // Ignore errors; keep existing value
      }
      
      // Get current sharing members from API
      final membersResult = await sharingService.getProjectMembers(projectPath);
      await membersResult.when(
        success: (members) async {
          AppLogger.info('SyncService: Successfully fetched ${members.length} shared members from API');
          for (int i = 0; i < members.length; i++) {
            final member = members[i];
            AppLogger.debug('SyncService: Member $i: ${member.targetUserEmail} (${member.projectRight}) from ${member.sourceUserEmail}');
          }
          
          // Convert SharedProjectMember objects to JSON for storage
          final membersJson = members.map((member) => member.toJson()).toList();
          AppLogger.debug('SyncService: Converting members to JSON: $membersJson');
          
          // Update calendar with sharing information
          final updatedCalendar = calendar
              .withSharedWith(membersJson)
              .copyWith(isSharedWithMe: isSharedWithMeFlag);
          AppLogger.debug('SyncService: Updated calendar sharedWith field: "${updatedCalendar.sharedWith}"');
          
          await _calendarRepository.save(updatedCalendar);
          AppLogger.info('SyncService: Successfully saved sharing info for ${calendar.path} - ${members.length} members');
        },
        failure: (failure) async {
          // Log the error but don't fail the sync - sharing is optional
          AppLogger.warning('SyncService: Failed to get sharing info for ${calendar.path}: ${failure.message}');
          AppLogger.debug('SyncService: Sharing API error code: ${failure.code}');
          AppLogger.debug('SyncService: Sharing API error details: ${failure.exception}');
          // Still persist isSharedWithMe flag if we could compute it
          if (isSharedWithMeFlag != calendar.isSharedWithMe) {
            try {
              final updatedCalendar = calendar.copyWith(isSharedWithMe: isSharedWithMeFlag);
              await _calendarRepository.save(updatedCalendar);
              AppLogger.debug('SyncService: Persisted isSharedWithMe=$isSharedWithMeFlag for ${calendar.path}');
            } catch (_) {
              // swallow
            }
          }
        },
      );
    } catch (e, stackTrace) {
      // Log the error but don't fail the sync - sharing is optional  
      AppLogger.warning('SyncService: Error updating sharing information for ${calendar.path}', e, stackTrace);
    }
  }
  
  /// Dispose resources
  void dispose() {
    // Note: No periodic sync to stop - CalDAVMonitor handles this
    _statusController.close();
    _progressController.close();
    // AppLogger.info('SyncService: Disposed');
  }
  
  // Compute exponential backoff with base 2s, 2^retryCount, cap at 16s, ±20% jitter
  Duration _computeBackoffDelay(int retryCount) {
    const int baseSeconds = 2;
    final int exponent = (1 << retryCount);
    int seconds = baseSeconds * exponent;
    if (seconds > 16) seconds = 16;
    // Deterministic jitter for testability
    final micros = DateTime.now().microsecondsSinceEpoch;
    final jitterPct = 0.8 + (micros % 401) / 1000.0; // 0.8..1.201
    final millis = (seconds * 1000 * jitterPct).round();
    final withJitter = Duration(milliseconds: millis);
    return withJitter < const Duration(seconds: 2) ? const Duration(seconds: 2) : withJitter;
  }
} 
