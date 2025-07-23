/// Tests unitaires pour ProjectListViewModel
/// Teste la logique métier de gestion de la liste des projets avec synchronisation

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart' as mockito;
import 'package:riverpod/riverpod.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';
import 'package:towdow_app/data/services/domain_service.dart';
import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/presentation/viewmodels/project_list_viewmodel.dart';

import 'project_list_viewmodel_test.mocks.dart';

@GenerateMocks([
  CalendarRepository,
  TaskRepository,
  SyncService,
  DomainService,
  AccountRepository,
  UserRepository,
])
void main() {
  group('ProjectListViewModel Tests', () {
    late ProjectListViewModel viewModel;
    late MockCalendarRepository mockCalendarRepository;
    late MockTaskRepository mockTaskRepository;
    late MockSyncService mockSyncService;
    late MockDomainService mockDomainService;
    late MockAccountRepository mockAccountRepository;
    late MockUserRepository mockUserRepository;

    late List<TaskCalendar> testCalendars;
    late List<Task> testTasks;

    setUp(() {
      mockCalendarRepository = MockCalendarRepository();
      mockTaskRepository = MockTaskRepository();
      mockSyncService = MockSyncService();
      mockDomainService = MockDomainService();
      mockAccountRepository = MockAccountRepository();
      mockUserRepository = MockUserRepository();

      // Create test data first
      testCalendars = [
        TaskCalendarFactory.createNew(
          path: '/calendars/project1/',
          displayName: 'Test Project 1',
          description: 'Test project 1 description',
        ),
        TaskCalendarFactory.createNew(
          path: '/calendars/project2/',
          displayName: 'Test Project 2',
          description: 'Test project 2 description',
        ),
      ];

      testTasks = [
        TaskFactory.createNew(
          summary: 'Task 1',
          description: 'Test task 1',
        ),
        TaskFactory.createNew(
          summary: 'Task 2',
          description: 'Test task 2',
        ),
        TaskFactory.createNew(
          summary: 'Task 3',
          description: 'Test task 3',
        ),
      ];

      // Add stubs for repository methods
      when(mockCalendarRepository.watchCalendars())
          .thenAnswer((_) => Stream.value(testCalendars));
      when(mockCalendarRepository.getProjectCalendars())
          .thenAnswer((_) async => Result.success(testCalendars));
      when(mockCalendarRepository.save(any))
          .thenAnswer((_) async => Result.success(testCalendars.first));
      when(mockTaskRepository.getByProject(any))
          .thenAnswer((_) async => Result.success(testTasks));
      when(mockUserRepository.addProjectToOrder(any))
          .thenAnswer((_) async => const Result.success(null));

      viewModel = ProjectListViewModel(
        mockCalendarRepository,
        mockTaskRepository,
        mockAccountRepository,
        mockUserRepository,
      );
    });

    group('Initialization', () {
      test('should initialize successfully with valid data', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success(testCalendars));
        when(mockTaskRepository.getByProject(mockito.any))
            .thenAnswer((_) async => Result.success([testTasks[0], testTasks[1]]));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.projects.length, 2);
        expect(viewModel.state.totalProjects, 2);
      });

      test('should handle calendar loading failure', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.failure(
                  Failure(message: 'Failed to load calendars'),
                ));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, isNotNull);
        expect(viewModel.state.projects.isEmpty, true);
      });

      test('should handle task loading failure for specific project', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success(testCalendars));
        when(mockTaskRepository.getByProject(mockito.any))
            .thenAnswer((_) async => Result.failure(
                  Failure(message: 'Failed to load tasks'),
                ));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.projects.length, 2);
        expect(viewModel.state.projects.any((p) => p.syncError != null), true);
      });
    });

    group('Refresh', () {
      test('should refresh projects successfully', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success(testCalendars));
        when(mockTaskRepository.getByProject(mockito.any))
            .thenAnswer((_) async => Result.success([testTasks[0], testTasks[1]]));

        // Act
        await viewModel.refresh();

        // Assert
        expect(viewModel.state.isRefreshing, false);
        expect(viewModel.state.error, null);
        expect(viewModel.state.projects.length, 2);
      });

      test('should handle refresh when no projects', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success([]));

        // Act
        await viewModel.refresh();

        // Assert
        expect(viewModel.state.isRefreshing, false);
        expect(viewModel.state.projects.isEmpty, true);
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
        viewModel.setSortBy(ProjectSort.name);

        // Assert
        expect(viewModel.state.sortBy, ProjectSort.name);
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

    group('Project Creation', () {
      test('should handle project creation when save fails', () async {
        // Arrange
        when(mockCalendarRepository.save(any))
            .thenAnswer((_) async => Result.failure(
                  Failure(message: 'Save failed'),
                ));

        // Act
        await viewModel.createProject(
          name: 'New Project',
          description: 'New project description',
        );

        // Assert
        expect(viewModel.state.error, contains('Failed to save project: Save failed'));
      });

      test('should handle project creation when save throws exception', () async {
        // Arrange
        when(mockCalendarRepository.save(any))
            .thenThrow(Exception('Save exception'));

        // Act
        await viewModel.createProject(
          name: 'New Project',
          description: 'New project description',
        );

        // Assert
        expect(viewModel.state.error, contains('Failed to create project: Exception: Save exception'));
      });
    });

    group('Error Handling', () {
      test('should handle repository exceptions gracefully', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenThrow(Exception('Repository error'));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, isNotNull);
        expect(viewModel.state.error!.contains('Failed to load projects: Exception: Repository error'), true);
      });

      test('should handle refresh exceptions', () async {
        // Arrange
        when(mockCalendarRepository.getProjectCalendars())
            .thenThrow(Exception('Refresh error'));

        // Act
        await viewModel.refresh();

        // Assert
        expect(viewModel.state.isRefreshing, false);
        expect(viewModel.state.error, isNotNull);
        expect(viewModel.state.error!.contains('Failed to refresh: Exception: Refresh error'), true);
      });
    });
  });
} 