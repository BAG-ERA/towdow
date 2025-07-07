import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/attendee.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/presentation/viewmodels/commands/attendee_commands.dart';
import 'package:towdow_app/core/result.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<TaskRepository>()])
import 'attendee_commands_test.mocks.dart';

void main() {
  group('Attendee Commands Tests', () {
    late MockTaskRepository mockRepository;
    late AddAttendeeCommand addAttendeeCommand;
    late RemoveAttendeeCommand removeAttendeeCommand;
    late UpdateAttendeeCommand updateAttendeeCommand;
    late UpdateAttendeeStatusCommand updateAttendeeStatusCommand;
    late Task sampleTask;
    late Attendee sampleAttendee;

    setUp(() {
      mockRepository = MockTaskRepository();
      addAttendeeCommand = AddAttendeeCommand(mockRepository);
      removeAttendeeCommand = RemoveAttendeeCommand(mockRepository);
      updateAttendeeCommand = UpdateAttendeeCommand(mockRepository);
      updateAttendeeStatusCommand = UpdateAttendeeStatusCommand(mockRepository);

      final now = DateTime.now();
      sampleTask = Task(
        uid: 'test-task-001',
        summary: 'Sample Task',
        description: 'Test description',
        status: 'NEEDS-ACTION',
        created: now,
        lastModified: now,
        dtstamp: now,
        attendees: [
          Attendee(
            email: 'existing@example.com',
            displayName: 'Existing User',
            status: AttendeeStatus.needsAction,
          ),
        ],
      );

      sampleAttendee = Attendee(
        email: 'new@example.com',
        displayName: 'New User',
        status: AttendeeStatus.needsAction,
        role: AttendeeRole.requiredParticipant,
      );
    });

    group('AddAttendeeCommand', () {
      test('should add new attendee to task successfully', () async {
        // Arrange
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));

        final params = AddAttendeeParams(
          task: sampleTask,
          attendee: sampleAttendee,
        );

        // Act
        final result = await addAttendeeCommand.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(2));
        expect(result.attendees.last.email, equals('new@example.com'));
        expect(result.attendees.last.displayName, equals('New User'));
        verify(mockRepository.save(any)).called(1);
      });

      test('should update existing attendee when adding duplicate email', () async {
        // Arrange
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));

        final updatedAttendee = Attendee(
          email: 'existing@example.com', // Same email as existing
          displayName: 'Updated User',
          status: AttendeeStatus.accepted,
        );

        final params = AddAttendeeParams(
          task: sampleTask,
          attendee: updatedAttendee,
        );

        // Act
        final result = await addAttendeeCommand.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1)); // Same count
        expect(result.attendees.first.email, equals('existing@example.com'));
        expect(result.attendees.first.displayName, equals('Updated User'));
        expect(result.attendees.first.status, equals(AttendeeStatus.accepted));
        verify(mockRepository.save(any)).called(1);
      });

      test('should return null when repository save fails', () async {
        // Arrange
        when(mockRepository.save(any)).thenAnswer(
          (_) async => Result.failure(Failure(message: 'Save failed')),
        );

        final params = AddAttendeeParams(
          task: sampleTask,
          attendee: sampleAttendee,
        );

        // Act
        final result = await addAttendeeCommand.executeWith(params);

        // Assert
        expect(result, isNull);
        expect(addAttendeeCommand.hasError, isTrue);
      });
    });

    group('RemoveAttendeeCommand', () {
      test('should remove attendee from task successfully', () async {
        // Arrange
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));

        final params = RemoveAttendeeParams(
          task: sampleTask,
          attendeeEmail: 'existing@example.com',
        );

        // Act
        final result = await removeAttendeeCommand.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(0));
        verify(mockRepository.save(any)).called(1);
      });

      test('should return task unchanged when attendee not found', () async {
        // Arrange
        final params = RemoveAttendeeParams(
          task: sampleTask,
          attendeeEmail: 'nonexistent@example.com',
        );

        // Act
        final result = await removeAttendeeCommand.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1)); // No change
        expect(result.attendees.first.email, equals('existing@example.com'));
        verifyNever(mockRepository.save(any)); // No save called
      });
    });

    group('UpdateAttendeeStatusCommand', () {
      test('should update attendee status successfully', () async {
        // Arrange
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));

        final params = UpdateAttendeeStatusParams(
          task: sampleTask,
          attendeeEmail: 'existing@example.com',
          status: AttendeeStatus.accepted,
        );

        // Act
        final result = await updateAttendeeStatusCommand.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1));
        expect(result.attendees.first.email, equals('existing@example.com'));
        expect(result.attendees.first.status, equals(AttendeeStatus.accepted));
        // Other properties should remain unchanged
        expect(result.attendees.first.displayName, equals('Existing User'));
        verify(mockRepository.save(any)).called(1);
      });

      test('should return null when attendee not found', () async {
        // Arrange
        final params = UpdateAttendeeStatusParams(
          task: sampleTask,
          attendeeEmail: 'nonexistent@example.com',
          status: AttendeeStatus.accepted,
        );

        // Act
        final result = await updateAttendeeStatusCommand.executeWith(params);

        // Assert
        expect(result, isNull);
        expect(updateAttendeeStatusCommand.hasError, isTrue);
      });
    });

    group('Email Validation Integration', () {
      test('should handle malformed email addresses gracefully', () async {
        // Arrange - As per specs: flexible email validation policy
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));

        final attendeeWithMalformedEmail = Attendee(
          email: 'invalid-email-format',
          displayName: 'Invalid Email User',
        );

        final params = AddAttendeeParams(
          task: sampleTask,
          attendee: attendeeWithMalformedEmail,
        );

        // Act - Should not throw exception (flexible email validation)
        final result = await addAttendeeCommand.executeWith(params);

        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(2));
        expect(result.attendees.last.email, equals('invalid-email-format'));
        verify(mockRepository.save(any)).called(1);
      });
    });

    group('Drag and Drop Commands Tests', () {
      late AssignAttendeeToTaskCommand assignAttendeeCommand;
      late UnassignAllAttendeesCommand unassignAllCommand;

      setUp(() {
        assignAttendeeCommand = AssignAttendeeToTaskCommand(mockRepository);
        unassignAllCommand = UnassignAllAttendeesCommand(mockRepository);
      });

      test('AssignAttendeeToTaskCommand should assign new attendee to task', () async {
        // Arrange
        final taskWithoutAttendees = sampleTask.copyWith(attendees: []);
        final params = AssignAttendeeToTaskParams(task: taskWithoutAttendees, attendeeEmail: 'newuser@example.com');
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));
        
        // Act
        final result = await assignAttendeeCommand.executeWith(params);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1));
        expect(result.attendees.first.email, equals('newuser@example.com'));
        expect(result.attendees.first.displayName, equals('Newuser'));
        verify(mockRepository.save(any)).called(1);
      });

      test('AssignAttendeeToTaskCommand should not modify task if attendee is already the only attendee', () async {
        // Arrange
        final params = AssignAttendeeToTaskParams(task: sampleTask, attendeeEmail: 'existing@example.com');
        
        // Act
        final result = await assignAttendeeCommand.executeWith(params);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1));
        expect(result.attendees.first.email, equals('existing@example.com'));
        verifyNever(mockRepository.save(any)); // Should not save if no changes
      });

      test('AssignAttendeeToTaskCommand should replace existing attendee with new one', () async {
        // Arrange
        final params = AssignAttendeeToTaskParams(task: sampleTask, attendeeEmail: 'newuser@example.com');
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));
        
        // Act
        final result = await assignAttendeeCommand.executeWith(params);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1));
        expect(result.attendees.first.email, equals('newuser@example.com'));
        expect(result.attendees.first.displayName, equals('Newuser'));
        verify(mockRepository.save(any)).called(1);
      });

      test('UnassignAllAttendeesCommand should remove all attendees from task', () async {
        // Arrange
        final attendee1 = Attendee(
          email: 'user1@example.com',
          displayName: 'User One',
          status: AttendeeStatus.accepted,
        );
        final attendee2 = Attendee(
          email: 'user2@example.com',
          displayName: 'User Two',
          status: AttendeeStatus.needsAction,
        );
        final taskWithMultipleAttendees = sampleTask.copyWith(attendees: [attendee1, attendee2]);
        final params = UnassignAllAttendeesParams(task: taskWithMultipleAttendees);
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));
        
        // Act
        final result = await unassignAllCommand.executeWith(params);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(0));
        expect(result.attendees, isEmpty);
        verify(mockRepository.save(any)).called(1);
      });

      test('AssignAttendeeToTaskCommand should format display name from email', () async {
        // Arrange
        final taskWithoutAttendees = sampleTask.copyWith(attendees: []);
        final params = AssignAttendeeToTaskParams(task: taskWithoutAttendees, attendeeEmail: 'john.doe-smith@company.com');
        when(mockRepository.save(any)).thenAnswer((_) async => const Result.success(null));
        
        // Act
        final result = await assignAttendeeCommand.executeWith(params);
        
        // Assert
        expect(result, isNotNull);
        expect(result!.attendees.length, equals(1));
        expect(result.attendees.first.displayName, equals('John Doe Smith'));
      });
    });
  });
}
