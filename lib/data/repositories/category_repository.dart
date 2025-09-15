// CategoryRepository for managing project categories
// Provides a singleton instance with CRUD operations following repository pattern

import 'dart:convert';
import 'dart:async';
import '../models/category.dart';
import '../models/task_calendar.dart';
import 'calendar_repository.dart';
import '../services/sync/sync_service.dart';
import 'calendar_repository.dart' show SyncCommander;
import 'account_repository.dart';
import '../../core/result.dart';
import '../../core/logger.dart';

/// Repository for category management
/// Handles CRUD operations and caching for categories
class CategoryRepository {
  final CalendarRepository _calendarRepository;
  final AccountRepository _accountRepository;
  final SyncCommander? _sync;
  
  // Category cache and project mapping
  final Map<String, Category> _categoryCache = {};
  final Map<String, Set<String>> _projectCategoriesMap = {};
  final Map<String, StreamController<List<Category>>> _projectStreams = {};
  
  CategoryRepository(this._calendarRepository, this._accountRepository, {SyncCommander? sync})
      : _sync = sync;
  
  /// Initialize the repository by loading all categories from projects
  Future<Result<void>> initialize() async {
    AppLogger.info('CategoryRepository: Initializing category cache');
    
    final calendarsResult = await _calendarRepository.getAll();
    return await calendarsResult.when(
      success: (calendars) async {
        _categoryCache.clear();
        _projectCategoriesMap.clear();
        
        for (final calendar in calendars) {
          final categories = calendar.projectCategoriesList;
          final categoryIds = <String>{};
          
          for (final category in categories) {
            _categoryCache[category.id] = category;
            categoryIds.add(category.id);
          }
          
          _projectCategoriesMap[calendar.path] = categoryIds;
          _emitProjectStream(calendar.path);
        }
        
        AppLogger.info('CategoryRepository: Loaded ${_categoryCache.length} categories from ${calendars.length} projects');
        return Result.success(null);
      },
      failure: (failure) async {
        AppLogger.error('CategoryRepository: Failed to initialize');
        return Result.failure(failure);
      },
    );
  }
  
  /// Get all categories across all projects
  Future<Result<List<Category>>> getAllCategories() async {
    if (_categoryCache.isEmpty) {
      await initialize();
    }
    
    final categories = _categoryCache.values.toList();
    AppLogger.debug('CategoryRepository: Retrieved ${categories.length} categories');
    return Result.success(categories);
  }
  
  /// Get categories for a specific project
  Future<Result<List<Category>>> getProjectCategories(String projectPath) async {
    if (_categoryCache.isEmpty) {
      await initialize();
    }

    // Always refresh categories for this project from the latest calendar snapshot.
    try {
      final calRes = await _calendarRepository.getByPath(projectPath);
      await calRes.when(
        success: (cal) async {
          if (cal != null) {
            // Reset mapping for this project, then load from calendar JSON.
            _projectCategoriesMap[projectPath] = <String>{};
            await loadCategoriesFromCalendar(cal);
          }
        },
        failure: (failure) async {
          AppLogger.warning('CategoryRepository: Could not refresh project categories for $projectPath: ${failure.message}');
        },
      );
    } catch (e, st) {
      AppLogger.warning('CategoryRepository: Exception while refreshing project categories for $projectPath: $e');
    }
    
    final categoryIds = _projectCategoriesMap[projectPath] ?? <String>{};
    final categories = categoryIds
        .map((id) => _categoryCache[id])
        .where((category) => category != null)
        .cast<Category>()
        .toList();
    
    AppLogger.debug('CategoryRepository: Retrieved ${categories.length} categories for project $projectPath');
    return Result.success(categories);
  }

  /// Watch categories for a specific project as a stream
  Stream<List<Category>> watchProjectCategories(String projectPath) {
    _projectStreams.putIfAbsent(projectPath, () => StreamController<List<Category>>.broadcast());
    // Emit current snapshot
    _emitProjectStream(projectPath);
    return _projectStreams[projectPath]!.stream;
  }
  
