// Test for RFC 5545 character escaping in VTODO serialization
// Ensures validator JSON with special characters is properly escaped

import 'package:flutter_test/flutter_test.dart';
import '../lib/data/services/parsers/vtodo_parser.dart';
import '../lib/data/models/task.dart';

void main() {
  group('VTODO Character Escaping', () {
    test('should escape special characters in validator JSON', () {
      // Create validator JSON with RFC 5545 special characters that need escaping
      final validatorWithSpecialChars = '''[[{"id":"test-validator","type":"checklist","title":"Test, with; special\\ncharacters","items":[{"id":"item1","text":"Item, with; commas\\nand newlines","checked":false}]}]]''';
      
      final task = Task(
        uid: 'test-task-escaping',
        summary: 'Test RFC 5545 Escaping',
        description: 'Testing character escaping for validator JSON',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: validatorWithSpecialChars,
      );

      // Serialize the task to VTODO
      final vtodoString = VTODOParser.serializeTask(task);
      print('Serialized VTODO:\n$vtodoString');

      // The VTODO should not be truncated and should contain the complete validator
      expect(vtodoString, contains('X-FLOWIT-VALIDATOR:'));
      expect(vtodoString, contains('END:VTODO'));
      expect(vtodoString.contains('[[{"id":"test-validator"'), isTrue);
      
      // Parse it back to ensure round-trip works
      final parsedTask = VTODOParser.parseVTODO(vtodoString);
      
      // Verify the task was parsed correctly and validator is complete
      expect(parsedTask, isNotNull);
      expect(parsedTask!.uid, equals('test-task-escaping'));
      expect(parsedTask.flowitValidator, equals(validatorWithSpecialChars));
      expect(parsedTask.flowitValidator.contains('"type":"checklist"'), isTrue);
      expect(parsedTask.flowitValidator.contains('"checked":false'), isTrue);
    });

    test('should handle validator JSON with commas and semicolons', () {
      // Test specifically the characters that commonly cause truncation
      final validatorWithCommas = '''[[{"id":"comma-test","title":"Test, title, with, commas","description":"Description; with; semicolons","value":"test,value;here"}]]''';
      
      final task = Task(
        uid: 'test-comma-validator',
        summary: 'Test Comma Handling',
        description: 'Testing comma and semicolon handling',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: validatorWithCommas,
      );

      // Serialize and check it's not truncated
      final vtodoString = VTODOParser.serializeTask(task);
      
      // Should contain the full validator, not truncated
      expect(vtodoString, contains('X-FLOWIT-VALIDATOR:'));
      expect(vtodoString, contains('END:VTODO'));
      expect(vtodoString.contains('"id":"comma-test"'), isTrue);
      expect(vtodoString.contains('"value":"test,value;here"'), isTrue);
      
      // Round-trip test
      final parsedTask = VTODOParser.parseVTODO(vtodoString);
      expect(parsedTask, isNotNull);
      expect(parsedTask!.flowitValidator, equals(validatorWithCommas));
    });

    test('should not truncate long validator JSON', () {
      // Test with the pattern from the user's example: long ID followed by more content
      final longValidator = '''[[{"id":"1751031815102-very-long-validator-id-that-exceeds-normal-length","type":"checklist","required":true,"title":"Long validator that should not be truncated","items":[{"id":"item-1","text":"First item","checked":false},{"id":"item-2","text":"Second item","checked":true}]}]]''';
      
      final task = Task(
        uid: 'task-1751029831719-350975689', // Using similar ID pattern as in user's example
        summary: 'dnnbg',
        description: '',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: longValidator,
        organizer: 'tibo',
      );

      // Serialize the task
      final vtodoString = VTODOParser.serializeTask(task);
      print('Long validator VTODO:\n$vtodoString');

      // Should not be truncated at the beginning like user's example
      expect(vtodoString, contains('X-FLOWIT-VALIDATOR:'));
      expect(vtodoString, contains('END:VTODO'));
      expect(vtodoString.contains('"id":"1751031815102'), isTrue);
      expect(vtodoString.contains('"checked":true'), isTrue);
      expect(vtodoString.contains(']]'), isTrue); // Should reach the end
      
      // Parse back and verify complete content
      final parsedTask = VTODOParser.parseVTODO(vtodoString);
      expect(parsedTask, isNotNull);
      expect(parsedTask!.flowitValidator, equals(longValidator));
      expect(parsedTask.flowitValidator.length, equals(longValidator.length));
    });
  });
} 