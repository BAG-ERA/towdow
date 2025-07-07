// External event repository interface and local implementation
// Follows repository pattern for external calendar event data access
// External events are read-only events from external CalDAV sources

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/calendar_event.dart';
import '../services/local_storage_service.dart';

// Abstract repository interface
abstract class ExternalEventRepository {
  Future<Result<List<CalendarEvent>>> getAll();
  Future<Result<CalendarEvent?>> getById(String uid);
  Future<Result<List<CalendarEvent>>> getByCalendar(String calendarUid);
  Future<Result<List<CalendarEvent>>> getByAccount(String accountId);
  Future<Result<void>> save(CalendarEvent event);
  Future<Result<void>> saveAll(List<CalendarEvent> events);
  Future<Result<void>> delete(String uid);
  Future<Result<void>> deleteByCalendar(String calendarUid);
  Future<Result<void>> deleteByAccount(String accountId);
  Stream<List<CalendarEvent>> watchEvents();
  Stream<List<CalendarEvent>> watchEventsByCalendar(String calendarUid);
  
  // Query methods
  Future<Result<List<CalendarEvent>>> getEventsInRange(DateTime start, DateTime end);
  Future<Result<List<CalendarEvent>>> getTodayEvents();
  Future<Result<List<CalendarEvent>>> getUpcomingEvents({int days = 7});
  Future<Result<List<CalendarEvent>>> getEventsByCategory(String category);
  Future<Result<List<CalendarEvent>>> searchEvents(String query);
  
  // Statistics
  Future<Result<Map<String, int>>> getCalendarStatistics();
  Future<Result<Map<String, int>>> getAccountStatistics();
  
  // Additional methods for sync operations
  Future<Result<void>> deleteByUrl(String url);
  Future<Result<void>> deleteByCalendarId(String calendarId);
  Future<Result<int>> countByAccountId(String accountId);
}

// Local implementation using Hive
class LocalExternalEventRepository implements ExternalEventRepository {
  final LocalStorageService _storageService;
  static const String _boxName = 'external_events';

  LocalExternalEventRepository(this._storageService);

  @override
  Future<Result<List<CalendarEvent>>> getAll() async {
    final result = await _storageService.getAll<CalendarEvent>(_boxName);
    return result.when(
      success: (events) {
        // Convert UTC events to local time for display
        final localEvents = _convertEventsToLocalTime(events);
        AppLogger.info('LocalExternalEventRepository: Found ${localEvents.length} external events (converted to local time)');
        return Result.success(localEvents);
      },
      failure: (failure) {
        AppLogger.error('LocalExternalEventRepository: Failed to get external events: ${failure.message}');
        return Result.failure(failure);
      },
    );
  }

  /// Convert UTC events to local time for display
  List<CalendarEvent> _convertEventsToLocalTime(List<CalendarEvent> events) {
    final now = DateTime.now();
    return events.map((event) {
      final rawDtstart = event.dtstart;
      final localDtstart = rawDtstart.toLocal();
      DateTime? rawDtend = event.dtend;
      DateTime? localDtend = rawDtend?.toLocal();
      // Log all info in one entry
      AppLogger.info(
        'Event: "${event.summary}" | Raw UTC start: $rawDtstart | Local start: $localDtstart | Raw UTC end: $rawDtend | Local end: $localDtend | Current local time: $now'
      );
      return event.copyWith(
        dtstart: localDtstart,
        dtend: localDtend,
      );
    }).toList();
  }

  @override
  Future<Result<CalendarEvent?>> getById(String uid) async {
    return await _storageService.get<CalendarEvent>(_boxName, uid);
  }

  @override
  Future<Result<List<CalendarEvent>>> getByCalendar(String calendarUid) async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final calendarEvents = events.where((e) => e.sourceCalendarUid == calendarUid).toList();
        AppLogger.info('LocalExternalEventRepository: Found ${calendarEvents.length} events for calendar $calendarUid');
        return Result.success(calendarEvents);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<CalendarEvent>>> getByAccount(String accountId) async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final accountEvents = events.where((e) => e.accountId == accountId).toList();
        AppLogger.info('LocalExternalEventRepository: Found ${accountEvents.length} events for account $accountId');
        return Result.success(accountEvents);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> save(CalendarEvent event) async {
    AppLogger.debug('LocalExternalEventRepository: Saving event "${event.summary}" (UID: ${event.uid}) from calendar ${event.sourceCalendarUid} in account ${event.accountId}');
    return await _storageService.put(_boxName, event.uid, event);
  }

