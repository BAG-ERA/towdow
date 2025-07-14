import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/attendee.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/core/result.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<LocalStorageService>()])
import 'task_with_attendees_test.mocks.dart';

void main() {
  group('Task with Attendees Tests', () {
    late MockLocalStorageService mockStorage;
    late LocalTaskRepository repository;

    setUp(() {
      mockStorage = MockLocalStorageService();
      repository = LocalTaskRepository(mockStorage);
    });

    test('should create and handle tasks with attendees', () async {
      // Create sample tasks with different properties
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      final tasksWithAttendees = [
        Task(
          uid: 'task-1',
          summary: 'Meeting with team',
          description: 'Daily standup',
          status: 'NEEDS-ACTION',
          lastModified: now,
          created: now,
          dtstamp: now,
          due: today,
          attendees: [
            Attendee(email: 'john@example.com', displayName: 'John'),
            Attendee(email: 'jane@example.com', displayName: 'Jane'),
          ],
          projectPath: 'project-1',
        ),
        Task(
          uid: 'task-2',
          summary: 'Review code',
          description: 'Code review session',
          status: 'COMPLETED',
          lastModified: now,
          created: now,
          dtstamp: now,
          due: today,
          attendees: [
            Attendee(email: 'alice@example.com', displayName: 'Alice', role: AttendeeRole.chair),
          ],
          projectPath: 'project-1',
        ),
        Task(
          uid: 'task-3',
          summary: 'Unregistered task',
          description: 'No project assigned',
          status: 'NEEDS-ACTION',
          lastModified: now,
          created: now,
          dtstamp: now,
          due: null,
          attendees: [
            Attendee(email: 'bob@example.com', displayName: 'Bob', status: AttendeeStatus.tentative),
          ],
          projectPath: null, // Unregistered
        ),
        Task(
          uid: 'task-4',
          summary: 'Future task',
          description: 'Future meeting',
          status: 'NEEDS-ACTION',
          lastModified: now,
          created: now,
          dtstamp: now,
          due: tomorrow,
          attendees: [], // No attendees
          projectPath: 'project-2',
        ),
      ];

      // Mock the storage service
      when(mockStorage.getAll<Task>(LocalStorageService.tasksBoxName))
          .thenAnswer((_) async => Result.success(tasksWithAttendees));

      // Test getting all tasks
      final allResult = await repository.getAll();
      expect(allResult, isA<Success<List<Task>>>());
      final allTasks = (allResult as Success<List<Task>>).data;
      expect(allTasks.length, 4);

      // Check attendees
      expect(allTasks[0].attendees.length, 2);
      expect(allTasks[0].attendees[0].email, equals('john@example.com'));
      expect(allTasks[0].attendees[1].email, equals('jane@example.com'));
      
      expect(allTasks[1].attendees.length, 1);
      expect(allTasks[1].attendees[0].email, equals('alice@example.com'));
      expect(allTasks[1].attendees[0].role, equals(AttendeeRole.chair));
      
      expect(allTasks[2].attendees.length, 1);
      expect(allTasks[2].attendees[0].email, equals('bob@example.com'));
      expect(allTasks[2].attendees[0].status, equals(AttendeeStatus.tentative));
      
      expect(allTasks[3].attendees.length, 0);

      // Test today's tasks
      final todayResult = await repository.getTasksWithDueDate(today);
      expect(todayResult, isA<Success<List<Task>>>());
      final todayTasks = (todayResult as Success<List<Task>>).data;
      expect(todayTasks.length, 2); // task-1 and task-2

      // Test unregistered tasks - they should be deleted and return empty list
      final unregisteredResult = await repository.getUnregisteredTasks();
      expect(unregisteredResult, isA<Success<List<Task>>>());
      final unregisteredTasks = (unregisteredResult as Success<List<Task>>).data;
      expect(unregisteredTasks.length, 0); // unregistered tasks are deleted
    });

    test('should properly filter completed tasks', () {
      final now = DateTime.now();
      final tasks = [
        Task(
          uid: 'active-task',
          summary: 'Active task',
          description: 'Not completed',
          status: 'NEEDS-ACTION',
          lastModified: now,
          created: now,
          dtstamp: now,
          attendees: [
            Attendee(email: 'user@example.com', displayName: 'User'),
          ],
        ),
        Task(
          uid: 'completed-task',
          summary: 'Completed task',
          description: 'Already done',
          status: 'COMPLETED',
          lastModified: now,
          created: now,
          dtstamp: now,
          attendees: [
            Attendee(email: 'user@example.com', displayName: 'User', status: AttendeeStatus.accepted),
          ],
        ),
      ];

      // Filter logic like in HomeViewModel
      final activeTasks = tasks.where((task) => task.status != 'COMPLETED').toList();
      expect(activeTasks.length, 1);
      expect(activeTasks.first.uid, 'active-task');

      final completedTasks = tasks.where((task) => task.status == 'COMPLETED').toList();
      expect(completedTasks.length, 1);
      expect(completedTasks.first.uid, 'completed-task');
      expect(completedTasks.first.attendees.first.status, equals(AttendeeStatus.accepted));
    });
  });
} 