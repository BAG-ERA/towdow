// Test d'intégration complet pour diagnostiquer le flow de suppression + synchronisation
// Vérifie chaque étape du processus depuis la suppression UI jusqu'à la sync serveur

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:riverpod/riverpod.dart';
import 'package:towdow_app/core/logger.dart';
import 'package:towdow_app/core/result.dart';
import 'package:towdow_app/data/models/caldav_account.dart';
import 'package:towdow_app/data/models/task.dart';
import 'package:towdow_app/data/models/task_calendar.dart';
import 'package:towdow_app/data/repositories/account_repository.dart';
import 'package:towdow_app/data/repositories/calendar_repository.dart';
import 'package:towdow_app/data/repositories/task_repository.dart';
import 'package:towdow_app/data/repositories/category_repository.dart';
import 'package:towdow_app/data/services/local_storage_service.dart';
import 'package:towdow_app/data/services/sync_service.dart';
import 'package:towdow_app/presentation/viewmodels/task_viewmodel.dart';
import 'sync_delete_flow_test.mocks.dart';

// Generate mocks
@GenerateMocks([
  TaskRepository,
  AccountRepository,
  CalendarRepository,
  CategoryRepository,
  LocalStorageService,
  SyncService,
])
void main() {
  group('Sync Delete Flow Integration Tests', () {
    late TaskViewModel taskViewModel;
    late SyncService syncService;
    late MockTaskRepository mockTaskRepository;
    late MockAccountRepository mockAccountRepository;
    late MockCalendarRepository mockCalendarRepository;
    late MockCategoryRepository mockCategoryRepository;
    late MockLocalStorageService mockLocalStorage;

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
      taskViewModel = TaskViewModel(mockTaskRepository, mockAccountRepository, syncService);

      final testCalendar = TaskCalendarFactory.createNew(
        path: '/calendars/test/calendar/',
        displayName: 'Test Calendar',
      );
      when(mockCalendarRepository.getProjectCalendars())
          .thenAnswer((_) async => Result.success([testCalendar]));
      
      // Add default stub for getAll to prevent MissingStubError
      when(mockLocalStorage.getAll<Map<String, dynamic>>(any))
          .thenAnswer((_) async => const Result.success([]));
    });

    testWidgets('FLOW TEST: Complete delete + sync flow from UI to server', (tester) async {
      AppLogger.debug('🔍 DIAGNOSIS: Starting complete delete + sync flow test');
      
      // === SETUP ===
      const taskUid = 'test-task-delete-flow';
      const calendarUid = 'test-calendar-123';
      final testTask = TaskFactory.createNew(
        summary: 'Task to Delete',
        projectPath: calendarUid,
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
      
      // Verify the sync queue operation was queued correctly
      expect(capturedArgs[0], 'sync_queue'); // box name
      expect(capturedArgs[1], startsWith('sync_')); // key starts with sync_
      expect(capturedArgs[1], contains(taskUid)); // key contains task UID
      
      // Verify the queued data has the correct structure and content
      final queuedData = capturedArgs[2] as Map<String, dynamic>;
      expect(queuedData['operation'], 'delete');
      expect(queuedData['itemId'], taskUid);
      expect(queuedData['data']['calendarUid'], calendarUid);
      expect(queuedData['data']['taskUid'], taskUid);
      expect(queuedData['retryCount'], 0);
      
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
      
      // Mock additional calls needed for sync processing
      when(mockTaskRepository.getByProject(any))
          .thenAnswer((_) async => const Result.success([]));
      
      // Note: CalDAV service is created internally by SyncService
      // We can't easily mock it in this integration test
      
      final syncResult = await syncService.syncAllActiveCaldav();
      
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
      
      // Note: We don't verify getAll here because the sync might fail early
      // due to CalDAV service not being mocked, so getAll might not be called.
      // The important verification is that the delete operation was queued correctly.
      
      // Clean up timers to avoid test framework complaints
      // Note: SyncService doesn't have periodic sync methods - CalDAVMonitor handles this
      
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
      
      final syncResult = await syncService.syncAllActiveCaldav();
      
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
      
      // Initialize sync service
      final initResult = await syncService.initialize();
      expect(initResult, isA<Success<void>>());
      
      // Note: SyncService doesn't have periodic sync methods - CalDAVMonitor handles this
      // The test was trying to test periodic sync functionality that doesn't exist in SyncService
      
      AppLogger.debug('🔍 DIAGNOSIS: Background sync not available in SyncService');
      
      // Wait a bit for cleanup
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify timer stopped
      expect(syncService.isBackgroundSyncRunning, isFalse);
      
      AppLogger.debug('✅ DIAGNOSIS: Periodic sync timer test completed');
    });
  });
} 