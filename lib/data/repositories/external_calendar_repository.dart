// External calendar repository interface and local implementation
// Follows repository pattern for external calendar data access
// External calendars are read-only calendars from external CalDAV sources

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/external_calendar.dart';
import '../services/local_storage_service.dart';

// Abstract repository interface
abstract class ExternalCalendarRepository {
  Future<Result<List<ExternalCalendar>>> getAll();
  Future<Result<ExternalCalendar?>> getById(String uid);
  Future<Result<ExternalCalendar?>> getByPath(String path);
  Future<Result<void>> save(ExternalCalendar calendar);
  Future<Result<void>> delete(String uid);
  Stream<List<ExternalCalendar>> watchCalendars();
  Future<Result<List<ExternalCalendar>>> getEnabledCalendars();
  Future<Result<List<ExternalCalendar>>> getCalendarsByAccount(String accountId);
  Future<Result<void>> deleteCalendarsByAccount(String accountId);
  Future<Result<void>> enableCalendar(String uid, bool enabled);
  Future<Result<Map<String, int>>> getAccountStatistics();
  Future<Result<void>> setEnabled(String uid, bool enabled);
  Future<Result<void>> updateSyncStatus(String uid, {
    DateTime? lastSyncAt,
    DateTime? lastSuccessfulSync,
    String? lastSyncError,
    int? syncErrorCount,
  });
  Future<Result<void>> updateSyncToken(String uid, String? syncToken);
}

// Local implementation using Hive
class LocalExternalCalendarRepository implements ExternalCalendarRepository {
  final LocalStorageService _storageService;
  static const String _boxName = 'external_calendars';

  LocalExternalCalendarRepository(this._storageService);

  @override
  Future<Result<List<ExternalCalendar>>> getAll() async {
    final result = await _storageService.getAll<ExternalCalendar>(_boxName);
    return result.when(
      success: (calendars) {
        AppLogger.info('LocalExternalCalendarRepository: Found ${calendars.length} external calendars');
        return Result.success(calendars);
      },
      failure: (failure) {
        AppLogger.error('LocalExternalCalendarRepository: Failed to get external calendars: ${failure.message}');
        return Result.failure(failure);
      },
    );
  }

  @override
  Future<Result<ExternalCalendar?>> getById(String uid) async {
    return await _storageService.get<ExternalCalendar>(_boxName, uid);
  }

