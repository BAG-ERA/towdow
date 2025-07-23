// User repository interface and local implementation
// Handles persistent storage of user preferences including project ordering
// Follows repository pattern consistent with other data repositories

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/user_preferences.dart';
import '../models/shared_with_me_project.dart';
import '../services/local_storage_service.dart';

// Abstract repository interface
abstract class UserRepository {
  Future<Result<UserPreferences>> getUserPreferences();
  Future<Result<void>> saveUserPreferences(UserPreferences preferences);
  Future<Result<void>> updateProjectOrder(List<String> projectOrder);
  Future<Result<void>> addProjectToOrder(String projectUid);
  Future<Result<void>> removeProjectFromOrder(String projectUid);
  Future<Result<void>> reorderProject(String projectUid, int newIndex);
  Future<Result<void>> updateSharedWithMeProjects(List<SharedWithMeProject> projects);
  Future<Result<void>> acknowledgeSharedProject(String projectId);
  Stream<UserPreferences> watchUserPreferences();
  
  // Set sync trigger callback for UserSyncService
  void setSyncTrigger(Future<void> Function() triggerSync);
}

// Local implementation using Hive
class LocalUserRepository implements UserRepository {
  final LocalStorageService _storageService;
  static const String _userPreferencesKey = 'user_preferences';
  
  // Sync trigger callback
  Future<void> Function()? _triggerSync;

  LocalUserRepository(this._storageService);
  
  @override
  void setSyncTrigger(Future<void> Function() triggerSync) {
    _triggerSync = triggerSync;
  }
  
  // Helper method to trigger sync after user preference changes
  Future<void> _triggerSyncIfAvailable() async {
    if (_triggerSync != null) {
      try {
        AppLogger.debug('LocalUserRepository: Triggering user data sync to S3');
        await _triggerSync!();
      } catch (e) {
        AppLogger.warning('LocalUserRepository: Failed to trigger sync: $e');
      }
    } else {
      AppLogger.debug('LocalUserRepository: No sync trigger available - changes saved locally only');
    }
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
    AppLogger.info('LocalUserRepository: Saving user preferences with ${preferences.projectOrder.length} project orders and ${preferences.sharedWithMeProjects.length} shared projects');
    final result = await _storageService.put(
      LocalStorageService.userPreferencesBoxName,
      _userPreferencesKey,
      preferences,
    );
    
    // Trigger sync after successful save
    await result.when(
      success: (_) async {
        await _triggerSyncIfAvailable();
      },
      failure: (_) async {
        // Don't trigger sync if save failed
      },
    );
    
    return result;
  }

  @override
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
    final preferencesResult = await getUserPreferences();
    return await preferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.withSharedWithMeProjects(projects);
        AppLogger.info('LocalUserRepository: Updating shared with me projects: ${projects.length} projects');
        return await saveUserPreferences(updatedPreferences);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<void>> acknowledgeSharedProject(String projectId) async {
    final preferencesResult = await getUserPreferences();
    return await preferencesResult.when(
      success: (preferences) async {
        final updatedPreferences = preferences.acknowledgeSharedProject(projectId);
        AppLogger.info('LocalUserRepository: Acknowledging shared project $projectId');
        return await saveUserPreferences(updatedPreferences);
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Stream<UserPreferences> watchUserPreferences() async* {
    // Emit initial value
    final result = await getUserPreferences();
    yield result.when(
      success: (preferences) => preferences,
      failure: (_) => UserPreferences.defaultPreferences(),
    );
    
    // Then listen to changes
    yield* _storageService.getStream(LocalStorageService.userPreferencesBoxName)
        .asyncMap((_) async {
          final result = await getUserPreferences();
          return result.when(
            success: (preferences) => preferences,
            failure: (_) => UserPreferences.defaultPreferences(),
          );
        });
  }
} 