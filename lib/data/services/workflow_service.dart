// Workflow service for converting between project and workflow
// Encapsulates business logic and sync queueing, used by ViewModels only

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/step_repository.dart';
// No direct use here; step creation is delegated to repository
import 'sync_service.dart';

class WorkflowService {
  final CalendarRepository _calendarRepository;
  StepRepository? _stepRepository; // injected lazily to avoid cycles

  WorkflowService(this._calendarRepository);

  void setStepRepository(StepRepository stepRepository) {
    _stepRepository = stepRepository;
  }

  Future<Result<void>> convertToWorkflow(String calendarPath) async {
    final getResult = await _calendarRepository.getByPath(calendarPath);
    return await getResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(const Failure(message: 'Calendar not found'));
        }
        // Ensure a default step when turning into a workflow
        final hasSteps = calendar.projectStepsList.isNotEmpty;
        // Delegate default step creation to repository to respect architecture
        if (!hasSteps && _stepRepository != null) {
          await _stepRepository!.ensureDefaultStep(calendar.path);
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
        // Keep steps as-is when converting back to project
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



