// Kanban Repository for managing kanban board configurations
// Handles data persistence and coordinates with KanbanService for business logic
// Follows repository pattern consistent with other repositories

import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/kanban.dart';
import '../../data/services/kanban_service.dart';

/// Abstract interface for kanban repository operations
abstract class KanbanRepository {
  /// Load kanban configurations for a specific project
  Future<Result<List<Kanban>>> getProjectKanbans(String projectPath);
  
  /// Create a new kanban configuration
  Future<Result<Kanban>> createKanban({
    required String projectPath,
    required String title,
    List<String>? orderedList,
    List<String>? filter,
    String? regex,
  });
  
  /// Update an existing kanban configuration
  Future<Result<Kanban>> updateKanban({
    required String projectPath,
    required Kanban updatedKanban,
  });
  
  /// Delete a kanban configuration
  Future<Result<void>> deleteKanban({
    required String projectPath,
    required String title,
  });
}

/// Local implementation of KanbanRepository
/// Delegates to KanbanService for business logic operations
class LocalKanbanRepository implements KanbanRepository {
  final KanbanService _kanbanService;

  LocalKanbanRepository(this._kanbanService);

  @override
  Future<Result<List<Kanban>>> getProjectKanbans(String projectPath) async {
    try {
      AppLogger.debug('KanbanRepository: Loading kanbans for project $projectPath');
      return await _kanbanService.loadKanbansForProject(projectPath);
    } catch (e, stackTrace) {
      AppLogger.error('KanbanRepository: Failed to load kanbans', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to load kanbans: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<Kanban>> createKanban({
    required String projectPath,
    required String title,
    List<String>? orderedList,
    List<String>? filter,
    String? regex,
  }) async {
    try {
      AppLogger.debug('KanbanRepository: Creating kanban "$title" for project $projectPath');
      return await _kanbanService.createKanban(
        projectPath: projectPath,
        title: title,
        orderedList: orderedList,
        filter: filter,
        regex: regex,
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanRepository: Failed to create kanban', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to create kanban: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<Kanban>> updateKanban({
    required String projectPath,
    required Kanban updatedKanban,
  }) async {
    try {
      AppLogger.debug('KanbanRepository: Updating kanban "${updatedKanban.title}" for project $projectPath');
      return await _kanbanService.updateKanban(
        projectPath: projectPath,
        updatedKanban: updatedKanban,
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanRepository: Failed to update kanban', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to update kanban: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }

  @override
  Future<Result<void>> deleteKanban({
    required String projectPath,
    required String title,
  }) async {
    try {
      AppLogger.debug('KanbanRepository: Deleting kanban "$title" for project $projectPath');
      return await _kanbanService.deleteKanban(
        projectPath: projectPath,
        title: title,
      );
    } catch (e, stackTrace) {
      AppLogger.error('KanbanRepository: Failed to delete kanban', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to delete kanban: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 