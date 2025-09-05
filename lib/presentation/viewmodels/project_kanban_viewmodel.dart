// Project Kanban ViewModel for managing kanban board configurations
// Handles kanban CRUD operations, state management, and synchronization for a specific project
// Follows MVVM architecture pattern consistent with other ViewModels

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/logger.dart';  
import '../../core/result.dart';
import '../../data/models/kanban.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/kanban_repository.dart';

part 'project_kanban_viewmodel.freezed.dart';

/// State class for ProjectKanbanViewModel
@freezed
abstract class ProjectKanbanState with _$ProjectKanbanState {
  const factory ProjectKanbanState({
    @Default([]) List<Kanban> kanbans,
    Kanban? selectedKanban,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    @Default(false) bool isDeleting,
    @Default(false) bool isSyncing,
    String? error,
    String? projectPath,
    @Default([]) List<Category> availableCategories,
    // Column drag and drop state
    String? draggingColumnId,
    @Default(false) bool isReorderingColumns,
  }) = _ProjectKanbanState;
}

/// ViewModel for project kanban management operations
/// Handles UI state management and delegates business logic to KanbanRepository
class ProjectKanbanViewModel extends StateNotifier<ProjectKanbanState> {
  final KanbanRepository _kanbanRepository;
  final CategoryRepository _categoryRepository;

  ProjectKanbanViewModel(
    this._kanbanRepository,
    this._categoryRepository,
  ) : super(const ProjectKanbanState());

