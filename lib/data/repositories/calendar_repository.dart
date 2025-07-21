// Calendar repository interface and local implementation
// Follows repository pattern for calendar/project data access
// Calendars represent projects at VCALENDAR level according to FlowIt specs

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';

// Abstract repository interface
abstract class CalendarRepository {
  Future<Result<List<TaskCalendar>>> getAll();
  Future<Result<TaskCalendar?>> getById(String uid);
  Future<Result<TaskCalendar?>> getByPath(String path);
  Future<Result<void>> save(TaskCalendar calendar);
  Future<Result<void>> delete(String uid);
  Stream<List<TaskCalendar>> watchCalendars();
  Future<Result<List<TaskCalendar>>> getProjectCalendars();
  
  // Domain-related methods
  Future<Result<List<TaskCalendar>>> getCalendarsByDomain(String? domain);
  Future<Result<List<String>>> getUniqueDomains();
  Future<Result<void>> renameDomain(String oldDomain, String newDomain);
  Future<Result<Map<String, int>>> getDomainStatistics();
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutDomain();
  
  // Status-related methods
  Future<Result<List<TaskCalendar>>> getCalendarsByStatus(String? status);
  Future<Result<List<String>>> getUniqueStatuses();
  Future<Result<void>> changeStatus(String oldStatus, String newStatus);
  Future<Result<Map<String, int>>> getStatusStatistics();
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutStatus();
  Future<Result<List<TaskCalendar>>> getArchivedCalendars();
  Future<Result<List<TaskCalendar>>> getActiveCalendars();
  
  // Sync-related methods
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar);
}

// Local implementation using Hive
class LocalCalendarRepository implements CalendarRepository {
  final LocalStorageService _storageService;

  LocalCalendarRepository(this._storageService);

  @override
  Future<Result<List<TaskCalendar>>> getAll() async {
    final result = await _storageService.getAll<TaskCalendar>(LocalStorageService.calendarsBoxName);
    return result.when(
      success: (calendars) {
        // AppLogger.info('LocalCalendarRepository: Found ${calendars.length} calendars');
        return Result.success(calendars);
      },
      failure: (failure) {
        AppLogger.error('LocalCalendarRepository: Failed to get calendars: ${failure.message}');
        return Result.failure(failure);
      },
    );
  }

  @override
  Future<Result<TaskCalendar?>> getById(String uid) async {
    return await _storageService.get<TaskCalendar>(LocalStorageService.calendarsBoxName, uid);
  }

  @override
  Future<Result<TaskCalendar?>> getByPath(String path) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final calendar = calendars.where((c) => c.path == path).firstOrNull;
        return Result.success(calendar);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> save(TaskCalendar calendar) async {
    return await _storageService.put(LocalStorageService.calendarsBoxName, calendar.path, calendar);
  }

  @override
  Future<Result<void>> delete(String uid) async {
    return await _storageService.delete(LocalStorageService.calendarsBoxName, uid);
  }

  @override
  Stream<List<TaskCalendar>> watchCalendars() async* {
    // Emit initial value
    final result = await getAll();
    yield result.when(
      success: (calendars) => calendars,
      failure: (_) => <TaskCalendar>[],
    );
    
    // Then listen to changes
    yield* _storageService.getStream(LocalStorageService.calendarsBoxName)
        .asyncMap((_) async {
          final result = await getAll();
          return result.when(
            success: (calendars) => calendars,
            failure: (_) => <TaskCalendar>[],
          );
        });
  }

  @override
  Future<Result<List<TaskCalendar>>> getProjectCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        // All calendars that support VTODO and are not archived are projects
        final projects = calendars.where((c) => c.supportsTodos && !c.isArchived).toList();
        // AppLogger.info('LocalCalendarRepository: Found  [32m${projects.length} [0m active project calendars (all synchronized VTODO calendars)');
        return Result.success(projects);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsByDomain(String? domain) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final filteredCalendars = calendars.where((calendar) {
          if (domain == null || domain.toLowerCase() == 'no domain') {
            return !calendar.hasDomain;
          }
          return calendar.belongsToDomain(domain);
        }).toList();
        
