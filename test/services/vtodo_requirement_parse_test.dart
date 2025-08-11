import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/services/parsers/vtodo_parser.dart';

void main() {
  test('parse and serialize X-FLOWIT-REQUIREMENT array', () {
    final vtodo = 'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//FlowIt//FlowIt CalDAV//EN\nBEGIN:VTODO\nUID:task-req-1\nDTSTAMP:20250101T090000Z\nCREATED:20250101T090000Z\nLAST-MODIFIED:20250101T090000Z\nSUMMARY:Task with requirements\nSTATUS:NEEDS-ACTION\nPERCENT-COMPLETE:0\nX-FLOWIT-TYPE:task\nX-FLOWIT-VALIDATOR:{"type":"default"}\nX-FLOWIT-REQUIREMENT:["r1","r2"]\nEND:VTODO\nEND:VCALENDAR';

    final task = VTODOParser.parseVTODO(vtodo)!;
    expect(task.flowitRequirement, '["r1","r2"]');

    final serialized = VTODOParser.serializeTask(task);
    expect(serialized.contains('X-FLOWIT-REQUIREMENT:["r1","r2"]'), true);
  });
}


