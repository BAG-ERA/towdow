// Category repository for managing categories across projects
// Provides a singleton instance with CRUD operations following repository pattern

import '../../core/result.dart';
import '../../core/logger.dart';
import '../models/category.dart';
import '../models/task_calendar.dart';
import 'calendar_repository.dart';

/// Singleton repository for category management
/// Manages categories across all projects and provides CRUD operations
class CategoryRepository {
  static CategoryRepository? _instance;
  final CalendarRepository _calendarRepository;
  
  // Cache for all categories across projects
  final Map<String, Category> _categoryCache = {};
  final Map<String, Set<String>> _projectCategoriesMap = {}; // projectPath -> categoryIds
  
  CategoryRepository._(this._calendarRepository);
  
  /// Get singleton instance
  static CategoryRepository getInstance(CalendarRepository calendarRepository) {
    _instance ??= CategoryRepository._(calendarRepository);
    return _instance!;
  }
  
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
    
    final categoryIds = _projectCategoriesMap[projectPath] ?? <String>{};
    final categories = categoryIds
        .map((id) => _categoryCache[id])
        .where((category) => category != null)
        .cast<Category>()
        .toList();
    
    AppLogger.debug('CategoryRepository: Retrieved ${categories.length} categories for project $projectPath');
    return Result.success(categories);
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
            
            AppLogger.info('CategoryRepository: Successfully created category $categoryId');
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
    AppLogger.debug('CategoryRepository: Cache cleared');
  }
} 