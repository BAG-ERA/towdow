// Workflow service for converting between project and workflow
// Encapsulates business logic and sync queueing, used by ViewModels only

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/task_calendar.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/task_repository.dart';
import '../models/task.dart';
import '../models/attendee.dart';
import '../repositories/step_repository.dart';
// No direct use here; step creation is delegated to repository
import 'sync_service.dart';
import 'dart:convert';

class WorkflowService {
  final CalendarRepository _calendarRepository;
  StepRepository? _stepRepository; // injected lazily to avoid cycles
  TaskRepository? _taskRepository; // injected lazily to avoid cycles

  WorkflowService(this._calendarRepository);

  void setStepRepository(StepRepository stepRepository) {
    _stepRepository = stepRepository;
  }

  void setTaskRepository(TaskRepository taskRepository) {
    _taskRepository = taskRepository;
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

  /// Read project requirements and apply mapped attendee emails to tasks
  /// A task whose X-FLOWIT-REQUIREMENT contains requirement ids will receive
  /// those requirement's attendee emails as Attendee entries (deduplicated).
  Future<Result<void>> applyRequirementAttendeesToTasks(String calendarPath) async {
    try {
      if (_taskRepository == null) {
        return Result.failure(const Failure(message: 'TaskRepository not initialized in WorkflowService'));
      }

      final encodedPath = calendarPath.replaceAll('@', '%40');

      // Load calendar (for requirements)
      final calRes = await _calendarRepository.getByPath(encodedPath);
      final calendar = await calRes.when(
        success: (c) async => c,
        failure: (f) async {
          return null;
        },
      );
      if (calendar == null) {
        return Result.failure(const Failure(message: 'Calendar not found'));
      }

      // Build requirementId -> emails mapping
      final requirementEmailMap = <String, List<String>>{};
      for (final req in calendar.projectRequirementsList) {
        requirementEmailMap[req.id] = List<String>.from(req.attendeeEmails);
      }

      // Load tasks in project
      final tasksRes = await _taskRepository!.getByProject(encodedPath);
      final tasks = await tasksRes.when(
        success: (t) async => t,
        failure: (f) async => <Task>[],
      );

      for (final task in tasks) {
        // Parse requirement ids from task.flowitRequirement
        final reqIds = _parseRequirementIds(task.flowitRequirement);
        if (reqIds.isEmpty) continue;

        final existingEmails = task.attendees.map((a) => a.email.toLowerCase()).toSet();
        final newAttendees = <Attendee>[];

        for (final reqId in reqIds) {
          final emails = requirementEmailMap[reqId] ?? const <String>[];
          for (final email in emails) {
            final normalized = email.trim();
            if (normalized.isEmpty) continue;
            if (existingEmails.contains(normalized.toLowerCase())) continue;
            existingEmails.add(normalized.toLowerCase());
            newAttendees.add(Attendee(
              email: normalized,
              displayName: null,
              status: AttendeeStatus.needsAction,
              role: AttendeeRole.requiredParticipant,
              rsvpRequested: false,
              userType: CalendarUserType.individual,
            ));
          }
        }

        if (newAttendees.isEmpty) continue;

        final updated = task.copyWith(
          attendees: [...task.attendees, ...newAttendees],
          lastModified: DateTime.now(),
        );
        await _taskRepository!.save(updated);
      }

      return Result.success(null);
    } catch (e, st) {
      AppLogger.error('WorkflowService: Failed to apply requirement attendees to tasks', e, st);
      return Result.failure(Failure(message: 'Failed to apply attendees: $e', exception: e is Exception ? e : Exception(e.toString()), stackTrace: st));
    }
  }

  List<String> _parseRequirementIds(String? jsonString) {
    try {
      if (jsonString == null || jsonString.isEmpty) return const [];
      final trimmed = jsonString.trim();
      if (trimmed.startsWith('[')) {
        // JSON array of strings
        final List<dynamic> data = json.decode(trimmed);
        return data.whereType<String>().toList();
      }
      // Legacy or other formats treated as empty
      return const [];
    } catch (_) {
      return const [];
    }
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



