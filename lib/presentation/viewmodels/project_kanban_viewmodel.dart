// Project Kanban ViewModel for managing kanban board configurations
// Handles kanban CRUD operations, state management, and synchronization for a specific project
// Follows MVVM architecture pattern consistent with other ViewModels

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:convert';

import '../../core/logger.dart';
import '../../core/result.dart';
import '../../data/models/kanban.dart';
import '../../data/models/task_calendar.dart';
import '../../data/models/category.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/caldav_service.dart';
import '../../data/services/local_storage_service.dart';

part 'project_kanban_viewmodel.freezed.dart';

/// State class for ProjectKanbanViewModel
@freezed
class ProjectKanbanState with _$ProjectKanbanState {
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
  }) = _ProjectKanbanState;
}

/// ViewModel for project kanban management operations
/// Handles CRUD operations for kanban boards with proper state management
class ProjectKanbanViewModel extends StateNotifier<ProjectKanbanState> {
  final CalendarRepository _calendarRepository;
  final UserRepository _userRepository;
  final CategoryRepository _categoryRepository;
  final SyncService _syncService;
  final LocalStorageService _localStorageService;

  ProjectKanbanViewModel(
    this._calendarRepository,
    this._userRepository,
    this._categoryRepository,
    this._syncService,
    this._localStorageService,
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

  /// Load kanban configurations for the project
  Future<void> _loadKanbans(String projectPath) async {
    try {
      // First try to load from user preferences (client-side storage)
      final preferencesResult = await _userRepository.getUserPreferences();
      
      await preferencesResult.when(
        success: (preferences) async {
          final kanbans = _loadKanbansFromPreferences(preferences, projectPath);
          
          if (kanbans.isEmpty) {
            // If no kanbans in preferences, try to load from calendar (server-side)
            await _loadKanbansFromCalendar(projectPath);
          } else {
            state = state.copyWith(kanbans: kanbans);
          }
        },
        failure: (failure) async {
          AppLogger.warning('ProjectKanbanViewModel: Failed to load from preferences: ${failure.message}');
          // Fallback to calendar loading
          await _loadKanbansFromCalendar(projectPath);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception loading kanbans', e, stackTrace);
      state = state.copyWith(error: 'Failed to load kanbans: $e');
    }
  }

  /// Load kanbans from user preferences
  List<Kanban> _loadKanbansFromPreferences(dynamic preferences, String projectPath) {
    try {
      final customSettings = preferences.customSettings;
      if (customSettings == null) return [];
      
      final projectKanbans = customSettings['kanbans_$projectPath'];
      if (projectKanbans == null) return [];
      
      if (projectKanbans is List) {
        return projectKanbans
            .map((kanbanData) => Kanban.fromJson(Map<String, dynamic>.from(kanbanData)))
            .toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.warning('ProjectKanbanViewModel: Failed to parse kanbans from preferences: $e');
      return [];
    }
  }

  /// Load kanbans from calendar (server-side storage)
  Future<void> _loadKanbansFromCalendar(String projectPath) async {
    try {
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      
      await calendarResult.when(
        success: (calendar) async {
          if (calendar != null && calendar.flowitKanban.isNotEmpty) {
            try {
              final kanbanData = jsonDecode(calendar.flowitKanban);
              if (kanbanData is List) {
                final kanbans = kanbanData
                    .map((data) => Kanban.fromJson(Map<String, dynamic>.from(data)))
                    .toList();
                state = state.copyWith(kanbans: kanbans);
                
                // Also save to preferences for client-side storage
                await _saveKanbansToPreferences(kanbans, projectPath);
              }
            } catch (e) {
              AppLogger.warning('ProjectKanbanViewModel: Failed to parse kanbans from calendar: $e');
            }
          }
        },
        failure: (failure) async {
          AppLogger.warning('ProjectKanbanViewModel: Failed to load calendar: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception loading from calendar', e, stackTrace);
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

      final kanban = Kanban(
        title: title,
        orderedList: orderedList ?? [],
        filter: filter ?? [],
        regex: regex ?? r'.*', // Default "capture all" regex pattern
      );

      final updatedKanbans = [...state.kanbans, kanban];
      
      // Save to preferences first (client-side)
      await _saveKanbansToPreferences(updatedKanbans, state.projectPath!);
      
      // Update state
      state = state.copyWith(
        kanbans: updatedKanbans,
        selectedKanban: kanban,
        isSaving: false,
      );

      // Queue for server sync
      await _queueKanbanUpdate(state.projectPath!);

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

      final updatedKanbans = state.kanbans.map((kanban) {
        // Find the kanban to update (by title for now)
        if (kanban.title == updatedKanban.title) {
          return updatedKanban;
        }
        return kanban;
      }).toList();

      // Save to preferences first (client-side)
      await _saveKanbansToPreferences(updatedKanbans, state.projectPath!);
      
      // Update state
      state = state.copyWith(
        kanbans: updatedKanbans,
        selectedKanban: updatedKanban,
        isSaving: false,
      );

      // Queue for server sync
      await _queueKanbanUpdate(state.projectPath!);

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

      final updatedKanbans = state.kanbans.where((kanban) => kanban.title != title).toList();

      // Save to preferences first (client-side)
      await _saveKanbansToPreferences(updatedKanbans, state.projectPath!);
      
      // Update state
      state = state.copyWith(
        kanbans: updatedKanbans,
        selectedKanban: updatedKanbans.isNotEmpty ? updatedKanbans.first : null,
        isDeleting: false,
      );

      // Queue for server sync
      await _queueKanbanUpdate(state.projectPath!);

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

  /// Save kanbans to user preferences
  Future<void> _saveKanbansToPreferences(List<Kanban> kanbans, String projectPath) async {
    try {
      final preferencesResult = await _userRepository.getUserPreferences();
      
      await preferencesResult.when(
        success: (preferences) async {
          final customSettings = Map<String, dynamic>.from(preferences.customSettings ?? {});
          customSettings['kanbans_$projectPath'] = kanbans.map((k) => k.toJson()).toList();
          
          final updatedPreferences = preferences.copyWith(customSettings: customSettings);
          await _userRepository.saveUserPreferences(updatedPreferences);
        },
        failure: (failure) async {
          AppLogger.warning('ProjectKanbanViewModel: Failed to save to preferences: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception saving to preferences', e, stackTrace);
    }
  }

  /// Queue kanban update for server synchronization
  Future<void> _queueKanbanUpdate(String projectPath) async {
    try {
      // Get the calendar to update
      final calendarResult = await _calendarRepository.getByPath(projectPath);
      
      await calendarResult.when(
        success: (calendar) async {
          if (calendar != null) {
            // Update the flowitKanban field
            final kanbanJson = jsonEncode(state.kanbans.map((k) => k.toJson()).toList());
            final updatedCalendar = calendar.copyWith(
              flowitKanban: kanbanJson,
              lastModified: DateTime.now(),
            );
            
            // Save locally
            await _calendarRepository.save(updatedCalendar);
            
            // Queue for sync (this would be handled by the sync service)
            AppLogger.info('ProjectKanbanViewModel: Queued kanban update for sync');
          }
        },
        failure: (failure) async {
          AppLogger.warning('ProjectKanbanViewModel: Failed to queue update: ${failure.message}');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ProjectKanbanViewModel: Exception queuing update', e, stackTrace);
    }
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

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get the current project path
  String? get projectPath => state.projectPath;

  /// Check if any operation is in progress
  bool get isBusy => state.isLoading || state.isSaving || state.isDeleting || state.isSyncing;
} 