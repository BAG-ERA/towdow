// Category view model for managing category operations
// Follows MVVM architecture pattern with state management and business logic

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/logger.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';

part 'category_viewmodel.freezed.dart';

/// State class for CategoryViewModel
@freezed
class CategoryViewModelState with _$CategoryViewModelState {
  const factory CategoryViewModelState({
    @Default([]) List<Category> categories,
    @Default([]) List<Category> projectCategories,
    @Default(false) bool isLoading,
    @Default(false) bool isCreating,
    @Default(false) bool isUpdating,
    @Default(false) bool isDeleting,
    String? error,
    String? currentProjectPath,
  }) = _CategoryViewModelState;
}

/// ViewModel for category management operations
/// Handles CRUD operations for categories with proper state management
class CategoryViewModel extends StateNotifier<CategoryViewModelState> {
  final CategoryRepository _categoryRepository;
  
  CategoryViewModel(this._categoryRepository) : super(const CategoryViewModelState());
  
  /// Initialize the view model and load categories
  Future<void> initialize([String? projectPath]) async {
    state = state.copyWith(isLoading: true, error: null, currentProjectPath: projectPath);
    
    try {
      // Initialize the repository first
      final initResult = await _categoryRepository.initialize();
      await initResult.when(
        success: (_) async {
          await _loadCategories();
        },
        failure: (failure) async {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to initialize categories: ${failure.message}',
          );
        },
      );
    } catch (e) {
      AppLogger.error('CategoryViewModel: Failed to initialize', e);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize categories: $e',
      );
    }
  }
  
  /// Load all categories and project-specific categories
  Future<void> _loadCategories() async {
    try {
      // Load all categories
      final allCategoriesResult = await _categoryRepository.getAllCategories();
      
      await allCategoriesResult.when(
        success: (allCategories) async {
          // Load project categories if project path is set
          if (state.currentProjectPath != null) {
            final projectCategoriesResult = await _categoryRepository.getProjectCategories(state.currentProjectPath!);
            await projectCategoriesResult.when(
              success: (projectCategories) async {
                state = state.copyWith(
                  categories: allCategories,
                  projectCategories: projectCategories,
                  isLoading: false,
                  error: null,
                );
              },
              failure: (failure) async {
                AppLogger.warning('CategoryViewModel: Failed to load project categories: ${failure.message}');
                state = state.copyWith(
                  categories: allCategories,
                  projectCategories: [],
                  isLoading: false,
                  error: null, // Don't fail entirely if project categories fail
                );
              },
            );
          } else {
            state = state.copyWith(
              categories: allCategories,
              projectCategories: [],
              isLoading: false,
              error: null,
            );
          }
        },
        failure: (failure) async {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load categories: ${failure.message}',
          );
        },
      );
    } catch (e) {
      AppLogger.error('CategoryViewModel: Failed to load categories', e);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load categories: $e',
      );
    }
  }
  
  /// Create a new category for the current project
  Future<void> createCategory({
    required String name,
    required Color color,
    String? projectPath,
  }) async {
    final targetProjectPath = projectPath ?? state.currentProjectPath;
    if (targetProjectPath == null) {
      state = state.copyWith(error: 'No project selected for category creation');
      return;
    }
    
    state = state.copyWith(isCreating: true, error: null);
    
    try {
      AppLogger.info('CategoryViewModel: Creating category "$name" for project $targetProjectPath');
      
      final result = await _categoryRepository.createCategory(
        projectPath: targetProjectPath,
        name: name,
        color: color.value,
      );
      
      await result.when(
        success: (category) async {
          AppLogger.info('CategoryViewModel: Successfully created category ${category.id}');
          // Reload categories to get updated state
          await _loadCategories();
          state = state.copyWith(isCreating: false);
        },
        failure: (failure) async {
          AppLogger.error('CategoryViewModel: Failed to create category: ${failure.message}');
          state = state.copyWith(
            isCreating: false,
            error: 'Failed to create category: ${failure.message}',
          );
        },
      );
    } catch (e) {
      AppLogger.error('CategoryViewModel: Exception creating category', e);
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create category: $e',
      );
    }
  }
  
  /// Update an existing category
  Future<void> updateCategory(Category updatedCategory) async {
    state = state.copyWith(isUpdating: true, error: null);
    
    try {
      AppLogger.info('CategoryViewModel: Updating category ${updatedCategory.id}');
      
      final result = await _categoryRepository.updateCategory(updatedCategory);
      
      await result.when(
        success: (category) async {
          AppLogger.info('CategoryViewModel: Successfully updated category ${category.id}');
          // Reload categories to get updated state
          await _loadCategories();
          state = state.copyWith(isUpdating: false);
        },
        failure: (failure) async {
          AppLogger.error('CategoryViewModel: Failed to update category: ${failure.message}');
          state = state.copyWith(
            isUpdating: false,
            error: 'Failed to update category: ${failure.message}',
          );
        },
      );
    } catch (e) {
      AppLogger.error('CategoryViewModel: Exception updating category', e);
      state = state.copyWith(
        isUpdating: false,
        error: 'Failed to update category: $e',
      );
    }
  }
  
  /// Delete a category
  Future<void> deleteCategory(String categoryId) async {
    state = state.copyWith(isDeleting: true, error: null);
    
    try {
      AppLogger.info('CategoryViewModel: Deleting category $categoryId');
      
      final result = await _categoryRepository.deleteCategory(categoryId);
      
      await result.when(
        success: (_) async {
          AppLogger.info('CategoryViewModel: Successfully deleted category $categoryId');
          // Reload categories to get updated state
          await _loadCategories();
          state = state.copyWith(isDeleting: false);
        },
        failure: (failure) async {
          AppLogger.error('CategoryViewModel: Failed to delete category: ${failure.message}');
          state = state.copyWith(
            isDeleting: false,
            error: 'Failed to delete category: ${failure.message}',
          );
        },
      );
    } catch (e) {
      AppLogger.error('CategoryViewModel: Exception deleting category', e);
      state = state.copyWith(
        isDeleting: false,
        error: 'Failed to delete category: $e',
      );
    }
  }
  
  /// Get a category by ID
  Future<Category?> getCategoryById(String categoryId) async {
    try {
      final result = await _categoryRepository.getCategoryById(categoryId);
      return result.when(
        success: (category) => category,
        failure: (failure) {
          AppLogger.error('CategoryViewModel: Failed to get category $categoryId: ${failure.message}');
          return null;
        },
      );
    } catch (e) {
      AppLogger.error('CategoryViewModel: Exception getting category $categoryId', e);
      return null;
    }
  }
  
  /// Set the current project path and reload project categories
  Future<void> setProjectPath(String? projectPath) async {
    if (state.currentProjectPath != projectPath) {
      state = state.copyWith(currentProjectPath: projectPath, isLoading: true);
      await _loadCategories();
    }
  }
  
  /// Refresh categories (useful for manual refresh)
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadCategories();
  }
  
  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  /// Check if a category is available for the current project
  bool isCategoryAvailableForProject(String categoryId) {
    return state.projectCategories.any((cat) => cat.id == categoryId);
  }
  
  /// Get category name by ID (useful for UI display)
  String? getCategoryNameById(String categoryId) {
    try {
      final category = state.categories.firstWhere((cat) => cat.id == categoryId);
      return category.name;
    } catch (e) {
      return null;
    }
  }
  
  /// Get category color by ID (useful for UI display)
  Color? getCategoryColorById(String categoryId) {
    try {
      final category = state.categories.firstWhere((cat) => cat.id == categoryId);
      return category.colorValue;
    } catch (e) {
      return null;
    }
  }
} 