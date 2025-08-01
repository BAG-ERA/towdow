// Test for attendee access warning functionality
// Verifies that attendees without project access are correctly identified

import 'package:flutter_test/flutter_test.dart';
import '../../lib/data/models/task.dart';
import '../../lib/data/models/task_calendar.dart';
import '../../lib/data/models/attendee.dart';

void main() {
  group('Attendee Access Warning Tests', () {
    test('should identify attendees without project access', () {
      // Create a project with members
      final project = TaskCalendar(
        path: '/test/project',
        displayName: 'Test Project',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        status: 'NEEDS-ACTION',
        flowitAuthor: 'author@example.com',
        flowitOwner: 'owner@example.com',
        sharedWith: '[{"targetUserEmail":"member1@example.com"},{"targetUserEmail":"member2@example.com"}]',
      );

      // Create tasks with attendees
      final tasks = [
        Task(
          uid: 'task-1',
          summary: 'Task 1',
          description: 'Description 1',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          attendees: [
            Attendee(email: 'member1@example.com'), // Has access
            Attendee(email: 'member2@example.com'), // Has access
            Attendee(email: 'outsider@example.com'), // No access
          ],
          projectPath: '/test/project',
        ),
        Task(
          uid: 'task-2',
          summary: 'Task 2',
          description: 'Description 2',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          attendees: [
            Attendee(email: 'another-outsider@example.com'), // No access
          ],
          projectPath: '/test/project',
        ),
      ];

      // Get all unique attendees from tasks
      final allAttendees = <String>{};
      for (final task in tasks) {
        for (final attendee in task.attendees) {
          allAttendees.add(attendee.email);
        }
      }

      // Get project members
      final projectMembers = <String>{};
      if (project.sharedWithEmails.isNotEmpty) {
        projectMembers.addAll(project.sharedWithEmails);
      }
      if (project.flowitOwner != null && project.flowitOwner!.isNotEmpty) {
        projectMembers.add(project.flowitOwner!);
      }
      if (project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty) {
        projectMembers.add(project.flowitAuthor!);
      }

      // Find attendees without project access
      final attendeesWithoutAccess = allAttendees.where(
        (attendee) => !projectMembers.contains(attendee)
      ).toList();

      // Verify results
      expect(allAttendees.length, 4);
      expect(projectMembers.length, 4); // author, owner, member1, member2
      expect(attendeesWithoutAccess.length, 2);
      expect(attendeesWithoutAccess, contains('outsider@example.com'));
      expect(attendeesWithoutAccess, contains('another-outsider@example.com'));
    });

    test('should return empty list when all attendees have access', () {
      // Create a project with members
      final project = TaskCalendar(
        path: '/test/project',
        displayName: 'Test Project',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        status: 'NEEDS-ACTION',
        flowitAuthor: 'author@example.com',
        sharedWith: '[{"targetUserEmail":"member1@example.com"}]',
      );

      // Create tasks with attendees who all have access
      final tasks = [
        Task(
          uid: 'task-1',
          summary: 'Task 1',
          description: 'Description 1',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          attendees: [
            Attendee(email: 'author@example.com'), // Has access (author)
            Attendee(email: 'member1@example.com'), // Has access (shared)
          ],
          projectPath: '/test/project',
        ),
      ];

      // Get all unique attendees from tasks
      final allAttendees = <String>{};
      for (final task in tasks) {
        for (final attendee in task.attendees) {
          allAttendees.add(attendee.email);
        }
      }

      // Get project members
      final projectMembers = <String>{};
      if (project.sharedWithEmails.isNotEmpty) {
        projectMembers.addAll(project.sharedWithEmails);
      }
      if (project.flowitOwner != null && project.flowitOwner!.isNotEmpty) {
        projectMembers.add(project.flowitOwner!);
      }
      if (project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty) {
        projectMembers.add(project.flowitAuthor!);
      }

      // Find attendees without project access
      final attendeesWithoutAccess = allAttendees.where(
        (attendee) => !projectMembers.contains(attendee)
      ).toList();

      // Verify results
      expect(attendeesWithoutAccess.isEmpty, true);
    });

    test('should handle empty attendees list', () {
      // Create a project with members
      final project = TaskCalendar(
        path: '/test/project',
        displayName: 'Test Project',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        status: 'NEEDS-ACTION',
        flowitAuthor: 'author@example.com',
      );

      // Create tasks with no attendees
      final tasks = [
        Task(
          uid: 'task-1',
          summary: 'Task 1',
          description: 'Description 1',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          attendees: [], // No attendees
          projectPath: '/test/project',
        ),
      ];

      // Get all unique attendees from tasks
      final allAttendees = <String>{};
      for (final task in tasks) {
        for (final attendee in task.attendees) {
          allAttendees.add(attendee.email);
        }
      }

      // Get project members
      final projectMembers = <String>{};
      if (project.sharedWithEmails.isNotEmpty) {
        projectMembers.addAll(project.sharedWithEmails);
      }
      if (project.flowitOwner != null && project.flowitOwner!.isNotEmpty) {
        projectMembers.add(project.flowitOwner!);
      }
      if (project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty) {
        projectMembers.add(project.flowitAuthor!);
      }

      // Find attendees without project access
      final attendeesWithoutAccess = allAttendees.where(
        (attendee) => !projectMembers.contains(attendee)
      ).toList();

      // Verify results
      expect(allAttendees.isEmpty, true);
      expect(attendeesWithoutAccess.isEmpty, true);
    });
  });
} 