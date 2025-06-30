import 'package:flutter_test/flutter_test.dart';
import 'package:flowit_app/data/models/task.dart';
import 'package:flowit_app/data/models/attendee.dart';
import 'package:flowit_app/data/repositories/task_repository.dart';
import 'package:flowit_app/data/services/local_storage_service.dart';
import 'package:flowit_app/core/result.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<LocalStorageService>()])
import 'attendees_sync_test.mocks.dart';

void main() {
  group('Attendees Synchronization Tests', () {
    late MockLocalStorageService mockStorage;
    late LocalTaskRepository repository;

    setUp(() {
      mockStorage = MockLocalStorageService();
      repository = LocalTaskRepository(mockStorage);
    });

    test('should preserve attendees when saving and retrieving tasks', () async {
      // Arrange - Create a task with multiple attendees (realistic CalDAV data)
      final now = DateTime.now();
      final taskWithAttendees = Task(
        uid: 'test-task-with-attendees-001',
        summary: 'Meeting with team',
        description: 'Weekly team meeting to discuss project progress',
        status: 'NEEDS-ACTION',
        created: now.subtract(const Duration(days: 1)),
        lastModified: now,
        dtstamp: now,
        due: now.add(const Duration(days: 1)),
        sourceCalendarUid: 'work-calendar-uid',
        attendees: [
          Attendee(email: 'john.doe@company.com', displayName: 'John Doe'),
          Attendee(email: 'jane.smith@company.com', displayName: 'Jane Smith'),
          Attendee(email: 'manager@company.com', displayName: 'Manager', role: AttendeeRole.chair),
        ],
      );

      // Mock storage responses
      when(mockStorage.put(any, any, any))
          .thenAnswer((_) async => const Result.success(null));
      
      when(mockStorage.get<Task>(any, any))
          .thenAnswer((_) async => Result.success(taskWithAttendees));
      
      when(mockStorage.getAll<Task>(any))
          .thenAnswer((_) async => Result.success([taskWithAttendees]));

      // Act - Save the task
      final saveResult = await repository.save(taskWithAttendees);
      
      // Assert - Save was successful
      expect(saveResult, isA<Success>());
      
      // Act - Retrieve the task by ID
      final getByIdResult = await repository.getById(taskWithAttendees.uid);
      
      // Assert - Task retrieved successfully with attendees intact
      expect(getByIdResult, isA<Success>());
      final retrievedTask = (getByIdResult as Success<Task?>).data!;
      
      expect(retrievedTask.uid, equals(taskWithAttendees.uid));
      expect(retrievedTask.summary, equals(taskWithAttendees.summary));
      expect(retrievedTask.attendees.length, equals(3));
      
      // Check attendee objects
      expect(retrievedTask.attendees[0].email, equals('john.doe@company.com'));
      expect(retrievedTask.attendees[0].displayName, equals('John Doe'));
      expect(retrievedTask.attendees[1].email, equals('jane.smith@company.com'));
      expect(retrievedTask.attendees[1].displayName, equals('Jane Smith'));
      expect(retrievedTask.attendees[2].email, equals('manager@company.com'));
      expect(retrievedTask.attendees[2].role, equals(AttendeeRole.chair));
      
      // Act - Get all tasks
      final getAllResult = await repository.getAll();
      
      // Assert - All tasks include attendees
      expect(getAllResult, isA<Success>());
      final allTasks = (getAllResult as Success<List<Task>>).data;
      expect(allTasks.length, equals(1));
      
      final firstTask = allTasks.first;
      expect(firstTask.attendees.length, equals(3));
      expect(firstTask.attendees.map((a) => a.email), containsAll([
        'john.doe@company.com',
        'jane.smith@company.com',
        'manager@company.com',
      ]));
    });

    test('should handle tasks without attendees correctly', () async {
      // Arrange - Task without attendees
      final now = DateTime.now();
      final taskWithoutAttendees = Task(
        uid: 'test-task-no-attendees-001',
        summary: 'Personal reminder',
        description: 'Remember to call mom',
        status: 'NEEDS-ACTION',
        created: now,
        lastModified: now,
        dtstamp: now,
        due: now.add(const Duration(hours: 2)),
        sourceCalendarUid: 'personal-calendar-uid',
        attendees: [], // Empty attendees list
      );

      // Mock storage
      when(mockStorage.getAll<Task>(any))
          .thenAnswer((_) async => Result.success([taskWithoutAttendees]));

      // Act
      final result = await repository.getAll();

      // Assert
      expect(result, isA<Success>());
      final tasks = (result as Success<List<Task>>).data;
      expect(tasks.first.attendees, isEmpty);
    });

    test('should filter tasks by project while preserving attendees', () async {
      // Arrange - Multiple tasks with different projects
      final now = DateTime.now();
      final task1 = Task(
        uid: 'project-a-task-001',
        summary: 'Project A meeting',
        description: 'Weekly project A meeting',
        status: 'NEEDS-ACTION',
        created: now,
        lastModified: now,
        dtstamp: now,
        sourceCalendarUid: 'project-a-calendar',
        attendees: [
          Attendee(email: 'team-a@company.com', displayName: 'Team A'),
          Attendee(email: 'lead-a@company.com', displayName: 'Lead A', role: AttendeeRole.chair),
        ],
      );

      final task2 = Task(
        uid: 'project-b-task-001', 
        summary: 'Project B review',
        description: 'Code review for project B',
        status: 'NEEDS-ACTION',
        created: now,
        lastModified: now,
        dtstamp: now,
        sourceCalendarUid: 'project-b-calendar',
        attendees: [
          Attendee(email: 'team-b@company.com', displayName: 'Team B'),
        ],
      );

      // Mock storage
      when(mockStorage.getAll<Task>(any))
          .thenAnswer((_) async => Result.success([task1, task2]));

      // Act - Filter by project A
      final result = await repository.getByProject('project-a-calendar');

      // Assert - Only project A task returned, with attendees preserved
      expect(result, isA<Success>());
      final projectTasks = (result as Success<List<Task>>).data;
      expect(projectTasks.length, equals(1));
      
      final projectTask = projectTasks.first;
      expect(projectTask.uid, equals('project-a-task-001'));
      expect(projectTask.attendees.length, equals(2));
      expect(projectTask.attendees[0].email, equals('team-a@company.com'));
      expect(projectTask.attendees[1].email, equals('lead-a@company.com'));
      expect(projectTask.attendees[1].role, equals(AttendeeRole.chair));
    });

    test('should handle different attendee statuses and roles', () async {
      // Arrange - Task with attendees having different statuses
      final now = DateTime.now();
      final taskWithVariousAttendees = Task(
        uid: 'various-attendees-test',
        summary: 'Test various attendee types',
        description: 'Testing different attendee statuses and roles',
        status: 'NEEDS-ACTION',
        created: now,
        lastModified: now,
        dtstamp: now,
        attendees: [
          Attendee(
            email: 'accepted@example.com',
            displayName: 'Accepted User',
            status: AttendeeStatus.accepted,
            role: AttendeeRole.requiredParticipant,
          ),
          Attendee(
            email: 'declined@example.com', 
            displayName: 'Declined User',
            status: AttendeeStatus.declined,
            role: AttendeeRole.optionalParticipant,
          ),
          Attendee(
            email: 'tentative@example.com',
            displayName: 'Tentative User', 
            status: AttendeeStatus.tentative,
            role: AttendeeRole.requiredParticipant,
          ),
          Attendee(
            email: 'chair@example.com',
            displayName: 'Meeting Chair',
            status: AttendeeStatus.accepted,
            role: AttendeeRole.chair,
          ),
        ],
      );

      // Mock storage
      when(mockStorage.getAll<Task>(any))
          .thenAnswer((_) async => Result.success([taskWithVariousAttendees]));

      // Act
      final result = await repository.getAll();

      // Assert - Should handle gracefully and preserve all attendee details
      expect(result, isA<Success>());
      final tasks = (result as Success<List<Task>>).data;
      expect(tasks.first.attendees.length, equals(4));
      
      final attendees = tasks.first.attendees;
      
      // Check specific attendee properties
      final acceptedAttendee = attendees.firstWhere((a) => a.email == 'accepted@example.com');
      expect(acceptedAttendee.status, equals(AttendeeStatus.accepted));
      expect(acceptedAttendee.role, equals(AttendeeRole.requiredParticipant));
      expect(acceptedAttendee.hasAccepted, isTrue);
      
      final chairAttendee = attendees.firstWhere((a) => a.email == 'chair@example.com');
      expect(chairAttendee.role, equals(AttendeeRole.chair));
      expect(chairAttendee.hasAccepted, isTrue);
      
      final declinedAttendee = attendees.firstWhere((a) => a.email == 'declined@example.com');
      expect(declinedAttendee.status, equals(AttendeeStatus.declined));
      expect(declinedAttendee.hasAccepted, isFalse);
    });
    
    test('should create attendees from email using factory method', () {
      // Test the AttendeeFactory.fromEmail method
      final attendee = AttendeeFactory.fromEmail(
        'test@example.com',
        displayName: 'Test User',
        status: AttendeeStatus.accepted,
        role: AttendeeRole.chair,
      );
      
      expect(attendee.email, equals('test@example.com'));
      expect(attendee.displayName, equals('Test User'));
      expect(attendee.status, equals(AttendeeStatus.accepted));
      expect(attendee.role, equals(AttendeeRole.chair));
      expect(attendee.hasAccepted, isTrue);
      expect(attendee.effectiveDisplayName, equals('Test User'));
    });
    
    test('should create organizer attendee using factory method', () {
      // Test the AttendeeFactory.fromOrganizer method
      final organizer = AttendeeFactory.fromOrganizer(
        'organizer@example.com',
        displayName: 'Meeting Organizer',
      );
      
      expect(organizer.email, equals('organizer@example.com'));
      expect(organizer.displayName, equals('Meeting Organizer'));
      expect(organizer.status, equals(AttendeeStatus.accepted));
      expect(organizer.role, equals(AttendeeRole.chair));
      expect(organizer.hasAccepted, isTrue);
    });
  });
} 