// Test for kanban view category task creation functionality
// Verifies that column buttons in kanban view create tasks with the correct category

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/category.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/presentation/viewmodels/task_viewmodel.dart';
import 'package:towdow_app/core/result.dart';

@GenerateNiceMocks([
  MockSpec<TaskRepository>(),
  MockSpec<AccountRepository>(),
])
import 'kanban_category_task_creation_test.mocks.dart';

void main() {
  group('Kanban Category Task Creation Tests', () {
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late TaskViewModel taskViewModel;

    setUp(() {
      mockTaskRepository = MockTaskRepository();
      mockAccountRepository = MockAccountRepository();
      taskViewModel = TaskViewModel(mockTaskRepository, mockAccountRepository);
    });

    tearDown(() {
      taskViewModel.dispose();
    });

    test('should create task with category when category is provided', () async {
      // Arrange
      const categoryId = 'test-category-123';
      const taskSummary = 'Test task with category';
      const projectPath = 'test-project';
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      await taskViewModel.createTask(
        summary: taskSummary,
        categories: [categoryId],
        projectPath: projectPath,
      );

      // Assert
      final savedTask = verify(mockTaskRepository.save(captureAny)).captured.first as Task;
      expect(savedTask.summary, equals(taskSummary));
      expect(savedTask.categoryIds, contains(categoryId));
      expect(savedTask.projectPath, equals(projectPath));
    });

    test('should create task without category when no category is provided', () async {
      // Arrange
      const taskSummary = 'Test task without category';
      const projectPath = 'test-project';
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      await taskViewModel.createTask(
        summary: taskSummary,
        categories: const [],
        projectPath: projectPath,
      );

      // Assert
      final savedTask = verify(mockTaskRepository.save(captureAny)).captured.first as Task;
      expect(savedTask.summary, equals(taskSummary));
      expect(savedTask.categoryIds, isEmpty);
      expect(savedTask.projectPath, equals(projectPath));
    });

    test('should create task with multiple categories when multiple categories are provided', () async {
      // Arrange
      const categoryIds = ['category-1', 'category-2', 'category-3'];
      const taskSummary = 'Test task with multiple categories';
      const projectPath = 'test-project';
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act
      await taskViewModel.createTask(
        summary: taskSummary,
        categories: categoryIds,
        projectPath: projectPath,
      );

      // Assert
      final savedTask = verify(mockTaskRepository.save(captureAny)).captured.first as Task;
      expect(savedTask.summary, equals(taskSummary));
      expect(savedTask.categoryIds, containsAll(categoryIds));
      expect(savedTask.projectPath, equals(projectPath));
    });

    test('should handle task creation failure gracefully', () async {
      // Arrange
      const taskSummary = 'Test task that fails';
      const categoryId = 'test-category';
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.failure(Failure(message: 'Save failed')));

      // Act
      await taskViewModel.createTask(
        summary: taskSummary,
        categories: [categoryId],
      );

      // Assert
      verify(mockTaskRepository.save(any)).called(1);
      
      // Verify the state reflects the error
      expect(taskViewModel.state.error, isNotNull);
      expect(taskViewModel.state.error!.contains('Save failed'), isTrue);
    });
  });
} 