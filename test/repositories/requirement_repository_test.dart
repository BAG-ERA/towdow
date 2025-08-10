import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/models/requirement.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/requirement_repository.dart';
import 'package:towdow_app/core/result.dart';

class _FakeCalendarRepository implements CalendarRepository {
  final Map<String, TaskCalendar> _store = {};

  @override
  Future<Result<void>> delete(String path) async => const Result.success(null);
  @override
  Future<Result<List<TaskCalendar>>> getAll() async => Result.success(_store.values.toList());
  @override
  Future<Result<TaskCalendar?>> getById(String uid) async => Result.success(_store[uid]);
  @override
  Future<Result<TaskCalendar?>> getByPath(String path) async => Result.success(_store[path]);
  @override
  Future<Result<List<TaskCalendar>>> getProjectCalendars() async => getAll();
  @override
  Stream<List<TaskCalendar>> watchCalendars() => const Stream.empty();
  @override
  Future<Result<void>> save(TaskCalendar calendar) async { _store[calendar.path] = calendar; return const Result.success(null);} 
  @override
  Future<Result<void>> unsyncCalendar(String path) async => const Result.success(null);
  @override
  Future<Result<void>> updateCalendarProperties(TaskCalendar calendar) async => const Result.success(null);
  @override
  Future<Result<List<TaskCalendar>>> getCalendarsByDomain(String? domain) async => getAll();
  @override
  Future<Result<List<String>>> getUniqueDomains() async => const Result.success([]);
  @override
  Future<Result<void>> renameDomain(String oldDomain, String newDomain) async => const Result.success(null);
  @override
  Future<Result<Map<String, int>>> getDomainStatistics() async => const Result.success({});
  @override
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutDomain() async => const Result.success([]);
  @override
  Future<Result<List<TaskCalendar>>> getCalendarsByStatus(String? status) async => getAll();
  @override
  Future<Result<List<String>>> getUniqueStatuses() async => const Result.success([]);
  @override
  Future<Result<void>> changeStatus(String oldStatus, String newStatus) async => const Result.success(null);
  @override
  Future<Result<Map<String, int>>> getStatusStatistics() async => const Result.success({});
  @override
  Future<Result<List<TaskCalendar>>> getCalendarsWithoutStatus() async => const Result.success([]);
  @override
  Future<Result<List<TaskCalendar>>> getArchivedCalendars() async => const Result.success([]);
  @override
  Future<Result<List<TaskCalendar>>> getActiveCalendars() async => const Result.success([]);
  @override
  Future<Result<void>> assignDomainToCalendar(String calendarPath, String? domain) async => const Result.success(null);
}

// No account repository needed for this repository test

void main() {
  group('RequirementRepository', () {
    late _FakeCalendarRepository calRepo;
    late RequirementRepository reqRepo;
    late TaskCalendar calendar;

    setUp(() async {
      calRepo = _FakeCalendarRepository();
      reqRepo = RequirementRepository(calRepo);
      calendar = TaskCalendarFactory.createNew(path: '/cal/x/', displayName: 'X');
      await calRepo.save(calendar);
    });

    test('create and load requirements', () async {
      final createRes = await reqRepo.createRequirement(projectPath: calendar.path, id: 'req-1', name: 'lawyer');
      expect(createRes is Success<Requirement>, true);

      final init = await reqRepo.initialize();
      expect(init is Success<void>, true);

      final listRes = await reqRepo.getProjectRequirements(calendar.path);
      final list = listRes.when(success: (l) => l, failure: (_) => <Requirement>[]);
      expect(list.length, 1);
      expect(list.first.id, 'req-1');
      expect(list.first.attendeeEmails, isEmpty);
    });

    test('update and delete requirement', () async {
      await reqRepo.createRequirement(projectPath: calendar.path, id: 'req-1', name: 'lawyer');
      final updated = await reqRepo.updateRequirement(const Requirement(id: 'req-1', name: 'legal', attendeeEmails: []));
      expect(updated is Success<Requirement>, true);

      final listAfterUpdate = await reqRepo.getProjectRequirements(calendar.path);
      final got = listAfterUpdate.when(success: (l) => l.first, failure: (_) => null);
      expect(got?.name, 'legal');

      final del = await reqRepo.deleteRequirement('req-1');
      expect(del is Success<void>, true);

      final listAfterDelete = await reqRepo.getProjectRequirements(calendar.path);
      final remain = listAfterDelete.when(success: (l) => l, failure: (_) => <Requirement>[]);
      expect(remain, isEmpty);
    });
  });
}


