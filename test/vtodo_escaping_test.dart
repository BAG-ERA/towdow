// Test for RFC 5545 character escaping in VTODO serialization
// Ensures validator JSON with special characters is properly escaped

import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/services/parsers/vtodo_parser.dart';
import 'package:towdow_app/data/models/task.dart';

void main() {
  group('VTODO Character Escaping', () {
    test('serialization: escapes commas, semicolons, and newlines in validator JSON', () {
      final validator = '''[[{"id":"test-validator","type":"checklist","title":"Test, with; special\ncharacters","items":[{"id":"item1","text":"Item, with; commas\nand newlines","checked":false}]}]]''';
      final task = Task(
        uid: 'test-task-escaping',
        summary: 'Test RFC 5545 Escaping',
        description: 'Testing character escaping for validator JSON',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: validator,
      );
      final vtodoString = VTODOParser.serializeTask(task);
      final validatorLine = vtodoString.split('\n').firstWhere((line) => line.startsWith('X-FLOWIT-VALIDATOR:'));
      expect(validatorLine, contains('\\,'), reason: 'Commas should be escaped');
      expect(validatorLine, contains('\\;'), reason: 'Semicolons should be escaped');
      expect(validatorLine, contains('\\n'), reason: 'Newlines should be escaped as \\n');
    });

    test('parsing: unescapes commas, semicolons, and newlines in validator JSON', () {
      // This is what would be in the VTODO file (already escaped)
      final escapedValidator = '[[{"id":"test-validator","type":"checklist","title":"Test\\, with\\; special\\ncharacters","items":[{"id":"item1","text":"Item\\, with\\; commas\\nand newlines","checked":false}]}]]';
      final vtodo = '''BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//FlowIt//FlowIt CalDAV//EN\nBEGIN:VTODO\nUID:test-task-escaping\nDTSTAMP:20250711T134103Z\nCREATED:20250711T134103Z\nLAST-MODIFIED:20250711T134103Z\nSUMMARY:Test RFC 5545 Escaping\nDESCRIPTION:Testing character escaping for validator JSON\nSTATUS:NEEDS-ACTION\nPERCENT-COMPLETE:0\nX-FLOWIT-TYPE:task\nX-FLOWIT-VALIDATOR:$escapedValidator\nX-FLOWIT-REQUIREMENT:{}\nEND:VTODO\nEND:VCALENDAR''';
      final parsedTask = VTODOParser.parseVTODO(vtodo);
      expect(parsedTask, isNotNull);
      // After unescaping, the validator should contain literal ',', ';', and '\n' (as a newline char)
      final expected = '''[[{"id":"test-validator","type":"checklist","title":"Test, with; special\ncharacters","items":[{"id":"item1","text":"Item, with; commas\nand newlines","checked":false}]}]]''';
      // Compare after replacing literal newlines for clarity
      expect(parsedTask!.flowitValidator.replaceAll('\n', '\\n'), expected.replaceAll('\n', '\\n'),
        reason: 'Parsed validator should match expected after unescaping.\nExpected: $expected\nActual: ${parsedTask.flowitValidator}');
    });

    test('round-trip: validator JSON with special chars survives serialize/parse', () {
      final original = '''[[{"id":"test-validator","type":"checklist","title":"Test, with; special\ncharacters","items":[{"id":"item1","text":"Item, with; commas\nand newlines","checked":false}]}]]''';
      final task = Task(
        uid: 'test-task-escaping',
        summary: 'Test RFC 5545 Escaping',
        description: 'Testing character escaping for validator JSON',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: original,
      );
      final vtodoString = VTODOParser.serializeTask(task);
      final parsedTask = VTODOParser.parseVTODO(vtodoString);
      expect(parsedTask, isNotNull);
      // Compare after replacing literal newlines for clarity
      expect(parsedTask!.flowitValidator.replaceAll('\n', '\\n'), original.replaceAll('\n', '\\n'),
        reason: 'Round-trip validator JSON should match original (modulo newline encoding).\nOriginal: $original\nParsed: ${parsedTask.flowitValidator}');
    });

    test('round-trip: validator JSON with commas and semicolons', () {
      final original = '''[[{"id":"comma-test","title":"Test, title, with, commas","description":"Description; with; semicolons","value":"test,value;here"}]]''';
      final task = Task(
        uid: 'test-comma-validator',
        summary: 'Test Comma Handling',
        description: 'Testing comma and semicolon handling',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: original,
      );
      final vtodoString = VTODOParser.serializeTask(task);
      final parsedTask = VTODOParser.parseVTODO(vtodoString);
      expect(parsedTask, isNotNull);
      expect(parsedTask!.flowitValidator, original,
        reason: 'Round-trip validator JSON with commas/semicolons should match original.\nOriginal: $original\nParsed: ${parsedTask.flowitValidator}');
    });

    test('round-trip: long validator JSON is not truncated', () {
      final longValidator = '''[[{"id":"1751031815102-very-long-validator-id-that-exceeds-normal-length","type":"checklist","required":true,"title":"Long validator that should not be truncated","items":[{"id":"item-1","text":"First item","checked":false},{"id":"item-2","text":"Second item","checked":true}]}]]''';
      final task = Task(
        uid: 'task-1751029831719-350975689',
        summary: 'dnnbg',
        description: '',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        flowitValidator: longValidator,
        organizer: 'tibo',
      );
      final vtodoString = VTODOParser.serializeTask(task);
      final parsedTask = VTODOParser.parseVTODO(vtodoString);
      expect(parsedTask, isNotNull);
      expect(parsedTask!.flowitValidator, longValidator,
        reason: 'Long validator JSON should not be truncated.\nOriginal: $longValidator\nParsed: ${parsedTask.flowitValidator}');
      expect(parsedTask.flowitValidator.length, longValidator.length,
        reason: 'Length should match for long validator JSON.');
    });
  });
} 