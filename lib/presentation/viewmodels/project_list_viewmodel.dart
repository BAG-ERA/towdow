// Project List ViewModel for managing project list with sync state
// Handles project loading, filtering, and synchronization tracking

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/domain_service.dart';
import '../../data/services/caldav_service.dart';
import '../../data/models/user_preferences.dart';
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

// Domain with projects
class DomainGroup {
  final String domain;
  final List<ProjectWithStats> projects;
  final bool isExpanded;

  const DomainGroup({
    required this.domain,
    required this.projects,
    this.isExpanded = true,
  });

  DomainGroup copyWith({
    String? domain,
    List<ProjectWithStats>? projects,
    bool? isExpanded,
  }) {
    return DomainGroup(
      domain: domain ?? this.domain,
      projects: projects ?? this.projects,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  /// Get domain statistics
  DomainStats get stats {
    final totalProjects = projects.length;
    final completedProjects = projects.where((p) => p.stats.progressPercentage == 100).length;
    final totalTasks = projects.fold(0, (sum, p) => sum + p.stats.totalTasks);
    final completedTasks = projects.fold(0, (sum, p) => sum + p.stats.completedTasks);
    
    return DomainStats(
      projectCount: totalProjects,
      completedProjects: completedProjects,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      progressPercentage: totalTasks > 0 ? (completedTasks * 100 / totalTasks).round() : 0,
    );
  }
}

// Domain statistics
class DomainStats {
  final int projectCount;
  final int completedProjects;
  final int totalTasks;
  final int completedTasks;
  final int progressPercentage;

  const DomainStats({
    required this.projectCount,
    required this.completedProjects,
    required this.totalTasks,
    required this.completedTasks,
    required this.progressPercentage,
  });
}

// Project List ViewModel State
class ProjectListState {
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final List<ProjectWithStats> projects;
  final List<DomainGroup> domainGroups;
  final ProjectFilter filter;
  final ProjectSort sortBy;
  final String searchQuery;
  final String? selectedDomain;
  final bool isDomainGroupingEnabled;
  final Map<String, bool> domainExpandedState;
  final int totalProjects;
  final int completedProjects;
  final int activeProjects;

  const ProjectListState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.projects = const [],
    this.domainGroups = const [],
    this.filter = ProjectFilter.all,
    this.sortBy = ProjectSort.custom,
    this.searchQuery = '',
    this.selectedDomain,
    this.isDomainGroupingEnabled = true,
    this.domainExpandedState = const {},
    this.totalProjects = 0,
    this.completedProjects = 0,
    this.activeProjects = 0,
  });

