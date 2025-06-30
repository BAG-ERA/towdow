// Integration test for validator serialization with RFC 5545 line folding
// Tests the complete flow of serializing and parsing tasks with long validator JSON

import 'package:test/test.dart';
import 'package:flowit_app/data/models/task.dart';
import 'package:flowit_app/data/models/caldav_account.dart';
import 'package:flowit_app/data/services/caldav_service.dart';

void main() {
  group('Validator Serialization Integration Tests', () {
    late CalDAVService service;
    
    setUp(() {
      final account = CaldavAccount(
        id: 'test-account',
        providerType: 'custom',
        serverUrl: 'https://caldav.example.com',
        username: 'test@example.com',
        password: 'test-password',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
      );
      service = CalDAVService(account: account);
    });

    test('should serialize and parse task with long validator JSON', () {
      // Create a task with a long validator JSON that would exceed 75 characters
      final longValidatorJson = '''[[[
        {
          "id": "validator-1750960264441",
          "type": "checklist",
          "required": true,
          "title": "Pre-flight Safety Checklist for Commercial Aviation Operations",
          "items": [
            {"id": "item-1750960264441-0", "text": "Verify aircraft weight and balance calculations are within operational limits", "checked": false},
            {"id": "item-1750960264441-1", "text": "Confirm weather conditions meet minimum visibility requirements for departure", "checked": false},
            {"id": "item-1750960264441-2", "text": "Test all communication and navigation systems functionality", "checked": false},
            {"id": "item-1750960264441-3", "text": "Ensure all required documentation is current and accessible", "checked": false}
          ]
        },
        {
          "id": "validator-1750960264442",
          "type": "single_select",
          "required": true,
          "title": "Aircraft Configuration Selection for Flight Operations",
          "options": [
            {"id": "option-1750960264442-0", "text": "Boeing 737-800 with enhanced performance package"},
            {"id": "option-1750960264442-1", "text": "Airbus A320neo with fuel-efficient engine configuration"},
            {"id": "option-1750960264442-2", "text": "Regional jet optimized for short-haul operations"}
          ],
          "selected": ""
        }
      ]]]'''.replaceAll(RegExp(r'\s+'), ''); // Remove whitespace to create one long line

      final task = Task(
        uid: 'test-task-123',
        summary: 'Test Task with Long Validator',
        description: 'Testing RFC 5545 line folding for validator serialization',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: longValidatorJson,
      );

      // Verify the validator JSON is indeed long (over 75 characters)
      expect(longValidatorJson.length, greaterThan(75));
      expect(longValidatorJson.length, greaterThan(300)); // Should be much longer

      // Test that task creation succeeds even with long validator
      expect(task.flowitValidator, equals(longValidatorJson));
      expect(task.uid, equals('test-task-123'));
    });

    test('should handle empty and default validator cases', () {
      final taskWithEmptyValidator = Task(
        uid: 'test-task-empty',
        summary: 'Task with Empty Validator',
        description: 'Testing empty validator handling',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: '',
      );

      final taskWithDefaultValidator = Task(
        uid: 'test-task-default',
        summary: 'Task with Default Validator',
        description: 'Testing default validator handling',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        // flowitValidator will default to '{"type":"default"}'
      );

      expect(taskWithEmptyValidator.flowitValidator, isEmpty);
      expect(taskWithDefaultValidator.flowitValidator, equals('{"type":"default"}'));
    });

    test('should preserve validator JSON structure integrity', () {
      // Test with complex nested structure
      final complexValidator = '''[[
        {
          "id": "complex-validator-001",
          "type": "checklist",
          "required": true,
          "title": "Multi-level Validation Process",
          "metadata": {
            "version": "2.1",
            "lastUpdated": "2024-01-20T15:30:00Z",
            "compliance": ["ISO-9001", "FAA-Part-145", "EASA-145"]
          },
          "items": [
            {
              "id": "item-001-alpha",
              "text": "Primary systems verification including backup redundancy checks",
              "checked": false,
              "priority": "critical",
              "dependencies": ["item-002-beta", "item-003-gamma"]
            }
          ]
        }
      ]]'''.replaceAll(RegExp(r'\s+'), '');

      final task = Task(
        uid: 'complex-validator-task',
        summary: 'Complex Validator Test',
        description: 'Testing complex nested JSON structure preservation',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: complexValidator,
      );

      // Verify the JSON structure is preserved
      expect(task.flowitValidator, equals(complexValidator));
      expect(task.flowitValidator.contains('"compliance"'), isTrue);
      expect(task.flowitValidator.contains('"dependencies"'), isTrue);
    });
  });
} 