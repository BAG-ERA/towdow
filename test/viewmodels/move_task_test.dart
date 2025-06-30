// Tests for move task functionality
// Verifies that tasks can be moved between calendars/projects correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../lib/data/models/task.dart';
import '../../lib/data/models/task_calendar.dart';
import '../../lib/data/repositories/task_repository.dart';
import '../../lib/data/services/sync_service.dart';
import '../../lib/presentation/viewmodels/task_viewmodel.dart';
import '../../lib/presentation/viewmodels/commands/task_commands.dart';
import '../../lib/core/result.dart';

// Mock classes
class MockTaskRepository extends Mock implements TaskRepository {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  group('Move Task Functionality Tests', () {
    late MockTaskRepository mockTaskRepository;
    late MockSyncService mockSyncService;
    late TaskViewModel taskViewModel;

    setUp(() {
      mockTaskRepository = MockTaskRepository();
      mockSyncService = MockSyncService();
      taskViewModel = TaskViewModel(mockTaskRepository, mockSyncService);
    });

    tearDown(() {
      taskViewModel.dispose();
    });

    group('MoveTaskCommand', () {
      test('should move task between calendars successfully', () async {
        // Arrange
        final sourceCalendarUid = 'calendar-1';
        final targetCalendarUid = 'calendar-2';
        
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: sourceCalendarUid,
        );

        final expectedMovedTask = originalTask.copyWith(
          sourceCalendarUid: targetCalendarUid,
          lastModified: DateTime.now(),
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => const Result.success(null));
        
        when(() => mockSyncService.queueSyncOperation(any(), any(), any()))
            .thenAnswer((_) async => const Result.success(null));

        final command = MoveTaskCommand(mockTaskRepository, mockSyncService);
        final params = MoveTaskParams(
          task: originalTask,
          targetCalendarUid: targetCalendarUid,
        );

        // Act
        final result = await command.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.sourceCalendarUid, equals(targetCalendarUid));
        
        // Verify task was saved
        verify(() => mockTaskRepository.save(any())).called(1);
        
        // Verify sync operations were queued (delete from source, create in target)
        verify(() => mockSyncService.queueSyncOperation(
          SyncOperation.delete,
          originalTask.uid,
          any(),
        )).called(1);
        
        verify(() => mockSyncService.queueSyncOperation(
          SyncOperation.create,
          originalTask.uid,
          any(),
        )).called(1);
      });

      test('should not move task if already in target calendar', () async {
        // Arrange
        final calendarUid = 'calendar-1';
        
        final task = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: calendarUid,
        );

        final command = MoveTaskCommand(mockTaskRepository, mockSyncService);
        final params = MoveTaskParams(
          task: task,
          targetCalendarUid: calendarUid,
        );

        // Act
        final result = await command.executeWith(params);

        // Assert
        expect(result, equals(task));
        
        // Verify no operations were performed
        verifyNever(() => mockTaskRepository.save(any()));
        verifyNever(() => mockSyncService.queueSyncOperation(any(), any(), any()));
      });

      test('should handle move without sync service', () async {
        // Arrange
        final sourceCalendarUid = 'calendar-1';
        final targetCalendarUid = 'calendar-2';
        
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: sourceCalendarUid,
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => const Result.success(null));

        final command = MoveTaskCommand(mockTaskRepository); // No sync service
        final params = MoveTaskParams(
          task: originalTask,
          targetCalendarUid: targetCalendarUid,
        );

        // Act
        final result = await command.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.sourceCalendarUid, equals(targetCalendarUid));
        
        // Verify task was saved locally
        verify(() => mockTaskRepository.save(any())).called(1);
      });

      test('should throw exception on repository save failure', () async {
        // Arrange
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: 'calendar-1',
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => Result.failure(Failure(
              message: 'Save failed',
              exception: Exception('Test error'),
            )));

        final command = MoveTaskCommand(mockTaskRepository);
        final params = MoveTaskParams(
          task: originalTask,
          targetCalendarUid: 'calendar-2',
        );

        // Act & Assert
        expect(
          () async => await command.executeWith(params),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('TaskViewModel.moveTask', () {
      test('should update state during move operation', () async {
        // Arrange
        final sourceCalendarUid = 'calendar-1';
        final targetCalendarUid = 'calendar-2';
        
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: sourceCalendarUid,
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => const Result.success(null));
        
        when(() => mockSyncService.queueSyncOperation(any(), any(), any()))
            .thenAnswer((_) async => const Result.success(null));

        // Act
        await taskViewModel.moveTask(originalTask, targetCalendarUid);

        // Assert
        expect(taskViewModel.state.isLoading, isFalse);
        expect(taskViewModel.state.error, isNull);
        expect(taskViewModel.state.selectedTask?.sourceCalendarUid, equals(targetCalendarUid));
      });

      test('should handle move operation failure', () async {
        // Arrange
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: 'calendar-1',
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => Result.failure(Failure(
              message: 'Move failed',
              exception: Exception('Test error'),
            )));

        // Act
        await taskViewModel.moveTask(originalTask, 'calendar-2');

        // Assert
        expect(taskViewModel.state.isLoading, isFalse);
        expect(taskViewModel.state.error, isNotNull);
        expect(taskViewModel.state.error, contains('Move failed'));
      });
    });

    group('Sync Queue Operations', () {
      test('should queue correct sync operations for move', () async {
        // Arrange
        final sourceCalendarUid = 'calendar-1';
        final targetCalendarUid = 'calendar-2';
        final taskUid = 'task-1';
        
        final originalTask = Task(
          uid: taskUid,
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: sourceCalendarUid,
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => const Result.success(null));
        
        when(() => mockSyncService.queueSyncOperation(any(), any(), any()))
            .thenAnswer((_) async => const Result.success(null));

        // Act
        await taskViewModel.moveTask(originalTask, targetCalendarUid);

        // Assert
        // Verify DELETE operation was queued with source calendar data
        verify(() => mockSyncService.queueSyncOperation(
          SyncOperation.delete,
          taskUid,
          argThat(predicate<Map<String, dynamic>>((data) => 
            data['calendarUid'] == sourceCalendarUid &&
            data['taskUid'] == taskUid
          )),
        )).called(1);

        // Verify CREATE operation was queued with target calendar data
        verify(() => mockSyncService.queueSyncOperation(
          SyncOperation.create,
          taskUid,
          argThat(predicate<Map<String, dynamic>>((data) => 
            data['calendarUid'] == targetCalendarUid &&
            data['taskUid'] == taskUid
          )),
        )).called(1);
      });
    });

    group('Edge Cases', () {
      test('should handle task with null sourceCalendarUid', () async {
        // Arrange
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: null, // Task not assigned to any calendar
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => const Result.success(null));
        
        when(() => mockSyncService.queueSyncOperation(any(), any(), any()))
            .thenAnswer((_) async => const Result.success(null));

        // Act
        await taskViewModel.moveTask(originalTask, 'calendar-2');

        // Assert
        expect(taskViewModel.state.isLoading, isFalse);
        expect(taskViewModel.state.error, isNull);
        expect(taskViewModel.state.selectedTask?.sourceCalendarUid, equals('calendar-2'));
        
        // Only CREATE operation should be queued (no DELETE since no source calendar)
        verify(() => mockSyncService.queueSyncOperation(
          SyncOperation.create,
          originalTask.uid,
          any(),
        )).called(1);
        
        verifyNever(() => mockSyncService.queueSyncOperation(
          SyncOperation.delete,
          any(),
          any(),
        ));
      });

      test('should handle empty calendar UIDs', () async {
        // Arrange
        final originalTask = Task(
          uid: 'task-1',
          summary: 'Test Task',
          description: 'Test description',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          sourceCalendarUid: '',
        );

        when(() => mockTaskRepository.save(any()))
            .thenAnswer((_) async => const Result.success(null));

        // Act
        await taskViewModel.moveTask(originalTask, '');

        // Assert
        expect(taskViewModel.state.isLoading, isFalse);
        expect(taskViewModel.state.error, isNull);
        
        // No sync operations should be queued for empty UIDs
        verifyNever(() => mockSyncService.queueSyncOperation(any(), any(), any()));
      });
    });
  });
} 