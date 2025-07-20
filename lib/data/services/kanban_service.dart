// Kanban service for managing kanban board configurations
// Handles kanban CRUD operations, default kanban creation, and synchronization
// Follows service layer pattern for business logic separation

import 'dart:convert';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../models/kanban.dart';
import '../models/task_calendar.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/account_repository.dart';
import '../services/caldav_service.dart';

class KanbanService {
  final CalendarRepository _calendarRepository;
  final AccountRepository _accountRepository;

  KanbanService({
    required CalendarRepository calendarRepository,
    required AccountRepository accountRepository,
  })  : _calendarRepository = calendarRepository,
        _accountRepository = accountRepository;

  /// Load kanbans for a project, creating default if none exist
  Future<Result<List<Kanban>>> loadKanbansForProject(String projectPath) async {
    try {
      AppLogger.info('KanbanService: Loading kanbans for project $projectPath');
      
      // Load from calendar (server-side storage)
      final calendarKanbans = await _loadKanbansFromCalendar(projectPath);
      if (calendarKanbans.isNotEmpty) {
        AppLogger.info('KanbanService: Found ${calendarKanbans.length} kanbans in calendar');
        return Result.success(calendarKanbans);
      }
      
      // If no kanbans, create a default one
      AppLogger.info('KanbanService: No kanbans found, creating default kanban');
      final defaultKanban = await _createDefaultKanban(projectPath);
      return Result.success([defaultKanban]);
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception loading kanbans', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to load kanbans: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }



  /// Load kanbans from calendar (server-side storage)
  Future<List<Kanban>> _loadKanbansFromCalendar(String projectPath) async {
    try {
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      
      return await calendarResult.when(
        success: (calendar) async {
          if (calendar != null && calendar.flowitKanban.isNotEmpty && calendar.flowitKanban != '[]') {
            try {
              final kanbanData = jsonDecode(calendar.flowitKanban);
              if (kanbanData is List && kanbanData.isNotEmpty) {
                AppLogger.info('KanbanService: Found ${kanbanData.length} kanbans in local calendar');
                return kanbanData
                    .map((data) => Kanban.fromJson(Map<String, dynamic>.from(data)))
                    .toList();
              }
            } catch (e) {
              AppLogger.warning('KanbanService: Failed to parse kanbans from calendar: $e');
            }
          }
          
          AppLogger.info('KanbanService: No kanbans in local calendar, checking server...');
          return await _loadKanbansFromServer(projectPath);
        },
        failure: (failure) async {
          AppLogger.warning('KanbanService: Failed to load calendar: ${failure.message}');
          return [];
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception loading from calendar', e, stackTrace);
      return [];
    }
  }

  /// Load kanbans directly from server when local data is missing
  Future<List<Kanban>> _loadKanbansFromServer(String projectPath) async {
    try {
      // Get active account to query server
      final accountResult = await _accountRepository.getActiveAccount();
      return await accountResult.when(
        success: (account) async {
          if (account == null) {
            AppLogger.warning('KanbanService: No active account, cannot check server');
            return [];
          }

          // Use CalDAV service to refresh calendar info from server
          final caldavService = CalDAVService(account: account);
          
          // Create a minimal calendar object to get properties
          final tempCalendar = TaskCalendarFactory.fromCalDAVDiscovery(
            path: projectPath,
            displayName: 'Temp',
          );
          
          final refreshResult = await caldavService.getCalendarProperties(tempCalendar);
          
          return await refreshResult.when(
            success: (updatedCalendar) async {
              if (updatedCalendar != null && 
                  updatedCalendar.flowitKanban.isNotEmpty && 
                  updatedCalendar.flowitKanban != '[]') {
                try {
                  final kanbanData = jsonDecode(updatedCalendar.flowitKanban);
                  if (kanbanData is List && kanbanData.isNotEmpty) {
                    AppLogger.info('KanbanService: Found ${kanbanData.length} kanbans from server');
                    
                    // Save the updated calendar to local repository
                    await _calendarRepository.save(updatedCalendar);
                    
                    return kanbanData
                        .map((data) => Kanban.fromJson(Map<String, dynamic>.from(data)))
                        .toList();
                  }
                } catch (e) {
                  AppLogger.warning('KanbanService: Failed to parse kanbans from server: $e');
                }
              }
              
              AppLogger.info('KanbanService: No kanbans found on server either');
              return [];
            },
            failure: (failure) async {
              AppLogger.warning('KanbanService: Failed to refresh calendar from server: ${failure.message}');
              return [];
            },
          );
        },
        failure: (failure) async {
          AppLogger.warning('KanbanService: Failed to get active account: ${failure.message}');
          return [];
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception loading from server', e, stackTrace);
      return [];
    }
  }



  /// Create a default kanban configuration for a project
  Future<Kanban> _createDefaultKanban(String projectPath) async {
    try {
      AppLogger.info('KanbanService: Creating default kanban for project $projectPath');
      
      const defaultKanban = Kanban(
        title: 'Default',
        orderedList: [],
        filter: [],
        regex: r'.*',
      );
      
      // Sync to server
      await _syncKanbanToServer(projectPath, [defaultKanban]);
      
      AppLogger.info('KanbanService: Successfully created default kanban');
      return defaultKanban;
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception creating default kanban', e, stackTrace);
      // Return the default kanban even if sync fails
      return const Kanban(
        title: 'Default',
        orderedList: [],
        filter: [],
        regex: r'.*',
      );
    }
  }

  /// Save kanbans for a project
  Future<Result<void>> saveKanbansForProject(String projectPath, List<Kanban> kanbans) async {
    try {
      AppLogger.info('KanbanService: Saving ${kanbans.length} kanbans for project $projectPath');
      
      // Sync to server
      await _syncKanbanToServer(projectPath, kanbans);
      
      AppLogger.info('KanbanService: Successfully saved kanbans');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception saving kanbans', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to save kanbans: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Sync kanban to CalDAV server
  Future<void> _syncKanbanToServer(String projectPath, List<Kanban> kanbans) async {
    try {
      AppLogger.info('KanbanService: *** Starting kanban sync to server ***');
      AppLogger.info('KanbanService: Project path: $projectPath');
      
      // Get the calendar to update
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      
      await calendarResult.when(
        success: (calendar) async {
          if (calendar != null) {
            // Update the flowitKanban field
            final kanbanJson = jsonEncode(kanbans.map((k) => k.toJson()).toList());
            final updatedCalendar = calendar.copyWith(
              flowitKanban: kanbanJson,
              lastModified: DateTime.now(),
            );
            
            // Save locally first
            final saveResult = await _calendarRepository.save(updatedCalendar);
            await saveResult.when(
              success: (_) async {
                AppLogger.info('KanbanService: Saved kanban locally for project $projectPath');
                
                // Get active account
                final accountResult = await _accountRepository.getActiveAccount();
                await accountResult.when(
                  success: (account) async {
                    if (account == null) {
                      AppLogger.warning('KanbanService: No active account found, skipping server sync');
                      return;
                    }
                    
                    AppLogger.info('KanbanService: Found active account: ${account.username}@${account.serverUrl}');
                    
                    // Create CalDAV service instance
                    final caldavService = CalDAVService(account: account);
                    AppLogger.info('KanbanService: Created CalDAV service, calling updateCalendarProperties...');
                    
                    // Update calendar properties on server
                    final updateResult = await caldavService.updateCalendarProperties(updatedCalendar);
                    
                    await updateResult.when(
                      success: (_) {
                        AppLogger.info('KanbanService: *** Successfully synced kanban to server ***');
                      },
                      failure: (failure) {
                        AppLogger.error('KanbanService: Failed to sync kanban to server: ${failure.message}');
                        AppLogger.error('KanbanService: Failure code: ${failure.code}');
                        // Don't fail the entire operation since local save succeeded
                        // The sync will be retried during next full sync
                      },
                    );
                  },
                  failure: (failure) {
                    AppLogger.error('KanbanService: Failed to get active account for server sync: ${failure.message}');
                    AppLogger.error('KanbanService: Account failure code: ${failure.code}');
                    // Don't fail the entire operation since local save succeeded
                  },
                );
              },
              failure: (failure) async {
                AppLogger.error('KanbanService: Failed to save kanban locally: ${failure.message}');
              },
            );
          }
        },
        failure: (failure) async {
          AppLogger.warning('KanbanService: Failed to get calendar: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception during server sync', e, stackTrace);
      // Don't fail the entire operation since local save succeeded
    }
  }

  /// Create a new kanban configuration
  Future<Result<Kanban>> createKanban({
    required String projectPath,
    required String title,
    List<String>? orderedList,
    List<String>? filter,
    String? regex,
  }) async {
    try {
      AppLogger.info('KanbanService: Creating kanban "$title" for project $projectPath');

      final kanban = Kanban(
        title: title,
        orderedList: orderedList ?? [],
        filter: filter ?? [],
        regex: regex ?? r'.*', // Default "capture all" regex pattern
      );

      // Load current kanbans
      final currentKanbansResult = await loadKanbansForProject(projectPath);
      final currentKanbans = await currentKanbansResult.when(
        success: (kanbans) async => kanbans,
        failure: (failure) async {
          AppLogger.warning('KanbanService: Failed to load current kanbans, starting with empty list');
          return <Kanban>[];
        },
      );

      final updatedKanbans = [...currentKanbans, kanban];
      
      // Save all kanbans
      final saveResult = await saveKanbansForProject(projectPath, updatedKanbans);
      
      return await saveResult.when(
        success: (_) async {
          AppLogger.info('KanbanService: Successfully created kanban "$title"');
          return Result.success(kanban);
        },
        failure: (failure) async {
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception creating kanban', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to create kanban: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Update an existing kanban configuration
  Future<Result<Kanban>> updateKanban({
    required String projectPath,
    required Kanban updatedKanban,
  }) async {
    try {
      AppLogger.info('KanbanService: Updating kanban "${updatedKanban.title}" for project $projectPath');

      // Load current kanbans
      final currentKanbansResult = await loadKanbansForProject(projectPath);
      final currentKanbans = await currentKanbansResult.when(
        success: (kanbans) async => kanbans,
        failure: (failure) async {
          AppLogger.warning('KanbanService: Failed to load current kanbans, starting with empty list');
          return <Kanban>[];
        },
      );

      final updatedKanbans = currentKanbans.map((kanban) {
        // Find the kanban to update (by title for now)
        if (kanban.title == updatedKanban.title) {
          return updatedKanban;
        }
        return kanban;
      }).toList();

      // Save all kanbans
      final saveResult = await saveKanbansForProject(projectPath, updatedKanbans);
      
      return await saveResult.when(
        success: (_) async {
          AppLogger.info('KanbanService: Successfully updated kanban "${updatedKanban.title}"');
          return Result.success(updatedKanban);
        },
        failure: (failure) async {
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception updating kanban', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to update kanban: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  /// Delete a kanban configuration
  Future<Result<void>> deleteKanban({
    required String projectPath,
    required String title,
  }) async {
    try {
      AppLogger.info('KanbanService: Deleting kanban "$title" from project $projectPath');

      // Load current kanbans
      final currentKanbansResult = await loadKanbansForProject(projectPath);
      final currentKanbans = await currentKanbansResult.when(
        success: (kanbans) async => kanbans,
        failure: (failure) async {
          AppLogger.warning('KanbanService: Failed to load current kanbans, starting with empty list');
          return <Kanban>[];
        },
      );

      final updatedKanbans = currentKanbans.where((kanban) => kanban.title != title).toList();

      // Save all kanbans
      final saveResult = await saveKanbansForProject(projectPath, updatedKanbans);
      
      return await saveResult.when(
        success: (_) async {
          AppLogger.info('KanbanService: Successfully deleted kanban "$title"');
          return const Result.success(null);
        },
        failure: (failure) async {
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanService: Exception deleting kanban', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete kanban: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 