// RequirementRepository for managing project-level requirements
// Mirrors CategoryRepository patterns: CRUD, caching, and calendar PROPPATCH sync

import 'dart:convert';
import '../models/requirement.dart';
import '../models/task_calendar.dart';
import 'calendar_repository.dart';
import '../services/sync/sync_service.dart';
import '../../core/result.dart';
import '../../core/logger.dart';

class RequirementRepository {
  final CalendarRepository _calendarRepository;

  final Map<String, Requirement> _requirementCache = {};
  final Map<String, Set<String>> _projectRequirementsMap = {};

  RequirementRepository(this._calendarRepository);

  Future<Result<void>> initialize() async {
    AppLogger.info('RequirementRepository: Initializing requirement cache');
    final calendarsResult = await _calendarRepository.getAll();
    return await calendarsResult.when(
      success: (calendars) async {
        _requirementCache.clear();
        _projectRequirementsMap.clear();
        for (final calendar in calendars) {
          final requirements = calendar.projectRequirementsList;
          final reqIds = <String>{};
          for (final req in requirements) {
            _requirementCache[req.id] = req;
            reqIds.add(req.id);
          }
          _projectRequirementsMap[calendar.path] = reqIds;
        }
        AppLogger.info('RequirementRepository: Loaded ${_requirementCache.length} requirements');
        return Result.success(null);
      },
      failure: (f) async => Result.failure(f),
    );
  }

  Future<Result<List<Requirement>>> getAllRequirements() async {
    if (_requirementCache.isEmpty) {
      await initialize();
    }
    return Result.success(_requirementCache.values.toList());
  }

  Future<Result<List<Requirement>>> getProjectRequirements(String projectPath) async {
    if (_requirementCache.isEmpty) {
      await initialize();
    }
    final ids = _projectRequirementsMap[projectPath] ?? <String>{};
    final list = ids.map((id) => _requirementCache[id]).whereType<Requirement>().toList();
    return Result.success(list);
  }

  Future<Result<Requirement?>> getRequirementById(String requirementId) async {
    if (_requirementCache.isEmpty) {
      await initialize();
    }
    return Result.success(_requirementCache[requirementId]);
  }

  Future<Result<Requirement>> createRequirement({
    required String projectPath,
    required String id,
    required String name,
  }) async {
    AppLogger.info('RequirementRepository: Creating requirement "$name" for project $projectPath');
    final requirement = Requirement(id: id, name: name, attendeeEmails: const []);

    final calendarResult = await _calendarRepository.getByPath(projectPath);
    return await calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(Failure(message: 'Project not found: $projectPath'));
        }
        final updated = calendar.addOrUpdateRequirement(requirement);
        final saveRes = await _calendarRepository.save(updated);
        return await saveRes.when(
          success: (_) async {
            _requirementCache[requirement.id] = requirement;
            _projectRequirementsMap[projectPath] ??= <String>{};
            _projectRequirementsMap[projectPath]!.add(requirement.id);
            await _syncRequirementsToServer(updated);
            return Result.success(requirement);
          },
          failure: (f) async => Result.failure(f),
        );
      },
      failure: (f) async => Result.failure(f),
    );
  }

  Future<Result<Requirement>> updateRequirement(Requirement updatedRequirement) async {
    AppLogger.info('RequirementRepository: Updating requirement ${updatedRequirement.id}');
    if (!_requirementCache.containsKey(updatedRequirement.id)) {
      return Result.failure(Failure(message: 'Requirement not found: ${updatedRequirement.id}'));
    }
    final affectedProjects = <String>[];
    for (final entry in _projectRequirementsMap.entries) {
      if (entry.value.contains(updatedRequirement.id)) {
        affectedProjects.add(entry.key);
      }
    }
    for (final projectPath in affectedProjects) {
      final calRes = await _calendarRepository.getByPath(projectPath);
      await calRes.when(
        success: (calendar) async {
          if (calendar != null) {
            final updated = calendar.addOrUpdateRequirement(updatedRequirement);
            await _calendarRepository.save(updated);
            await _syncRequirementsToServer(updated);
          }
        },
        failure: (_) async {},
      );
    }
    _requirementCache[updatedRequirement.id] = updatedRequirement;
    return Result.success(updatedRequirement);
  }

  Future<Result<void>> deleteRequirement(String requirementId) async {
    AppLogger.info('RequirementRepository: Deleting requirement $requirementId');
    if (!_requirementCache.containsKey(requirementId)) {
      return Result.failure(Failure(message: 'Requirement not found: $requirementId'));
    }
    final affectedProjects = <String>[];
    for (final entry in _projectRequirementsMap.entries) {
      if (entry.value.contains(requirementId)) {
        affectedProjects.add(entry.key);
      }
    }
    for (final projectPath in affectedProjects) {
      final calRes = await _calendarRepository.getByPath(projectPath);
      await calRes.when(
        success: (calendar) async {
          if (calendar != null) {
            final updated = calendar.removeRequirement(requirementId);
            await _calendarRepository.save(updated);
            await _syncRequirementsToServer(updated);
          }
        },
        failure: (_) async {},
      );
      _projectRequirementsMap[projectPath]?.remove(requirementId);
    }
    _requirementCache.remove(requirementId);
    return Result.success(null);
  }

  Future<Result<void>> _syncRequirementsToServer(TaskCalendar calendar) async {
    try {
      final syncService = SyncService.instance;
      if (syncService == null) {
        return Result.failure(const Failure(message: 'SyncService not initialized'));
      }
      final queueRes = await syncService.queueCalendarUpdate(calendar.path);
      return await queueRes.when(
        success: (_) async => const Result.success(null),
        failure: (f) async => Result.failure(f),
      );
    } catch (e, st) {
      AppLogger.error('RequirementRepository: Failed to queue calendar update', e, st);
      return Result.failure(Failure(message: 'Failed to queue calendar update: $e'));
    }
  }

  Future<Result<List<Requirement>>> loadRequirementsFromCalendar(TaskCalendar calendar) async {
    try {
      AppLogger.info('RequirementRepository: Loading requirements from calendar ${calendar.displayName}');
      if (calendar.projectRequirements.isEmpty || calendar.projectRequirements == '[]') {
        return Result.success([]);
      }
      final List<dynamic> requirementsJson = jsonDecode(calendar.projectRequirements);
      final List<Requirement> requirements = [];
      for (final reqData in requirementsJson) {
        if (reqData is Map<String, dynamic>) {
          try {
            final req = Requirement.fromJson(reqData);
            requirements.add(req);
            _requirementCache[req.id] = req;
            _projectRequirementsMap[calendar.path] ??= <String>{};
            _projectRequirementsMap[calendar.path]!.add(req.id);
          } catch (e) {
            AppLogger.warning('RequirementRepository: Failed to parse requirement from JSON: $reqData, error: $e');
          }
        }
      }
      AppLogger.info('RequirementRepository: Successfully loaded ${requirements.length} requirements from calendar ${calendar.displayName}');
      return Result.success(requirements);
    } catch (e, st) {
      AppLogger.error('RequirementRepository: Failed to load requirements from calendar', e, st);
      return Result.failure(Failure(message: 'Failed to load requirements from calendar: $e'));
    }
  }
}


