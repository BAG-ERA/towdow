// Project List ViewModel for managing project list with sync state
// Handles project loading, filtering, and synchronization tracking

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/services/sync_service.dart';
import '../../core/logger.dart';

// Project with associated statistics
class ProjectWithStats {
  final TaskCalendar project;
  final ProjectStats stats;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? syncError;

  const ProjectWithStats({
    required this.project,
    required this.stats,
    this.isSyncing = false,
    this.lastSyncTime,
    this.syncError,
  });

  ProjectWithStats copyWith({
    TaskCalendar? project,
    ProjectStats? stats,
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? syncError,
  }) {
    return ProjectWithStats(
      project: project ?? this.project,
      stats: stats ?? this.stats,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncError: syncError ?? this.syncError,
    );
  }
}

// Project List ViewModel State
class ProjectListState {
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final List<ProjectWithStats> projects;
  final ProjectFilter filter;
  final ProjectSort sortBy;
  final String searchQuery;
  final int totalProjects;
  final int completedProjects;
  final int activeProjects;

  const ProjectListState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.projects = const [],
    this.filter = ProjectFilter.all,
    this.sortBy = ProjectSort.name,
    this.searchQuery = '',
    this.totalProjects = 0,
    this.completedProjects = 0,
    this.activeProjects = 0,
  });

  ProjectListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<ProjectWithStats>? projects,
    ProjectFilter? filter,
    ProjectSort? sortBy,
    String? searchQuery,
    int? totalProjects,
    int? completedProjects,
    int? activeProjects,
  }) {
    return ProjectListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      projects: projects ?? this.projects,
      filter: filter ?? this.filter,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      totalProjects: totalProjects ?? this.totalProjects,
      completedProjects: completedProjects ?? this.completedProjects,
      activeProjects: activeProjects ?? this.activeProjects,
    );
  }

  /// Get filtered and sorted projects
  List<ProjectWithStats> get filteredProjects {
    var filtered = projects.where((projectWithStats) {
      final project = projectWithStats.project;
      final stats = projectWithStats.stats;
      
      // Apply search filter
      if (searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        if (!project.displayName.toLowerCase().contains(searchLower) &&
            !project.description.toLowerCase().contains(searchLower)) {
          return false;
        }
      }
      
      // Apply status filter
      switch (filter) {
        case ProjectFilter.all:
          return true;
        case ProjectFilter.active:
          return stats.progressPercentage < 100;
        case ProjectFilter.completed:
          return stats.progressPercentage == 100;
        case ProjectFilter.inProgress:
          return stats.progressPercentage > 0 && stats.progressPercentage < 100;
        case ProjectFilter.notStarted:
          return stats.progressPercentage == 0;
      }
    }).toList();
    
    // Apply sorting
    switch (sortBy) {
      case ProjectSort.name:
        filtered.sort((a, b) => a.project.displayName.compareTo(b.project.displayName));
        break;
      case ProjectSort.progress:
        filtered.sort((a, b) => b.stats.progressPercentage.compareTo(a.stats.progressPercentage));
        break;
      case ProjectSort.created:
        filtered.sort((a, b) => b.project.created.compareTo(a.project.created));
        break;
      case ProjectSort.lastModified:
        filtered.sort((a, b) => b.project.lastModified.compareTo(a.project.lastModified));
        break;
      case ProjectSort.taskCount:
        filtered.sort((a, b) => b.stats.totalTasks.compareTo(a.stats.totalTasks));
        break;
    }
    
    return filtered;
  }
}

enum ProjectFilter {
  all,
  active,
  completed,
  inProgress,
  notStarted,
}

enum ProjectSort {
  name,
  progress,
  created,
  lastModified,
  taskCount,
}

// Project List ViewModel
class ProjectListViewModel extends StateNotifier<ProjectListState> {
  final CalendarRepository _calendarRepository;
  final TaskRepository _taskRepository;
  final SyncService _syncService;

