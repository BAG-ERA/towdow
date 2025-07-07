// Project Task Search ViewModel for basic search functionality within project detail screens
// Provides simple text-based search across task summary, description, and categories

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/logger.dart';
import '../../data/models/task.dart';
import '../screens/project_detail/project_detail_screen.dart';

part 'project_task_search_viewmodel.freezed.dart';

/// State for basic project task search functionality
@freezed
class ProjectTaskSearchState with _$ProjectTaskSearchState {
  const factory ProjectTaskSearchState({
    @Default('') String searchQuery,
    @Default(false) bool isSearchActive,
  }) = _ProjectTaskSearchState;
}

/// ViewModel for basic task search within a project
class ProjectTaskSearchViewModel extends StateNotifier<ProjectTaskSearchState> {
  ProjectTaskSearchViewModel() : super(const ProjectTaskSearchState());

  /// Set search query
  void setSearchQuery(String query) {
    final trimmedQuery = query.trim();
    AppLogger.debug('ProjectTaskSearchViewModel.setSearchQuery: "${trimmedQuery}" (was: "${state.searchQuery}")');
    state = state.copyWith(
      searchQuery: trimmedQuery,
      isSearchActive: trimmedQuery.isNotEmpty,
    );
  }

  /// Clear search and reset to default state
  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      isSearchActive: false,
    );
  }

  /// Filter tasks based on search query
  List<Task> filterTasks(List<Task> allTasks) {
    AppLogger.debug('ProjectTaskSearchViewModel.filterTasks: searchQuery="${state.searchQuery}", allTasks.length=${allTasks.length}');
    
    if (state.searchQuery.isEmpty) {
      AppLogger.debug('Empty search query, returning all ${allTasks.length} tasks');
      return allTasks;
    }

    final searchLower = state.searchQuery.toLowerCase();
    
    final filteredTasks = allTasks.where((task) {
      final summaryMatch = task.summary.toLowerCase().contains(searchLower);
      final descriptionMatch = task.description != null && task.description!.toLowerCase().contains(searchLower);
      final categoriesMatch = task.categories.any(
        (category) => category.toLowerCase().contains(searchLower),
      );
      
      final matches = summaryMatch || descriptionMatch || categoriesMatch;
      if (matches) {
        AppLogger.debug('Task matches: "${task.summary}"');
      }
      
      return matches;
    }).toList();
    
    AppLogger.debug('Filtered ${filteredTasks.length} tasks from ${allTasks.length} total tasks');
    return filteredTasks;
  }
}

/// Provider for project task search functionality  
/// Family provider to maintain separate search state per project
final projectTaskSearchProvider = StateNotifierProvider.family<ProjectTaskSearchViewModel, ProjectTaskSearchState, String>(
  (ref, projectUid) => ProjectTaskSearchViewModel(),
);

/// Provider for filtered tasks within a specific project
final filteredProjectTasksProvider = Provider.family<List<Task>, String>((ref, projectUid) {
  // Import from existing project detail screen providers
  final projectTasksAsync = ref.watch(projectTasksProvider(projectUid));
  final allTasks = projectTasksAsync.asData?.value ?? [];
  final searchState = ref.watch(projectTaskSearchProvider(projectUid));
  final searchViewModel = ref.read(projectTaskSearchProvider(projectUid).notifier);
  
  AppLogger.debug('filteredProjectTasksProvider called for project $projectUid with ${allTasks.length} tasks, searchQuery="${searchState.searchQuery}"');
  
  return searchViewModel.filterTasks(allTasks);
}); 