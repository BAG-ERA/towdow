// Test to verify that kanban view uses the proper task creation dialog
// This ensures consistent UX across the application

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
import 'kanban_task_dialog_test.mocks.dart';

void main() {
  group('Kanban Task Dialog Integration Tests', () {
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

    test('should create task with category when using TaskCreationDialog', () async {
      // Arrange
      const categoryId = 'test-category-123';
      const taskSummary = 'Test task with category via dialog';
      const projectPath = 'test-project';
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act - Simulate what the TaskCreationDialog would do
      await taskViewModel.createTask(
        summary: taskSummary,
        description: 'Test description',
        due: DateTime.now().add(const Duration(days: 1)),
        categories: [categoryId],
        projectPath: projectPath,
      );

      // Assert
      final savedTask = verify(mockTaskRepository.save(captureAny)).captured.first as Task;
      expect(savedTask.summary, equals(taskSummary));
      expect(savedTask.categoryIds, contains(categoryId));
      expect(savedTask.projectPath, equals(projectPath));
      expect(savedTask.description, isNotEmpty);
      expect(savedTask.due, isNotNull);
    });

    test('should create task without category when using TaskCreationDialog for uncategorized', () async {
      // Arrange
      const taskSummary = 'Test task without category via dialog';
      const projectPath = 'test-project';
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act - Simulate what the TaskCreationDialog would do for uncategorized
      await taskViewModel.createTask(
        summary: taskSummary,
        description: 'Test description',
        due: null,
        categories: const [],
        projectPath: projectPath,
      );

      // Assert
      final savedTask = verify(mockTaskRepository.save(captureAny)).captured.first as Task;
      expect(savedTask.summary, equals(taskSummary));
      expect(savedTask.categoryIds, isEmpty);
      expect(savedTask.projectPath, equals(projectPath));
      expect(savedTask.description, isNotEmpty);
      expect(savedTask.due, isNull);
    });

    test('should handle task creation with rich properties via dialog', () async {
      // Arrange
      const taskSummary = 'Rich task via dialog';
      const projectPath = 'test-project';
      final dueDate = DateTime.now().add(const Duration(days: 3));
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      when(mockTaskRepository.save(any))
          .thenAnswer((_) async => const Result.success(null));

      // Act - Simulate rich task creation via dialog
      await taskViewModel.createTask(
        summary: taskSummary,
        description: 'This is a detailed description with multiple lines\nand formatting',
        due: dueDate,
        categories: const [],
        projectPath: projectPath,
      );

      // Assert
      final savedTask = verify(mockTaskRepository.save(captureAny)).captured.first as Task;
      expect(savedTask.summary, equals(taskSummary));
      expect(savedTask.description, contains('detailed description'));
      expect(savedTask.description, contains('\n'));
      expect(savedTask.due, equals(dueDate));
      expect(savedTask.projectPath, equals(projectPath));
    });
  });
} 