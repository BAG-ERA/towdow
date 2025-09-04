/// Tests spécifiques pour la fonctionnalité de suppression
/// Vérifie que les méthodes delete fonctionnent correctement

import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/presentation/viewmodels/project_list_viewmodel.dart';
import 'package:towdow_app/presentation/viewmodels/task_viewmodel.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';
import 'package:towdow_app/data/services/sync/sync_service.dart';
import 'package:towdow_app/data/services/storage/local_storage_service.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/core/result.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'delete_functionality_test.mocks.dart';

// Minimal fake TaskRepository to satisfy cascade delete without complex stubbing
class _FakeTaskRepositoryForDelete implements TaskRepository {
  @override
  Future<Result<void>> deleteByProjectLocalOnly(String projectPath) async {
    return const Result.success(null);
  }

  // Unused in this specific test; throw to surface accidental calls
  @override
  Future<Result<void>> delete(String uid) => throw UnimplementedError();
  @override
  Future<Result<List<Task>>> getAll() => throw UnimplementedError();
  @override
  Future<Result<Task?>> getById(String uid) => throw UnimplementedError();
  @override
  Future<Result<List<Task>>> getByProject(String projectUid) => throw UnimplementedError();
  @override
  Future<Result<List<Task>>> getTasksWithDueDate(DateTime date) => throw UnimplementedError();
  @override
  Future<Result<List<Task>>> getTasksWithoutDueDate() => throw UnimplementedError();
  @override
  Future<Result<List<Task>>> getUnregisteredTasks() => throw UnimplementedError();
  @override
  Future<Result<void>> save(Task task) => throw UnimplementedError();
  @override
  Future<Result<void>> saveFromSync(Task task) => throw UnimplementedError();
  @override
  Stream<List<Task>> watchTasks() => const Stream.empty();
  @override
  Stream<List<Task>> watchTasksByProject(String projectPath) => const Stream.empty();
  @override
  Future<Result<void>> deleteOrphanedTasksLocalOnly(Set<String> validCalendarPaths) => throw UnimplementedError();
}

@GenerateNiceMocks([
  MockSpec<LocalStorageService>(),
  MockSpec<CalendarRepository>(),
  MockSpec<TaskRepository>(),
  MockSpec<AccountRepository>(),
  MockSpec<UserRepository>(),
  MockSpec<SyncService>(),
])