  /// Get a category by ID
  Future<Result<Category?>> getCategoryById(String categoryId) async {
    if (_categoryCache.isEmpty) {
      await initialize();
    }
    
    final category = _categoryCache[categoryId];
    AppLogger.debug('CategoryRepository: Retrieved category $categoryId: ${category?.name ?? 'not found'}');
    return Result.success(category);
  }
  
  /// Create a new category for a project
  Future<Result<Category>> createCategory({
    required String projectPath,
    required String name,
    required int color,
  }) async {
    AppLogger.info('CategoryRepository: Creating category "$name" for project $projectPath');
    
    // Generate unique ID
    final categoryId = CategoryExtension.generateId(name);
    final category = Category(
      id: categoryId,
      name: name,
      color: color,
    );
    
    // Get calendar and update it
    final calendarResult = await _calendarRepository.getByPath(projectPath);
    return await calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(
            Failure(message: 'Project not found: $projectPath'),
          );
        }
        
        // Add category to calendar
        final updatedCalendar = calendar.addCategory(category);
        final saveResult = await _calendarRepository.save(updatedCalendar);
        
        return await saveResult.when(
          success: (_) async {
            // Update cache
            _categoryCache[categoryId] = category;
            _projectCategoriesMap[projectPath] ??= <String>{};
            _projectCategoriesMap[projectPath]!.add(categoryId);
            _emitProjectStream(projectPath);
            
            AppLogger.info('CategoryRepository: Successfully created category $categoryId');
            
            // Sync to CalDAV server (similar to DomainService and StatusService)
            await _syncCategoryToServer(updatedCalendar);
            
            return Result.success(category);
          },
          failure: (failure) async {
            AppLogger.error('CategoryRepository: Failed to save calendar after creating category');
            return Result.failure(failure);
          },
        );
      },
      failure: (failure) async {
        AppLogger.error('CategoryRepository: Failed to get calendar for category creation');
        return Result.failure(failure);
      },
    );
  }
  
  /// Update an existing category
  Future<Result<Category>> updateCategory(Category updatedCategory) async {
    AppLogger.info('CategoryRepository: Updating category ${updatedCategory.id}');
    
    if (!_categoryCache.containsKey(updatedCategory.id)) {
      return Result.failure(
        Failure(message: 'Category not found: ${updatedCategory.id}'),
      );
    }
    
    // Find all projects that have this category and update them
    final affectedProjects = <String>[];
    for (final entry in _projectCategoriesMap.entries) {
      if (entry.value.contains(updatedCategory.id)) {
        affectedProjects.add(entry.key);
      }
    }
    
    // Update all affected project calendars
    for (final projectPath in affectedProjects) {
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar != null) {
            final updatedCalendar = calendar.updateCategory(updatedCategory);
            await _calendarRepository.save(updatedCalendar);
            _emitProjectStream(projectPath);
            
            // Sync category changes to CalDAV server
            await _syncCategoryToServer(updatedCalendar);
          }
        },
        failure: (failure) async {
          AppLogger.error('CategoryRepository: Failed to update calendar $projectPath');
        },
      );
    }
    
    // Update cache
    _categoryCache[updatedCategory.id] = updatedCategory;
    
    AppLogger.info('CategoryRepository: Successfully updated category ${updatedCategory.id} in ${affectedProjects.length} projects');
    return Result.success(updatedCategory);
  }
  
  /// Delete a category
  Future<Result<void>> deleteCategory(String categoryId) async {
    AppLogger.info('CategoryRepository: Deleting category $categoryId');
    
    if (!_categoryCache.containsKey(categoryId)) {
      return Result.failure(
        Failure(message: 'Category not found: $categoryId'),
      );
    }
    
    // Find all projects that have this category and remove it
    final affectedProjects = <String>[];
    for (final entry in _projectCategoriesMap.entries) {
      if (entry.value.contains(categoryId)) {
        affectedProjects.add(entry.key);
      }
    }
    
    // Remove from all affected project calendars
    for (final projectPath in affectedProjects) {
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar != null) {
            final updatedCalendar = calendar.removeCategory(categoryId);
            await _calendarRepository.save(updatedCalendar);
            _emitProjectStream(projectPath);
            
            // Sync category deletion to CalDAV server
            await _syncCategoryToServer(updatedCalendar);
          }
        },
        failure: (failure) async {
          AppLogger.error('CategoryRepository: Failed to update calendar $projectPath during deletion');
        },
      );
    }
    
    // Update cache
    _categoryCache.remove(categoryId);
    for (final categoryIds in _projectCategoriesMap.values) {
      categoryIds.remove(categoryId);
    }
    
    AppLogger.info('CategoryRepository: Successfully deleted category $categoryId from ${affectedProjects.length} projects');
    return Result.success(null);
  }
  
  /// Add a category to a project (assigns existing category to project)
  Future<Result<void>> addCategoryToProject({
    required String projectPath,
    required String categoryId,
  }) async {
    AppLogger.info('CategoryRepository: Adding category $categoryId to project $projectPath');
    
    final category = _categoryCache[categoryId];
    if (category == null) {
      return Result.failure(
        Failure(message: 'Category not found: $categoryId'),
      );
    }
    
    final calendarResult = await _calendarRepository.getByPath(projectPath);
    return await calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(
            Failure(message: 'Project not found: $projectPath'),
          );
        }
        
        if (calendar.hasCategory(categoryId)) {
          AppLogger.debug('CategoryRepository: Category $categoryId already exists in project $projectPath');
          return Result.success(null);
        }
        
        final updatedCalendar = calendar.addCategory(category);
        final saveResult = await _calendarRepository.save(updatedCalendar);
        
        return await saveResult.when(
          success: (_) async {
            // Update cache
            _projectCategoriesMap[projectPath] ??= <String>{};
            _projectCategoriesMap[projectPath]!.add(categoryId);
            
            AppLogger.info('CategoryRepository: Successfully added category $categoryId to project $projectPath');
            return Result.success(null);
          },
          failure: (failure) async {
            AppLogger.error('CategoryRepository: Failed to save calendar');
            return Result.failure(failure);
          },
        );
      },
      failure: (failure) async {
        AppLogger.error('CategoryRepository: Failed to get calendar');
        return Result.failure(failure);
      },
    );
  }
  
  /// Remove a category from a project (unassigns category from project)
  Future<Result<void>> removeCategoryFromProject({
    required String projectPath,
    required String categoryId,
  }) async {
    AppLogger.info('CategoryRepository: Removing category $categoryId from project $projectPath');
    
    final calendarResult = await _calendarRepository.getByPath(projectPath);
    return await calendarResult.when(
      success: (calendar) async {
        if (calendar == null) {
          return Result.failure(
            Failure(message: 'Project not found: $projectPath'),
          );
        }
        
        if (!calendar.hasCategory(categoryId)) {
          AppLogger.debug('CategoryRepository: Category $categoryId not found in project $projectPath');
          return Result.success(null);
        }
        
        final updatedCalendar = calendar.removeCategory(categoryId);
        final saveResult = await _calendarRepository.save(updatedCalendar);
        
        return await saveResult.when(
          success: (_) async {
            // Update cache
            _projectCategoriesMap[projectPath]?.remove(categoryId);
            _emitProjectStream(projectPath);
            
            AppLogger.info('CategoryRepository: Successfully removed category $categoryId from project $projectPath');
            return Result.success(null);
          },
          failure: (failure) async {
            AppLogger.error('CategoryRepository: Failed to save calendar');
            return Result.failure(failure);
          },
        );
      },
      failure: (failure) async {
        AppLogger.error('CategoryRepository: Failed to get calendar');
        return Result.failure(failure);
      },
    );
  }
  
  /// Clear cache (useful for testing or reinitialization)
  void clearCache() {
    _categoryCache.clear();
    _projectCategoriesMap.clear();
    for (final c in _projectStreams.values) {
      c.close();
    }
    _projectStreams.clear();
    AppLogger.debug('CategoryRepository: Cache cleared');
  }

  /// Load categories for a project from its calendar's projectCategories field
  /// This populates the cache with categories from server data
  Future<Result<List<Category>>> loadCategoriesFromCalendar(TaskCalendar calendar) async {
    try {
      AppLogger.info('CategoryRepository: Loading categories from calendar ${calendar.displayName}');
      
      if (calendar.projectCategories.isEmpty || calendar.projectCategories == '[]') {
        AppLogger.debug('CategoryRepository: No categories found in calendar ${calendar.displayName}');
        return Result.success([]);
      }
      
      // Parse categories JSON
      final List<dynamic> categoriesJson = jsonDecode(calendar.projectCategories);
      final List<Category> categories = [];
      
      for (final categoryData in categoriesJson) {
        if (categoryData is Map<String, dynamic>) {
          try {
            final category = Category.fromJson(categoryData);
            categories.add(category);
            
            // Update cache
            _categoryCache[category.id] = category;
            _projectCategoriesMap[calendar.path] ??= <String>{};
            _projectCategoriesMap[calendar.path]!.add(category.id);
            _emitProjectStream(calendar.path);
            
            AppLogger.debug('CategoryRepository: Loaded category ${category.name} (${category.id}) from calendar');
          } catch (e) {
            AppLogger.warning('CategoryRepository: Failed to parse category from JSON: $categoryData, error: $e');
          }
        }
      }
      
      AppLogger.info('CategoryRepository: Successfully loaded ${categories.length} categories from calendar ${calendar.displayName}');
      return Result.success(categories);
      
    } catch (e, stackTrace) {
      AppLogger.error('CategoryRepository: Failed to load categories from calendar', e, stackTrace);
      return Result.failure(
        Failure(
          message: 'Failed to load categories from calendar: $e',
          exception: e is Exception ? e : Exception(e.toString()),
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Syncs categories to the CalDAV server using queue for offline resilience.
  /// This method follows the same pattern as DomainService and StatusService.
  Future<Result<void>> _syncCategoryToServer(TaskCalendar calendar) async {
    try {
      AppLogger.info('CategoryRepository: *** Starting category sync to server ***');
      AppLogger.info('CategoryRepository: Calendar path: ${calendar.path}');
      AppLogger.info('CategoryRepository: Categories value: ${calendar.projectCategories}');
      
      // Always use sync queue for offline resilience (injected commander preferred)
      final syncService = _sync ?? SyncService.instance;
      if (syncService != null) {
        AppLogger.debug('CategoryRepository: Queuing calendar update for category sync');
        final queueResult = await syncService.queueCalendarUpdate(calendar.path);
        
        return await queueResult.when(
          success: (_) async {
            AppLogger.info('CategoryRepository: *** Successfully queued category sync to server ***');
            return Result.success(null);
          },
          failure: (failure) async {
            AppLogger.error('CategoryRepository: Failed to queue category sync: ${failure.message}');
            return Result.failure(failure);
          },
        );
      } else {
        AppLogger.error('CategoryRepository: SyncService singleton not initialized - cannot queue update');
        return Result.failure(Failure(
          message: 'SyncService not initialized',
          exception: Exception('SyncService singleton not available'),
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.error('CategoryRepository: Exception during category sync', e, stackTrace);
      return Result.failure(Failure(
        message: 'Failed to sync category to server: $e',
        exception: e is Exception ? e : Exception(e.toString()),
        stackTrace: stackTrace,
      ));
    }
  }
} 

extension on CategoryRepository {
  void _emitProjectStream(String projectPath) {
    final controller = _projectStreams[projectPath];
    if (controller == null || controller.isClosed) return;
    final ids = _projectCategoriesMap[projectPath] ?? <String>{};
    final categories = ids
        .map((id) => _categoryCache[id])
        .whereType<Category>()
        .toList();
    controller.add(categories);
  }
}