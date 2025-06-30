/// Tests unitaires pour ProjectListViewModel
/// Teste la logique métier de gestion de la liste des projets avec synchronisation

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flowit_app/presentation/viewmodels/project_list_viewmodel.dart';
import 'package:flowit_app/data/repositories/calendar_repository.dart';
import 'package:flowit_app/data/repositories/task_repository.dart';
import 'package:flowit_app/data/services/sync_service.dart';
import 'package:flowit_app/data/models/task_calendar.dart';
import 'package:flowit_app/data/models/task.dart';
import 'package:flowit_app/core/result.dart';

// Generate mocks
@GenerateMocks([CalendarRepository, TaskRepository, SyncService])
import 'project_list_viewmodel_test.mocks.dart';

void main() {
  group('ProjectListViewModel', () {
    late ProjectListViewModel viewModel;
    late MockCalendarRepository mockCalendarRepository;
    late MockTaskRepository mockTaskRepository;
    late MockSyncService mockSyncService;

    setUp(() {
      mockCalendarRepository = MockCalendarRepository();
      mockTaskRepository = MockTaskRepository();
      mockSyncService = MockSyncService();

      viewModel = ProjectListViewModel(
        mockCalendarRepository,
        mockTaskRepository,
        mockSyncService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state should be default', () {
      expect(viewModel.state.isLoading, false);
      expect(viewModel.state.isRefreshing, false);
      expect(viewModel.state.error, null);
      expect(viewModel.state.projects, isEmpty);
      expect(viewModel.state.filter, ProjectFilter.all);
      expect(viewModel.state.sortBy, ProjectSort.name);
      expect(viewModel.state.searchQuery, '');
      expect(viewModel.state.totalProjects, 0);
      expect(viewModel.state.completedProjects, 0);
      expect(viewModel.state.activeProjects, 0);
    });

    group('initialize', () {
      test('should load projects successfully', () async {
        // Arrange
        final testCalendars = [
          TaskCalendar(
            path: '/test/calendar1',
            displayName: 'Test Project 1',
            uid: 'project1',
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            summary: 'Test Project 1',
            status: 'NEEDS-ACTION',
          ),
          TaskCalendar(
            path: '/test/calendar2',
            displayName: 'Test Project 2',
            uid: 'project2',
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            summary: 'Test Project 2',
            status: 'NEEDS-ACTION',
          ),
        ];

        final testTasks = [
          Task.createNew(
            uid: 'task1',
            summary: 'Test Task 1',
            sourceCalendarUid: 'project1',
          ),
          Task.createNew(
            uid: 'task2',
            summary: 'Test Task 2',
            sourceCalendarUid: 'project1',
            status: 'COMPLETED',
          ),
          Task.createNew(
            uid: 'task3',
            summary: 'Test Task 3',
            sourceCalendarUid: 'project2',
          ),
        ];

        when(() => mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success(testCalendars));
        when(() => mockTaskRepository.getByProject('project1'))
            .thenAnswer((_) async => Result.success([testTasks[0], testTasks[1]]));
        when(() => mockTaskRepository.getByProject('project2'))
            .thenAnswer((_) async => Result.success([testTasks[2]]));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.projects.length, 2);
        expect(viewModel.state.totalProjects, 2);
        expect(viewModel.state.completedProjects, 0); // No project is 100% complete
        expect(viewModel.state.activeProjects, 2);
        expect(viewModel.state.error, null);

        // Check project statistics
        final project1 = viewModel.state.projects.firstWhere((p) => p.project.uid == 'project1');
        expect(project1.stats.totalTasks, 2);
        expect(project1.stats.completedTasks, 1);
        expect(project1.stats.progressPercentage, 50);
      });

      test('should handle calendar loading failure', () async {
        // Arrange
        when(() => mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Test error'), message: 'Failed to load')));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, contains('Failed to load projects'));
      });

      test('should handle task loading failure gracefully', () async {
        // Arrange
        final testCalendars = [
          TaskCalendar(
            path: '/test/calendar1',
            displayName: 'Test Project 1',
            uid: 'project1',
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            summary: 'Test Project 1',
            status: 'NEEDS-ACTION',
          ),
        ];

        when(() => mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success(testCalendars));
        when(() => mockTaskRepository.getByProject('project1'))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Task error'), message: 'Failed to load tasks')));

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.projects.length, 1);
        expect(viewModel.state.projects.first.syncError, 'Failed to load tasks');
      });
    });

    group('refresh', () {
      test('should trigger sync and reload projects', () async {
        // Arrange
        when(() => mockSyncService.syncNow())
            .thenAnswer((_) async => Result.success(SyncResult(
              tasksUpdated: 1,
              calendarsUpdated: 1,
              conflicts: [],
            )));
        when(() => mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success([]));

        // Act
        await viewModel.refresh();

        // Assert
        verify(() => mockSyncService.syncNow()).called(1);
        expect(viewModel.state.isRefreshing, false);
      });

      test('should continue refresh even if sync fails', () async {
        // Arrange
        when(() => mockSyncService.syncNow())
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Sync error'), message: 'Sync failed')));
        when(() => mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success([]));

        // Act
        await viewModel.refresh();

        // Assert
        verify(() => mockSyncService.syncNow()).called(1);
        verify(() => mockCalendarRepository.getProjectCalendars()).called(1);
        expect(viewModel.state.isRefreshing, false);
      });
    });

    group('filters and search', () {
      test('setSearchQuery should update search query', () {
        // Act
        viewModel.setSearchQuery('test query');

        // Assert
        expect(viewModel.state.searchQuery, 'test query');
      });

      test('setFilter should update filter', () {
        // Act
        viewModel.setFilter(ProjectFilter.completed);

        // Assert
        expect(viewModel.state.filter, ProjectFilter.completed);
      });

      test('setSortBy should update sort order', () {
        // Act
        viewModel.setSortBy(ProjectSort.progress);

        // Assert
        expect(viewModel.state.sortBy, ProjectSort.progress);
      });

      test('clearFilters should reset search and filter', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(
          searchQuery: 'test',
          filter: ProjectFilter.completed,
        );

        // Act
        viewModel.clearFilters();

        // Assert
        expect(viewModel.state.searchQuery, '');
        expect(viewModel.state.filter, ProjectFilter.all);
      });
    });

    group('filteredProjects', () {
      setUp(() {
        // Setup test data for filtering tests
        final projects = [
          ProjectWithStats(
            project: TaskCalendar(
              path: '/test/calendar1',
              displayName: 'Active Project',
              description: 'An active project',
              uid: 'project1',
              dtstamp: DateTime.now(),
              created: DateTime.now(),
              lastModified: DateTime.now(),
              summary: 'Active Project',
              status: 'NEEDS-ACTION',
            ),
            stats: const ProjectStats(
              totalTasks: 10,
              completedTasks: 5,
              inProgressTasks: 3,
              pendingTasks: 2,
              progressPercentage: 50,
            ),
          ),
          ProjectWithStats(
            project: TaskCalendar(
              path: '/test/calendar2',
              displayName: 'Completed Project',
              description: 'A completed project',
              uid: 'project2',
              dtstamp: DateTime.now(),
              created: DateTime.now(),
              lastModified: DateTime.now(),
              summary: 'Completed Project',
              status: 'COMPLETED',
            ),
            stats: const ProjectStats(
              totalTasks: 5,
              completedTasks: 5,
              inProgressTasks: 0,
              pendingTasks: 0,
              progressPercentage: 100,
            ),
          ),
          ProjectWithStats(
            project: TaskCalendar(
              path: '/test/calendar3',
              displayName: 'New Project',
              description: 'A new project',
              uid: 'project3',
              dtstamp: DateTime.now(),
              created: DateTime.now(),
              lastModified: DateTime.now(),
              summary: 'New Project',
              status: 'NEEDS-ACTION',
            ),
            stats: const ProjectStats(
              totalTasks: 0,
              completedTasks: 0,
              inProgressTasks: 0,
              pendingTasks: 0,
              progressPercentage: 0,
            ),
          ),
        ];

        viewModel.state = viewModel.state.copyWith(projects: projects);
      });

      test('should filter by search query', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(searchQuery: 'active');

        // Act
        final filtered = viewModel.state.filteredProjects;

        // Assert
        expect(filtered.length, 1);
        expect(filtered.first.project.displayName, 'Active Project');
      });

      test('should filter by active status', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(filter: ProjectFilter.active);

        // Act
        final filtered = viewModel.state.filteredProjects;

        // Assert
        expect(filtered.length, 2); // Active and New projects (not 100% complete)
        expect(filtered.any((p) => p.project.displayName == 'Completed Project'), false);
      });

      test('should filter by completed status', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(filter: ProjectFilter.completed);

        // Act
        final filtered = viewModel.state.filteredProjects;

        // Assert
        expect(filtered.length, 1);
        expect(filtered.first.project.displayName, 'Completed Project');
      });

      test('should filter by in progress status', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(filter: ProjectFilter.inProgress);

        // Act
        final filtered = viewModel.state.filteredProjects;

        // Assert
        expect(filtered.length, 1);
        expect(filtered.first.project.displayName, 'Active Project');
      });

      test('should filter by not started status', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(filter: ProjectFilter.notStarted);

        // Act
        final filtered = viewModel.state.filteredProjects;

        // Assert
        expect(filtered.length, 1);
        expect(filtered.first.project.displayName, 'New Project');
      });

      test('should sort by name', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(sortBy: ProjectSort.name);

        // Act
        final sorted = viewModel.state.filteredProjects;

        // Assert
        expect(sorted[0].project.displayName, 'Active Project');
        expect(sorted[1].project.displayName, 'Completed Project');
        expect(sorted[2].project.displayName, 'New Project');
      });

      test('should sort by progress descending', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(sortBy: ProjectSort.progress);

        // Act
        final sorted = viewModel.state.filteredProjects;

        // Assert
        expect(sorted[0].stats.progressPercentage, 100); // Completed
        expect(sorted[1].stats.progressPercentage, 50);  // Active
        expect(sorted[2].stats.progressPercentage, 0);   // New
      });
    });

    group('createProject', () {
      test('should create project successfully', () async {
        // Arrange
        when(() => mockCalendarRepository.save(any()))
            .thenAnswer((_) async => Result.success(null));
        when(() => mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => Result.success([]));

        // Act
        await viewModel.createProject(
          name: 'New Project',
          description: 'Test description',
          organizer: 'test@example.com',
          categories: ['work'],
        );

        // Assert
        verify(() => mockCalendarRepository.save(any())).called(1);
        verify(() => mockCalendarRepository.getProjectCalendars()).called(1);
        expect(viewModel.state.error, null);
      });

      test('should handle creation failure', () async {
        // Arrange
        when(() => mockCalendarRepository.save(any()))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Save error'), message: 'Failed to save')));

        // Act
        await viewModel.createProject(
          name: 'New Project',
          description: 'Test description',
        );

        // Assert
        expect(viewModel.state.error, contains('Failed to create project'));
      });
    });

    group('deleteProject', () {
      test('should delete project successfully', () async {
        // Arrange
        final projects = [
          ProjectWithStats(
            project: TaskCalendar(
              path: '/test/calendar1',
              displayName: 'Test Project',
              uid: 'project1',
              dtstamp: DateTime.now(),
              created: DateTime.now(),
              lastModified: DateTime.now(),
              summary: 'Test Project',
              status: 'NEEDS-ACTION',
            ),
            stats: const ProjectStats(
              totalTasks: 0,
              completedTasks: 0,
              inProgressTasks: 0,
              pendingTasks: 0,
              progressPercentage: 0,
            ),
          ),
        ];

        viewModel.state = viewModel.state.copyWith(projects: projects);

        when(() => mockCalendarRepository.delete('project1'))
            .thenAnswer((_) async => Result.success(null));

        // Act
        await viewModel.deleteProject('project1');

        // Assert
        verify(() => mockCalendarRepository.delete('project1')).called(1);
        expect(viewModel.state.projects, isEmpty);
        expect(viewModel.state.error, null);
      });

      test('should handle deletion failure', () async {
        // Arrange
        when(() => mockCalendarRepository.delete('project1'))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Delete error'), message: 'Failed to delete')));

        // Act
        await viewModel.deleteProject('project1');

        // Assert
        expect(viewModel.state.error, contains('Failed to delete project'));
      });
    });

    group('getters and utility methods', () {
      test('getProjectById should return project when found', () {
        // Arrange
        final project = ProjectWithStats(
          project: TaskCalendar(
            path: '/test/calendar1',
            displayName: 'Test Project',
            uid: 'project1',
            dtstamp: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            summary: 'Test Project',
            status: 'NEEDS-ACTION',
          ),
          stats: const ProjectStats(
            totalTasks: 0,
            completedTasks: 0,
            inProgressTasks: 0,
            pendingTasks: 0,
            progressPercentage: 0,
          ),
        );

        viewModel.state = viewModel.state.copyWith(projects: [project]);

        // Act
        final found = viewModel.getProjectById('project1');

        // Assert
        expect(found, isNotNull);
        expect(found!.project.uid, 'project1');
      });

      test('getProjectById should return null when not found', () {
        // Act
        final found = viewModel.getProjectById('nonexistent');

        // Assert
        expect(found, isNull);
      });

      test('isAnySyncing should return true when any project is syncing', () {
        // Arrange
        final projects = [
          ProjectWithStats(
            project: TaskCalendar(
              path: '/test/calendar1',
              displayName: 'Test Project',
              uid: 'project1',
              dtstamp: DateTime.now(),
              created: DateTime.now(),
              lastModified: DateTime.now(),
              summary: 'Test Project',
              status: 'NEEDS-ACTION',
            ),
            stats: const ProjectStats(
              totalTasks: 0,
              completedTasks: 0,
              inProgressTasks: 0,
              pendingTasks: 0,
              progressPercentage: 0,
            ),
            isSyncing: true,
          ),
        ];

        viewModel.state = viewModel.state.copyWith(projects: projects);

        // Act & Assert
        expect(viewModel.isAnySyncing, true);
      });

      test('clearError should clear error state', () {
        // Arrange
        viewModel.state = viewModel.state.copyWith(error: 'Test error');

        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.state.error, null);
      });

      test('getFilterDisplayName should return correct names', () {
        expect(viewModel.getFilterDisplayName(ProjectFilter.all), 'All Projects');
        expect(viewModel.getFilterDisplayName(ProjectFilter.active), 'Active');
        expect(viewModel.getFilterDisplayName(ProjectFilter.completed), 'Completed');
        expect(viewModel.getFilterDisplayName(ProjectFilter.inProgress), 'In Progress');
        expect(viewModel.getFilterDisplayName(ProjectFilter.notStarted), 'Not Started');
      });

      test('getSortDisplayName should return correct names', () {
        expect(viewModel.getSortDisplayName(ProjectSort.name), 'Name');
        expect(viewModel.getSortDisplayName(ProjectSort.progress), 'Progress');
        expect(viewModel.getSortDisplayName(ProjectSort.created), 'Created');
        expect(viewModel.getSortDisplayName(ProjectSort.lastModified), 'Modified');
        expect(viewModel.getSortDisplayName(ProjectSort.taskCount), 'Task Count');
      });
    });
  });
} 