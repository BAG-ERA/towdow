// Unit tests for SyncService
// Tests sync operations, error handling, and integration with repositories

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/data/services/caldav_service.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/category_repository.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/core/result.dart';

import 'sync_service_test.mocks.dart';

@GenerateMocks([
  TaskRepository,
  AccountRepository,
  CalendarRepository,
  CategoryRepository,
  LocalStorageService,
  CalDAVService,
])
void main() {
  group('SyncService', () {
    late SyncService syncService;
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockLocalStorageService mockLocalStorage;

    // Test data
    late CaldavAccount testAccount;
    late List<Task> testTasks;

    setUp(() {
      mockTaskRepository = MockTaskRepository();
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockCategoryRepository = MockCategoryRepository();
      mockLocalStorage = MockLocalStorageService();

      syncService = SyncService(
        taskRepository: mockTaskRepository,
        accountRepository: mockAccountRepository,
        calendarRepository: mockCalendarRepository,
        categoryRepository: mockCategoryRepository,
        localStorage: mockLocalStorage,
      );

      // Create test account
      testAccount = CaldavAccount(
        id: 'test-account-id',
        providerType: 'custom',
        serverUrl: 'https://example.com/caldav/',
        username: 'testuser',
        password: 'testpass',
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        isActive: true,
      );

      // Create test tasks
      testTasks = [
        Task(
          uid: 'task-1',
          summary: 'Test Task 1',
          description: 'First test task',
          status: 'NEEDS-ACTION',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          flowitValidator: 'default',
        ),
        Task(
          uid: 'task-2',
          summary: 'Test Task 2',
          description: 'Second test task',
          status: 'IN-PROCESS',
          lastModified: DateTime.now(),
          created: DateTime.now(),
          dtstamp: DateTime.now(),
          due: DateTime.now().add(const Duration(days: 1)),
          flowitValidator: 'default',
        ),
      ];
    });

    group('initialization', () {
      test('should initialize successfully with active account', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));
        when(mockLocalStorage.getAll<Map<String, dynamic>>('sync_queue'))
            .thenAnswer((_) async => const Result.success([]));
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => const Result.success([]));
        when(mockTaskRepository.getAll())
            .thenAnswer((_) async => const Result.success([]));
        when(mockLocalStorage.debugAllBoxes())
            .thenAnswer((_) async {});
        when(mockLocalStorage.getAll<CaldavAccount>('accounts'))
            .thenAnswer((_) async => const Result.success([]));

        // Act
        final result = await syncService.initialize();

        // Assert
        final isSuccess = result.when(
          success: (_) => true,
          failure: (_) => false,
        );
        expect(isSuccess, true);
        // Note: getActiveAccount is called twice - once in initialize, once in syncAllActiveCaldav
        verify(mockAccountRepository.getActiveAccount()).called(2);
      });

      test('should initialize successfully without active account', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => const Result.success(null));

        // Act
        final result = await syncService.initialize();

        // Assert
        final isSuccess = result.when(
          success: (_) => true,
          failure: (_) => false,
        );
        expect(isSuccess, true);
        verify(mockAccountRepository.getActiveAccount()).called(2);
      });

      test('should handle account repository failure', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(Failure(
                  message: 'Database error',
                  exception: Exception('DB error'),
                )));

        // Act
        final result = await syncService.initialize();

        // Assert - Should still succeed but log warning
        final isSuccess = result.when(
          success: (_) => true,
          failure: (_) => false,
        );
        expect(isSuccess, true);
        verify(mockAccountRepository.getActiveAccount()).called(2);
      });
    });

    group('syncAllActiveCaldav', () {
      test('should prevent multiple concurrent syncs', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));
        when(mockLocalStorage.getAll<Map<String, dynamic>>('sync_queue'))
            .thenAnswer((_) async => const Result.success([]));
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => const Result.success([]));
        when(mockTaskRepository.getAll())
            .thenAnswer((_) async => const Result.success([]));
        when(mockLocalStorage.debugAllBoxes())
            .thenAnswer((_) async {});
        when(mockLocalStorage.getAll<CaldavAccount>('accounts'))
            .thenAnswer((_) async => const Result.success([]));

        // Start first sync (will be slow)
        final future1 = syncService.syncAllActiveCaldav();
        
        // Start second sync immediately  
        final result2 = await syncService.syncAllActiveCaldav();

        // Assert second sync is rejected
        final isFailure = result2.when(
          success: (_) => false,
          failure: (failure) => failure.message.contains('already in progress'),
        );
        expect(isFailure, true);

        // Clean up first sync
        await future1;
      });

      test('should handle missing active account', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => const Result.success(null));

        // Act
        final result = await syncService.syncAllActiveCaldav();

        // Assert
        final isFailure = result.when(
          success: (_) => false,
          failure: (failure) => failure.message.contains('No active CalDAV account'),
        );
        expect(isFailure, true);
        expect(syncService.status, SyncStatus.offline);
      });

      test('should handle account repository failure', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.failure(Failure(
                  message: 'Account fetch failed',
                  exception: Exception('Fetch error'),
                )));

        // Act
        final result = await syncService.syncAllActiveCaldav();

        // Assert
        final isFailure = result.when(
          success: (_) => false,
          failure: (_) => true,
        );
        expect(isFailure, true);
        expect(syncService.status, SyncStatus.error);
      });
    });

    group('sync process', () {
      setUp(() {
        // Common setup for sync process tests
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));
        when(mockLocalStorage.getAll<Map<String, dynamic>>('sync_queue'))
            .thenAnswer((_) async => const Result.success([]));
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => const Result.success([]));
        when(mockTaskRepository.getAll())
            .thenAnswer((_) async => const Result.success([]));
      });

      test('should update sync status during operation', () async {
        // Arrange
        final statusUpdates = <SyncStatus>[];
        syncService.statusStream.listen((status) {
          statusUpdates.add(status);
        });

        when(mockTaskRepository.getAll())
            .thenAnswer((_) async => const Result.success([]));

        // Act
        await syncService.syncAllActiveCaldav();

        // Assert
        expect(statusUpdates, contains(SyncStatus.syncing));
      });
    });



    group('status and progress streams', () {
      test('should provide status stream', () {
        expect(syncService.statusStream, isA<Stream<SyncStatus>>());
        expect(syncService.progressStream, isA<Stream<double>>());
      });

      test('should provide current status', () {
        expect(syncService.status, SyncStatus.idle);
        expect(syncService.lastSyncTime, isNull);
      });
    });

    group('error handling', () {
      test('should handle sync queue processing errors', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));
        when(mockLocalStorage.getAll<Map<String, dynamic>>('sync_queue'))
            .thenAnswer((_) async => Result.failure(Failure(
                  message: 'Storage error',
                  exception: Exception('Storage error'),
                )));
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => const Result.success([]));
        when(mockTaskRepository.getAll())
            .thenAnswer((_) async => const Result.success([]));

        // Act
        final result = await syncService.syncAllActiveCaldav();

        // Assert - Sync should complete but with errors
        final syncResult = result.when(
          success: (syncResult) => syncResult,
          failure: (_) => null,
        );
        expect(syncResult, isNotNull);
        expect(syncResult!.errors.isNotEmpty, true);
        expect(syncResult.errors.any((error) => error.contains('Failed to load sync queue')), true);
        expect(syncService.status, SyncStatus.error);
      });

      test('should handle task repository errors', () async {
        // Arrange
        when(mockAccountRepository.getActiveAccount())
            .thenAnswer((_) async => Result.success(testAccount));
        when(mockLocalStorage.getAll<Map<String, dynamic>>('sync_queue'))
            .thenAnswer((_) async => const Result.success([]));
        when(mockCalendarRepository.getProjectCalendars())
            .thenAnswer((_) async => const Result.success([]));
        when(mockTaskRepository.getAll())
            .thenAnswer((_) async => Result.failure(Failure(
                  message: 'Repository error',
                  exception: Exception('Repository error'),
                )));

        // Act
        final result = await syncService.syncAllActiveCaldav();

        // Assert - Sync should complete but with errors due to no calendars
        final syncResult = result.when(
          success: (syncResult) => syncResult,
          failure: (_) => null,
        );
        expect(syncResult, isNotNull);
        expect(syncResult!.errors.isNotEmpty, true);
        expect(syncResult.errors.any((error) => error.contains('No calendars selected')), true);
        expect(syncService.status, SyncStatus.error);
      });
    });

    // TODO: Add calendar selection sync tests when new calendar architecture is finalized
  });

  group('SyncQueueItem', () {
    test('should create SyncQueueItem correctly', () {
      final item = SyncQueueItem(
        id: 'test-id',
        operation: SyncOperation.create,
        itemId: 'item-id',
        data: {'test': 'data'},
        createdAt: DateTime.now(),
      );

      expect(item.id, 'test-id');
      expect(item.operation, SyncOperation.create);
      expect(item.retryCount, 0);
    });

    test('should copy with new retry count', () {
      final original = SyncQueueItem(
        id: 'test-id',
        operation: SyncOperation.update,
        itemId: 'item-id',
        data: {'test': 'data'},
        createdAt: DateTime.now(),
      );

      final copied = original.copyWith(retryCount: 3);

      expect(copied.id, original.id);
      expect(copied.operation, original.operation);
      expect(copied.retryCount, 3);
    });
  });

  group('SyncResult', () {
    test('should create SyncResult correctly', () {
      final result = SyncResult(
        success: true,
        syncedItems: 5,
        failedItems: 1,
        errors: ['Error 1'],
        syncTime: DateTime.now(),
      );

      expect(result.success, true);
      expect(result.syncedItems, 5);
      expect(result.failedItems, 1);
      expect(result.errors, ['Error 1']);
    });
  });
} 
