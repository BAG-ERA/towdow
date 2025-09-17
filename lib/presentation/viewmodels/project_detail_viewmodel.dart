// Project Detail ViewModel
// Encapsulates all business logic for the Project Detail screen:
// - Project stream and derived state
// - Update and sync project metadata
// - Acknowledge shared projects
// - Attendee assignment commands handling

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/step.dart';
import '../../data/models/task.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/sync/sync_service.dart'; // TODO: remove direct access to service
import 'commands/attendee_commands.dart';
import '../../data/providers/providers.dart';
import '../../data/models/shared_with_me_project.dart';

class ProjectDetailState {
  final String projectPath;
  final AsyncValue<TaskCalendar?> project;

  const ProjectDetailState({
    required this.projectPath,
    required this.project,
  });

  ProjectDetailState copyWith({
    String? projectPath,
    AsyncValue<TaskCalendar?>? project,
  }) {
    return ProjectDetailState(
      projectPath: projectPath ?? this.projectPath,
      project: project ?? this.project,
    );
  }
}

class ProjectDetailViewModel extends StateNotifier<ProjectDetailState> {
  final Ref _ref;
  final CalendarRepository _calendarRepository;
  final UserRepository _userRepository;
  final StepRepository _stepRepository;
  final TaskRepository _taskRepository;
  final SyncService _syncService;

  StreamSubscription<List<TaskCalendar>>? _calendarSub;

  ProjectDetailViewModel(
    this._ref,
    String projectPath,
    this._calendarRepository,
    this._userRepository,
    this._stepRepository,
    this._taskRepository,
    this._syncService,
  ) : super(ProjectDetailState(projectPath: projectPath, project: const AsyncValue.loading()));

  Future<void> initialize() async {
    // Observe calendars and update the current project state
    _calendarSub = _calendarRepository.watchCalendars().listen((calendars) async {
      try {
        final encodedProjectPath = state.projectPath.replaceAll('@', '%40');
        TaskCalendar? calendar;
        try {
          calendar = calendars.firstWhere((cal) => cal.path == encodedProjectPath);
        } catch (_) {
          calendar = null;
        }
        state = state.copyWith(project: AsyncValue.data(calendar));
      } catch (e, st) {
        AppLogger.error('ProjectDetailViewModel: Error finding project ${state.projectPath}', e, st);
        state = state.copyWith(project: AsyncValue.error(e, st));
      }
    });
  }

  @override
  void dispose() {
    _calendarSub?.cancel();
    super.dispose();
  }

  Future<Result<void>> updateProject(TaskCalendar updatedProject) async {
    try {
      AppLogger.info('ProjectDetailVM: Saving project locally...');
      final result = await _calendarRepository.save(updatedProject);
      return await result.when(
        success: (_) async {
          // Invalidate dependent streams by invalidating known providers
          try {
            _ref.invalidate(calendarRepositoryProvider);
            _ref.invalidate(taskRepositoryProvider);
          } catch (_) {}
          // Fire-and-forget sync
          unawaited(syncProjectToServer(updatedProject));
          return const Result.success(null);
        },
        failure: (failure) async {
          AppLogger.error('ProjectDetailVM: Failed to update project: ${failure.message}', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectDetailVM: Exception updating project', e, st);
      return Result.failure(Failure(message: e.toString(), exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  Future<Result<void>> syncProjectToServer(TaskCalendar project) async {
    try {
      AppLogger.info('ProjectDetailVM: Syncing project metadata to server');
      final syncResult = await _calendarRepository.updateCalendarProperties(project);
      return await syncResult.when(
        success: (_) => const Result.success(null),
        failure: (failure) {
          AppLogger.error('ProjectDetailVM: Failed to sync project metadata to server: ${failure.message}', failure.exception, failure.stackTrace);
          return Result.failure(failure);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectDetailVM: Exception during server sync', e, st);
      return Result.failure(Failure(message: e.toString(), exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  Future<Result<void>> acknowledgeSharedProjectIfNeeded(TaskCalendar project) async {
    try {
      final preferencesResult = await _userRepository.getUserPreferences();
      return await preferencesResult.when(
        success: (preferences) async {
          // UserPreferences.sharedWithMeProjects store projectId as a PATH.
          // Try to find a matching entry by comparing UID extracted from the path.
          SharedWithMeProject? match;
          try {
            match = preferences.sharedWithMeProjects.firstWhere(
              (p) => _extractUidFromPath(p.projectId) == project.uid,
            );
          } catch (_) {
            match = null;
          }
          if (match != null && !match.ack) {
            AppLogger.info('ProjectDetailVM: Auto-acknowledging shared project ${project.displayName}');
            final ackResult = await _userRepository.acknowledgeSharedProject(project.uid);
            return ackResult;
          }
          return const Result.success(null);
        },
        failure: (failure) async {
          AppLogger.warning('ProjectDetailVM: Failed to get user preferences for acknowledgment: ${failure.message}');
          return const Result.success(null);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectDetailVM: Exception during shared project acknowledgment', e, st);
      return Result.failure(Failure(message: e.toString(), exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  String _extractUidFromPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '';
    final last = segments.last;
    return last.isEmpty && segments.length > 1 ? segments[segments.length - 2] : last;
  }

  Future<Result<void>> handleAttendeeTaskMove(Task task, String columnId) async {
    try {
      if (columnId == '__no_attendees__') {
        final command = UnassignAllAttendeesCommand(_taskRepository, _syncService);
        final params = UnassignAllAttendeesParams(task: task);
        await command.executeWith(params);
        return const Result.success(null);
      } else {
        final command = AssignAttendeeToTaskCommand(_taskRepository, _syncService);
        final params = AssignAttendeeToTaskParams(task: task, attendeeEmail: columnId);
        await command.executeWith(params);
        return const Result.success(null);
      }
    } catch (e, st) {
      AppLogger.error('ProjectDetailVM: Error moving task to attendee column', e, st);
      return Result.failure(Failure(message: e.toString(), exception: e is Exception ? e : Exception('$e'), stackTrace: st));
    }
  }

  Future<Result<StepStatus?>> getStepStatusForTask(Task task) async {
    if (task.stepId == null || task.stepId!.isEmpty) return const Result.success(null);
    final stepRes = await _stepRepository.getStepById(task.stepId!);
    return stepRes.when(
      success: (step) => Result.success(step?.status),
      failure: (f) => Result.failure(f),
    );
  }
}


