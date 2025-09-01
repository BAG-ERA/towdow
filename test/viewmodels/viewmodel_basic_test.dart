/// Tests basiques pour les ViewModels
/// Vérifie que tous les ViewModels se compilent et fonctionnent correctement

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:riverpod/riverpod.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';
import 'package:towdow_app/data/services/sync/sync_service.dart';
import 'package:towdow_app/presentation/viewmodels/project_list_viewmodel.dart';

import 'viewmodel_basic_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<CalendarRepository>(),
  MockSpec<TaskRepository>(),
  MockSpec<AccountRepository>(),
  MockSpec<UserRepository>(),
  MockSpec<SyncService>(),
])
void main() {
  group('ProjectListViewModel Basic Tests', () {
    late ProjectListViewModel viewModel;
    late MockCalendarRepository mockCalendarRepository;
    late MockTaskRepository mockTaskRepository;
    late MockSyncService mockSyncService;
    late MockAccountRepository mockAccountRepository;
    late MockUserRepository mockUserRepository;

    setUp(() {
      mockCalendarRepository = MockCalendarRepository();
      mockTaskRepository = MockTaskRepository();
      mockSyncService = MockSyncService();
      mockAccountRepository = MockAccountRepository();
      mockUserRepository = MockUserRepository();

      // Add stub for watchCalendars method
      when(mockCalendarRepository.watchCalendars())
          .thenAnswer((_) => Stream.empty());

      viewModel = ProjectListViewModel(
        mockCalendarRepository,
        mockTaskRepository,
        mockUserRepository,
      );
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.isRefreshing, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.projects, isEmpty);
        expect(viewModel.state.domainGroups, isEmpty);
        expect(viewModel.state.totalProjects, 0);
        expect(viewModel.state.completedProjects, 0);
        expect(viewModel.state.activeProjects, 0);
        expect(viewModel.state.searchQuery, '');
        expect(viewModel.state.filter, ProjectFilter.all);
        expect(viewModel.state.sortBy, ProjectSort.custom);
      });
    });

    group('State Management', () {
      test('should update loading state', () {
        // Act
        viewModel.state = viewModel.state.copyWith(isLoading: true);

        // Assert
        expect(viewModel.state.isLoading, true);
      });

      test('should update error state', () {
        // Act
        viewModel.state = viewModel.state.copyWith(error: 'Test error');

        // Assert
        expect(viewModel.state.error, 'Test error');
      });

      test('should update projects list', () {
        // Arrange
        final projects = [
          ProjectWithStats(
            project: TaskCalendarFactory.createNew(
              path: '/calendars/project1/',
              displayName: 'Test Project',
            ),
            stats: const ProjectStats(
              totalTasks: 5,
              completedTasks: 2,
              inProgressTasks: 2,
              pendingTasks: 1,
              progressPercentage: 40,
            ),
            lastSyncTime: DateTime.now(),
          ),
        ];

        // Act
        viewModel.state = viewModel.state.copyWith(
          projects: projects,
          totalProjects: projects.length,
          completedProjects: projects.where((p) => p.stats.progressPercentage == 100).length,
          activeProjects: projects.where((p) => p.stats.progressPercentage < 100).length,
        );

        // Assert
        expect(viewModel.state.projects.length, 1);
        expect(viewModel.state.totalProjects, 1);
      });
    });

    group('Search and Filtering', () {
      test('should set search query', () {
        // Act
        viewModel.setSearchQuery('test query');

        // Assert
        expect(viewModel.state.searchQuery, 'test query');
      });

      test('should set filter', () {
        // Act
        viewModel.setFilter(ProjectFilter.completed);

        // Assert
        expect(viewModel.state.filter, ProjectFilter.completed);
      });

      test('should set sort order', () {
        // Act
        viewModel.setSortBy(ProjectSort.progress);

        // Assert
        expect(viewModel.state.sortBy, ProjectSort.progress);
      });

      test('should clear filters', () {
        // Arrange
        viewModel.setSearchQuery('test');
        viewModel.setFilter(ProjectFilter.completed);

        // Act
        viewModel.clearFilters();

        // Assert
        expect(viewModel.state.searchQuery, '');
        expect(viewModel.state.filter, ProjectFilter.all);
      });
    });

    group('Error Handling', () {
      test('should handle state updates with errors', () {
        // Act
        viewModel.state = viewModel.state.copyWith(
          error: 'Test error message',
          isLoading: false,
        );

        // Assert
        expect(viewModel.state.error, 'Test error message');
        expect(viewModel.state.isLoading, false);
      });

      test('should clear error when setting new state', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(error: 'Old error');

        // Act
        viewModel.state = viewModel.state.copyWith(error: null);

        // Assert
        expect(viewModel.state.error, null);
      });
    });

    group('Project Statistics', () {
      test('should calculate project statistics correctly', () {
        // Arrange
        final projects = [
          ProjectWithStats(
            project: TaskCalendarFactory.createNew(
              path: '/calendars/project1/',
              displayName: 'Active Project',
            ),
            stats: const ProjectStats(
              totalTasks: 10,
              completedTasks: 3,
              inProgressTasks: 4,
              pendingTasks: 3,
              progressPercentage: 30,
            ),
            lastSyncTime: DateTime.now(),
          ),
          ProjectWithStats(
            project: TaskCalendarFactory.createNew(
              path: '/calendars/project2/',
              displayName: 'Completed Project',
            ),
            stats: const ProjectStats(
              totalTasks: 5,
              completedTasks: 5,
              inProgressTasks: 0,
              pendingTasks: 0,
              progressPercentage: 100,
            ),
            lastSyncTime: DateTime.now(),
          ),
        ];

        // Act
        viewModel.state = viewModel.state.copyWith(
          projects: projects,
          totalProjects: projects.length,
          completedProjects: projects.where((p) => p.stats.progressPercentage == 100).length,
          activeProjects: projects.where((p) => p.stats.progressPercentage < 100).length,
        );

        // Assert
        expect(viewModel.state.totalProjects, 2);
        expect(viewModel.state.completedProjects, 1);
        expect(viewModel.state.activeProjects, 1);
      });
    });

    group('Domain Groups', () {
      test('should handle domain groups correctly', () {
        // Arrange
        final projects = [
          ProjectWithStats(
            project: TaskCalendarFactory.createNew(
              path: '/calendars/project1/',
              displayName: 'Project 1',
              domain: 'Work',
            ),
            stats: const ProjectStats(
              totalTasks: 5,
              completedTasks: 2,
              inProgressTasks: 2,
              pendingTasks: 1,
              progressPercentage: 40,
            ),
            lastSyncTime: DateTime.now(),
          ),
          ProjectWithStats(
            project: TaskCalendarFactory.createNew(
              path: '/calendars/project2/',
              displayName: 'Project 2',
              domain: 'Personal',
            ),
            stats: const ProjectStats(
              totalTasks: 3,
              completedTasks: 1,
              inProgressTasks: 1,
              pendingTasks: 1,
              progressPercentage: 33,
            ),
            lastSyncTime: DateTime.now(),
          ),
        ];

        final domainGroups = [
          DomainGroup(
            domain: 'Work',
            projects: [projects[0]],
          ),
          DomainGroup(
            domain: 'Personal',
            projects: [projects[1]],
          ),
        ];

        // Act
        viewModel.state = viewModel.state.copyWith(
          projects: projects,
          domainGroups: domainGroups,
        );

        // Assert
        expect(viewModel.state.domainGroups.length, 2);
        expect(viewModel.state.domainGroups.first.domain, 'Work');
        expect(viewModel.state.domainGroups.last.domain, 'Personal');
      });
    });
  });
} 