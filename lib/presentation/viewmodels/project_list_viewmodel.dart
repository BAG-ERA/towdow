// Project List ViewModel for managing project list with sync state
// Handles project loading, filtering, and synchronization tracking

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/task_calendar.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';

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

enum ProjectSort {
  name,
  progress,
  created,
  lastModified,
  taskCount,
  domain,
  custom, // User-defined ordering
}

enum SortDirection {
  none,
  ascending,
  descending,
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
  final SortDirection sortDirection;
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
    this.sortDirection = SortDirection.none,
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
    SortDirection? sortDirection,
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
      sortDirection: sortDirection ?? this.sortDirection,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDomain: selectedDomain ?? this.selectedDomain,
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
          // Active projects are all projects except TEMPLATE, STOPPED, ARCHIVE
          final status = project.flowitStatus?.toUpperCase() ?? 'ONGOING';
          return status != 'TEMPLATE' && status != 'STOPPED' && status != 'ARCHIVE';
        case ProjectFilter.completed:
          // Completed projects are STOPPED or ARCHIVE
          final status = project.flowitStatus?.toUpperCase() ?? 'ONGOING';
          return status == 'STOPPED' || status == 'ARCHIVE';
        case ProjectFilter.inProgress:
          return stats.progressPercentage > 0 && stats.progressPercentage < 100;
        case ProjectFilter.notStarted:
          return stats.progressPercentage == 0;
      }
    }).toList();
    
    // Apply sorting
    if (sortDirection != SortDirection.none) {
      switch (sortBy) {
        case ProjectSort.name:
          filtered.sort((a, b) {
            final comparison = a.project.displayName.compareTo(b.project.displayName);
            return sortDirection == SortDirection.ascending ? comparison : -comparison;
          });
          break;
        case ProjectSort.progress:
          filtered.sort((a, b) {
            final comparison = a.stats.progressPercentage.compareTo(b.stats.progressPercentage);
            return sortDirection == SortDirection.ascending ? comparison : -comparison;
          });
          break;
        case ProjectSort.created:
          filtered.sort((a, b) {
            final comparison = a.project.created.compareTo(b.project.created);
            return sortDirection == SortDirection.ascending ? comparison : -comparison;
          });
          break;
        case ProjectSort.lastModified:
          filtered.sort((a, b) {
            final comparison = a.project.lastModified.compareTo(b.project.lastModified);
            return sortDirection == SortDirection.ascending ? comparison : -comparison;
          });
          break;
        case ProjectSort.taskCount:
          filtered.sort((a, b) {
            final comparison = a.stats.totalTasks.compareTo(b.stats.totalTasks);
            return sortDirection == SortDirection.ascending ? comparison : -comparison;
          });
          break;
        case ProjectSort.domain:
          filtered.sort((a, b) {
            final domainA = a.project.domainDisplayName;
            final domainB = b.project.domainDisplayName;
            final domainCompare = domainA.compareTo(domainB);
            if (domainCompare != 0) {
              return sortDirection == SortDirection.ascending ? domainCompare : -domainCompare;
            }
            final nameCompare = a.project.displayName.compareTo(b.project.displayName);
            return sortDirection == SortDirection.ascending ? nameCompare : -nameCompare;
          });
          break;
        case ProjectSort.custom:
          // Custom ordering will be handled by the ViewModel
          // For now, keep the original order
          break;
      }
    }
    
    return filtered;
  }

  /// Get available domains
  List<String> get availableDomains {
    final domains = projects
        .map((p) => p.project.domainDisplayName)
        .toSet()
        .toList();
    
    // Sort domains with "No Domain" first (only if it exists), then alphabetically
    domains.sort((a, b) {
      if (a == 'No Domain') return -1; // "No Domain" comes first
      if (b == 'No Domain') return 1;
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

// Project List ViewModel
class ProjectListViewModel extends StateNotifier<ProjectListState> {
  final CalendarRepository _calendarRepository;
  final TaskRepository _taskRepository;
  final UserRepository _userRepository;
  // When true, this view model will list only workflows (flow calendars)
  // When false, it will list only standard projects (non-workflow calendars)
  final bool workflowsMode;
  
  // Stream subscription for repository changes
  StreamSubscription? _calendarSubscription;
  Timer? _debounceTimer;

  ProjectListViewModel(
    this._calendarRepository,
    this._taskRepository,
    this._userRepository,
    {this.workflowsMode = false}
  ) : super(const ProjectListState()) {
    // Listen to calendar repository changes and update state automatically
    _startListeningToRepositoryChanges();
  }

  /// Start listening to repository changes for automatic UI updates
  void _startListeningToRepositoryChanges() {
    // Listen to calendar repository stream for automatic updates
    _calendarSubscription = _calendarRepository.watchCalendars().listen((calendars) {
      // Only reload if the ViewModel is still mounted
      if (mounted) {
        // Debounce rapid changes to prevent excessive reloads during sync
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            loadProjects();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel the stream subscription to prevent memory leaks
    _calendarSubscription?.cancel();
    // Cancel the debounce timer to prevent memory leaks
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Initialize the view model
  Future<void> initialize() async {
    // AppLogger.info('ProjectListViewModel: Initializing');
    
    // Check if still mounted before updating state
    if (!mounted) return;
    
    state = state.copyWith(
      isLoading: true, 
      error: null,
      // Preserve domain expanded state to prevent UI reset
      domainExpandedState: state.domainExpandedState,
    );
    
    try {
      await loadProjects();
      // AppLogger.info('ProjectListViewModel: Initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Failed to initialize', e, stackTrace);
      // Check if still mounted before updating state
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: 'Failed to initialize: $e',
          // Preserve domain expanded state to prevent UI reset
          domainExpandedState: state.domainExpandedState,
        );
      }
    }
  }

  /// Load all projects with their statistics
  Future<void> loadProjects() async {
    // AppLogger.info('ProjectListViewModel: Loading projects');
    
    // Check if still mounted before proceeding
    if (!mounted) return;
    
    try {
      // Load all calendars (projects)
      final calendarsResult = await _calendarRepository.getProjectCalendars();
      
      await calendarsResult.when(
        success: (calendars) async {
          // AppLogger.info('ProjectListViewModel: Found ${calendars.length} projects');
          
          // Filter calendars based on mode
          final filteredCalendars = calendars.where((c) {
            final isWorkflow = c.flowitAsFlow == true || (c.flowitType.toUpperCase() == 'WORKFLOW');
            return workflowsMode ? isWorkflow : !isWorkflow;
          }).toList();

          // Load tasks for each project/workflow and calculate statistics
          final projectsWithStats = <ProjectWithStats>[];
          
          for (final calendar in filteredCalendars) {
            // Check if still mounted before each async operation
            if (!mounted) return;
            
            try {
              final tasksResult = await _taskRepository.getByProject(calendar.path);
              
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
          
          // Check if still mounted before updating state
          if (!mounted) return;
          
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
            // Preserve domain expanded state to prevent UI reset
            domainExpandedState: state.domainExpandedState,
          );
          
          // AppLogger.info('ProjectListViewModel: Loaded $totalProjects projects ($completedProjects completed, $activeProjects active)');
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to load calendars', failure.exception, failure.stackTrace);
          // Check if still mounted before updating state
          if (mounted) {
            state = state.copyWith(
              isLoading: false,
              isRefreshing: false,
              error: 'Failed to load projects: ${failure.message}',
              // Preserve domain expanded state to prevent UI reset
              domainExpandedState: state.domainExpandedState,
            );
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception loading projects', e, stackTrace);
      // Check if still mounted before updating state
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: 'Failed to load projects: $e',
          // Preserve domain expanded state to prevent UI reset
          domainExpandedState: state.domainExpandedState,
        );
      }
    }
  }

  /// Refresh projects list (pull-to-refresh)
  Future<void> refresh() async {
    // AppLogger.info('ProjectListViewModel: Refreshing projects');
    
    // Check if still mounted before updating state
    if (!mounted) return;
    
    state = state.copyWith(
      isRefreshing: true, 
      error: null,
      // Preserve domain expanded state to prevent UI reset
      domainExpandedState: state.domainExpandedState,
    );
    
    try {
      // Reload projects - sync is handled by repositories
      await loadProjects();
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception during refresh', e, stackTrace);
      // Check if still mounted before updating state
      if (mounted) {
        state = state.copyWith(
          isRefreshing: false,
          error: 'Failed to refresh: $e',
          // Preserve domain expanded state to prevent UI reset
          domainExpandedState: state.domainExpandedState,
        );
      }
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    // AppLogger.info('ProjectListViewModel: Setting search query: "$query"');
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(searchQuery: query);
    }
  }

  /// Set project filter
  void setFilter(ProjectFilter filter) {
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(filter: filter);
    }
  }

  /// Set project sort order with three-state cycling: none -> ascending -> descending -> none
  void setSortBy(ProjectSort sortBy) {
    // AppLogger.info('ProjectListViewModel: Setting sort: $sortBy');
    // Check if still mounted before updating state
    if (mounted) {
      SortDirection newDirection;
      
      if (state.sortBy == sortBy) {
        // Same column clicked - cycle through directions
        switch (state.sortDirection) {
          case SortDirection.none:
            newDirection = SortDirection.ascending;
            break;
          case SortDirection.ascending:
            newDirection = SortDirection.descending;
            break;
          case SortDirection.descending:
            newDirection = SortDirection.none;
            break;
        }
      } else {
        // Different column clicked - start with ascending
        newDirection = SortDirection.ascending;
      }
      
      state = state.copyWith(
        sortBy: sortBy,
        sortDirection: newDirection,
      );
    }
  }

  /// Clear search and filters
  void clearFilters() {
    // AppLogger.info('ProjectListViewModel: Clearing filters');
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(
        searchQuery: '',
        filter: ProjectFilter.all,
        // Preserve domain expanded state to prevent UI reset
        domainExpandedState: state.domainExpandedState,
      );
    }
  }

  /// Create a new project
  Future<void> createProject({
    required String name,
    required String description,
    String? organizer,
    List<String> categories = const [],
  }) async {
    // AppLogger.info('ProjectListViewModel: Creating project: $name');
    
    // Check if still mounted before proceeding
    if (!mounted) return;
    
    try {
      state = state.copyWith(error: null);
      
             // Create calendar through repository (handles sync internally)
             final calendar = TaskCalendarFactory.createNew(
               path: '/temp/${DateTime.now().millisecondsSinceEpoch}', // Will be updated by repository
               displayName: name,
               description: description,
             );
             
             final result = await _calendarRepository.save(calendar);
             await result.when(
               success: (_) async {
                 AppLogger.info('ProjectListViewModel: Calendar created successfully');
                 
                 // Add to user ordering
                 await _addProjectToUserOrder(calendar.path);
                 // Reload projects to show the new one
                 await loadProjects();
               },
               failure: (failure) async {
                 AppLogger.error('ProjectListViewModel: Failed to save project locally', failure.exception, failure.stackTrace);
                 // Check if still mounted before updating state
                 if (mounted) {
                   state = state.copyWith(error: 'Failed to save project: ${failure.message}');
                 }
               },
             );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception creating project', e, stackTrace);
      // Check if still mounted before updating state
      if (mounted) {
        state = state.copyWith(error: 'Failed to create project: $e');
      }
    }
  }

  /// Delete a project
  Future<void> deleteProject(String projectPath) async {
    AppLogger.info('ProjectListViewModel: Deleting project: $projectPath');
    
    // Check if still mounted before proceeding
    if (!mounted) return;
    
    try {
      state = state.copyWith(error: null);
      
      // First get the project to obtain its path for server deletion
      final calendarResult = await _calendarRepository.getById(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) {
            AppLogger.warning('ProjectListViewModel: Project $projectPath not found for deletion');
            return; // Already deleted
          }

          // Delete through repository using path directly (handles sync internally)
          AppLogger.info('ProjectListViewModel: Deleting project with path: ${calendar.path}');
          final result = await _calendarRepository.delete(calendar.path);
          await result.when(
            success: (_) async {
              AppLogger.info('ProjectListViewModel: Project deleted successfully: $projectPath');
              // Local-only cascade delete of project tasks to avoid queuing per-task deletes
              final cascadeResult = await _taskRepository.deleteByProjectLocalOnly(calendar.path);
              cascadeResult.when(
                success: (_) => AppLogger.info('ProjectListViewModel: Locally removed tasks for deleted project: ${calendar.path}'),
                failure: (f) => AppLogger.warning('ProjectListViewModel: Failed to locally remove project tasks: ${f.message}'),
              );
              // Remove from user ordering
              await _removeProjectFromUserOrder(projectPath);
              // Remove from local state
              final updatedProjects = state.projects.where((p) => p.project.path != projectPath).toList();
              state = state.copyWith(
                projects: updatedProjects,
                // Preserve domain expanded state to prevent UI reset
                domainExpandedState: state.domainExpandedState,
              );
            },
            failure: (failure) async {
              AppLogger.error('ProjectListViewModel: Failed to delete project locally', failure.exception, failure.stackTrace);
              // Check if still mounted before updating state
              if (mounted) {
                state = state.copyWith(error: 'Failed to delete project: ${failure.message}');
              }
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('ProjectListViewModel: Failed to get project for deletion', failure.exception, failure.stackTrace);
          // Check if still mounted before updating state
          if (mounted) {
            state = state.copyWith(error: 'Failed to delete project: ${failure.message}');
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception deleting project', e, stackTrace);
      // Check if still mounted before updating state
      if (mounted) {
        state = state.copyWith(error: 'Failed to delete project: $e');
      }
    }
  }

  /// Convert a calendar to workflow
  Future<void> convertProjectToWorkflow(String projectPath) async {
    if (!mounted) return;
    try {
      state = state.copyWith(error: null);
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) return;
          final updated = calendar.copyWith(
            flowitAsFlow: true,
            flowitType: 'WORKFLOW',
            lastModified: DateTime.now(),
          );
          final updateResult = await _calendarRepository.updateCalendarProperties(updated);
          await updateResult.when(
            success: (_) async {
              await loadProjects();
            },
            failure: (f) async {
              if (mounted) state = state.copyWith(error: f.message);
            },
          );
        },
        failure: (f) async {
          if (mounted) state = state.copyWith(error: f.message);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectListViewModel: convertProjectToWorkflow failed', e, st);
      if (mounted) state = state.copyWith(error: e.toString());
    }
  }

  /// Convert a calendar to project
  Future<void> convertWorkflowToProject(String projectPath) async {
    if (!mounted) return;
    try {
      state = state.copyWith(error: null);
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) return;
          final updated = calendar.copyWith(
            flowitAsFlow: false,
            flowitType: 'PROJECT',
            lastModified: DateTime.now(),
          );
          final updateResult = await _calendarRepository.updateCalendarProperties(updated);
          await updateResult.when(
            success: (_) async {
              await loadProjects();
            },
            failure: (f) async {
              if (mounted) state = state.copyWith(error: f.message);
            },
          );
        },
        failure: (f) async {
          if (mounted) state = state.copyWith(error: f.message);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectListViewModel: convertWorkflowToProject failed', e, st);
      if (mounted) state = state.copyWith(error: e.toString());
    }
  }

  /// Archive a calendar
  Future<void> archiveProject(String projectPath) async {
    if (!mounted) return;
    try {
      state = state.copyWith(error: null);
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) return;
          final updated = calendar.copyWith(
            flowitStatus: 'ARCHIVE',
            lastModified: DateTime.now(),
          );
          final updateResult = await _calendarRepository.updateCalendarProperties(updated);
          await updateResult.when(
            success: (_) async {
              await loadProjects();
            },
            failure: (f) async {
              if (mounted) state = state.copyWith(error: f.message);
            },
          );
        },
        failure: (f) async {
          if (mounted) state = state.copyWith(error: f.message);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectListViewModel: archiveProject failed', e, st);
      if (mounted) state = state.copyWith(error: e.toString());
    }
  }

  /// Unarchive a calendar
  Future<void> unarchiveProject(String projectPath) async {
    if (!mounted) return;
    try {
      state = state.copyWith(error: null);
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      await calendarResult.when(
        success: (calendar) async {
          if (calendar == null) return;
          final updated = calendar.copyWith(
            flowitStatus: 'ONGOING',
            lastModified: DateTime.now(),
          );
          final updateResult = await _calendarRepository.updateCalendarProperties(updated);
          await updateResult.when(
            success: (_) async {
              await loadProjects();
            },
            failure: (f) async {
              if (mounted) state = state.copyWith(error: f.message);
            },
          );
        },
        failure: (f) async {
          if (mounted) state = state.copyWith(error: f.message);
        },
      );
    } catch (e, st) {
      AppLogger.error('ProjectListViewModel: unarchiveProject failed', e, st);
      if (mounted) state = state.copyWith(error: e.toString());
    }
  }

  /// Clear any errors
  void clearError() {
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(error: null);
    }
  }

  /// Get project by ID
  ProjectWithStats? getProjectById(String projectPath) {
    return state.projects.cast<ProjectWithStats?>().firstWhere(
      (p) => p?.project.path == projectPath,
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
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(selectedDomain: domain);
    }
  }

  /// Toggle domain grouping
  void toggleDomainGrouping() {
    // AppLogger.info('ProjectListViewModel: Toggling domain grouping');
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(isDomainGroupingEnabled: !state.isDomainGroupingEnabled);
    }
  }

  /// Toggle domain expansion state
  void expandDomain(String domain) {
    // Check if still mounted before updating state
    if (mounted) {
      final newExpandedState = Map<String, bool>.from(state.domainExpandedState);
      newExpandedState[domain] = true;
      state = state.copyWith(domainExpandedState: newExpandedState);
    }
  }

  void collapseDomain(String domain) {
    // Check if still mounted before updating state
    if (mounted) {
      final newExpandedState = Map<String, bool>.from(state.domainExpandedState);
      newExpandedState[domain] = false;
      state = state.copyWith(domainExpandedState: newExpandedState);
    }
  }

  /// Get domain expansion state
  bool isDomainExpanded(String domain) {
    // Default to collapsed when no explicit state is stored
    return state.domainExpandedState[domain] ?? false;
  }

  /// Assign domain to project
  Future<void> assignDomainToProject(String projectPath, String? domain) async {
    // Use repository method that handles both local save and server sync
    final result = await _calendarRepository.assignDomainToCalendar(projectPath, domain);
    await result.when(
      success: (_) async {
        AppLogger.info('ProjectListViewModel: Domain assigned successfully');
      },
      failure: (failure) async {
        AppLogger.error('ProjectListViewModel: Failed to assign domain', failure.exception, failure.stackTrace);
        throw Exception(failure.message);
      },
    );
  }

  /// Reorder project to a new position in the user's custom ordering
  Future<void> reorderProject(String projectPath, int newIndex) async {
    AppLogger.info('ProjectListViewModel: Reordering project $projectPath to index $newIndex');
    
    // Check if still mounted before proceeding
    if (!mounted) return;
    
    try {
      state = state.copyWith(error: null);
      
      final result = await _userRepository.reorderProject(projectPath, newIndex);
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
          // Check if still mounted before updating state
          if (mounted) {
            state = state.copyWith(error: 'Failed to reorder project: ${failure.message}');
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectListViewModel: Exception reordering project', e, stackTrace);
      // Check if still mounted before updating state
      if (mounted) {
        state = state.copyWith(error: 'Failed to reorder project: $e');
      }
    }
  }

  /// Set custom sort order as the default
  Future<void> setCustomSortOrder() async {
    AppLogger.info('ProjectListViewModel: Switching to custom sort order');
    // Check if still mounted before updating state
    if (mounted) {
      state = state.copyWith(sortBy: ProjectSort.custom);
    }
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
        for (final projectPath in projectOrder) {
          final project = allProjects.cast<ProjectWithStats?>().firstWhere(
            (p) => p?.project.path == projectPath,
            orElse: () => null,
          );
          if (project != null) {
            orderedProjects.add(project);
          }
        }
        
        // Add any projects that aren't in the user order (new projects)
        for (final project in allProjects) {
          if (!projectOrder.contains(project.project.path)) {
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
  Future<void> _addProjectToUserOrder(String projectPath) async {
    try {
      final result = await _userRepository.addProjectToOrder(projectPath);
      result.when(
        success: (_) {
          AppLogger.info('ProjectListViewModel: Added project $projectPath to user order');
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
  Future<void> _removeProjectFromUserOrder(String projectPath) async {
    try {
      final result = await _userRepository.removeProjectFromOrder(projectPath);
      result.when(
        success: (_) {
          AppLogger.info('ProjectListViewModel: Removed project $projectPath from user order');
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
    
    // Sort domains with "No Domain" first (only if it exists), then alphabetically
    sortedDomains.sort((a, b) {
      if (a == 'No Domain') return -1; // "No Domain" comes first
      if (b == 'No Domain') return 1;
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

  /// Get filtered domain groups based on current filter
  List<DomainGroup> get filteredDomainGroups {
    return _buildDomainGroups(state.filteredProjects);
  }
} 
