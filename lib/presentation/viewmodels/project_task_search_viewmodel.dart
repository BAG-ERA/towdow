// Project Task Search ViewModel for basic search functionality within project detail screens
// Provides simple text-based search across task summary, description, and categories

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
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
    state = state.copyWith(
      searchQuery: query.trim(),
      isSearchActive: query.trim().isNotEmpty,
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
    if (state.searchQuery.isEmpty) {
      return allTasks;
    }

    final searchLower = state.searchQuery.toLowerCase();
    
    return allTasks.where((task) {
      final summaryMatch = task.summary.toLowerCase().contains(searchLower);
      final descriptionMatch = task.description != null && task.description!.toLowerCase().contains(searchLower);
      final categoriesMatch = task.categories.any(
        (category) => category.toLowerCase().contains(searchLower),
      );
      
      return summaryMatch || descriptionMatch || categoriesMatch;
    }).toList();
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
  final searchViewModel = ref.read(projectTaskSearchProvider(projectUid).notifier);
  
  return searchViewModel.filterTasks(allTasks);
}); 