  @override
  Future<Result<void>> saveAll(List<CalendarEvent> events) async {
    try {
      for (final event in events) {
        final result = await save(event);
        if (result is Error<void>) {
          return result;
        }
      }
      AppLogger.info('LocalExternalEventRepository: Saved ${events.length} events');
      return const Result.success(null);
    } catch (e, stackTrace) {
      AppLogger.error('LocalExternalEventRepository: Failed to save events', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to save events: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> delete(String uid) async {
    return await _storageService.delete(_boxName, uid);
  }

  @override
  Future<Result<void>> deleteByCalendar(String calendarUid) async {
    final result = await getByCalendar(calendarUid);
    return result.when(
      success: (events) async {
        AppLogger.info('LocalExternalEventRepository: Deleting ${events.length} events for calendar $calendarUid');
        
        for (final event in events) {
          final deleteResult = await delete(event.uid);
          if (deleteResult is Error<void>) {
            AppLogger.error('LocalExternalEventRepository: Failed to delete event ${event.uid}: ${deleteResult.failure.message}');
            return deleteResult;
          }
        }
        
        return const Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> deleteByAccount(String accountId) async {
    final result = await getByAccount(accountId);
    return result.when(
      success: (events) async {
        AppLogger.info('LocalExternalEventRepository: Deleting ${events.length} events for account $accountId');
        
        for (final event in events) {
          final deleteResult = await delete(event.uid);
          if (deleteResult is Error<void>) {
            AppLogger.error('LocalExternalEventRepository: Failed to delete event ${event.uid}: ${deleteResult.failure.message}');
            return deleteResult;
          }
        }
        
        return const Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Stream<List<CalendarEvent>> watchEvents() async* {
    // Emit initial value
    final result = await getAll();
    yield result.when(
      success: (events) => events,
      failure: (_) => <CalendarEvent>[],
    );
    
    // Then listen to changes
    yield* _storageService.getStream(_boxName)
        .asyncMap((_) async {
          final result = await getAll();
          return result.when(
            success: (events) => events,
            failure: (_) => <CalendarEvent>[],
          );
        });
  }

  @override
  Stream<List<CalendarEvent>> watchEventsByCalendar(String calendarUid) async* {
    yield* watchEvents().map((events) =>
        events.where((e) => e.sourceCalendarUid == calendarUid).toList());
  }

  @override
  Future<Result<List<CalendarEvent>>> getEventsInRange(DateTime start, DateTime end) async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final rangeEvents = events.where((event) {
          // Event overlaps with the range if it starts before the range ends
          // and ends after the range starts
          // Note: events are now in local time from getAll()
          final eventStart = event.dtstart;
          final eventEnd = event.dtend ?? event.dtstart;
          
          return eventStart.isBefore(end) && eventEnd.isAfter(start);
        }).toList();
        
        // Sort by start time
        rangeEvents.sort((a, b) => a.dtstart.compareTo(b.dtstart));
        
        // Debug log calendar breakdown
        final calendarBreakdown = <String, int>{};
        for (final event in rangeEvents) {
          final calendarName = event.sourceCalendarUid;
          calendarBreakdown[calendarName] = (calendarBreakdown[calendarName] ?? 0) + 1;
        }
        
        AppLogger.info('LocalExternalEventRepository: Found ${rangeEvents.length} events in range $start to $end');
        AppLogger.debug('LocalExternalEventRepository: Calendar breakdown: $calendarBreakdown');
        
        return Result.success(rangeEvents);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<CalendarEvent>>> getTodayEvents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await getEventsInRange(startOfDay, endOfDay);
  }

  @override
  Future<Result<List<CalendarEvent>>> getUpcomingEvents({int days = 7}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    
    return await getEventsInRange(now, endDate);
  }

  @override
  Future<Result<List<CalendarEvent>>> getEventsByCategory(String category) async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final categoryEvents = events.where((event) {
          return event.categories.any((cat) => 
              cat.toLowerCase().contains(category.toLowerCase()));
        }).toList();
        
        AppLogger.info('LocalExternalEventRepository: Found ${categoryEvents.length} events with category $category');
        return Result.success(categoryEvents);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<CalendarEvent>>> searchEvents(String query) async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final lowercaseQuery = query.toLowerCase();
        final searchResults = events.where((event) {
          return event.summary.toLowerCase().contains(lowercaseQuery) ||
                 event.description.toLowerCase().contains(lowercaseQuery) ||
                 (event.location?.toLowerCase().contains(lowercaseQuery) ?? false) ||
                 event.categories.any((cat) => cat.toLowerCase().contains(lowercaseQuery));
        }).toList();
        
        // Sort by relevance (summary matches first, then description, then location)
        searchResults.sort((a, b) {
          final aInSummary = a.summary.toLowerCase().contains(lowercaseQuery);
          final bInSummary = b.summary.toLowerCase().contains(lowercaseQuery);
          
          if (aInSummary && !bInSummary) return -1;
          if (!aInSummary && bInSummary) return 1;
          
          return a.dtstart.compareTo(b.dtstart);
        });
        
        AppLogger.info('LocalExternalEventRepository: Found ${searchResults.length} events matching "$query"');
        return Result.success(searchResults);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getCalendarStatistics() async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final statistics = <String, int>{};
        
        for (final event in events) {
          final calendarUid = event.sourceCalendarUid;
          statistics[calendarUid] = (statistics[calendarUid] ?? 0) + 1;
        }
        
        AppLogger.info('LocalExternalEventRepository: Calendar statistics calculated for ${statistics.length} calendars');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Map<String, int>>> getAccountStatistics() async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final statistics = <String, int>{};
        
        for (final event in events) {
          final accountId = event.accountId;
          statistics[accountId] = (statistics[accountId] ?? 0) + 1;
        }
        
        AppLogger.info('LocalExternalEventRepository: Account statistics calculated for ${statistics.length} accounts');
        return Result.success(statistics);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> deleteByUrl(String url) async {
    final result = await getAll();
    return result.when(
      success: (events) async {
        final eventsToDelete = events.where((e) => e.url == url).toList();
        AppLogger.info('LocalExternalEventRepository: Deleting ${eventsToDelete.length} events with URL $url');
        
        for (final event in eventsToDelete) {
          final deleteResult = await delete(event.uid);
          if (deleteResult is Error<void>) {
            AppLogger.error('LocalExternalEventRepository: Failed to delete event ${event.uid}: ${deleteResult.failure.message}');
            return deleteResult;
          }
        }
        
        return const Result.success(null);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> deleteByCalendarId(String calendarId) async {
    // Delegate to deleteByCalendar method
    return await deleteByCalendar(calendarId);
  }

  @override
  Future<Result<int>> countByAccountId(String accountId) async {
    final result = await getByAccount(accountId);
    return result.when(
      success: (events) {
        AppLogger.info('LocalExternalEventRepository: Found ${events.length} events for account $accountId');
        return Result.success(events.length);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
}

// Extension for external event repository operations
extension ExternalEventRepositoryExtensions on ExternalEventRepository {
  /// Get events happening now
  Future<Result<List<CalendarEvent>>> getCurrentEvents() async {
    final result = await getAll();
    return result.when(
      success: (events) {
        final currentEvents = events.where((event) => event.isNow).toList();
        return Result.success(currentEvents);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
  
  /// Get events for a specific date
  Future<Result<List<CalendarEvent>>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return await getEventsInRange(startOfDay, endOfDay);
  }
  
  /// Replace all events for a calendar (useful for full sync)
  Future<Result<void>> replaceCalendarEvents(String calendarUid, List<CalendarEvent> newEvents) async {
    // Delete existing events for this calendar
    final deleteResult = await deleteByCalendar(calendarUid);
    if (deleteResult is Error<void>) {
      return deleteResult;
    }
    
    // Save new events
    return await saveAll(newEvents);
  }
} 