  /// Initialize the view model for a specific project
  Future<void> initialize(String projectPath) async {
    AppLogger.info('ProjectKanbanViewModel: Initializing for project $projectPath');
    
    state = state.copyWith(
      isLoading: true, 
      error: null, 
      projectPath: projectPath,
    );
    
    try {
      await _loadKanbans(projectPath);
      await _loadAvailableCategories(projectPath);
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Failed to initialize', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize: $e',
      );
    }
  }

  /// Load kanban configurations for the project using the repository
  Future<void> _loadKanbans(String projectPath) async {
    try {
      final kanbansResult = await _kanbanRepository.getProjectKanbans(projectPath);
      
      await kanbansResult.when(
        success: (kanbans) async {
          state = state.copyWith(
            kanbans: kanbans,
            selectedKanban: kanbans.isNotEmpty ? kanbans.first : null,
          );
        },
        failure: (failure) async {
          AppLogger.error('ProjectKanbanViewModel: Failed to load kanbans: ${failure.message}');
          state = state.copyWith(error: 'Failed to load kanbans: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception loading kanbans', e, stackTrace);
      state = state.copyWith(error: 'Failed to load kanbans: $e');
    }
  }

  /// Load available categories for the project
  Future<void> _loadAvailableCategories(String projectPath) async {
    try {
      final categoriesResult = await _categoryRepository.getProjectCategories(projectPath);
      
      await categoriesResult.when(
        success: (categories) async {
          state = state.copyWith(availableCategories: categories);
        },
        failure: (failure) async {
          AppLogger.warning('ProjectKanbanViewModel: Failed to load categories: ${failure.message}');
          state = state.copyWith(availableCategories: []);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception loading categories', e, stackTrace);
      state = state.copyWith(availableCategories: []);
    }
  }

  /// Create a new kanban configuration
  Future<void> createKanban({
    required String title,
    List<String>? orderedList,
    List<String>? filter,
    String? regex,
  }) async {
    if (state.projectPath == null) {
      state = state.copyWith(error: 'No project selected');
      return;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      AppLogger.info('ProjectKanbanViewModel: Creating kanban "$title"');

      final kanbanResult = await _kanbanRepository.createKanban(
        projectPath: state.projectPath!,
        title: title,
        orderedList: orderedList,
        filter: filter,
        regex: regex,
      );

      await kanbanResult.when(
        success: (kanban) async {
          // Reload kanbans to get the updated list
          await _loadKanbans(state.projectPath!);
          
          // Update selected kanban
          state = state.copyWith(
            selectedKanban: kanban,
            isSaving: false,
          );
        },
        failure: (failure) async {
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to create kanban: ${failure.message}',
          );
        },
      );

      AppLogger.info('ProjectKanbanViewModel: Successfully created kanban "$title"');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception creating kanban', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to create kanban: $e',
      );
    }
  }

  /// Update an existing kanban configuration
  Future<void> updateKanban(Kanban updatedKanban) async {
    if (state.projectPath == null) {
      state = state.copyWith(error: 'No project selected');
      return;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      AppLogger.info('ProjectKanbanViewModel: Updating kanban "${updatedKanban.title}"');

      final kanbanResult = await _kanbanRepository.updateKanban(
        projectPath: state.projectPath!,
        updatedKanban: updatedKanban,
      );

      await kanbanResult.when(
        success: (kanban) async {
          // Reload kanbans to get the updated list
          await _loadKanbans(state.projectPath!);
          
          // Update selected kanban
          state = state.copyWith(
            selectedKanban: kanban,
            isSaving: false,
          );
        },
        failure: (failure) async {
          state = state.copyWith(
            isSaving: false,
            error: 'Failed to update kanban: ${failure.message}',
          );
        },
      );

      AppLogger.info('ProjectKanbanViewModel: Successfully updated kanban "${updatedKanban.title}"');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception updating kanban', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to update kanban: $e',
      );
    }
  }

  /// Delete a kanban configuration
  Future<void> deleteKanban(String title) async {
    if (state.projectPath == null) {
      state = state.copyWith(error: 'No project selected');
      return;
    }

    state = state.copyWith(isDeleting: true, error: null);

    try {
      AppLogger.info('ProjectKanbanViewModel: Deleting kanban "$title"');

      final deleteResult = await _kanbanRepository.deleteKanban(
        projectPath: state.projectPath!,
        title: title,
      );

      await deleteResult.when(
        success: (_) async {
          // Reload kanbans to get the updated list
          await _loadKanbans(state.projectPath!);
          
          // Update selected kanban
          state = state.copyWith(
            selectedKanban: state.kanbans.isNotEmpty ? state.kanbans.first : null,
            isDeleting: false,
          );
        },
        failure: (failure) async {
          state = state.copyWith(
            isDeleting: false,
            error: 'Failed to delete kanban: ${failure.message}',
          );
        },
      );

      AppLogger.info('ProjectKanbanViewModel: Successfully deleted kanban "$title"');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception deleting kanban', e, stackTrace);
      state = state.copyWith(
        isDeleting: false,
        error: 'Failed to delete kanban: $e',
      );
    }
  }

  /// Select a kanban for editing/viewing
  void selectKanban(Kanban kanban) {
    state = state.copyWith(selectedKanban: kanban);
  }

  /// Clear the selected kanban
  void clearSelection() {
    state = state.copyWith(selectedKanban: null);
  }



  /// Get kanban by title
  Kanban? getKanbanByTitle(String title) {
    try {
      return state.kanbans.firstWhere((kanban) => kanban.title == title);
    } catch (e) {
      return null;
    }
  }

  /// Check if a kanban exists with the given title
  bool hasKanbanWithTitle(String title) {
    return state.kanbans.any((kanban) => kanban.title == title);
  }

  /// Hide a column by updating the regex to exclude the category ID
  Future<void> hideColumn(String columnId) async {
    if (state.projectPath == null) {
      state = state.copyWith(error: 'No project selected');
      return;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      AppLogger.info('ProjectKanbanViewModel: Hiding column "$columnId"');

      // Get the current kanban or create a default one
      Kanban currentKanban = state.selectedKanban ?? 
          (state.kanbans.isNotEmpty ? state.kanbans.first : const Kanban(title: 'Default'));

      // Create a regex pattern that excludes the column ID
      // The regex should match all category IDs except the one we want to hide
      final currentRegex = currentKanban.regex ?? r'.*';
      final updatedRegex = _buildExclusionRegex(currentRegex, columnId);

      final updatedKanban = currentKanban.copyWith(regex: updatedRegex);

      // Update the kanban
      await updateKanban(updatedKanban);

      AppLogger.info('ProjectKanbanViewModel: Successfully hidden column "$columnId"');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception hiding column', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to hide column: $e',
      );
    }
  }

  /// Show a column by updating the regex to include the category ID
  Future<void> showColumn(String columnId) async {
    if (state.projectPath == null) {
      state = state.copyWith(error: 'No project selected');
      return;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      AppLogger.info('ProjectKanbanViewModel: Showing column "$columnId"');

      // Get the current kanban or create a default one
      Kanban currentKanban = state.selectedKanban ?? 
          (state.kanbans.isNotEmpty ? state.kanbans.first : const Kanban(title: 'Default'));

      // Create a regex pattern that includes the column ID
      // The regex should match all category IDs including the one we want to show
      final currentRegex = currentKanban.regex ?? r'.*';
      final updatedRegex = _buildInclusionRegex(currentRegex, columnId);

      final updatedKanban = currentKanban.copyWith(regex: updatedRegex);

      // Update the kanban
      await updateKanban(updatedKanban);

      AppLogger.info('ProjectKanbanViewModel: Successfully shown column "$columnId"');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception showing column', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to show column: $e',
      );
    }
  }

  /// Build a regex pattern that excludes a specific category ID
  String _buildExclusionRegex(String currentRegex, String categoryId) {
    final escapedCategoryId = RegExp.escape(categoryId);
    
    // If current regex is the default "match all" pattern, create a negative lookahead
    if (currentRegex == r'.*') {
      return '^(?!${escapedCategoryId}\$).*';
    }
    
    // If the current regex is already a negative lookahead pattern, add to it
    if (currentRegex.startsWith('^(?!') && currentRegex.endsWith(').*')) {
      // Extract existing exclusions and add the new one
      final complexPattern = RegExp(r'^\^\(\?!(.*)\$\)\.\*$');
      final match = complexPattern.firstMatch(currentRegex);
      
      if (match != null) {
        final existingExclusions = match.group(1)!.split('|');
        if (!existingExclusions.contains(escapedCategoryId)) {
          existingExclusions.add(escapedCategoryId);
          return '^(?!${existingExclusions.join('|')}\$).*';
        }
      }
    }
    
    // For other patterns, create a new negative lookahead
    return '^(?!${escapedCategoryId}\$).*';
  }

  /// Build a regex pattern that includes a specific category ID
  String _buildInclusionRegex(String currentRegex, String categoryId) {
    // If the current regex is a negative lookahead pattern, remove the exclusion
    if (currentRegex.startsWith('^(?!') && currentRegex.contains(categoryId)) {
      // Remove the negative lookahead for this specific category
      // The pattern is like: ^(?!cat-id$).* or ^(?!cat-id1$|cat-id2$).*
      final escapedCategoryId = RegExp.escape(categoryId);
      
      // Check if it's a simple exclusion pattern: ^(?!categoryId$).*
      if (currentRegex == '^(?!${escapedCategoryId}\$).*') {
        return r'.*'; // Return match all pattern
      }
      
      // Check if it's a complex exclusion pattern with multiple categories
      // Pattern like: ^(?!cat-id1$|cat-id2$|cat-id3$).*
      final complexPattern = RegExp(r'^\^\(\?!(.*)\$\)\.\*$');
      final match = complexPattern.firstMatch(currentRegex);
      
      if (match != null) {
        final excludedCategories = match.group(1)!.split('|');
        // Remove the category we want to show
        final remainingCategories = excludedCategories
            .where((cat) => cat != escapedCategoryId)
            .toList();
        
        if (remainingCategories.isEmpty) {
          return r'.*'; // No more exclusions, show all
        } else {
          // Rebuild the exclusion pattern without the removed category
          return '^(?!${remainingCategories.join('|')}\$).*';
        }
      }
    }
    
    // For other patterns, just return the original regex
    return currentRegex;
  }

  /// Start dragging a column
  void startDraggingColumn(String columnId) {
    state = state.copyWith(
      draggingColumnId: columnId,
      isReorderingColumns: true,
    );
  }

  /// Stop dragging a column
  void stopDraggingColumn() {
    state = state.copyWith(
      draggingColumnId: null,
      isReorderingColumns: false,
    );
  }

  /// Reorder columns by moving a column to a new position
  Future<void> reorderColumns(String draggedColumnId, int newIndex) async {
    if (state.projectPath == null) {
      state = state.copyWith(error: 'No project selected');
      return;
    }

    if (state.selectedKanban == null) {
      AppLogger.warning('ProjectKanbanViewModel: No selected kanban for reordering');
      return;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {

      final currentKanban = state.selectedKanban!;
      final currentOrder = List<String>.from(currentKanban.orderedList);
      
      // Find the current index of the dragged column
      final currentIndex = currentOrder.indexOf(draggedColumnId);
      
      if (currentIndex == -1) {
        
        // Ensure the newIndex is within bounds
        final adjustedIndex = newIndex.clamp(0, currentOrder.length);
        currentOrder.insert(adjustedIndex, draggedColumnId);
      } else {
        // Column found, move it to the new position
        // Remove the column from its current position
        currentOrder.removeAt(currentIndex);
        
        // Insert it at the new position (adjust for removal)
        final adjustedIndex = newIndex > currentIndex ? newIndex - 1 : newIndex;
        currentOrder.insert(adjustedIndex, draggedColumnId);
      }

      // Create updated kanban with new order
      final updatedKanban = currentKanban.copyWith(orderedList: currentOrder);

      // Update the kanban
      await updateKanban(updatedKanban);

    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception reordering columns', e, stackTrace);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to reorder columns: $e',
      );
    }
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get the current project path
  String? get projectPath => state.projectPath;

  /// Check if any operation is in progress
  bool get isBusy => state.isLoading || state.isSaving || state.isDeleting || state.isSyncing;
} 