        AppLogger.info('LocalCalendarRepository: Found ${filteredCalendars.length} calendars in domain: ${domain ?? "No Domain"}');
        return Result.success(filteredCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<String>>> getUniqueDomains() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final domains = calendars
            .where((calendar) => calendar.hasDomain)
            .map((calendar) => calendar.flowitDomain!)
            .toSet()
            .toList();
        
        // Sort domains alphabetically (case-insensitive)
        domains.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        
        AppLogger.info('LocalCalendarRepository: Found ${domains.length} unique domains');
        return Result.success(domains);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> renameDomain(String oldDomain, String newDomain) async {
    final result = await getAll();
    return result.when(
      success: (calendars) async {
        final calendarsToUpdate = calendars
            .where((calendar) => calendar.belongsToDomain(oldDomain))
            .toList();
        
        AppLogger.info('LocalCalendarRepository: Renaming domain "$oldDomain" to "$newDomain" for ${calendarsToUpdate.length} calendars');
        
        for (final calendar in calendarsToUpdate) {
          final updatedCalendar = calendar.withDomain(newDomain);
          final saveResult = await save(updatedCalendar);
          if (saveResult is Error<void>) {
            AppLogger.error('LocalCalendarRepository: Failed to rename domain for calendar ${calendar.path}: ${saveResult.failure.message}');
            return saveResult;
          }
        }
        
        return Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getDomainStatistics() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statistics = <String, int>{};
        
        for (final calendar in calendars) {
          final domain = calendar.domainDisplayName;
          statistics[domain] = (statistics[domain] ?? 0) + 1;
        }
        
        AppLogger.info('LocalCalendarRepository: Domain statistics calculated for ${statistics.length} domains');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutDomain() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final calendarsWithoutDomain = calendars.where((calendar) => !calendar.hasDomain).toList();
        AppLogger.info('LocalCalendarRepository: Found ${calendarsWithoutDomain.length} calendars without domain');
        return Result.success(calendarsWithoutDomain);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsByStatus(String? status) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
                 final filteredCalendars = calendars.where((calendar) {
           if (status == null || status.toLowerCase() == 'no status') {
             return !calendar.hasStatus;
           }
           return calendar.hasProjectStatus(status);
         }).toList();
        
        AppLogger.info('LocalCalendarRepository: Found ${filteredCalendars.length} calendars in status: ${status ?? "No Status"}');
        return Result.success(filteredCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<String>>> getUniqueStatuses() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statuses = calendars
            .where((calendar) => calendar.hasStatus)
            .map((calendar) => calendar.flowitStatus!)
            .toSet()
            .toList();
        
        // Sort statuses alphabetically (case-insensitive)
        statuses.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        
        AppLogger.info('LocalCalendarRepository: Found ${statuses.length} unique statuses');
        return Result.success(statuses);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> changeStatus(String oldStatus, String newStatus) async {
    final result = await getAll();
    return result.when(
      success: (calendars) async {
                 final calendarsToUpdate = calendars
             .where((calendar) => calendar.hasProjectStatus(oldStatus))
             .toList();
        
        AppLogger.info('LocalCalendarRepository: Changing status from "$oldStatus" to "$newStatus" for ${calendarsToUpdate.length} calendars');
        
        for (final calendar in calendarsToUpdate) {
          final updatedCalendar = calendar.withStatus(newStatus);
          final saveResult = await save(updatedCalendar);
          if (saveResult is Error<void>) {
            AppLogger.error('LocalCalendarRepository: Failed to change status for calendar ${calendar.path}: ${saveResult.failure.message}');
            return saveResult;
          }
        }
        
        return Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getStatusStatistics() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statistics = <String, int>{};
        
        for (final calendar in calendars) {
          final status = calendar.statusDisplayName;
          statistics[status] = (statistics[status] ?? 0) + 1;
        }
        
        AppLogger.info('LocalCalendarRepository: Status statistics calculated for ${statistics.length} statuses');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutStatus() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final calendarsWithoutStatus = calendars.where((calendar) => !calendar.hasStatus).toList();
        AppLogger.info('LocalCalendarRepository: Found ${calendarsWithoutStatus.length} calendars without status');
        return Result.success(calendarsWithoutStatus);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getArchivedCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final archivedCalendars = calendars.where((calendar) => calendar.isArchived).toList();
        AppLogger.info('LocalCalendarRepository: Found ${archivedCalendars.length} archived calendars');
        return Result.success(archivedCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<TaskCalendar>>> getActiveCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final activeCalendars = calendars.where((calendar) => !calendar.isArchived).toList();
        AppLogger.info('LocalCalendarRepository: Found ${activeCalendars.length} active calendars');
        return Result.success(activeCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async {
    try {
      AppLogger.info('LocalCalendarRepository: Updating calendar properties for ${calendar.displayName}');
      AppLogger.debug('LocalCalendarRepository: Calendar path: ${calendar.path}');
      
      final saveResult = await save(calendar); // Save locally first
      
      return await saveResult.when(
        success: (_) async {
          AppLogger.debug('LocalCalendarRepository: Calendar saved locally, queuing server sync');
          
          // Always use sync queue for offline resilience via singleton
          final syncService = SyncService.instance;
          if (syncService != null) {
            AppLogger.debug('LocalCalendarRepository: SyncService singleton found, queuing calendar update');
            AppLogger.debug('LocalCalendarRepository: Queuing update for calendar path: ${calendar.path}');
            
            final queueResult = await syncService.queueCalendarUpdate(calendar.path);
            
            return await queueResult.when(
              success: (_) async {
                AppLogger.info('LocalCalendarRepository: Successfully queued calendar properties update');
                return Result.success(null);
              },
              failure: (failure) async {
                AppLogger.error('LocalCalendarRepository: Failed to queue calendar update: ${failure.message}');
                return Result.failure(failure);
              },
            );
          } else {
            AppLogger.error('LocalCalendarRepository: SyncService singleton is NULL - cannot queue update');
            AppLogger.error('LocalCalendarRepository: This indicates the SyncService was not properly initialized');
            return Result.failure(Failure(
              message: 'SyncService not initialized',
              exception: Exception('SyncService singleton not available - check initialization order'),
            ));
          }
        },
        failure: (failure) async {
          AppLogger.error('LocalCalendarRepository: Failed to save calendar locally: ${failure.message}');
          return Result.failure(failure);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('LocalCalendarRepository: Exception updating calendar properties', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to update calendar properties: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 
