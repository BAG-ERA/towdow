// User repository interface and local implementation
// Handles persistent storage of user preferences including project ordering
// Follows repository pattern consistent with other data repositories

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/user_preferences.dart';
import '../models/shared_with_me_project.dart';
import '../services/storage/local_storage_service.dart';
import '../services/user/user_preferences_queue_service.dart';

// Abstract repository interface
abstract class UserRepository {
  Future<Result<UserPreferences>> getUserPreferences();
  Future<Result<void>> saveUserPreferences(UserPreferences preferences);
  Future<Result<void>> saveUserPreferencesWithoutSync(UserPreferences preferences);
  
  // Project order management
  Future<Result<void>> addProjectToOrder(String projectUid);
  Future<Result<void>> removeProjectFromOrder(String projectUid);
  Future<Result<void>> reorderProject(String projectUid, int newIndex);
  
  // Shared projects management
  Future<Result<void>> acknowledgeSharedProject(String projectId);
  Future<Result<void>> updateSharedWithMeProjects(List<SharedWithMeProject> projects);
  Future<Result<void>> updateSharedWithMeProjectsWithoutSync(List<SharedWithMeProject> projects);
  
  // Etag methods for S3 sync tracking
  Future<Result<String?>> getEtag();
  Future<Result<void>> setEtag(String? etag);
  
  // Stream for watching user preferences changes
  Stream<UserPreferences> watchUserPreferences();
  
  // Set queue callback for user preferences updates
  void setQueueCallback(Future<void> Function(UserPreferences) callback);
}

// Local implementation using Hive
class LocalUserRepository implements UserRepository {
  final LocalStorageService _storageService;
  final UserPreferencesQueueService? _userPreferencesQueueService;
  static const String _userPreferencesKey = 'user_preferences';
  
  // Queue callback for user preferences updates
  Future<void> Function(UserPreferences)? _queueCallback;

  LocalUserRepository(this._storageService, [this._userPreferencesQueueService]);
  
  @override
  void setQueueCallback(Future<void> Function(UserPreferences) callback) {
    _queueCallback = callback;
  }

  @override
  Future<Result<UserPreferences>> getUserPreferences() async {
    final result = await _storageService.get<UserPreferences>(
      LocalStorageService.userPreferencesBoxName, 
      _userPreferencesKey,
    );
    
    return result.when(
      success: (preferences) {
        if (preferences == null) {
          // No preferences stored yet, return defaults
          AppLogger.info('LocalUserRepository: No user preferences found, returning defaults');
          return Result.success(UserPreferences.defaultPreferences());
        }
        AppLogger.info('LocalUserRepository: Loaded user preferences with ${preferences.projectOrder.length} project orders and ${preferences.sharedWithMeProjects.length} shared projects');
        return Result.success(preferences);
      },
      failure: (failure) {
        AppLogger.error('LocalUserRepository: Failed to get user preferences: ${failure.message}');
        // Return default preferences on error
        return Result.success(UserPreferences.defaultPreferences());
      },
    );
  }

  @override
  Future<Result<void>> saveUserPreferences(UserPreferences preferences) async {
    // Save to local storage
    final result = await _storageService.put(
      LocalStorageService.userPreferencesBoxName,
      _userPreferencesKey,
      preferences,
    );
    
    // Queue for upload instead of direct upload
    await result.when(
      success: (_) async {
        // Use queue callback if available, otherwise use direct service
        if (_queueCallback != null) {
          await _queueCallback!(preferences);
          AppLogger.debug('LocalUserRepository: User preferences saved locally and queued for upload via callback');
        } else if (_userPreferencesQueueService != null) {
          await _userPreferencesQueueService.queueUserPreferencesUpdate(preferences);
          AppLogger.debug('LocalUserRepository: User preferences saved locally and queued for upload via service');
        } else {
          AppLogger.debug('LocalUserRepository: User preferences saved locally only (no queue available)');
        }
      },
      failure: (_) async {
        // Don't queue if save failed
        AppLogger.warning('LocalUserRepository: Failed to save preferences locally, not queuing for upload');
      },
    );
    
    return result;
  }

