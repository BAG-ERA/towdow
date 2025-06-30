// Calendar repository interface and local implementation
// Follows repository pattern for calendar/project data access
// Calendars represent projects at VCALENDAR level according to FlowIt specs

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../services/local_storage_service.dart';

// Abstract repository interface
abstract class CalendarRepository {
  Future<Result<List<TaskCalendar>>> getAll();
  Future<Result<TaskCalendar?>> getById(String uid);
  Future<Result<TaskCalendar?>> getByPath(String path);
  Future<Result<void>> save(TaskCalendar calendar);
  Future<Result<void>> delete(String uid);
  Stream<List<TaskCalendar>> watchCalendars();
  Future<Result<List<TaskCalendar>>> getProjectCalendars();
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
    return await _storageService.put(LocalStorageService.calendarsBoxName, calendar.uid, calendar);
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
        // All calendars that support VTODO are projects
        final projects = calendars.where((c) => c.supportsTodos).toList();
        // AppLogger.info('LocalCalendarRepository: Found ${projects.length} project calendars (all synchronized VTODO calendars)');
        return Result.success(projects);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
} 