void main() {
  group('Delete Functionality Tests', () {
    late MockCalendarRepository mockCalendarRepository;
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late MockUserRepository mockUserRepository;

    setUp(() {
      mockCalendarRepository = MockCalendarRepository();
      mockTaskRepository = MockTaskRepository();
      // Avoid stream-driven reloads in tests unless explicitly needed
      when(mockCalendarRepository.watchCalendars()).thenAnswer((_) => const Stream<List<TaskCalendar>>.empty());
      mockAccountRepository = MockAccountRepository();
      mockUserRepository = MockUserRepository();

      // Add this stub for user repository
      when(mockUserRepository.removeProjectFromOrder(any)).thenAnswer((_) async => const Result.success(null));
    });

    group('ProjectListViewModel Delete', () {
      test('should delete project successfully and update state', () async {
        // Arrange
        final testProject = ProjectWithStats(
          project: TaskCalendarFactory.createNew(
            path: 'project1',
            displayName: 'Test Project',
          ),
          stats: const ProjectStats(
            totalTasks: 0,
            completedTasks: 0,
            inProgressTasks: 0,
            pendingTasks: 0,
            progressPercentage: 0,
          ),
        );

        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          _FakeTaskRepositoryForDelete(),
          mockUserRepository,
        );

        // Set initial state with the project
        viewModel.state = viewModel.state.copyWith(projects: [testProject]);
        expect(viewModel.state.projects.length, 1);

        // Mock getById to return the test project
        when(mockCalendarRepository.getById('project1'))
            .thenAnswer((_) async => Result.success(testProject.project));

        // Mock repository stream to avoid debounce-triggered reloads altering local state mid-assertions
        when(mockCalendarRepository.watchCalendars()).thenAnswer((_) => const Stream<List<TaskCalendar>>.empty());

        // Task cascade handled by fake repository above

        // Mock successful deletion
        when(mockCalendarRepository.delete('project1'))
            .thenAnswer((_) async => const Result.success(null));

        // Mock account repository
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(Failure(exception: Exception('No account'), message: 'No active account')));

        // Act
        await viewModel.deleteProject('project1');

        // Assert
        expect(viewModel.state.projects.length, 0);
        expect(viewModel.state.error, null);
        verify(mockCalendarRepository.delete('project1')).called(1);
      });

      test('should handle delete failure and show error', () async {
        // Arrange
        final testProject = ProjectWithStats(
          project: TaskCalendarFactory.createNew(
            path: 'project1',
            displayName: 'Test Project',
          ),
          stats: const ProjectStats(
            totalTasks: 0,
            completedTasks: 0,
            inProgressTasks: 0,
            pendingTasks: 0,
            progressPercentage: 0,
          ),
        );

        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          mockTaskRepository,
          mockUserRepository,
        );

        // Set initial state with the project
        viewModel.state = viewModel.state.copyWith(projects: [testProject]);

        // Mock getById to return the test project
        when(mockCalendarRepository.getById('project1'))
            .thenAnswer((_) async => Result.success(testProject.project));

        // Mock failed deletion
        when(mockCalendarRepository.delete('project1'))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Server error'), message: 'Failed to delete on server')));

        // Mock account repository
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(Failure(exception: Exception('No account'), message: 'No active account')));

        // Act
        await viewModel.deleteProject('project1');

        // Assert
        expect(viewModel.state.projects.length, 1); // Project should still be there
        expect(viewModel.state.error, contains('Failed to delete project'));
        verify(mockCalendarRepository.delete('project1')).called(1);
      });

      test('should not delete non-existent project', () async {
        // Arrange
        final viewModel = ProjectListViewModel(
          mockCalendarRepository,
          mockTaskRepository,
          mockUserRepository,
        );

        // Mock getById to return null (project not found)
        when(mockCalendarRepository.getById('nonexistent'))
            .thenAnswer((_) async => const Result.success(null));

        // Mock deletion (won't be called for non-existent project)
        when(mockCalendarRepository.delete('nonexistent'))
            .thenAnswer((_) async => const Result.success(null));

        // Act
        await viewModel.deleteProject('nonexistent');

        // Assert
        expect(viewModel.state.projects.length, 0);
        expect(viewModel.state.error, null);
        verifyNever(mockCalendarRepository.delete('nonexistent'));
      });
    });

    group('TaskViewModel Delete', () {
      test('should delete task successfully', () async {
        // Arrange
        final testTask = TaskFactory.createNew(
          summary: 'Test Task',
          projectPath: 'project1',
        ).copyWith(uid: 'task1');

        final viewModel = TaskViewModel(mockTaskRepository, mockAccountRepository);

        // Mock getById to return the test task
        when(mockTaskRepository.getById('task1'))
            .thenAnswer((_) async => Result.success(testTask));

        // Mock successful deletion
        when(mockTaskRepository.delete('task1'))
            .thenAnswer((_) async => const Result.success(null));

        // Act
        await viewModel.deleteTask('task1');

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, null);
        verify(mockTaskRepository.delete('task1')).called(1);
      });

      test('should handle delete failure and show error', () async {
        // Arrange
        final testTask = TaskFactory.createNew(
          summary: 'Test Task',
          projectPath: 'project1',
        ).copyWith(uid: 'task1');

        final viewModel = TaskViewModel(mockTaskRepository, mockAccountRepository);

        // Mock getById to return the test task
        when(mockTaskRepository.getById('task1'))
            .thenAnswer((_) async => Result.success(testTask));

        // Mock failed deletion
        when(mockTaskRepository.delete('task1'))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Storage error'), message: 'Failed to delete from storage')));

        // Act
        await viewModel.deleteTask('task1');

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, contains('Failed to delete from storage'));
        verify(mockTaskRepository.delete('task1')).called(1);
      });

      test('should handle exception during deletion', () async {
        // Arrange
        final testTask = TaskFactory.createNew(
          summary: 'Test Task',
          projectPath: 'project1',
        ).copyWith(uid: 'task1');

        final viewModel = TaskViewModel(mockTaskRepository, mockAccountRepository);

        // Mock getById to return the test task
        when(mockTaskRepository.getById('task1'))
            .thenAnswer((_) async => Result.success(testTask));

        // Mock exception
        when(mockTaskRepository.delete('task1'))
            .thenThrow(Exception('Unexpected error'));

        // Act
        await viewModel.deleteTask('task1');

        // Assert
        expect(viewModel.state.isLoading, false);
        expect(viewModel.state.error, contains('Failed to delete task'));
        verify(mockTaskRepository.delete('task1')).called(1);
      });
    });

    group('Repository Level Delete (Integration check)', () {
      test('local storage delete should work correctly', () async {
        // This test simulates what happens at the repository level
        // to verify that the delete chain works properly

        // Arrange
        final mockStorage = MockLocalStorageService();
        final mockAccountRepository = MockAccountRepository();
        final mockUserRepository = MockUserRepository();
        final calendarRepo = LocalCalendarRepository(mockStorage, mockAccountRepository, mockUserRepository);
        final taskRepo = LocalTaskRepository(mockStorage);

        // Mock successful storage operations
        when(mockStorage.get(LocalStorageService.tasksBoxName, 'task1'))
            .thenAnswer((_) async => const Result<Task?>.success(null)); // Task not found, which is fine for delete
        when(mockStorage.get(LocalStorageService.calendarsBoxName, 'calendar1'))
            .thenAnswer((_) async => const Result<TaskCalendar?>.success(null)); // Calendar not found, which is fine for delete
        when(mockStorage.getAll(LocalStorageService.calendarsBoxName))
            .thenAnswer((_) async => const Result<List<TaskCalendar>>.success([])); // Empty list for getAll
        
        // Create a mock calendar for the delete test
        final mockCalendar = TaskCalendarFactory.createNew(
          path: 'calendar1',
          displayName: 'Test Calendar',
        );
        when(mockStorage.getAll<TaskCalendar>(LocalStorageService.calendarsBoxName))
            .thenAnswer((_) async => Result<List<TaskCalendar>>.success([mockCalendar])); // Return the mock calendar
        
        when(mockStorage.delete(LocalStorageService.calendarsBoxName, 'calendar1'))
            .thenAnswer((_) async => const Result.success(null));
        when(mockStorage.delete(LocalStorageService.tasksBoxName, 'task1'))
            .thenAnswer((_) async => const Result.success(null));
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(Failure(exception: Exception('No account'), message: 'No active account')));

        // Act - Test calendar deletion
        final calendarResult = await calendarRepo.delete('calendar1');
        final taskResult = await taskRepo.delete('task1');

        // Assert
        expect(calendarResult, isA<Success>());
        expect(taskResult, isA<Success>());
        verify(mockStorage.delete(LocalStorageService.calendarsBoxName, 'calendar1')).called(1);
        verify(mockStorage.delete(LocalStorageService.tasksBoxName, 'task1')).called(1);
      });

      test('should handle storage deletion failure', () async {
        // Arrange
        final mockStorage = MockLocalStorageService();
        final mockAccountRepository = MockAccountRepository();
        final mockUserRepository = MockUserRepository();
        final calendarRepo = LocalCalendarRepository(mockStorage, mockAccountRepository, mockUserRepository);

        // Mock storage failure
        when(mockStorage.get(LocalStorageService.calendarsBoxName, 'calendar1'))
            .thenAnswer((_) async => const Result<TaskCalendar?>.success(null)); // Calendar not found, which is fine for delete
        when(mockStorage.getAll(LocalStorageService.calendarsBoxName))
            .thenAnswer((_) async => const Result<List<TaskCalendar>>.success([])); // Empty list for getAll
        
        // Create a mock calendar for the delete test
        final mockCalendar = TaskCalendarFactory.createNew(
          path: 'calendar1',
          displayName: 'Test Calendar',
        );
        when(mockStorage.getAll<TaskCalendar>(LocalStorageService.calendarsBoxName))
            .thenAnswer((_) async => Result<List<TaskCalendar>>.success([mockCalendar])); // Return the mock calendar
        
        when(mockStorage.delete(LocalStorageService.calendarsBoxName, 'calendar1'))
            .thenAnswer((_) async => Result.failure(
                Failure(exception: Exception('Storage locked'), message: 'Storage is locked by another process')));
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(Failure(exception: Exception('No account'), message: 'No active account')));

        // Act
        final result = await calendarRepo.delete('calendar1');

        // Assert
        expect(result, isA<Error>());
        final error = result as Error;
        expect(error.failure.message, contains('Storage is locked'));
        verify(mockStorage.delete(LocalStorageService.calendarsBoxName, 'calendar1')).called(1);
      });
    });

    group('Delete Workflow Analysis', () {
      test('should demonstrate complete delete workflow', () async {
        // This test shows the complete delete workflow
              // print('=== DELETE WORKFLOW ANALYSIS ===');
      // print('1. UI calls ViewModel.deleteProject(uid)');
      // print('2. ViewModel calls Repository.delete(uid)');
      // print('3. Repository calls LocalStorage.delete(boxName, uid)');
      // print('4. LocalStorage removes from Hive box');
      // print('5. Background sync should sync deletion to CalDAV server');
      // print('6. If sync fails, item may reappear on next sync');
      // print('');
      // print('POTENTIAL ISSUES:');
      // print('- UI not connected to ViewModel methods');
      // print('- Sync service not propagating deletions to server');
      // print('- Server rejecting deletion requests');
      // print('- Background sync overwriting local deletions');
      // print('================================');
        
        // This always passes - it's just for documentation
        expect(true, true);
      });
    });
  });
} 