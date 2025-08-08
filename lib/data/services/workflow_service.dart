// Workflow service for converting between project and workflow
// Encapsulates business logic and sync queueing, used by ViewModels only

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../repositories/calendar_repository.dart';
import 'sync_service.dart';

class WorkflowService {
  final CalendarRepository _calendarRepository;

  WorkflowService(this._calendarRepository);

  Future<Result<void>> convertToWorkflow(String calendarPath) async {
    final getResult = await _calendarRepository.getByPath(calendarPath);
    return await getResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(message: 'Calendar not found'));
        }
        final updated = calendar.copyWith(
          flowitAsFlow: true,
          flowitType: 'WORKFLOW',
          lastModified: DateTime.now(),
        );
        final saveRes = await _calendarRepository.save(updated);
        if (saveRes is Error<void>) {
          return saveRes;
        }
        return _queueCalendarUpdate(updated);
      },
      failure: (f) async => Result.failure(f),
    );
  }

  Future<Result<void>> convertToProject(String calendarPath) async {
    final getResult = await _calendarRepository.getByPath(calendarPath);
    return await getResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(message: 'Calendar not found'));
        }
        final updated = calendar.copyWith(
          flowitAsFlow: false,
          flowitType: 'PROJECT',
          lastModified: DateTime.now(),
        );
        final saveRes = await _calendarRepository.save(updated);
        if (saveRes is Error<void>) {
          return saveRes;
        }
        return _queueCalendarUpdate(updated);
      },
      failure: (f) async => Result.failure(f),
    );
  }

  Future<Result<void>> _queueCalendarUpdate(TaskCalendar calendar) async {
    try {
      final syncService = SyncService.instance;
      if (syncService == null) {
        return Result.failure(const Failure(message: 'SyncService not initialized'));
      }
      final res = await syncService.queueCalendarUpdate(calendar.path);
      return await res.when(
        success: (_) async => Result.success(null),
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('WorkflowService: Failed to queue update', e, st);
      return Result.failure(Failure(message: 'Failed to queue update: $e'));
    }
  }
}