  ProjectListState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<ProjectWithStats>? projects,
    List<DomainGroup>? domainGroups,
    ProjectFilter? filter,
    ProjectSort? sortBy,
    String? searchQuery,
    String? selectedDomain,
    bool? isDomainGroupingEnabled,
    Map<String, bool>? domainExpandedState,
    int? totalProjects,
    int? completedProjects,
    int? activeProjects,
  }) {
    return ProjectListState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      projects: projects ?? this.projects,
      domainGroups: domainGroups ?? this.domainGroups,
      filter: filter ?? this.filter,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDomain: selectedDomain,
      isDomainGroupingEnabled: isDomainGroupingEnabled ?? this.isDomainGroupingEnabled,
      domainExpandedState: domainExpandedState ?? this.domainExpandedState,
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
      
      // Apply domain filter
      if (selectedDomain != null) {
        if (!project.belongsToDomain(selectedDomain!)) {
          return false;
        }
      }
      
      // Apply search filter
      if (searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        if (!project.displayName.toLowerCase().contains(searchLower) &&
            !project.description.toLowerCase().contains(searchLower) &&
            !(project.flowitDomain?.toLowerCase().contains(searchLower) ?? false)) {
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
      case ProjectSort.domain:
        filtered.sort((a, b) {
          final domainA = a.project.domainDisplayName;
          final domainB = b.project.domainDisplayName;
          final domainCompare = domainA.compareTo(domainB);
          if (domainCompare != 0) return domainCompare;
          return a.project.displayName.compareTo(b.project.displayName);
        });
        break;
      case ProjectSort.custom:
        // Custom ordering will be handled by the ViewModel
        // For now, keep the original order
        break;
    }
    
    return filtered;
  }

  /// Get available domains
  List<String> get availableDomains {
    final domains = projects
        .map((p) => p.project.domainDisplayName)
        .toSet()
        .toList();
    
    // Sort domains alphabetically, but put "No Domain" last
    domains.sort((a, b) {
      if (a == 'No Domain') return 1;
      if (b == 'No Domain') return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    
    return domains;
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
  domain,
  custom, // User-defined ordering
}

// Project List ViewModel
class ProjectListViewModel extends StateNotifier<ProjectListState> {
  final CalendarRepository _calendarRepository;
  final TaskRepository _taskRepository;
  final SyncService _syncService;
  final DomainService _domainService;
  final AccountRepository _accountRepository;
  final UserRepository _userRepository;

  ProjectListViewModel(
    this._calendarRepository,
    this._taskRepository,
    this._syncService,
    this._domainService,
    this._accountRepository,
    this._userRepository,
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
          
          // Build domain groups
          final domainGroups = _buildDomainGroups(projectsWithStats);
          
          state = state.copyWith(
            projects: projectsWithStats,
            domainGroups: domainGroups,
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '/calendars/project_${timestamp}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}/';
      AppLogger.info('ProjectListViewModel: Creating project with path: $path');
      
      final newProject = TaskCalendarFactory.createNew(
        path: path,
        displayName: name,
        description: description,
        organizer: organizer,
        categories: categories,
      );
      
      AppLogger.info('ProjectListViewModel: Created project object with UID: ${newProject.uid}');
      
      final result = await _calendarRepository.save(newProject);
      await result.when(
        success: (_) async {
          // AppLogger.info('ProjectListViewModel: Project created successfully: $name');
          // Add to user ordering
          await _addProjectToUserOrder(newProject.uid);
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
    AppLogger.info('ProjectListViewModel: Deleting project: $projectUid');
    
    try {
      state = state.copyWith(error: null);
      
      // First get the project to obtain its path for server deletion
      final calendarResult = await _calendarRepository.getById(projectUid);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) {
            AppLogger.warning('ProjectListViewModel: Project $projectUid not found for deletion');
            return; // Already deleted
          }

          // Delete from server first (if we have an active account)
          try {
            final accountResult = await _accountRepository.getActiveAccount();
            await accountResult.when(
              success: (account) async {
                if (account != null) {
                  final caldavService = CalDAVService(account: account);
                  final serverDeleteResult = await caldavService.deleteCalendar(calendar.path);
                  
                  serverDeleteResult.when(
                    success: (_) {
                      AppLogger.info('ProjectListViewModel: Project deleted from server successfully');
                    },
                    failure: (failure) {
                      AppLogger.warning('ProjectListViewModel: Failed to delete project from server: ${failure.message}');
                      // Continue with local deletion even if server deletion fails
                    },
                  );
                }
              },
              failure: (failure) {
                AppLogger.warning('ProjectListViewModel: No active account, skipping server deletion');
              },
            );
          } catch (e) {
            AppLogger.warning('ProjectListViewModel: Server deletion failed, continuing with local deletion: $e');
          }

          // Delete locally
          final result = await _calendarRepository.delete(projectUid);
          await result.when(
            success: (_) async {
              AppLogger.info('ProjectListViewModel: Project deleted successfully: $projectUid');
              // Remove from user ordering
              await _removeProjectFromUserOrder(projectUid);
              // Remove from local state
              final updatedProjects = state.projects.where((p) => p.project.uid != projectUid).toList();
              state = state.copyWith(projects: updatedProjects);
            },
            failure: (failure) async {
              AppLogger.error('ProjectListViewModel: Failed to delete project locally', failure.exception, failure.stackTrace);
              state = state.copyWith(error: 'Failed to delete project: ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to get project for deletion', failure.exception, failure.stackTrace);
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
      case ProjectSort.domain:
        return 'Domain';
      case ProjectSort.custom:
        return 'Custom Order';
    }
  }

  /// Set domain filter
  void setDomainFilter(String? domain) {
    // AppLogger.info('ProjectListViewModel: Setting domain filter: ${domain ?? "All"}');
    state = state.copyWith(selectedDomain: domain);
  }

  /// Toggle domain grouping
  void toggleDomainGrouping() {
    // AppLogger.info('ProjectListViewModel: Toggling domain grouping');
    state = state.copyWith(isDomainGroupingEnabled: !state.isDomainGroupingEnabled);
  }

  /// Toggle domain expansion state
  void toggleDomainExpansion(String domain) {
    final newExpandedState = Map<String, bool>.from(state.domainExpandedState);
    newExpandedState[domain] = !(newExpandedState[domain] ?? true);
    state = state.copyWith(domainExpandedState: newExpandedState);
  }

  /// Get domain expansion state
  bool isDomainExpanded(String domain) {
    return state.domainExpandedState[domain] ?? true;
  }

  /// Assign domain to project
  Future<void> assignDomainToProject(String projectUid, String? domain) async {
    // AppLogger.info('ProjectListViewModel: Assigning domain "$domain" to project $projectUid');
    
    try {
      state = state.copyWith(error: null);
      
      final result = await _domainService.assignDomainToCalendar(projectUid, domain);
      await result.when(
        success: (_) async {
          // AppLogger.info('ProjectListViewModel: Domain assigned successfully');
          // Reload projects to reflect the change
          await loadProjects();
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to assign domain', failure.exception, failure.stackTrace);
          state = state.copyWith(error: 'Failed to assign domain: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception assigning domain', e, stackTrace);
      state = state.copyWith(error: 'Failed to assign domain: $e');
    }
  }

  /// Reorder project to a new position in the user's custom ordering
  Future<void> reorderProject(String projectUid, int newIndex) async {
    AppLogger.info('ProjectListViewModel: Reordering project $projectUid to index $newIndex');
    
    try {
      state = state.copyWith(error: null);
      
      final result = await _userRepository.reorderProject(projectUid, newIndex);
      await result.when(
        success: (_) async {
          AppLogger.info('ProjectListViewModel: Project reordered successfully');
          // If we're currently using custom sorting, reload to reflect the change
          if (state.sortBy == ProjectSort.custom) {
            await loadProjects();
          }
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to reorder project', failure.exception, failure.stackTrace);
          state = state.copyWith(error: 'Failed to reorder project: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception reordering project', e, stackTrace);
      state = state.copyWith(error: 'Failed to reorder project: $e');
    }
  }

  /// Set custom sort order as the default
  Future<void> setCustomSortOrder() async {
    AppLogger.info('ProjectListViewModel: Switching to custom sort order');
    state = state.copyWith(sortBy: ProjectSort.custom);
  }

  /// Get projects in user-defined order (for custom sorting)
  Future<List<ProjectWithStats>> _getCustomOrderedProjects() async {
    final preferencesResult = await _userRepository.getUserPreferences();
    
    return await preferencesResult.when(
      success: (preferences) async {
        final projectOrder = preferences.projectOrder;
        final allProjects = state.projects;
        
        if (projectOrder.isEmpty) {
          // No custom order defined, return projects sorted by name as default
          final sorted = List<ProjectWithStats>.from(allProjects);
          sorted.sort((a, b) => a.project.displayName.compareTo(b.project.displayName));
          return sorted;
        }
        
        // Apply user-defined ordering
        final orderedProjects = <ProjectWithStats>[];
        final unorderedProjects = <ProjectWithStats>[];
        
        // Add projects in user-defined order
        for (final projectUid in projectOrder) {
          final project = allProjects.cast<ProjectWithStats?>().firstWhere(
            (p) => p?.project.uid == projectUid,
            orElse: () => null,
          );
          if (project != null) {
            orderedProjects.add(project);
          }
        }
        
        // Add any projects that aren't in the user order (new projects)
        for (final project in allProjects) {
          if (!projectOrder.contains(project.project.uid)) {
            unorderedProjects.add(project);
          }
        }
        
        // Sort unordered projects by name and append to the end
        unorderedProjects.sort((a, b) => a.project.displayName.compareTo(b.project.displayName));
        
        return [...orderedProjects, ...unorderedProjects];
      },
      failure: (failure) async {
        AppLogger.error('ProjectListViewModel: Failed to get user preferences for ordering', failure.exception, failure.stackTrace);
        // Fallback to name sorting
        final sorted = List<ProjectWithStats>.from(state.projects);
        sorted.sort((a, b) => a.project.displayName.compareTo(b.project.displayName));
        return sorted;
      },
    );
  }

  /// Get filtered and sorted projects (override for custom ordering)
  Future<List<ProjectWithStats>> getFilteredProjects() async {
    if (state.sortBy == ProjectSort.custom) {
      // Use custom ordering
      final customOrdered = await _getCustomOrderedProjects();
      
      // Apply filters to the custom-ordered list
      return customOrdered.where((projectWithStats) {
        final project = projectWithStats.project;
        final stats = projectWithStats.stats;
        
        // Apply domain filter
        if (state.selectedDomain != null) {
          if (!project.belongsToDomain(state.selectedDomain!)) {
            return false;
          }
        }
        
        // Apply search filter
        if (state.searchQuery.isNotEmpty) {
          final searchLower = state.searchQuery.toLowerCase();
          if (!project.displayName.toLowerCase().contains(searchLower) &&
              !project.description.toLowerCase().contains(searchLower) &&
              !(project.flowitDomain?.toLowerCase().contains(searchLower) ?? false)) {
            return false;
          }
        }
        
        // Apply status filter
        switch (state.filter) {
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
    } else {
      // Use the existing filteredProjects getter from state
      return state.filteredProjects;
    }
  }

  /// Initialize project ordering for a new project
  Future<void> _addProjectToUserOrder(String projectUid) async {
    try {
      final result = await _userRepository.addProjectToOrder(projectUid);
      result.when(
        success: (_) {
          AppLogger.info('ProjectListViewModel: Added project $projectUid to user order');
        },
        failure: (failure) {
          AppLogger.warning('ProjectListViewModel: Failed to add project to user order: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.warning('ProjectListViewModel: Exception adding project to user order: $e');
    }
  }

  /// Clean up deleted projects from user ordering
  Future<void> _removeProjectFromUserOrder(String projectUid) async {
    try {
      final result = await _userRepository.removeProjectFromOrder(projectUid);
      result.when(
        success: (_) {
          AppLogger.info('ProjectListViewModel: Removed project $projectUid from user order');
        },
        failure: (failure) {
          AppLogger.warning('ProjectListViewModel: Failed to remove project from user order: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.warning('ProjectListViewModel: Exception removing project from user order: $e');
    }
  }

  /// Build domain groups from projects
  List<DomainGroup> _buildDomainGroups(List<ProjectWithStats> projects) {
    if (!state.isDomainGroupingEnabled) return [];
    
    final groupedProjects = <String, List<ProjectWithStats>>{};
    
    // Group projects by domain
    for (final project in projects) {
      final domain = project.project.domainDisplayName;
      groupedProjects.putIfAbsent(domain, () => []).add(project);
    }
    
    // Create domain groups
    final domainGroups = <DomainGroup>[];
    final sortedDomains = groupedProjects.keys.toList();
    
    // Sort domains alphabetically, but put "No Domain" last
    sortedDomains.sort((a, b) {
      if (a == 'No Domain') return 1;
      if (b == 'No Domain') return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    
    for (final domain in sortedDomains) {
      final domainProjects = groupedProjects[domain]!;
      
      // Sort projects within domain
      domainProjects.sort((a, b) => a.project.displayName.compareTo(b.project.displayName));
      
      domainGroups.add(DomainGroup(
        domain: domain,
        projects: domainProjects,
        isExpanded: isDomainExpanded(domain),
      ));
    }
    
    return domainGroups;
  }
} 
