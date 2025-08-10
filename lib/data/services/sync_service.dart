// Sync service for bidirectional synchronization between local storage and CalDAV
// Implements offline-first architecture with sync queue

import 'dart:async';
import 'package:xml/xml.dart';
import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task.dart';
import '../models/caldav_account.dart';
import '../models/task_calendar.dart';
import '../repositories/task_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/user_repository.dart';
import 'caldav_service.dart';
import 'local_storage_service.dart';
import 'webdav_client.dart';
import 'parsers/vtodo_parser.dart';
import 'share_service.dart';

enum SyncOperation {
  create,
  update,
  delete,
  updateCalendar,
  createCalendar,
  deleteCalendar,
  exitShare,
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

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.itemId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  SyncQueueItem copyWith({
    int? retryCount,
  }) {
    return SyncQueueItem(
      id: id,
      operation: operation,
      itemId: itemId,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
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
class SyncService {
  static SyncService? _instance;
  static ICalDAVService Function(CaldavAccount) caldavFactory =
      (account) => CalDAVService(account: account);
  
  final TaskRepository _taskRepository;
  final AccountRepository _accountRepository;
  final CalendarRepository _calendarRepository;
  final CategoryRepository _categoryRepository;
  final UserRepository _userRepository;
  final LocalStorageService _localStorage;
  final ShareService? _shareService;

  // Private constructor
  SyncService._({
    required TaskRepository taskRepository,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required CategoryRepository categoryRepository,
    required UserRepository userRepository,
    required LocalStorageService localStorage,
    ShareService? shareService,
  })  : _taskRepository = taskRepository,
        _accountRepository = accountRepository,
        _calendarRepository = calendarRepository,
        _categoryRepository = categoryRepository,
        _userRepository = userRepository,
        _localStorage = localStorage,
        _shareService = shareService;

  // Factory constructor for creating/getting singleton instance
  factory SyncService({
    required TaskRepository taskRepository,
    required AccountRepository accountRepository,
    required CalendarRepository calendarRepository,
    required CategoryRepository categoryRepository,
    required UserRepository userRepository,
    required LocalStorageService localStorage,
    ShareService? shareService,
  }) {
    _instance ??= SyncService._(
      taskRepository: taskRepository,
      accountRepository: accountRepository,
      calendarRepository: calendarRepository,
      categoryRepository: categoryRepository,
      userRepository: userRepository,
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

  /// Perform immediate sync with CalDAV server
  Future<Result<SyncResult>> syncAllActiveCaldav() async {
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

      // AppLogger.info('SyncService: Starting sync operation');

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
            return await _performSync(account);
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
  Future<Result<SyncResult>> _performSync(CaldavAccount account) async {
    final ICalDAVService caldavService = SyncService.caldavFactory(account);
    final errors = <String>[];
    int syncedItems = 0;
    int failedItems = 0;

    try {
      // DEBUG: Inspect storage contents
      // AppLogger.info('SyncService: DEBUG - Inspecting storage before sync');
      await _localStorage.debugAllBoxes();
      
      // Get ALL available calendars from repository (discovery ensures all are available)
      final allCalendarsResult = await _calendarRepository.getProjectCalendars();
      final allCalendars = allCalendarsResult.when(
        success: (calendars) => calendars,
        failure: (failure) {
          AppLogger.error('SyncService: Failed to get calendars: ${failure.message}');
          return <TaskCalendar>[];
        },
      );
      
      // Filter out excluded calendars based on user preferences
      final userPrefsResult = await _userRepository.getUserPreferences();
      final calendarsToSync = await userPrefsResult.when(
        success: (prefs) async {
          final filtered = allCalendars.where((calendar) => prefs.shouldSyncProject(calendar.path)).toList();
          AppLogger.info('SyncService: Syncing ${filtered.length} of ${allCalendars.length} available calendars (${prefs.excludedProjects.length} excluded)');
          return filtered;
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: Failed to get user preferences, syncing all calendars: ${failure.message}');
          return allCalendars; // Fallback: sync all if can't get preferences
        },
      );
      
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
          
          final calendarResult = await _syncCalendar(caldavService, calendar, errors);
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
      await _processRemainingQueueItems(caldavService, includedPaths, errors);

      // Process queue items for calendars that no longer exist locally
      await _processOrphanedQueueItems(caldavService, errors);

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
  Future<bool> _syncCalendar(ICalDAVService caldavService, TaskCalendar calendar, List<String> errors) async {
    // Étape 1: Obtenir le sync-token actuel du serveur
    final serverSyncTokenResult = await _getServerSyncToken(caldavService, calendar);
    
    return await serverSyncTokenResult.when(
      success: (serverSyncToken) async {
        final localSyncToken = calendar.syncToken;
        
        AppLogger.debug('🔄 SyncService: Calendar ${calendar.path} - Local: ${localSyncToken ?? "(null)"}, Server: ${serverSyncToken ?? "(null)"}');
        
        if (localSyncToken != serverSyncToken) {
          // Case 1: Sync token changed - get actual changes and apply them
          AppLogger.debug('🔄 SyncService: Sync-tokens differ - syncing changes from server');
          await _syncFromServer(caldavService, calendar, serverSyncToken, errors);
          return true;
        }
        
        // Case 2: Sync token unchanged - check if ETag needs updating
        final serverPropertiesResult = await caldavService.getCalendarProperties(calendar);
        await serverPropertiesResult.when(
          success: (serverCalendar) async {
            AppLogger.debug('🔄 SyncService: ETag comparison for ${calendar.path}:');
            AppLogger.debug('🔄 SyncService:   Local ETag: ${calendar.etag ?? "(null)"}');
            AppLogger.debug('🔄 SyncService:   Server ETag: ${serverCalendar.etag ?? "(null)"}');
            AppLogger.debug('🔄 SyncService:   ETags equal? ${calendar.etag == serverCalendar.etag}');
            
            if (calendar.etag != serverCalendar.etag) {
              AppLogger.info('🔄 SyncService: ETag differs - updating calendar properties');
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
                  AppLogger.info('🔄 SyncService: Calendar ${calendar.path} ETag updated successfully');
                },
                failure: (failure) async {
                  AppLogger.error('🔄 SyncService: Failed to save ETag update: ${failure.message}');
                },
              );
            } else {
              AppLogger.debug('🔄 SyncService: ETags are equal - no update needed');
            }
          },
          failure: (failure) async {
            AppLogger.warning('🔄 SyncService: Could not get server properties: ${failure.message}');
          },
        );
        
        // TEST 2: queue non vide → pousser modifications vers serveur
        final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
        if (hasQueuedOperations) {
          //AppLogger.debug('🔄 SyncService: Queue has operations - pushing to server');
          await _processSyncQueueForCalendar(caldavService, calendar.path, errors);
          
          // Récupérer le nouveau sync-token après push
          final newServerSyncTokenResult = await _getServerSyncToken(caldavService, calendar);
          await newServerSyncTokenResult.when(
            success: (newServerSyncToken) async {
              AppLogger.debug('🔄 SyncService: Server sync token after queue processing: ${newServerSyncToken ?? "(null)"}');
              if (newServerSyncToken != serverSyncToken) {
                AppLogger.debug('🔄 SyncService: Server sync-token updated after push: ${newServerSyncToken ?? "(null)"}');
                
                // Get current calendar properties to update ETag as well
                final serverPropertiesResult = await caldavService.getCalendarProperties(calendar);
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
                AppLogger.info('🔄 SyncService: Server sync token unchanged after queue processing');
              }
            },
            failure: (failure) async {
              AppLogger.warning('🔄 SyncService: Could not get updated sync token after push: ${failure.message}');
            },
          );
          return true;
        }
        
        // Si aucun des deux tests n'est vrai, rien à faire
        if (localSyncToken == serverSyncToken && !hasQueuedOperations) {
          //AppLogger.debug('🔄 SyncService: No changes needed for ${calendar.path}');
        }
        
        return true;
      },
      failure: (failure) async {
        AppLogger.warning('🔄 SyncService: Could not get server sync token for ${calendar.path}: ${failure.message}');
        // Fallback: traiter la queue si elle existe
        final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
        if (hasQueuedOperations) {
          //AppLogger.debug('🔄 SyncService: Fallback - processing queue without sync token verification');
          await _processSyncQueueForCalendar(caldavService, calendar.path, errors);
        }
        errors.add('Could not verify sync state for ${calendar.path}: ${failure.message}');
        return false;
      },
    );
  }

  /// Public method to sync a single calendar (for use by monitor/services)
  Future<bool> syncCalendar(CaldavAccount account, TaskCalendar calendar, List<String> errors) async {
    final ICalDAVService caldavService = SyncService.caldavFactory(account);
    return _syncCalendar(caldavService, calendar, errors);
  }

  /// Process a single sync queue item
  Future<void> _processSyncQueueItem(SyncQueueItem item, ICalDAVService caldavService) async {
    switch (item.operation) {
      case SyncOperation.create:
        // Get the complete task from repository using taskUid (same pattern as UPDATE/DELETE)
        final taskUid = item.data['taskUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;
        
        if (taskUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing taskUid or calendarPath for create');
          throw Exception('Missing required data for task creation');
        }
        
        // Get the complete task from repository
        final taskResult = await _taskRepository.getById(taskUid);
        await taskResult.when(
          success: (task) async {
            if (task == null) {
              throw Exception('Task not found in repository: $taskUid');
            }
            
            // Get calendar path from repository for proper CalDAV path
            final calendarResult = await _calendarRepository.getById(calendarPath);
            await calendarResult.when(
              success: (calendar) async {
                if (calendar != null) {
                  final result = await caldavService.createTask(task, calendar.path);
                  await result.when(
                    success: (_) async {
                      //AppLogger.debug('SyncService: Created task ${task.uid} on server in calendar ${calendar.path}');
                    },
                    failure: (failure) async {
                      throw Exception('Failed to create task: ${failure.message}');
                    },
                  );
                } else {
                  throw Exception('Calendar not found: $calendarPath');
                }
              },
              failure: (failure) async {
                AppLogger.warning('SyncService: Could not find calendar $calendarPath for task creation');
                throw Exception('Calendar not found for task creation: ${failure.message}');
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
        // Get the complete task from repository using taskUid
        final taskUid = item.data['taskUid'] as String?;
        final calendarPath = item.data['calendarPath'] as String?;
        
        if (taskUid == null || calendarPath == null) {
          AppLogger.warning('SyncService: Missing taskUid or calendarPath for update');
          throw Exception('Missing required data for task update');
        }
        
        // Get the complete task from repository
        final taskResult = await _taskRepository.getById(taskUid);
        await taskResult.when(
          success: (task) async {
            if (task == null) {
              throw Exception('Task not found in repository: $taskUid');
            }
            
            // Get calendar path from repository
            final calendarResult = await _calendarRepository.getById(calendarPath);
            await calendarResult.when(
              success: (calendar) async {
                if (calendar != null) {
                  // Construct task URL: calendar.path + taskUid + .ics
                  final taskUrl = '${calendar.path}${taskUid}.ics';
                  
                  final result = await caldavService.updateTask(task, taskUrl);
                  await result.when(
                    success: (_) async {
                      // AppLogger.debug('SyncService: Updated task ${task.uid} on server at $taskUrl');
                    },
                    failure: (failure) async {
                      throw Exception('Failed to update task: ${failure.message}');
                    },
                  );
                } else {
                  throw Exception('Calendar not found: $calendarPath');
                }
              },
              failure: (failure) async {
                AppLogger.warning('SyncService: Could not find calendar $calendarPath for task update');
                throw Exception('Calendar not found for task update: ${failure.message}');
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
        // Construct task URL from calendar UID and task UID
        final calendarPath = item.data['calendarPath'] as String?;
        final taskUid = item.data['taskUid'] as String?;
        
        if (calendarPath != null && taskUid != null) {
          // Get calendar path from repository
          final calendarResult = await _calendarRepository.getById(calendarPath);
          await calendarResult.when(
            success: (calendar) async {
              if (calendar != null) {
                // Construct task URL: calendar.path + taskUid + .ics
                final taskUrl = '${calendar.path}${taskUid}.ics';
                // AppLogger.debug('SyncService: Constructed delete URL: $taskUrl');
                
                final result = await caldavService.deleteTask(taskUrl);
                await result.when(
                  success: (_) async {
                    // AppLogger.info('SyncService: Deleted task ${item.itemId} from server at $taskUrl');
                  },
                  failure: (failure) async {
                    throw Exception('Failed to delete task: ${failure.message}');
                  },
                );
              } else {
                throw Exception('Calendar not found: $calendarPath');
              }
            },
            failure: (failure) async {
              AppLogger.warning('SyncService: Could not find calendar $calendarPath for task deletion');
              throw Exception('Calendar not found for task deletion: ${failure.message}');
            },
          );
        } else {
          AppLogger.warning('SyncService: Missing calendarPath or taskUid for deletion');
          throw Exception('Missing required data for task deletion');
        }
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
            
            AppLogger.debug('SyncService: Found calendar ${calendar.displayName}, calling CalDAV update');
            
            // Update calendar properties on server
            final result = await caldavService.updateCalendarProperties(calendar);
            await result.when(
              success: (_) async {
                AppLogger.debug('SyncService: Updated calendar properties ${calendar.displayName} on server');
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
            final result = await caldavService.createCalendar(
              displayName: calendar.displayName,
              description: calendar.description,
              domain: calendar.flowitDomain,
              kanban: calendar.flowitKanban,
              author: calendar.flowitAuthor,
              owner: calendar.flowitOwner,
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
        // Get the calendar from repository using calendarPath
        final calendarPath = item.data['calendarPath'] as String?;
        
        AppLogger.debug('SyncService: Processing calendar deletion for: $calendarPath');
        
        if (calendarPath == null) {
          AppLogger.warning('SyncService: Missing calendarPath for calendar deletion');
          throw Exception('Missing required data for calendar deletion');
        }
        
        // Get the complete calendar from repository
        final calendarResult = await _calendarRepository.getById(calendarPath);
        await calendarResult.when(
          success: (calendar) async {
            if (calendar == null) {
              AppLogger.warning('SyncService: Calendar not found in repository: $calendarPath');
              throw Exception('Calendar not found in repository: $calendarPath');
            }
            
            AppLogger.debug('SyncService: Found calendar ${calendar.displayName}, calling CalDAV delete');
            
            // Delete calendar from server
            final result = await caldavService.deleteCalendar(calendar.path);
            await result.when(
              success: (_) async {
                AppLogger.info('SyncService: Deleted calendar ${calendar.displayName} from server');
              },
              failure: (failure) async {
                throw Exception('Failed to delete calendar: ${failure.message}');
              },
            );
          },
          failure: (failure) async {
            AppLogger.warning('SyncService: Could not find calendar $calendarPath for deletion');
            throw Exception('Calendar not found for deletion: ${failure.message}');
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
        final shareService = ShareService(account: caldavService.account);       
        final result = await shareService.exitShare(calendarPath);
        await result.when(
          success: (_) async {
          },
          failure: (failure) async {
            throw Exception('Failed to exit share: ${failure.message}');
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
          // AppLogger.debug('SyncService: Queued ${operation.name} operation for $itemId');
          
          // IMMEDIATE SYNC: Trigger sync immediately instead of waiting for timer
          _triggerImmediateSync();
          
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

  /// Trigger immediate sync (called after queuing operations)
  void _triggerImmediateSync() {
    // Use Future.microtask to avoid blocking the current operation
    Future.microtask(() async {
      try {
        final result = await syncAllActiveCaldav();
        result.when(
          success: (syncResult) {
            // Sync completed successfully
          },
          failure: (failure) {
            // Sync failed, will retry later
          },
        );
      } catch (e, stackTrace) {
        AppLogger.error('SyncService: Error during immediate sync', e, stackTrace);
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

  /// Get current sync token from server for a calendar
  Future<Result<String>> _getServerSyncToken(ICalDAVService caldavService, TaskCalendar calendar) async {
    try {
      // Use CalDAVService to get both sync token and ETag
      final propertiesResult = await caldavService.getCalendarProperties(calendar);
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
  Future<void> _syncFromServer(ICalDAVService caldavService, TaskCalendar calendar, String newSyncToken, List<String> errors) async {
    try {
      //AppLogger.debug('🔄 SyncService: Syncing from server for ${calendar.path}');
      
      // Use CalDAVMonitor logic for incremental sync
      final webdavClient = WebDAVClient.fromAccount(caldavService.account);
      
      // Check if calendar exists on server before attempting sync
      final calendarExists = await _checkCalendarExistsOnServer(webdavClient, calendar.path);
      if (!calendarExists) {
        AppLogger.info('SyncService: Calendar ${calendar.path} not found on server, attempting to create it');
        final createdSuccessfully = await _createCalendarOnServer(caldavService.account, calendar);
        if (!createdSuccessfully) {
          AppLogger.warning('SyncService: Failed to create calendar on server, skipping sync for ${calendar.path}');
          return;
        }
        AppLogger.info('SyncService: Successfully created calendar on server: ${calendar.path}');
      }
      
      if (calendar.syncToken == null) {
        // First sync - fetch all tasks
        final tasksResult = await caldavService.fetchTasks(calendarPath: calendar.path);
        await tasksResult.when(
          success: (remoteTasks) async {
            for (final task in remoteTasks) {
              final taskWithCalendar = task.copyWith(projectPath: calendar.path);
              await _taskRepository.saveFromSync(taskWithCalendar);
            }
            //AppLogger.debug('🔄 SyncService: Full sync completed - ${remoteTasks.length} tasks from ${calendar.path}');
          },
          failure: (failure) async {
            errors.add('Failed to fetch tasks from ${calendar.path}: ${failure.message}');
          },
        );
      } else {
        // Incremental sync using sync-collection
        final changesResult = await _getSyncChanges(webdavClient, calendar.path, calendar.syncToken!);
        await changesResult.when(
          success: (result) async {
            final changes = result['changes'] as List<dynamic>;
            //AppLogger.debug('🔄 SyncService: Processing ${changes.length} changes from server');
            
            // Process each change
            for (final change in changes) {
              final changeMap = change as Map<String, dynamic>;
              final changeType = changeMap['type'] as String;
              final href = changeMap['href'] as String;
              
              if (changeType == 'deleted') {
                // Delete task from local storage
                await _deleteTaskByHref(href, calendar.path);
                //AppLogger.debug('🔄 SyncService: Deleted task $href');
              } else if (changeType == 'updated') {
                // Create or update task in local storage
                final taskData = changeMap['task'] as Map<String, dynamic>;
                final task = Task.fromJson(taskData);
                final taskWithCalendar = task.copyWith(projectPath: calendar.path);
                await _taskRepository.saveFromSync(taskWithCalendar);
                //AppLogger.debug('🔄 SyncService: Updated task ${task.uid}');
              }
            }
          },
          failure: (failure) async {
            errors.add('Failed to get sync changes for ${calendar.path}: ${failure.message}');
          },
        );
      }
      
      // Get current calendar properties from server to update ETag
      final serverPropertiesResult = await caldavService.getCalendarProperties(calendar);
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
            await _updateSharingInformation(caldavService.account, freshCalendar);
          } else {
            AppLogger.warning('SyncService: Could not get fresh calendar for sharing update, using original');
            await _updateSharingInformation(caldavService.account, calendar);
          }
        },
        failure: (failure) async {
          AppLogger.warning('SyncService: Could not get fresh calendar for sharing update: ${failure.message}, using original');
          await _updateSharingInformation(caldavService.account, calendar);
        },
      );
      
      AppLogger.info('SyncService: Finished updating sharing information for calendar ${calendar.path}');
      
    } catch (e, stackTrace) {
      AppLogger.error('SyncService: Failed to sync from server for ${calendar.path}', e, stackTrace);
      errors.add('Failed to sync from server for ${calendar.path}: $e');
    }
  }

  /// Process sync queue operations for a specific calendar
  Future<void> _processSyncQueueForCalendar(ICalDAVService caldavService, String calendarPath, List<String> errors) async {
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

          //AppLogger.debug('🔄 SyncService: Found ${queueItems.length} queued operations for calendar $calendarPath');

          for (final item in queueItems) {
            try {
              await _processSyncQueueItem(item, caldavService);
              // Remove from queue on success
              await _localStorage.delete(syncQueueBoxName, item.id);
              AppLogger.debug('🔄 SyncService: Successfully processed and removed queue item ${item.id}');
            } catch (e) {
              AppLogger.error('SyncService: Failed to process queue item ${item.id}', e, StackTrace.current);
              AppLogger.error('SyncService: Failed to process queue item data : ${item.data}');
              
              if (item.retryCount >= maxRetryCount) {
                // Max retries reached, remove from queue
                errors.add('Max retries reached for item ${item.id}: $e');
                await _localStorage.delete(syncQueueBoxName, item.id);
              } else {
                // Increment retry count
                final updatedItem = item.copyWith(retryCount: item.retryCount + 1);
                await _localStorage.put(syncQueueBoxName, item.id, _mapFromSyncQueueItem(updatedItem));
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
  Future<void> _processOrphanedQueueItems(ICalDAVService caldavService, List<String> errors) async {
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
          for (final item in queueItems) {
            final calendarPath = item.data['calendarPath'] as String?;
            if (calendarPath != null) {
              final calendarResult = await _calendarRepository.getById(calendarPath);
              await calendarResult.when(
                success: (calendar) async {
                  if (calendar == null) {
                    // Calendar no longer exists locally, process the queue item
                    AppLogger.info('🔄 SyncService: Processing orphaned queue item for deleted calendar: $calendarPath');
                    try {
                      await _processSyncQueueItem(item, caldavService);
                      // Remove from queue on success
                      await _localStorage.delete(syncQueueBoxName, item.id);
                      AppLogger.info('🔄 SyncService: Successfully processed orphaned queue item ${item.id}');
                    } catch (e) {
                      AppLogger.error('SyncService: Failed to process orphaned queue item ${item.id}', e, StackTrace.current);
                      if (item.retryCount >= maxRetryCount) {
                        errors.add('Max retries reached for orphaned item ${item.id}: $e');
                        await _localStorage.delete(syncQueueBoxName, item.id);
                      } else {
                        // Increment retry count
                        final updatedItem = item.copyWith(retryCount: item.retryCount + 1);
                        await _localStorage.put(syncQueueBoxName, item.id, _mapFromSyncQueueItem(updatedItem));
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
  Future<void> _processRemainingQueueItems(ICalDAVService caldavService, Set<String> includedCalendarPaths, List<String> errors) async {
    try {
      final queueResult = await _localStorage.getAll<Map<String, dynamic>>(syncQueueBoxName);
      await queueResult.when(
        success: (queueData) async {
          final queueItems = queueData
              .map((data) => _mapToSyncQueueItem(data))
              .where((item) => item != null)
              .cast<SyncQueueItem>()
              .toList();

          for (final item in queueItems) {
            final calendarPath = item.data['calendarPath'] as String?;
            if (calendarPath == null) continue;
            if (includedCalendarPaths.contains(calendarPath)) continue; // already processed in regular loop

            // Ensure the calendar exists locally; if it does, process its queue now
            final calendarResult = await _calendarRepository.getById(calendarPath);
            await calendarResult.when(
              success: (calendar) async {
                if (calendar != null) {
                  try {
                    await _processSyncQueueItem(item, caldavService);
                    await _localStorage.delete(syncQueueBoxName, item.id);
                  } catch (e) {
                    if (item.retryCount >= maxRetryCount) {
                      errors.add('Max retries reached for item ${item.id}: $e');
                      await _localStorage.delete(syncQueueBoxName, item.id);
                    } else {
                      final updatedItem = item.copyWith(retryCount: item.retryCount + 1);
                      await _localStorage.put(syncQueueBoxName, item.id, _mapFromSyncQueueItem(updatedItem));
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
                  
                  final task = _parseVTODOFromCalendarData(vtodoContent);
                  
                  if (task != null) {
                    changes.add({
                      'href': href,
                      'etag': etag,
                      'type': 'updated',
                      'task': task.toJson(),
                    });
                    AppLogger.debug('🔄 SyncService: Added updated change for task ${task.uid}');
                  } else {
                    AppLogger.warning('🔄 SyncService: Failed to parse VTODO for $href');
                  }
                  break;
                }
              }
            } else {
              final vtodoContent = calendarDataElement.innerText;
              //AppLogger.debug('🔄 SyncService: VTODO content length: ${vtodoContent.length}');
              //AppLogger.debug('🔄 SyncService: VTODO content: $vtodoContent');
              
              final task = _parseVTODOFromCalendarData(vtodoContent);
              
              if (task != null) {
                changes.add({
                  'href': href,
                  'etag': etag,
                  'type': 'updated',
                  'task': task.toJson(),
                });
                //AppLogger.debug('🔄 SyncService: Added updated change for task ${task.uid}');
              } else {
                AppLogger.warning('🔄 SyncService: Failed to parse VTODO for $href');
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
    final caldavService = CalDAVService(account: account);
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
            await _processSyncQueueForCalendar(caldavService, calendar.path, errors);
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
          final ICalDAVService caldavService = SyncService.caldavFactory(account);
          final errors = <String>[];
          
          for (final calendar in selectedCalendars) {
            final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.path);
            if (hasQueuedOperations) {
              AppLogger.debug('SyncService: Processing queue for calendar ${calendar.path}');
              await _processSyncQueueForCalendar(caldavService, calendar.path, errors);
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
      final ICalDAVService caldavService = SyncService.caldavFactory(account);
      final createResult = await caldavService.createCalendar(
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
          final updatedCalendar = calendar.withSharedWith(membersJson);
          AppLogger.debug('SyncService: Updated calendar sharedWith field: "${updatedCalendar.sharedWith}"');
          
          await _calendarRepository.save(updatedCalendar);
          AppLogger.info('SyncService: Successfully saved sharing info for ${calendar.path} - ${members.length} members');
        },
        failure: (failure) async {
          // Log the error but don't fail the sync - sharing is optional
          AppLogger.warning('SyncService: Failed to get sharing info for ${calendar.path}: ${failure.message}');
          AppLogger.debug('SyncService: Sharing API error code: ${failure.code}');
          AppLogger.debug('SyncService: Sharing API error details: ${failure.exception}');
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
} 
