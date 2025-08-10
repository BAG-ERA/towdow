// Tests for SyncService queue processing (create/update/delete)

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/data/services/caldav_service.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/category_repository.dart';
import 'package:towdow_app/data/repositories/user_repository.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/user_preferences.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/core/result.dart';

import '../services/sync_service_test.mocks.dart';

void main() {
  group('SyncService queue processing', () {
    late MockCalDAVService mockCaldav;
    late MockTaskRepository mockTaskRepo;
    late MockAccountRepository mockAccountRepo;
    late MockCalendarRepository mockCalendarRepo;
    late MockCategoryRepository mockCategoryRepo;
    late MockUserRepository mockUserRepo;
    late MockLocalStorageService mockStorage;

    late SyncService syncService;
    late CaldavAccount account;
    late TaskCalendar calendar;
    late Task task;

    setUp(() async {
      mockCaldav = MockCalDAVService();
      mockTaskRepo = MockTaskRepository();
      mockAccountRepo = MockAccountRepository();
      mockCalendarRepo = MockCalendarRepository();
      mockCategoryRepo = MockCategoryRepository();
      mockUserRepo = MockUserRepository();
      mockStorage = MockLocalStorageService();

      // Provide a factory that returns our mock
      SyncService.caldavFactory = (_) => mockCaldav;

      // Basic objects
      account = CaldavAccount(
        id: 'acc',
        providerType: 'custom',
        serverUrl: 'https://example/caldav/',
        username: 'u',
        password: 'p',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );
      calendar = TaskCalendar(
        path: '/cal/u/project/',
        displayName: 'Project',
        description: '',
        dtstamp: DateTime.now(),
        created: DateTime.now(),
        lastModified: DateTime.now(),
        status: 'ONGOING',
      );
      task = Task(
        uid: 't1',
        summary: 'S',
        description: '',
        status: 'NEEDS-ACTION',
        lastModified: DateTime.now(),
        created: DateTime.now(),
        dtstamp: DateTime.now(),
        projectPath: calendar.path,
        flowitValidator: '{"type":"default"}',
      );

      when(mockAccountRepo.getActiveAccount())
          .thenAnswer((_) async => Result.success(account));
      when(mockUserRepo.getUserPreferences())
          .thenAnswer((_) async => Result.success(UserPreferences.defaultPreferences()));
      when(mockCalendarRepo.getProjectCalendars())
          .thenAnswer((_) async => Result.success([calendar]));
      when(mockStorage.getAll<Map<String, dynamic>>(any))
          .thenAnswer((_) async => const Result.success([]));
      when(mockStorage.debugAllBoxes()).thenAnswer((_) async {});
      when(mockStorage.getAll<CaldavAccount>('accounts'))
          .thenAnswer((_) async => const Result.success([]));

      syncService = SyncService(
        taskRepository: mockTaskRepo,
        accountRepository: mockAccountRepo,
        calendarRepository: mockCalendarRepo,
        categoryRepository: mockCategoryRepo,
        userRepository: mockUserRepo,
        localStorage: mockStorage,
      );
    });

    tearDown(() async {
      await SyncService.reset();
      // Reset factory to default
      SyncService.caldavFactory = (acc) => CalDAVService(account: acc);
    });

    Future<void> _stubQueue(List<Map<String, dynamic>> rawItems) async {
      when(mockStorage.getAll<Map<String, dynamic>>('sync_queue'))
          .thenAnswer((_) async => Result.success(rawItems.cast<Map<String, dynamic>>()));
      when(mockStorage.put(any, any, any))
          .thenAnswer((_) async => const Result.success(null));
      when(mockStorage.delete(any, any))
          .thenAnswer((_) async => const Result.success(null));
    }

    test('CREATE: enqueued item triggers caldav createTask', () async {
      await _stubQueue([
        {
          'id': 'id-1',
          'operation': 'create',
          'itemId': 't1',
          'data': {
            'calendarPath': calendar.path,
            'taskUid': 't1',
          },
          'createdAt': DateTime.now().toIso8601String(),
          'retryCount': 0,
        }
      ]);

      when(mockTaskRepo.getById('t1')).thenAnswer((_) async => Result.success(task));
      when(mockCalendarRepo.getById(calendar.path))
          .thenAnswer((_) async => Result.success(calendar));
      when(mockCaldav.createTask(any, any))
          .thenAnswer((_) async => const Result.success('/cal/u/project/t1.ics'));

      // Force sync to process queue only path
      when(mockCaldav.getCalendarProperties(any))
          .thenAnswer((_) async => Result.success(calendar));
      when(mockCaldav.testConnection()).thenAnswer((_) async => Result.success(
            CalDAVCapabilities(
              supportsCalDAV: true,
              supportsTasks: true,
              principal: '',
              calendarHome: '/cal/u/',
              taskCalendars: [calendar],
              serverInfo: '',
            ),
          ));

      final result = await syncService.syncAllActiveCaldav();
      expect(result, isA<Result<SyncResult>>());
      verify(mockCaldav.createTask(task, calendar.path)).called(1);
    });

    test('UPDATE: enqueued item triggers caldav updateTask', () async {
      await _stubQueue([
        {
          'id': 'id-2',
          'operation': 'update',
          'itemId': 't1',
          'data': {
            'calendarPath': calendar.path,
            'taskUid': 't1',
          },
          'createdAt': DateTime.now().toIso8601String(),
          'retryCount': 0,
        }
      ]);

      when(mockTaskRepo.getById('t1')).thenAnswer((_) async => Result.success(task));
      when(mockCalendarRepo.getById(calendar.path))
          .thenAnswer((_) async => Result.success(calendar));
      when(mockCaldav.updateTask(any, any, etag: anyNamed('etag')))
          .thenAnswer((_) async => const Result.success(null));

      when(mockCaldav.getCalendarProperties(any))
          .thenAnswer((_) async => Result.success(calendar));
      when(mockCaldav.testConnection()).thenAnswer((_) async => Result.success(
            CalDAVCapabilities(
              supportsCalDAV: true,
              supportsTasks: true,
              principal: '',
              calendarHome: '/cal/u/',
              taskCalendars: [calendar],
              serverInfo: '',
            ),
          ));

      final result = await syncService.syncAllActiveCaldav();
      expect(result, isA<Result<SyncResult>>());
      verify(mockCaldav.updateTask(task, '${calendar.path}t1.ics', etag: null)).called(1);
    });

    test('DELETE: enqueued item triggers caldav deleteTask', () async {
      await _stubQueue([
        {
          'id': 'id-3',
          'operation': 'delete',
          'itemId': 't1',
          'data': {
            'calendarPath': calendar.path,
            'taskUid': 't1',
          },
          'createdAt': DateTime.now().toIso8601String(),
          'retryCount': 0,
        }
      ]);

      when(mockCalendarRepo.getById(calendar.path))
          .thenAnswer((_) async => Result.success(calendar));
      when(mockCaldav.deleteTask(any, etag: anyNamed('etag')))
          .thenAnswer((_) async => const Result.success(null));

      when(mockCaldav.getCalendarProperties(any))
          .thenAnswer((_) async => Result.success(calendar));
      when(mockCaldav.testConnection()).thenAnswer((_) async => Result.success(
            CalDAVCapabilities(
              supportsCalDAV: true,
              supportsTasks: true,
              principal: '',
              calendarHome: '/cal/u/',
              taskCalendars: [calendar],
              serverInfo: '',
            ),
          ));

      final result = await syncService.syncAllActiveCaldav();
      expect(result, isA<Result<SyncResult>>());
      verify(mockCaldav.deleteTask('${calendar.path}t1.ics', etag: null)).called(1);
    });
  });
}