  ProjectListViewModel(
    this._calendarRepository,
    this._taskRepository,
    this._syncService,
  ) : super(const ProjectListState());

  /// Initialize the view model
  Future<void> initialize() async {
    // AppLogger.info('ProjectListViewModel: Initializing');
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await loadProjects();
      // AppLogger.info('ProjectListViewModel: Initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Failed to initialize', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize: $e',
      );
    }
  }

  /// Load all projects with their statistics
  Future<void> loadProjects() async {
    // AppLogger.info('ProjectListViewModel: Loading projects');
    
    try {
      // Load all calendars (projects)
      final calendarsResult = await _calendarRepository.getProjectCalendars();
      
      await calendarsResult.when(
        success: (calendars) async {
          // AppLogger.info('ProjectListViewModel: Found ${calendars.length} projects');
          
          // Load tasks for each project and calculate statistics
          final projectsWithStats = <ProjectWithStats>[];
          
          for (final calendar in calendars) {
            try {
              final tasksResult = await _taskRepository.getByProject(calendar.uid);
              
              await tasksResult.when(
                success: (tasks) async {
                  final stats = calendar.getStats(tasks);
                  final projectWithStats = ProjectWithStats(
                    project: calendar,
                    stats: stats,
                    lastSyncTime: calendar.lastSyncAt,
                  );
                  projectsWithStats.add(projectWithStats);
                },
                failure: (failure) async {
                  AppLogger.error('ProjectListViewModel: Failed to load tasks for ${calendar.displayName}', 
                                  failure.exception, failure.stackTrace);
                  // Add project with empty stats if tasks can't be loaded
                  final stats = calendar.getStats([]);
                  final projectWithStats = ProjectWithStats(
                    project: calendar,
                    stats: stats,
                    lastSyncTime: calendar.lastSyncAt,
                    syncError: 'Failed to load tasks',
                  );
                  projectsWithStats.add(projectWithStats);
                },
              );
            } catch (e, stackTrace) {
              AppLogger.error('ProjectListViewModel: Exception loading tasks for ${calendar.displayName}', e, stackTrace);
              // Add project with error
              final stats = calendar.getStats([]);
              final projectWithStats = ProjectWithStats(
                project: calendar,
                stats: stats,
                lastSyncTime: calendar.lastSyncAt,
                syncError: 'Error: $e',
              );
              projectsWithStats.add(projectWithStats);
            }
          }
          
          // Calculate overall statistics
          final totalProjects = projectsWithStats.length;
          final completedProjects = projectsWithStats.where((p) => p.stats.progressPercentage == 100).length;
          final activeProjects = totalProjects - completedProjects;
          
          state = state.copyWith(
            projects: projectsWithStats,
            totalProjects: totalProjects,
            completedProjects: completedProjects,
            activeProjects: activeProjects,
            isLoading: false,
            isRefreshing: false,
          );
          
          // AppLogger.info('ProjectListViewModel: Loaded $totalProjects projects ($completedProjects completed, $activeProjects active)');
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to load calendars', failure.exception, failure.stackTrace);
          state = state.copyWith(
            isLoading: false,
            isRefreshing: false,
            error: 'Failed to load projects: ${failure.message}',
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception loading projects', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Failed to load projects: $e',
      );
    }
  }

  /// Refresh projects list (pull-to-refresh)
  Future<void> refresh() async {
    // AppLogger.info('ProjectListViewModel: Refreshing projects');
    
    state = state.copyWith(isRefreshing: true, error: null);
    
    try {
      // Trigger sync first
      final syncResult = await _syncService.syncNow();
      await syncResult.when(
        success: (_) async {
          // AppLogger.info('ProjectListViewModel: Sync completed, reloading projects');
        },
        failure: (failure) async {
          AppLogger.warning('ProjectListViewModel: Sync failed during refresh', failure.exception, failure.stackTrace);
          // Continue with local refresh even if sync failed
        },
      );
      
      // Reload projects
      await loadProjects();
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception during refresh', e, stackTrace);
      state = state.copyWith(
        isRefreshing: false,
        error: 'Failed to refresh: $e',
      );
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    // AppLogger.info('ProjectListViewModel: Setting search query: "$query"');
    state = state.copyWith(searchQuery: query);
  }

  /// Set project filter
  void setFilter(ProjectFilter filter) {
    // AppLogger.info('ProjectListViewModel: Setting filter: $filter');
    state = state.copyWith(filter: filter);
  }

  /// Set project sort order
  void setSortBy(ProjectSort sortBy) {
    // AppLogger.info('ProjectListViewModel: Setting sort: $sortBy');
    state = state.copyWith(sortBy: sortBy);
  }

  /// Clear search and filters
  void clearFilters() {
    // AppLogger.info('ProjectListViewModel: Clearing filters');
    state = state.copyWith(
      searchQuery: '',
      filter: ProjectFilter.all,
    );
  }

  /// Create a new project
  Future<void> createProject({
    required String name,
    required String description,
    String? organizer,
    List<String> categories = const [],
  }) async {
    // AppLogger.info('ProjectListViewModel: Creating project: $name');
    
    try {
      state = state.copyWith(error: null);
      
      // Create new project calendar
      final newProject = TaskCalendarFactory.createNew(
        path: '/calendars/${DateTime.now().millisecondsSinceEpoch}/',
        displayName: name,
        description: description,
        organizer: organizer,
        categories: categories,
      );
      
      final result = await _calendarRepository.save(newProject);
      await result.when(
        success: (_) async {
          // AppLogger.info('ProjectListViewModel: Project created successfully: $name');
          // Reload projects to show the new one
          await loadProjects();
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to create project', failure.exception, failure.stackTrace);
          state = state.copyWith(error: 'Failed to create project: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception creating project', e, stackTrace);
      state = state.copyWith(error: 'Failed to create project: $e');
    }
  }

  /// Delete a project
  Future<void> deleteProject(String projectUid) async {
    // AppLogger.info('ProjectListViewModel: Deleting project: $projectUid');
    
    try {
      state = state.copyWith(error: null);
      
      final result = await _calendarRepository.delete(projectUid);
      await result.when(
        success: (_) async {
          // AppLogger.info('ProjectListViewModel: Project deleted successfully: $projectUid');
          // Remove from local state
          final updatedProjects = state.projects.where((p) => p.project.uid != projectUid).toList();
          state = state.copyWith(projects: updatedProjects);
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to delete project', failure.exception, failure.stackTrace);
          state = state.copyWith(error: 'Failed to delete project: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception deleting project', e, stackTrace);
      state = state.copyWith(error: 'Failed to delete project: $e');
    }
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get project by ID
  ProjectWithStats? getProjectById(String projectUid) {
    return state.projects.cast<ProjectWithStats?>().firstWhere(
      (p) => p?.project.uid == projectUid,
      orElse: () => null,
    );
  }

  /// Check if any project is currently syncing
  bool get isAnySyncing => state.projects.any((p) => p.isSyncing);

  /// Get filter display name
  String getFilterDisplayName(ProjectFilter filter) {
    switch (filter) {
      case ProjectFilter.all:
        return 'All Projects';
      case ProjectFilter.active:
        return 'Active';
      case ProjectFilter.completed:
        return 'Completed';
      case ProjectFilter.inProgress:
        return 'In Progress';
      case ProjectFilter.notStarted:
        return 'Not Started';
    }
  }

  /// Get sort display name
  String getSortDisplayName(ProjectSort sort) {
    switch (sort) {
      case ProjectSort.name:
        return 'Name';
      case ProjectSort.progress:
        return 'Progress';
      case ProjectSort.created:
        return 'Created';
      case ProjectSort.lastModified:
        return 'Modified';
      case ProjectSort.taskCount:
        return 'Task Count';
    }
  }
} 