  @override
  Future<Result<ExternalCalendar?>> getByPath(String path) async {
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
  Future<Result<void>> save(ExternalCalendar calendar) async {
    return await _storageService.put(_boxName, calendar.uid, calendar);
  }

  @override
  Future<Result<void>> delete(String uid) async {
    return await _storageService.delete(_boxName, uid);
  }

  @override
  Stream<List<ExternalCalendar>> watchCalendars() async* {
    // Emit initial value
    final result = await getAll();
    yield result.when(
      success: (calendars) => calendars,
      failure: (_) => <ExternalCalendar>[],
    );
    
    // Then listen to changes
    yield* _storageService.getStream(_boxName)
        .asyncMap((_) async {
          final result = await getAll();
          return result.when(
            success: (calendars) => calendars,
            failure: (_) => <ExternalCalendar>[],
          );
        });
  }

  @override
  Future<Result<List<ExternalCalendar>>> getEnabledCalendars() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final enabledCalendars = calendars.where((c) => c.isEnabled).toList();
        AppLogger.info('LocalExternalCalendarRepository: Found ${enabledCalendars.length} enabled external calendars');
        return Result.success(enabledCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<ExternalCalendar>>> getCalendarsByAccount(String accountId) async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final accountCalendars = calendars.where((c) => c.accountId == accountId).toList();
        AppLogger.info('LocalExternalCalendarRepository: Found ${accountCalendars.length} calendars for account $accountId');
        return Result.success(accountCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> deleteCalendarsByAccount(String accountId) async {
    final result = await getCalendarsByAccount(accountId);
    return result.when(
      success: (calendars) async {
        AppLogger.info('LocalExternalCalendarRepository: Deleting ${calendars.length} calendars for account $accountId');
        
        for (final calendar in calendars) {
          final deleteResult = await delete(calendar.uid);
          if (deleteResult is Error<void>) {
            AppLogger.error('LocalExternalCalendarRepository: Failed to delete calendar ${calendar.uid}: ${deleteResult.failure.message}');
            return deleteResult;
          }
        }
        
        return Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> enableCalendar(String uid, bool enabled) async {
    final getResult = await getById(uid);
    return getResult.when(
      success: (calendar) async {
        if (calendar != null) {
          final updatedCalendar = calendar.withEnabled(enabled);
          return await save(updatedCalendar);
        } else {
          return Result.failure(Failure(
            message: 'Calendar not found: $uid',
            exception: Exception('Calendar not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getAccountStatistics() async {
    final result = await getAll();
    return result.when(
      success: (calendars) {
        final statistics = <String, int>{};
        
        for (final calendar in calendars) {
          final accountId = calendar.accountId;
          statistics[accountId] = (statistics[accountId] ?? 0) + 1;
        }
        
        AppLogger.info('LocalExternalCalendarRepository: Account statistics calculated for ${statistics.length} accounts');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> setEnabled(String uid, bool enabled) async {
    return await enableCalendar(uid, enabled);
  }

  @override
  Future<Result<void>> updateSyncStatus(String uid, {
    DateTime? lastSyncAt,
    DateTime? lastSuccessfulSync,
    String? lastSyncError,
    int? syncErrorCount,
  }) async {
    final getResult = await getById(uid);
    return getResult.when(
      success: (calendar) async {
        if (calendar != null) {
          final updatedCalendar = calendar.copyWith(
            lastSyncAt: lastSyncAt,
            lastSuccessfulSync: lastSuccessfulSync,
            lastSyncError: lastSyncError,
            syncErrorCount: syncErrorCount ?? calendar.syncErrorCount,
            lastModified: DateTime.now(),
          );
          return await save(updatedCalendar);
        } else {
          return Result.failure(Failure(
            message: 'Calendar not found: $uid',
            exception: Exception('Calendar not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> updateSyncToken(String uid, String? syncToken) async {
    final getResult = await getById(uid);
    return getResult.when(
      success: (calendar) async {
        if (calendar != null) {
          final updatedCalendar = calendar.copyWith(
            syncToken: syncToken,
            lastModified: DateTime.now(),
          );
          return await save(updatedCalendar);
        } else {
          return Result.failure(Failure(
            message: 'Calendar not found: $uid',
            exception: Exception('Calendar not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }
}

// Extension for external calendar repository operations
extension ExternalCalendarRepositoryExtensions on ExternalCalendarRepository {
  /// Get all calendars that are active for sync (enabled and support VEVENT)
  Future<Result<List<ExternalCalendar>>> getActiveForSync() async {
    final result = await getEnabledCalendars();
    return result.when(
      success: (calendars) {
        final activeCalendars = calendars.where((c) => c.isActiveForSync).toList();
        return Result.success(activeCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Update calendar statistics after sync
  Future<Result<void>> updateCalendarStats(String uid, {
    String? syncToken,
    DateTime? lastSyncAt,
    int? eventCount,
    DateTime? lastEventDate,
    DateTime? nextEventDate,
  }) async {
    final getResult = await getById(uid);
    return getResult.when(
      success: (calendar) async {
        if (calendar != null) {
          final updatedCalendar = calendar.withSyncUpdate(
            syncToken: syncToken,
            lastSyncAt: lastSyncAt,
            eventCount: eventCount,
            lastEventDate: lastEventDate,
            nextEventDate: nextEventDate,
          );
          return await save(updatedCalendar);
        } else {
          return Result.failure(Failure(
            message: 'Calendar not found: $uid',
            exception: Exception('Calendar not found'),
          ));
        }
      },
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Get calendars that need sync (enabled and haven't synced recently)
  Future<Result<List<ExternalCalendar>>> getCalendarsNeedingSync({Duration? maxAge}) async {
    final result = await getEnabledCalendars();
    return result.when(
      success: (calendars) {
        final now = DateTime.now();
        final maxSyncAge = maxAge ?? const Duration(minutes: 15);
        
        final needingSyncCalendars = calendars.where((calendar) {
          // Include calendars that have never synced or haven't synced recently
          if (calendar.lastSyncAt == null) return true;
          
          final timeSinceSync = now.difference(calendar.lastSyncAt!);
          return timeSinceSync > maxSyncAge;
        }).toList();
        
        return Result.success(needingSyncCalendars);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
} 