  Future<Result<void>> updateProjectOrder(List<String> projectOrder) async {
    final preferencesResult = await getUserPreferences();
    return await preferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.withProjectOrder(projectOrder);
        AppLogger.info('LocalUserRepository: Updating project order: $projectOrder');
        return await saveUserPreferences(updatedPreferences);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> addProjectToOrder(String projectUid) async {
    final preferencesResult = await getUserPreferences();
    return await preferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.addProject(projectUid);
        AppLogger.info('LocalUserRepository: Adding project $projectUid to order');
        return await saveUserPreferences(updatedPreferences);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> removeProjectFromOrder(String projectUid) async {
    final preferencesResult = await getUserPreferences();
    return await preferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.removeProject(projectUid);
        AppLogger.info('LocalUserRepository: Removing project $projectUid from order');
        return await saveUserPreferences(updatedPreferences);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> reorderProject(String projectUid, int newIndex) async {
    final preferencesResult = await getUserPreferences();
    return await preferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.reorderProject(projectUid, newIndex);
        AppLogger.info('LocalUserRepository: Reordering project $projectUid to index $newIndex');
        return await saveUserPreferences(updatedPreferences);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> updateSharedWithMeProjects(List<SharedWithMeProject> projects) async {
    final prefsResult = await getUserPreferences();
    return await prefsResult.when(
      success: (prefs) async {
        final updatedPrefs = prefs.copyWith(sharedWithMeProjects: projects);
        return await saveUserPreferences(updatedPrefs);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> acknowledgeSharedProject(String projectId) async {
    final prefsResult = await getUserPreferences();
    return await prefsResult.when(
      success: (prefs) async {
        final updatedProjects = prefs.sharedWithMeProjects
            .map((project) => project.projectId == projectId 
                ? project.copyWith(ack: true) 
                : project)
            .toList();
        
        final updatedPrefs = prefs.copyWith(sharedWithMeProjects: updatedProjects);
        final saveResult = await saveUserPreferences(updatedPrefs);
        
        return saveResult;
      },
      failure: (failure) async => Result.failure(failure),
    );
  }


  @override
  Stream<UserPreferences> watchUserPreferences() async* {
    // Yield current preferences first
    final result = await getUserPreferences();
    yield result.when(
      success: (preferences) => preferences,
      failure: (_) => UserPreferences.defaultPreferences(),
    );

    // Then watch for changes in storage
    yield* _storageService.getStream(LocalStorageService.userPreferencesBoxName)
        .asyncMap((_) async {
      final result = await getUserPreferences();
      return result.when(
        success: (preferences) => preferences,
        failure: (_) => UserPreferences.defaultPreferences(),
      );
    });
  }

  @override
  Future<Result<String?>> getEtag() async {
    final preferencesResult = await getUserPreferences();
    return preferencesResult.when(
      success: (prefs) => Result.success(prefs.etag),
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> setEtag(String? etag) async {
    final currentPrefs = await getUserPreferences();
    return currentPrefs.when(
      success: (prefs) async {
        final updatedPrefs = prefs.copyWith(etag: etag);
        return await saveUserPreferencesWithoutSync(updatedPrefs);
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> saveUserPreferencesWithoutSync(UserPreferences preferences) async {
    AppLogger.info('LocalUserRepository: Saving user preferences without triggering sync: ${preferences.projectOrder.length} project orders and ${preferences.sharedWithMeProjects.length} shared projects');
    final result = await _storageService.put(
      LocalStorageService.userPreferencesBoxName,
      _userPreferencesKey,
      preferences,
    );
    return result;
  }

  @override
  Future<Result<void>> updateSharedWithMeProjectsWithoutSync(List<SharedWithMeProject> projects) async {
    final prefsResult = await getUserPreferences();
    return await prefsResult.when(
      success: (prefs) async {
        final updatedPrefs = prefs.copyWith(sharedWithMeProjects: projects);
        return await saveUserPreferencesWithoutSync(updatedPrefs);
      },
      failure: (failure) => Result.failure(failure),
    );
  }
} 