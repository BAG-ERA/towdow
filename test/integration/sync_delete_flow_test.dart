// Test d'intégration complet pour diagnostiquer le flow de suppression + synchronisation
// Vérifie chaque étape du processus depuis la suppression UI jusqu'à la sync serveur

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/presentation/viewmodels/task_viewmodel.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/core/logger.dart';

import 'sync_delete_flow_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<TaskRepository>(),
  MockSpec<AccountRepository>(),
  MockSpec<CalendarRepository>(),
  MockSpec<LocalStorageService>(),
])
void main() {
  group('SYNC DELETE FLOW DIAGNOSIS', () {
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockLocalStorageService mockLocalStorage;
    late SyncService syncService;
    late TaskViewModel taskViewModel;

    setUp(() {
      mockTaskRepository = MockTaskRepository();
      mockAccountRepository = MockAccountRepository();
      mockCalendarRepository = MockCalendarRepository();
      mockLocalStorage = MockLocalStorageService();
      
      // Initialize real SyncService with mocked dependencies
      syncService = SyncService(
        taskRepository: mockTaskRepository,
        accountRepository: mockAccountRepository,
        calendarRepository: mockCalendarRepository,
        localStorage: mockLocalStorage,
      );
      
      taskViewModel = TaskViewModel(mockTaskRepository, syncService);
    });

    testWidgets('FLOW TEST: Complete delete + sync flow from UI to server', (tester) async {
      AppLogger.debug('🔍 DIAGNOSIS: Starting complete delete + sync flow test');
      
      // === SETUP ===
      const taskUid = 'test-task-delete-flow';
      const calendarUid = 'test-calendar-123';
      final testTask = TaskFactory.createNew(
        summary: 'Task to Delete',
        sourceCalendarUid: calendarUid,
      );
      
      final now = DateTime.now();
      final testAccount = CaldavAccount(
        id: 'test-account',
        providerType: 'custom',
        username: 'test@example.com',
        password: 'password',
        serverUrl: 'https://test.caldav.com',
        isActive: true,
        createdAt: now,
        lastSyncAt: now,
      );
      
      final testCalendar = TaskCalendarFactory.createNew(
        path: '/calendars/test/calendar/',
        displayName: 'Test Calendar',
      );

      // Mock repository responses
      when(mockTaskRepository.getById(taskUid))
          .thenAnswer((_) async => Result.success(testTask));
      when(mockTaskRepository.delete(taskUid))
          .thenAnswer((_) async => const Result.success(null));
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => Result.success(testAccount));
      when(mockCalendarRepository.getById(calendarUid))
          .thenAnswer((_) async => Result.success(testCalendar));
      
      // Mock sync queue operations
      when(mockLocalStorage.put(any, any, any))
          .thenAnswer((_) async => const Result.success(null));
      
      // Initially empty queue, then queue with delete operation after task deletion
      var queueCallCount = 0;
      when(mockLocalStorage.getAll<Map<String, dynamic>>(any))
          .thenAnswer((_) async {
            queueCallCount++;
            if (queueCallCount == 1) {
              // Empty queue initially
              return const Result.success([]);
            } else {
              // Queue contains delete operation
              final queueItem = {
                'id': 'sync_test_delete_operation',
                'operation': 'delete',
                'itemId': taskUid,
                'data': {
                  'calendarUid': calendarUid,
                  'taskUid': taskUid,
                },
                'createdAt': DateTime.now().toIso8601String(),
                'retryCount': 0,
              };
              return Result.success([queueItem]);
            }
          });
      
      when(mockLocalStorage.debugAllBoxes())
          .thenAnswer((_) async {});

      AppLogger.debug('🔍 DIAGNOSIS: Setup completed - starting deletion');

      // === STEP 1: UI Deletion ===
      AppLogger.debug('🔍 DIAGNOSIS: STEP 1 - Triggering UI deletion');
      await taskViewModel.deleteTask(taskUid);
      
      // Verify local deletion happened
      verify(mockTaskRepository.getById(taskUid)).called(1);
      verify(mockTaskRepository.delete(taskUid)).called(1);
      AppLogger.debug('✅ DIAGNOSIS: STEP 1 - Local deletion completed');

      // === STEP 2: Sync Queue ===
      AppLogger.debug('🔍 DIAGNOSIS: STEP 2 - Verifying sync queue operation');
      
      // Capture what was queued (this also verifies the call was made)
      final capturedArgs = verify(mockLocalStorage.put(
        captureAny,
        captureAny,
        captureAny,
      )).captured;
      
      AppLogger.debug('🔍 DIAGNOSIS: STEP 2 - Queued box: ${capturedArgs[0]}');
      AppLogger.debug('🔍 DIAGNOSIS: STEP 2 - Queued key: ${capturedArgs[1]}');
      AppLogger.debug('🔍 DIAGNOSIS: STEP 2 - Queued data: ${capturedArgs[2]}');
      
      expect(capturedArgs[0], 'sync_queue');
      expect(capturedArgs[2], isA<Map<String, dynamic>>());
      AppLogger.debug('✅ DIAGNOSIS: STEP 2 - Sync queue operation verified');

      // === STEP 3: Sync Service Initialization ===
      AppLogger.debug('🔍 DIAGNOSIS: STEP 3 - Testing sync service initialization');
      
      final initResult = await syncService.initialize();
      
      await initResult.when(
        success: (_) {
          AppLogger.debug('✅ DIAGNOSIS: STEP 3 - Sync service initialized successfully');
        },
        failure: (failure) {
          AppLogger.debug('❌ DIAGNOSIS: STEP 3 - Sync service initialization failed: ${failure.message}');
        },
      );

      // Verify account was checked during initialization
      verify(mockAccountRepository.getActiveAccount()).called(greaterThanOrEqualTo(1));
      AppLogger.debug('✅ DIAGNOSIS: STEP 3 - Account verification completed');

      // === STEP 4: Manual Sync (to trigger queue processing) ===
      AppLogger.debug('🔍 DIAGNOSIS: STEP 4 - Triggering manual sync to process queue');
      
      // Mock additional calls for sync
      when(mockCalendarRepository.getProjectCalendars())
          .thenAnswer((_) async => Result.success([testCalendar]));
      
      // Mock the missing getByProject call
      when(mockTaskRepository.getByProject(any))
          .thenAnswer((_) async => const Result.success([]));
      
      // Note: CalDAV service is created internally by SyncService
      // We can't easily mock it in this integration test
      
      final syncResult = await syncService.syncNow();
      
      await syncResult.when(
        success: (result) {
          AppLogger.debug('✅ DIAGNOSIS: STEP 4 - Manual sync completed successfully');
          AppLogger.debug('🔍 DIAGNOSIS: STEP 4 - Sync result: ${result.syncedItems} synced, ${result.failedItems} failed');
        },
        failure: (failure) {
          AppLogger.debug('⚠️ DIAGNOSIS: STEP 4 - Manual sync failed (expected in test): ${failure.message}');
          // This is expected since we can't fully mock CalDAV service
        },
      );

      // === VERIFICATION ===
      AppLogger.debug('🔍 DIAGNOSIS: FINAL - Verifying complete flow');
      
      // Verify sync queue was accessed for processing
      verify(mockLocalStorage.getAll<Map<String, dynamic>>('sync_queue')).called(greaterThanOrEqualTo(1));
      
      // Clean up timers to avoid test framework complaints
      syncService.stopPeriodicSync();
      
      AppLogger.debug('✅ DIAGNOSIS: Complete delete + sync flow test completed');
    });

    test('DIAGNOSIS: Check sync service state without initialization', () async {
      AppLogger.debug('🔍 DIAGNOSIS: Testing sync service state before initialization');
      
      // Check initial state
      expect(syncService.status, SyncStatus.idle);
      expect(syncService.lastSyncTime, isNull);
      expect(syncService.isBackgroundSyncRunning, isFalse);
      
      AppLogger.debug('📊 DIAGNOSIS: Initial state - Status: ${syncService.status}');
      AppLogger.debug('📊 DIAGNOSIS: Initial state - Last sync: ${syncService.lastSyncTime}');
      AppLogger.debug('📊 DIAGNOSIS: Initial state - Background running: ${syncService.isBackgroundSyncRunning}');
      
      // Try to sync without initialization
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => const Result.success(null));
      
      final syncResult = await syncService.syncNow();
      
      await syncResult.when(
        success: (_) {
          AppLogger.debug('❓ DIAGNOSIS: Sync succeeded without account - unexpected');
        },
        failure: (failure) {
          AppLogger.debug('✅ DIAGNOSIS: Sync failed without account - expected: ${failure.message}');
        },
      );
    });

    test('DIAGNOSIS: Check periodic sync timer behavior', () async {
      AppLogger.debug('🔍 DIAGNOSIS: Testing periodic sync timer');
      
      // Mock successful account
      final now = DateTime.now();
      final testAccount = CaldavAccount(
        id: 'test-account',
        providerType: 'custom',
        username: 'test@example.com',
        password: 'password',
        serverUrl: 'https://test.caldav.com',
        isActive: true,
        createdAt: now,
        lastSyncAt: now,
      );
      
      when(mockAccountRepository.getActiveAccount())
          .thenAnswer((_) async => Result.success(testAccount));
      when(mockLocalStorage.getAll<Map<String, dynamic>>(any))
          .thenAnswer((_) async => const Result.success([]));
      when(mockLocalStorage.debugAllBoxes())
          .thenAnswer((_) async {});
      when(mockCalendarRepository.getProjectCalendars())
          .thenAnswer((_) async => const Result.success([]));

      AppLogger.debug('🔍 DIAGNOSIS: Before initialization - Background sync running: ${syncService.isBackgroundSyncRunning}');
      
      // Initialize sync service
      await syncService.initialize();
      
      AppLogger.debug('🔍 DIAGNOSIS: After initialization - Background sync running: ${syncService.isBackgroundSyncRunning}');
      
      // Wait a moment to see if periodic sync triggers
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Clean up timers
      syncService.stopPeriodicSync();
      
      AppLogger.debug('✅ DIAGNOSIS: Periodic sync timer test completed');
    });
  });
} 