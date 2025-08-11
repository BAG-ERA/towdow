import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/models/requirement.dart';

void main() {
  test('TaskCalendar requirement helpers work', () {
    final cal = TaskCalendarFactory.createNew(path: '/p/x/', displayName: 'P');
    final withReq = cal.addOrUpdateRequirement(const Requirement(id: 'r1', name: 'lawyer'));
    expect(withReq.projectRequirementsList.length, 1);
    expect(withReq.hasRequirement('r1'), true);
    expect(withReq.getRequirementById('r1')?.name, 'lawyer');

    final updated = withReq.addOrUpdateRequirement(const Requirement(id: 'r1', name: 'legal'));
    expect(updated.getRequirementById('r1')?.name, 'legal');

    final removed = updated.removeRequirement('r1');
    expect(removed.projectRequirementsList, isEmpty);
  });
}


